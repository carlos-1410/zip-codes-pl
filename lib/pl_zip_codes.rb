# frozen_string_literal: true

require_relative "pl_zip_codes/errors"
require_relative "pl_zip_codes/version"
require_relative "pl_zip_codes/normalize"
require_relative "pl_zip_codes/voivodeship"
require_relative "pl_zip_codes/record"
require_relative "pl_zip_codes/city"
require_relative "pl_zip_codes/sources/geonames"
require_relative "pl_zip_codes/configuration"
require_relative "pl_zip_codes/manifest"
require_relative "pl_zip_codes/builder"
require_relative "pl_zip_codes/reader"
require_relative "pl_zip_codes/railtie" if defined?(Rails::Railtie)

module PlZipCodes
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
