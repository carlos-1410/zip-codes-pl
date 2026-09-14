# frozen_string_literal: true

module PlZipCodes
  class Configuration
    DEFAULT_OUTPUT_DIR = "data"
    DATA_FILENAME = "pl-zip-codes.tsv.gz"
    MANIFEST_FILENAME = "pl-zip-codes.manifest.json"

    attr_accessor :output_dir, :source_url, :user_agent, :open_timeout, :read_timeout

    def initialize
      @output_dir = ENV.fetch("PL_ZIP_CODES_DIR", DEFAULT_OUTPUT_DIR)
      @source_url = Sources::Geonames::URL
      @user_agent = "pl-zip-codes/#{VERSION} (+https://github.com/carlos-1410/pl-zip-codes)"
      @open_timeout = 10
      @read_timeout = 60
    end

    def data_path
      File.join(output_dir, DATA_FILENAME)
    end

    def manifest_path
      File.join(output_dir, MANIFEST_FILENAME)
    end
  end
end
