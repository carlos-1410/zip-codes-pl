# frozen_string_literal: true

module ZipCodes
  module PL
    class Error < StandardError; end

    class DownloadError < Error; end

    class DatasetError < Error; end
  end
end
