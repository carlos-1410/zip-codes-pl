# frozen_string_literal: true

require_relative "pl/errors"
require_relative "pl/version"
require_relative "pl/normalize"
require_relative "pl/voivodeship"
require_relative "pl/record"
require_relative "pl/city"
require_relative "pl/sources/geonames"
require_relative "pl/sources/poczta_polska"
require_relative "pl/configuration"
require_relative "pl/manifest"
require_relative "pl/builder"
require_relative "pl/reader"
require_relative "pl/railtie" if defined?(Rails::Railtie)

module ZipCodes
  module PL
    class << self
      def config
        @config ||= Configuration.new
      end

      def configure
        yield config
        reset!
        config
      end

      # Drops the loaded dataset so the next read picks up a freshly built file.
      def reset!
        @reader = nil
        self
      end

      # Streams the file. Holds nothing, costs about 15 ms per call.
      def reader
        @reader ||= Reader.new(config.readable_data_path)
      end

      def update(output_dir: nil)
        config.output_dir = output_dir if output_dir
        Builder.new(config: config).call.tap { reset! }
      end

      def manifest = Manifest.read(config.readable_manifest_path)

      def find_by_postal_code(code) = reader.find_by_postal_code(code)

      def find_by_city(name, voivodeship: nil) = reader.find_by_city(name, voivodeship: voivodeship)

      def search_by_city(fragment, voivodeship: nil) = reader.search_by_city(fragment, voivodeship: voivodeship)

      def cities = reader.cities

      def each_record(&) = reader.each(&)

      def voivodeships = Voivodeship.all
    end
  end
end
