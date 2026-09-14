# frozen_string_literal: true

module ZipCodes
  module PL
    class Configuration
      DEFAULT_OUTPUT_DIR = "data"
      DATA_FILENAME = "zip-codes-pl.tsv"
      MANIFEST_FILENAME = "zip-codes-pl.manifest.json"
      BUNDLED_DIR = File.expand_path("../../../data", __dir__)

      attr_accessor :output_dir, :source_url, :user_agent, :open_timeout, :read_timeout, :poczta_request_interval

      def initialize
        @output_dir = ENV.fetch("ZIP_CODES_PL_DIR", DEFAULT_OUTPUT_DIR)
        @source_url = Sources::Geonames::URL
        @user_agent = "zip-codes-pl/#{VERSION} (+https://github.com/carlos-1410/zip-codes-pl)"
        @open_timeout = 10
        @read_timeout = 60
        @poczta_request_interval = Sources::PocztaPolska::DEFAULT_REQUEST_INTERVAL
      end

      # Where a refresh writes.
      def data_path
        File.join(output_dir, DATA_FILENAME)
      end

      def manifest_path
        File.join(output_dir, MANIFEST_FILENAME)
      end

      # Where a read looks. Your own refreshed copy wins; without one the dataset
      # shipped inside the gem answers, so nothing has to be built before first use.
      def readable_data_path
        File.exist?(data_path) ? data_path : bundled_data_path
      end

      def readable_manifest_path
        File.exist?(data_path) ? manifest_path : File.join(BUNDLED_DIR, MANIFEST_FILENAME)
      end

      def bundled_data_path
        File.join(BUNDLED_DIR, DATA_FILENAME)
      end
    end
  end
end
