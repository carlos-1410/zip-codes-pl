# frozen_string_literal: true

require "fileutils"
require "time"

module ZipCodes
  module PL
    # Downloads the source and writes the dataset into the configured directory.
    class Builder
      Result = Data.define(:status, :data_path, :manifest) do
        def built? = status == :built
        def up_to_date? = status == :up_to_date
      end

      # `administrative_names_source: false` builds with the raw upstream labels.
      # The two sources default independently: tying the names to whether a custom
      # row source was injected silently dropped the enrichment, and the manifest
      # attribution with it.
      def initialize(config: ZipCodes::PL.config, source: nil, administrative_names_source: nil)
        @config = config
        @source = source || Sources::Geonames.new(config: config)
        @administrative_names_source =
          case administrative_names_source
          when nil then Sources::PocztaPolska.new(config: config)
          when false then nil
          else administrative_names_source
          end
      end

      def call
        previous = Manifest.read(config.manifest_path)
        download = source.download(etag: reusable_etag(previous))
        return Result.new(status: :up_to_date, data_path: config.data_path, manifest: previous) if download.nil?

        names = administrative_names_source&.fetch
        write(download, names)
      end

      private

      attr_reader :administrative_names_source, :config, :source

      # Only claim a cached copy when the data file it describes is still there;
      # a 304 with no file on disk would leave the caller with nothing.
      def reusable_etag(previous)
        return nil if previous.nil? || !File.exist?(config.data_path)

        previous.etag
      end

      def write(download, names)
        FileUtils.mkdir_p(config.output_dir)
        row_count = write_data(download, names)
        manifest = build_manifest(download, row_count, names).write(config.manifest_path)

        Result.new(status: :built, data_path: config.data_path, manifest: manifest)
      end

      # Written to a temporary file and renamed, so an interrupted run never
      # leaves a half-written dataset where a complete one used to be.
      def write_data(download, names)
        temporary_path = "#{config.data_path}.tmp"
        row_count = 0

        File.open(temporary_path, "w") do |file|
          file.puts(Record::COLUMNS.join("\t"))
          source.each_record(download.body) do |record|
            record = apply_administrative_names(record, names) if names
            file.puts(record.to_row.join("\t"))
            row_count += 1
          end
        end

        File.rename(temporary_path, config.data_path)
        row_count
      ensure
        FileUtils.rm_f(temporary_path) if temporary_path && File.exist?(temporary_path)
      end

      def apply_administrative_names(record, names)
        county = name_for!(names.counties, record.county_teryt, "county")
        commune = name_for!(names.communes, record.commune_teryt, "commune")
        county = "powiat #{county}" if county && record.county_teryt[2, 2].to_i < 60

        Record.new(**record.to_h, county: county, commune: commune)
      end

      def name_for!(names, code, level)
        return nil if code.nil?

        names.fetch(code) do
          raise DownloadError, "no #{level} name for TERYT code #{code} in the Poczta Polska response"
        end
      end

      def build_manifest(download, row_count, names)
        attribution = Sources::Geonames::ATTRIBUTION
        attribution = "#{attribution}; #{Sources::PocztaPolska::ATTRIBUTION}" if names

        Manifest.new(
          source_url: config.source_url,
          attribution: attribution,
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
end
