# frozen_string_literal: true

module PlZipCodes
  class Error < StandardError; end

  class DownloadError < Error; end

  class DatasetError < Error; end
end
