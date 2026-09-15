# frozen_string_literal: true

require "json"
require "uri"
require_relative "poczta_polska/client"

module ZipCodes
  module PL
    module Sources
      class PocztaPolska
        DISTRICTS_URL = "https://www.poczta-polska.pl/wp-content/themes/pp/inc/pna-form/pna-search-district.php"
        COMMUNES_URL = "https://www.poczta-polska.pl/wp-content/themes/pp/inc/pna-form/pna-search-commune.php"
        ATTRIBUTION = "county and commune names: Poczta Polska (https://www.poczta-polska.pl)"
        DEFAULT_REQUEST_INTERVAL = 0.25
        LEGACY_COMMUNES = { "320304" => "Ostrowice" }.freeze
        Names = Data.define(:counties, :communes)

        def initialize(config: ZipCodes::PL.config, client: nil, voivodeships: Voivodeship.all)
          @client = client || Client.new(config: config)
          @voivodeships = voivodeships
        end

        def fetch
          counties, districts = fetch_counties
          communes = fetch_communes(districts)

          Names.new(counties: counties.freeze, communes: communes.freeze)
        end

        private

        attr_reader :client, :voivodeships

        def fetch_counties
          counties = {}
          districts = []

          voivodeships.each do |voivodeship|
            entries(DISTRICTS_URL, province: voivodeship.teryt_code).each do |entry|
              code, name = entry.values_at("value", "name")
              validate_code!(code, 4, voivodeship.teryt_code)
              add!(counties, code, name)
              districts << [voivodeship.teryt_code, code]
            end
          end

          [counties, districts]
        end

        def fetch_communes(districts)
          communes = LEGACY_COMMUNES.dup
          districts.each do |province, district|
            entries(COMMUNES_URL, province: province, district: district).each do |entry|
              terc, name = entry.values_at("value", "name")
              validate_commune_code!(terc, district)
              add!(communes, terc[0, 6], normalize_commune_name(name))
            end
          end

          communes
        end

        def entries(url, params)
          response = client.post_form(URI(url), params)
          # A success with no body is still a success to Net::HTTP, and JSON.parse
          # raises TypeError rather than ParserError on nil.
          payload = JSON.parse(response.body.to_s)
          unless payload.is_a?(Array) && payload.all? { |entry| valid_entry?(entry) }
            raise DownloadError, "malformed Poczta Polska response from #{url}"
          end

          payload
        rescue JSON::ParserError
          raise DownloadError, "malformed Poczta Polska JSON from #{url}"
        end

        # Strings are demanded rather than coerced, so a number where a code should
        # be is refused here instead of reaching String methods further down and
        # surfacing as NoMethodError instead of a controlled failure.
        def valid_entry?(entry)
          entry.is_a?(Hash) &&
            entry["name"].is_a?(String) && !entry["name"].empty? &&
            entry["value"].is_a?(String) && !entry["value"].empty?
        end

        def validate_code!(code, length, prefix)
          return if code.match?(/\A\d{#{length}}\z/) && code.start_with?(prefix)

          raise DownloadError, "malformed Poczta Polska TERYT code: #{code.inspect}"
        end

        def validate_commune_code!(code, district)
          return if code.match?(/\A\d{6,7}\z/) && code.start_with?(district)

          raise DownloadError, "malformed Poczta Polska TERYT code: #{code.inspect}"
        end

        def add!(names, code, name)
          normalized = name.strip
          previous = names[code]
          if previous && previous != normalized
            raise DownloadError,
                  "conflicting Poczta Polska names for TERYT #{code}: #{previous.inspect} and #{normalized.inspect}"
          end

          names[code] = normalized
        end

        def normalize_commune_name(name)
          name.sub(/ \((?:miejska|wiejska|miejsko-wiejska)\)\z/, "")
        end
      end
    end
  end
end
