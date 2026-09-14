# frozen_string_literal: true

require "net/http"
require "time"

module PlZipCodes
  module Sources
    class PocztaPolska
      class Client
        def initialize(
          config:,
          sleeper: ->(seconds) { sleep(seconds) },
          clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) },
          transport: nil
        )
          @request_interval = config.poczta_request_interval
          @sleeper = sleeper
          @clock = clock
          @transport = transport || ->(uri, params) { post(uri, params, config) }
          @last_request_at = nil
        end

        def post_form(uri, params)
          loop do
            throttle
            response = transport.call(uri, params)
            @last_request_at = clock.call

            if response.is_a?(Net::HTTPTooManyRequests)
              sleeper.call(retry_after(response))
              next
            end

            unless response.is_a?(Net::HTTPSuccess)
              raise DownloadError, "Poczta Polska odpowiedziała #{response.code} dla #{uri}"
            end

            return response
          end
        end

        private

        attr_reader :clock, :request_interval, :sleeper, :transport

        def throttle
          return if @last_request_at.nil?

          remaining = request_interval - (clock.call - @last_request_at)
          sleeper.call(remaining) if remaining.positive?
        end

        def retry_after(response)
          value = response["retry-after"]
          seconds = Float(value, exception: false)
          return seconds if seconds

          retry_at = Time.httpdate(value.to_s)
          [retry_at - Time.now, 0].max
        rescue ArgumentError
          [request_interval, 1.0].max
        end

        def post(uri, params, config)
          request = Net::HTTP::Post.new(uri)
          request["user-agent"] = config.user_agent
          request.set_form_data(params)

          Net::HTTP.start(
            uri.host, uri.port,
            use_ssl: uri.scheme == "https",
            open_timeout: config.open_timeout,
            read_timeout: config.read_timeout
          ) { |http| http.request(request) }
        end
      end
    end
  end
end
