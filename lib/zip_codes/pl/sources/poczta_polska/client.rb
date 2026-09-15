# frozen_string_literal: true

require "net/http"
require "time"

module ZipCodes
  module PL
    module Sources
      class PocztaPolska
        class Client
          MAX_ATTEMPTS = 5
          MAX_RETRY_DELAY = 30.0

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

          # Retries rate limiting a bounded number of times. An unbounded loop here
          # would turn sustained throttling into a refresh that never finishes and
          # never says why.
          def post_form(uri, params)
            MAX_ATTEMPTS.times do
              throttle
              response = transport.call(uri, params)
              @last_request_at = clock.call

              return response if response.is_a?(Net::HTTPSuccess)

              raise DownloadError, failure_message(response, uri) unless response.is_a?(Net::HTTPTooManyRequests)

              sleeper.call(retry_after(response))
            end

            raise DownloadError, "Poczta Polska is rate limiting - gave up after #{MAX_ATTEMPTS} attempts for #{uri}"
          end

          private

          attr_reader :clock, :request_interval, :sleeper, :transport

          def throttle
            return if @last_request_at.nil?

            remaining = request_interval - (clock.call - @last_request_at)
            sleeper.call(remaining) if remaining.positive?
          end

          # Clamped at both ends: a hostile or broken header must not make the
          # build sleep backwards, which raises, nor park it for an hour.
          def retry_after(response)
            value = response["retry-after"]
            seconds = Float(value, exception: false) || (Time.httpdate(value.to_s) - Time.now)
            seconds.clamp(0.0, MAX_RETRY_DELAY)
          rescue ArgumentError
            [request_interval, 1.0].max
          end

          # A moved endpoint is reported rather than followed: this is a POST to a
          # form, and replaying it against an unknown location is not a safe guess.
          def failure_message(response, uri)
            message = "Poczta Polska answered #{response.code} for #{uri}"
            location = response["location"] if response.is_a?(Net::HTTPRedirection)
            location ? "#{message} (redirected to #{location})" : message
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
end
