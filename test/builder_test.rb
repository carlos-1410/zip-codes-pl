# frozen_string_literal: true

require "test_helper"

class BuilderTest < Minitest::Test
  def setup
    @archive = TestHelpers.geonames_archive
  end

  def test_writes_the_dataset_and_its_manifest
    in_output_dir do |config|
      result = PlZipCodes::Builder.new(config: config, source: TestHelpers::StubSource.new(archive: @archive)).call

      assert result.built?
      assert_path_exists config.data_path
      assert_path_exists config.manifest_path
      assert_equal 7, result.manifest.row_count
      assert_equal PlZipCodes::VERSION, result.manifest.gem_version
      assert_match(/GeoNames/, result.manifest.attribution)
    end
  end

  def test_second_run_asks_the_server_with_the_stored_etag
    in_output_dir do |config|
      source = TestHelpers::StubSource.new(archive: @archive, etag: "\"v1\"")
      PlZipCodes::Builder.new(config: config, source: source).call
      PlZipCodes::Builder.new(config: config, source: source).call

      assert_equal [nil, "\"v1\""], source.requested_etags
    end
  end

  def test_unchanged_source_leaves_the_dataset_alone
    in_output_dir do |config|
      first = TestHelpers::StubSource.new(archive: @archive, etag: "\"v1\"")
      PlZipCodes::Builder.new(config: config, source: first).call
      written_at = File.mtime(config.data_path)

      second = TestHelpers::StubSource.new(archive: @archive, etag: "\"v1\"", not_modified_for: "\"v1\"")
      result = PlZipCodes::Builder.new(config: config, source: second).call

      assert result.up_to_date?
      assert_equal written_at, File.mtime(config.data_path)
      assert_equal 7, result.manifest.row_count
    end
  end

  def test_failed_refresh_keeps_the_previous_dataset_and_manifest
    in_output_dir do |config|
      first = TestHelpers::StubSource.new(archive: @archive, etag: "\"v1\"")
      PlZipCodes::Builder.new(config: config, source: first).call
      previous_data = File.binread(config.data_path)
      previous_manifest = File.binread(config.manifest_path)
      broken_rows = [TestHelpers::SAMPLE_ROWS.first, "PL\t86-010"]
      broken_archive = TestHelpers.geonames_archive(rows: broken_rows)
      broken = TestHelpers::StubSource.new(archive: broken_archive, etag: "\"v2\"")

      assert_raises(PlZipCodes::DownloadError) do
        PlZipCodes::Builder.new(config: config, source: broken).call
      end

      assert_equal previous_data, File.binread(config.data_path)
      assert_equal previous_manifest, File.binread(config.manifest_path)
      assert_empty Dir.glob(File.join(config.output_dir, "*.tmp"))
    end
  end

  # A cached etag with no file behind it would answer "unchanged" and leave the
  # caller with nothing to read.
  def test_missing_data_file_forces_a_fresh_download
    in_output_dir do |config|
      source = TestHelpers::StubSource.new(archive: @archive, etag: "\"v1\"", not_modified_for: "\"v1\"")
      PlZipCodes::Builder.new(config: config, source: source).call
      File.delete(config.data_path)

      result = PlZipCodes::Builder.new(config: config, source: source).call

      assert result.built?
      assert_path_exists config.data_path
    end
  end

  def test_leaves_no_temporary_file_behind
    in_output_dir do |config|
      PlZipCodes::Builder.new(config: config, source: TestHelpers::StubSource.new(archive: @archive)).call

      assert_empty Dir.glob("#{config.data_path}.tmp")
    end
  end

  def test_creates_the_output_directory
    Dir.mktmpdir do |dir|
      config = PlZipCodes::Configuration.new
      config.output_dir = File.join(dir, "deeply", "nested")

      PlZipCodes::Builder.new(config: config, source: TestHelpers::StubSource.new(archive: @archive)).call

      assert_path_exists config.data_path
    end
  end

  private

  def in_output_dir
    Dir.mktmpdir do |dir|
      config = PlZipCodes::Configuration.new
      config.output_dir = dir
      yield config
    end
  end
end
