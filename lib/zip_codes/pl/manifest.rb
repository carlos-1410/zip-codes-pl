# frozen_string_literal: true

require "json"
require "time"

module ZipCodes
  module PL
    # Sits next to the dataset and records where it came from. The etag is what
    # lets a later run ask the server "changed?" instead of downloading again.
    class Manifest < Data.define(
      :source_url, :attribution, :etag, :last_modified,
      :row_count, :built_at, :gem_version, :format_version
    )
      FORMAT_VERSION = 1

      def self.read(path)
        return nil unless File.exist?(path)

        payload = JSON.parse(File.read(path), symbolize_names: true)
        return nil unless payload[:format_version] == FORMAT_VERSION

        new(**payload.slice(*members))
      rescue JSON::ParserError, ArgumentError
        nil
      end

      def write(path)
        File.write(path, "#{JSON.pretty_generate(to_h)}\n")
        self
      end

      def built_at_time
        Time.iso8601(built_at)
      rescue ArgumentError, TypeError
        nil
      end
    end
  end
end
