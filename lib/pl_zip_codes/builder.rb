# frozen_string_literal: true

require "fileutils"
require "time"
require "zlib"

module PlZipCodes
  # Downloads the source and writes the dataset into the configured directory.
  class Builder
    Result = Data.define(:status, :data_path, :manifest) do
      def built? = status == :built
      def up_to_date? = status == :up_to_date
    end

    def initialize(config: PlZipCodes.config, source: nil)
      @config = config
      @source = source || Sources::Geonames.new(config: config)
    end

    def call
      previous = Manifest.read(config.manifest_path)
      download = source.download(etag: reusable_etag(previous))
      return Result.new(status: :up_to_date, data_path: config.data_path, manifest: previous) if download.nil?

      write(download)
    end

    private

    attr_reader :config, :source

    # Only claim a cached copy when the data file it describes is still there;
    # a 304 with no file on disk would leave the caller with nothing.
    def reusable_etag(previous)
      return nil if previous.nil? || !File.exist?(config.data_path)

      previous.etag
    end

    def write(download)
      FileUtils.mkdir_p(config.output_dir)
      row_count = write_data(download)
      manifest = build_manifest(download, row_count).write(config.manifest_path)

      Result.new(status: :built, data_path: config.data_path, manifest: manifest)
    end

    # Written to a temporary file and renamed, so an interrupted run never
    # leaves a half-written dataset where a complete one used to be.
    def write_data(download)
      temporary_path = "#{config.data_path}.tmp"
      row_count = 0

      Zlib::GzipWriter.open(temporary_path) do |gzip|
        gzip.puts(Record::COLUMNS.join("\t"))
        source.each_record(download.body) do |record|
          gzip.puts(record.to_row.join("\t"))
          row_count += 1
        end
      end

      File.rename(temporary_path, config.data_path)
      row_count
    ensure
      FileUtils.rm_f(temporary_path) if temporary_path && File.exist?(temporary_path)
    end

    def build_manifest(download, row_count)
      Manifest.new(
        source_url: config.source_url,
        attribution: Sources::Geonames::ATTRIBUTION,
        etag: download.etag,
        last_modified: download.last_modified,
        row_count: row_count,
        built_at: Time.now.utc.iso8601,
        gem_version: VERSION,
        format_version: Manifest::FORMAT_VERSION
      )
    end
  end
end
