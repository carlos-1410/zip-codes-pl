# frozen_string_literal: true

require "net/http"
require "stringio"
require "uri"
require "zip"

module ZipCodes
  module PL
    module Sources
      # The GeoNames postal-code export for Poland: one tab separated row per
      # (postal code, place), carrying WGS84 coordinates and the TERYT county and
      # commune codes.
      class Geonames
        URL = "https://download.geonames.org/export/zip/PL.zip"
        ENTRY = "PL.txt"
        ATTRIBUTION = "GeoNames (https://www.geonames.org), CC BY 4.0"
        MAX_REDIRECTS = 3
        EXPECTED_FIELDS = 12

        Download = Data.define(:body, :etag, :last_modified)

        def initialize(config: ZipCodes::PL.config)
          @config = config
        end

        # Returns nil when the server reports the file is unchanged, which is what
        # makes re-running the rake task cheap.
        def download(etag: nil)
          response = get(URI.parse(config.source_url), etag: etag)
          return nil if response.is_a?(Net::HTTPNotModified)

          raise DownloadError, "#{config.source_url} answered #{response.code}" unless response.is_a?(Net::HTTPSuccess)

          Download.new(
            body: response.body,
            etag: response["etag"],
            last_modified: response["last-modified"]
          )
        end

        def each_record(archive, &block)
          return enum_for(:each_record, archive) unless block

          Zip::File.open_buffer(StringIO.new(archive)) do |zip|
            entry = zip.find_entry(ENTRY)
            raise DownloadError, "the archive has no #{ENTRY}" if entry.nil?

            entry.get_input_stream do |stream|
              # The entry stream yields ASCII-8BIT, and Polish names have to survive it.
              stream.each_line { |line| parse_line(line.force_encoding(Encoding::UTF_8), &block) }
            end
          end
        end

        private

        attr_reader :config

        def get(uri, etag:, redirects: 0)
          response = perform(uri, build_request(uri, etag))

          # 304 is a subclass of Net::HTTPRedirection, and it carries no Location.
          # Following it as a redirect is how the second run used to die.
          return response if response.is_a?(Net::HTTPNotModified)
          return response unless response.is_a?(Net::HTTPRedirection)
          raise DownloadError, "too many redirects from #{config.source_url}" if redirects >= MAX_REDIRECTS

          get(URI.parse(response["location"]), etag: etag, redirects: redirects + 1)
        end

        def build_request(uri, etag)
          request = Net::HTTP::Get.new(uri)
          request["user-agent"] = config.user_agent
          request["if-none-match"] = etag if etag
          request
        end

        def perform(uri, request)
          Net::HTTP.start(
            uri.host, uri.port,
            use_ssl: uri.scheme == "https",
            open_timeout: config.open_timeout,
            read_timeout: config.read_timeout
          ) { |http| http.request(request) }
        end

        def parse_line(line)
          return if line.strip.empty?

          fields = line.chomp.split("\t", -1)
          unless fields.length == EXPECTED_FIELDS
            raise DownloadError,
                  "malformed GeoNames row: expected #{EXPECTED_FIELDS} fields, got #{fields.length}"
          end

          voivodeship = Voivodeship.find_by_geonames_code(fields[4])
          # An unknown admin1 code means the canonical table above is stale, and a
          # silently dropped row would quietly corrupt the output.
          raise DownloadError, "unknown GeoNames voivodeship code: #{fields[4].inspect}" if voivodeship.nil?

          yield build_record(fields, voivodeship)
        end

        def build_record(fields, voivodeship)
          Record.new(
            postal_code: fields[1],
            city: fields[2],
            voivodeship: voivodeship.name,
            voivodeship_teryt: voivodeship.teryt_code,
            county: blank_to_nil(fields[5]&.tr("_", " ")),
            county_teryt: blank_to_nil(fields[6]),
            commune: blank_to_nil(fields[7]&.tr("_", " ")),
            commune_teryt: blank_to_nil(fields[8]),
            latitude: fields[9].to_f,
            longitude: fields[10].to_f,
            accuracy: blank_to_nil(fields[11])&.to_i
          )
        end

        def blank_to_nil(value)
          value.nil? || value.strip.empty? ? nil : value.strip
        end
      end
    end
  end
end
