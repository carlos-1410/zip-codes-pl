# frozen_string_literal: true

require "test_helper"

class BuilderTest < Minitest::Test
  def setup
    @archive = TestHelpers.geonames_archive
  end

  def test_writes_the_dataset_and_its_manifest
    in_output_dir do |config|
      result = ZipCodes::PL::Builder.new(config: config, source: TestHelpers::StubSource.new(archive: @archive),
                                         administrative_names_source: false).call

      assert result.built?
      assert_path_exists config.data_path
      assert_path_exists config.manifest_path
      assert_equal 7, result.manifest.row_count
      assert_equal ZipCodes::PL::VERSION, result.manifest.gem_version
      assert_match(/GeoNames/, result.manifest.attribution)
    end
  end

  def test_replaces_source_county_and_commune_names_with_official_ones
    in_output_dir do |config|
      names = ZipCodes::PL::Sources::PocztaPolska::Names.new(
        counties: { "3013" => "leszczyński" },
        communes: { "301302" => "Lipno" }
      )
      names_source = Object.new
      names_source.define_singleton_method(:fetch) { names }
      rows = [TestHelpers::SAMPLE_ROWS[2]]
      source = TestHelpers::StubSource.new(archive: TestHelpers.geonames_archive(rows: rows))

      ZipCodes::PL::Builder.new(config: config, source: source, administrative_names_source: names_source).call
      record = ZipCodes::PL::Reader.new(config.data_path).first

      assert_equal "powiat leszczyński", record.county
      assert_equal "Lipno", record.commune
      assert_match(/Poczta Polska/, ZipCodes::PL::Manifest.read(config.manifest_path).attribution)
    end
  end

  def test_second_run_asks_the_server_with_the_stored_etag
    in_output_dir do |config|
      source = TestHelpers::StubSource.new(archive: @archive, etag: "\"v1\"")
      ZipCodes::PL::Builder.new(config: config, source: source, administrative_names_source: false).call
      ZipCodes::PL::Builder.new(config: config, source: source, administrative_names_source: false).call

      assert_equal [nil, "\"v1\""], source.requested_etags
    end
  end

  def test_unchanged_source_leaves_the_dataset_alone
    in_output_dir do |config|
      first = TestHelpers::StubSource.new(archive: @archive, etag: "\"v1\"")
      ZipCodes::PL::Builder.new(config: config, source: first, administrative_names_source: false).call
      written_at = File.mtime(config.data_path)

      second = TestHelpers::StubSource.new(archive: @archive, etag: "\"v1\"", not_modified_for: "\"v1\"")
      result = ZipCodes::PL::Builder.new(config: config, source: second, administrative_names_source: false).call

      assert result.up_to_date?
      assert_equal written_at, File.mtime(config.data_path)
      assert_equal 7, result.manifest.row_count
    end
  end

  def test_unchanged_source_does_not_fetch_administrative_names
    in_output_dir do |config|
      source = TestHelpers::StubSource.new(archive: @archive, etag: "\"v1\"", not_modified_for: "\"v1\"")
      ZipCodes::PL::Builder.new(config: config, source: source, administrative_names_source: false).call
      names_source = Object.new
      names_source.define_singleton_method(:fetch) { raise "should not fetch names" }

      result = ZipCodes::PL::Builder.new(
        config: config,
        source: source,
        administrative_names_source: names_source
      ).call

      assert result.up_to_date?
    end
  end

  def test_refuses_an_incomplete_administrative_names_dictionary
    in_output_dir do |config|
      names = ZipCodes::PL::Sources::PocztaPolska::Names.new(counties: {}, communes: {})
      names_source = Object.new
      names_source.define_singleton_method(:fetch) { names }
      source = TestHelpers::StubSource.new(archive: @archive)

      error = assert_raises(ZipCodes::PL::DownloadError) do
        ZipCodes::PL::Builder.new(
          config: config,
          source: source,
          administrative_names_source: names_source
        ).call
      end

      assert_match(/0403/, error.message)
      refute_path_exists config.data_path
    end
  end

  def test_failed_refresh_keeps_the_previous_dataset_and_manifest
    in_output_dir do |config|
      first = TestHelpers::StubSource.new(archive: @archive, etag: "\"v1\"")
      ZipCodes::PL::Builder.new(config: config, source: first, administrative_names_source: false).call
      previous_data = File.binread(config.data_path)
      previous_manifest = File.binread(config.manifest_path)
      broken_rows = [TestHelpers::SAMPLE_ROWS.first, "PL\t86-010"]
      broken_archive = TestHelpers.geonames_archive(rows: broken_rows)
      broken = TestHelpers::StubSource.new(archive: broken_archive, etag: "\"v2\"")

      assert_raises(ZipCodes::PL::DownloadError) do
        ZipCodes::PL::Builder.new(config: config, source: broken, administrative_names_source: false).call
      end

      assert_equal previous_data, File.binread(config.data_path)
      assert_equal previous_manifest, File.binread(config.manifest_path)
      assert_empty Dir.glob(File.join(config.output_dir, "*.tmp"))
    end
  end

  def test_failed_administrative_names_refresh_keeps_the_previous_files
    in_output_dir do |config|
      source = TestHelpers::StubSource.new(archive: @archive, etag: "\"v1\"")
      ZipCodes::PL::Builder.new(config: config, source: source, administrative_names_source: false).call
      previous_data = File.binread(config.data_path)
      previous_manifest = File.binread(config.manifest_path)
      failed_names = Object.new
      failed_names.define_singleton_method(:fetch) { raise ZipCodes::PL::DownloadError, "Poczta nie działa" }

      assert_raises(ZipCodes::PL::DownloadError) do
        ZipCodes::PL::Builder.new(
          config: config,
          source: source,
          administrative_names_source: failed_names
        ).call
      end

      assert_equal previous_data, File.binread(config.data_path)
      assert_equal previous_manifest, File.binread(config.manifest_path)
    end
  end

  # A cached etag with no file behind it would answer "unchanged" and leave the
  # caller with nothing to read.
  def test_missing_data_file_forces_a_fresh_download
    in_output_dir do |config|
      source = TestHelpers::StubSource.new(archive: @archive, etag: "\"v1\"", not_modified_for: "\"v1\"")
      ZipCodes::PL::Builder.new(config: config, source: source, administrative_names_source: false).call
      File.delete(config.data_path)

      result = ZipCodes::PL::Builder.new(config: config, source: source, administrative_names_source: false).call

      assert result.built?
      assert_path_exists config.data_path
    end
  end

  def test_leaves_no_temporary_file_behind
    in_output_dir do |config|
      ZipCodes::PL::Builder.new(config: config, source: TestHelpers::StubSource.new(archive: @archive),
                                administrative_names_source: false).call

      assert_empty Dir.glob("#{config.data_path}.tmp")
    end
  end

  def test_creates_the_output_directory
    Dir.mktmpdir do |dir|
      config = ZipCodes::PL::Configuration.new
      config.output_dir = File.join(dir, "deeply", "nested")

      ZipCodes::PL::Builder.new(config: config, source: TestHelpers::StubSource.new(archive: @archive),
                                administrative_names_source: false).call

      assert_path_exists config.data_path
    end
  end

  # Tying the names source to whether a row source was injected meant any caller
  # passing its own source silently lost the Polish names and the attribution.
  def test_names_source_defaults_independently_of_the_row_source
    builder = ZipCodes::PL::Builder.new(config: ZipCodes::PL::Configuration.new,
                                        source: TestHelpers::StubSource.new(archive: @archive))

    assert_instance_of ZipCodes::PL::Sources::PocztaPolska,
                       builder.send(:administrative_names_source)
  end

  def test_names_can_be_switched_off_explicitly
    builder = ZipCodes::PL::Builder.new(config: ZipCodes::PL::Configuration.new,
                                        source: TestHelpers::StubSource.new(archive: @archive),
                                        administrative_names_source: false)

    assert_nil builder.send(:administrative_names_source)
  end

  private

  def in_output_dir
    Dir.mktmpdir do |dir|
      config = ZipCodes::PL::Configuration.new
      config.output_dir = dir
      yield config
    end
  end
end
