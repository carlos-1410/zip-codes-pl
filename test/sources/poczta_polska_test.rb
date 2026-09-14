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

  def test_rejects_an_invalid_response
    source = source_with(response(Net::HTTPOK, "200", body: "not json"))

    assert_raises(PlZipCodes::DownloadError) { source.fetch }
  end

  private

  def source_with(*responses, sleeper: ->(_seconds) {})
    queue = responses.dup
    transport = ->(_uri, _params) { queue.shift }
    voivodeships = [PlZipCodes::Voivodeship.find_by_teryt_code("30")]
    config = PlZipCodes::Configuration.new
    config.poczta_request_interval = 0.1
    client = PlZipCodes::Sources::PocztaPolska::Client.new(config: config, sleeper: sleeper, transport: transport)

    PlZipCodes::Sources::PocztaPolska.new(
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
