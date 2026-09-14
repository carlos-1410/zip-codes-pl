# frozen_string_literal: true

require "test_helper"

class PocztaPolskaTest < Minitest::Test
  def test_fetches_county_and_commune_names_by_teryt_code
    source = source_with(
      response(Net::HTTPOK, "200", body: '[{"name":"leszczyński","value":"3013"}]'),
      response(
        Net::HTTPOK,
        "200",
        body: '[{"name":"Lipno (wiejska)","value":"3013022"},{"name":"Osieczna","value":"301303"}]'
      )
    )

    names = source.fetch

    assert_equal "leszczyński", names.counties.fetch("3013")
    assert_equal "Lipno", names.communes.fetch("301302")
    assert_equal "Osieczna", names.communes.fetch("301303")
    assert_equal "Ostrowice", names.communes.fetch("320304")
  end

  def test_waits_between_requests_and_honours_retry_after
    waits = []
    source = source_with(
      response(Net::HTTPTooManyRequests, "429", headers: { "retry-after" => "7" }),
      response(Net::HTTPOK, "200", body: '[{"name":"leszczyński","value":"3013"}]'),
      response(Net::HTTPOK, "200", body: '[{"name":"Lipno (wiejska)","value":"3013022"}]'),
      sleeper: ->(seconds) { waits << seconds }
    )

    source.fetch

    assert_includes waits, 7.0
    assert(waits.any? { |seconds| (seconds - 0.1).abs < 0.001 })
  end

  # Sustained throttling used to spin forever instead of failing.
  def test_gives_up_after_repeated_rate_limiting
    waits = []
    limited = Array.new(20) { response(Net::HTTPTooManyRequests, "429", headers: { "retry-after" => "1" }) }
    source = source_with(*limited, sleeper: ->(seconds) { waits << seconds })

    error = assert_raises(ZipCodes::PL::DownloadError) { source.fetch }

    assert_match(/ogranicza ruch/, error.message)
    assert_equal ZipCodes::PL::Sources::PocztaPolska::Client::MAX_ATTEMPTS, waits.count(1.0)
  end

  # sleep(-1) raises, so an absurd header must not reach the sleeper unclamped.
  def test_clamps_a_hostile_retry_after
    waits = []
    source = source_with(
      response(Net::HTTPTooManyRequests, "429", headers: { "retry-after" => "-1" }),
      response(Net::HTTPTooManyRequests, "429", headers: { "retry-after" => "99999" }),
      response(Net::HTTPOK, "200", body: '[{"name":"leszczyński","value":"3013"}]'),
      response(Net::HTTPOK, "200", body: '[{"name":"Lipno (wiejska)","value":"3013022"}]'),
      sleeper: ->(seconds) { waits << seconds }
    )

    source.fetch

    assert_includes waits, 0.0
    assert_includes waits, ZipCodes::PL::Sources::PocztaPolska::Client::MAX_RETRY_DELAY
    assert(waits.none?(&:negative?))
  end

  def test_reports_where_a_moved_endpoint_went
    moved = response(Net::HTTPMovedPermanently, "301", headers: { "location" => "https://example.test/new" })

    error = assert_raises(ZipCodes::PL::DownloadError) { source_with(moved).fetch }

    assert_match(%r{https://example.test/new}, error.message)
  end

  # A number where a code belongs reached String methods and surfaced as
  # NoMethodError instead of a controlled failure.
  def test_rejects_a_non_string_value
    source = source_with(response(Net::HTTPOK, "200", body: '[{"name":"leszczyński","value":3013}]'))

    assert_raises(ZipCodes::PL::DownloadError) { source.fetch }
  end

  # 204 is a success to Net::HTTP, and JSON.parse(nil) raises TypeError.
  def test_rejects_a_success_with_no_body
    source = source_with(response(Net::HTTPNoContent, "204"))

    assert_raises(ZipCodes::PL::DownloadError) { source.fetch }
  end

  def test_rejects_an_invalid_response
    source = source_with(response(Net::HTTPOK, "200", body: "not json"))

    assert_raises(ZipCodes::PL::DownloadError) { source.fetch }
  end

  private

  def source_with(*responses, sleeper: ->(_seconds) {})
    queue = responses.dup
    transport = ->(_uri, _params) { queue.shift }
    voivodeships = [ZipCodes::PL::Voivodeship.find_by_teryt_code("30")]
    config = ZipCodes::PL::Configuration.new
    config.poczta_request_interval = 0.1
    client = ZipCodes::PL::Sources::PocztaPolska::Client.new(config: config, sleeper: sleeper, transport: transport)

    ZipCodes::PL::Sources::PocztaPolska.new(
      client: client,
      voivodeships: voivodeships
    )
  end

  def response(klass, code, body: nil, headers: {})
    built = klass.new("1.1", code, "")
    headers.each { |name, value| built[name] = value }
    built.define_singleton_method(:body) { body }
    built
  end
end
