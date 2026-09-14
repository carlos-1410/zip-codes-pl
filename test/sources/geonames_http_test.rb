# frozen_string_literal: true

require "test_helper"

# Covers the transport branches that a stubbed source cannot reach. The 304 case
# is here because the real server answered one and the redirect handling ate it.
class GeonamesHttpTest < Minitest::Test
  def setup
    @source = PlZipCodes::Sources::Geonames.new
  end

  def test_not_modified_reports_no_download
    with_responses([response(Net::HTTPNotModified, "304")]) do
      assert_nil @source.download(etag: "\"v1\"")
    end
  end

  def test_sends_the_stored_etag
    requests = []

    with_responses([response(Net::HTTPNotModified, "304")], requests: requests) do
      @source.download(etag: "\"v1\"")
    end

    assert_equal "\"v1\"", requests.first["if-none-match"]
  end

  def test_successful_download_carries_body_and_validators
    success = response(Net::HTTPOK, "200", body: "zip-bytes", headers: { "etag" => "\"v2\"" })

    with_responses([success]) do
      download = @source.download

      assert_equal "zip-bytes", download.body
      assert_equal "\"v2\"", download.etag
    end
  end

  def test_follows_a_redirect_to_the_new_location
    moved = response(Net::HTTPMovedPermanently, "301",
                     headers: { "location" => "https://example.test/moved.zip" })
    success = response(Net::HTTPOK, "200", body: "zip-bytes")

    with_responses([moved, success]) do
      assert_equal "zip-bytes", @source.download.body
    end
  end

  def test_gives_up_after_too_many_redirects
    moved = -> { response(Net::HTTPMovedPermanently, "301", headers: { "location" => "https://example.test/again.zip" }) }

    with_responses(Array.new(5) { moved.call }) do
      assert_raises(PlZipCodes::DownloadError) { @source.download }
    end
  end

  def test_reports_an_error_status
    with_responses([response(Net::HTTPServerError, "500")]) do
      error = assert_raises(PlZipCodes::DownloadError) { @source.download }

      assert_match(/500/, error.message)
    end
  end

  private

  def response(klass, code, body: nil, headers: {})
    built = klass.new("1.1", code, "")
    headers.each { |name, value| built[name] = value }
    built.define_singleton_method(:body) { body }
    built
  end

  def with_responses(responses, requests: [])
    queue = responses.dup
    original = Net::HTTP.method(:start)

    silently do
      Net::HTTP.define_singleton_method(:start) do |*_args, **_options, &block|
        http = Object.new
        http.define_singleton_method(:request) do |request|
          requests << request
          queue.shift
        end
        block.call(http)
      end
    end

    yield
  ensure
    silently { Net::HTTP.define_singleton_method(:start, original) }
  end

  def silently
    previous = $VERBOSE
    $VERBOSE = nil
    yield
  ensure
    $VERBOSE = previous
  end
end
