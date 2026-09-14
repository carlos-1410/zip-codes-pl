# frozen_string_literal: true

require "test_helper"

class RecordTest < Minitest::Test
  Record = PlZipCodes::Record

  def test_survives_a_round_trip_through_a_row
    record = build_record

    assert_equal record, Record.from_row(record.to_row.map(&:to_s))
  end

  # A blank column is written as an empty string, so reading it back has to give
  # nil again or the missing commune turns into a place called "".
  def test_blank_columns_come_back_as_nil
    record = build_record(county: nil, county_teryt: nil, commune: nil, commune_teryt: nil, accuracy: nil)

    restored = Record.from_row(record.to_row.map(&:to_s))

    assert_nil restored.county
    assert_nil restored.commune_teryt
    assert_nil restored.accuracy
    assert_equal "Jeziora", restored.city
  end

  def test_exposes_coordinates_as_a_pair
    assert_equal [53.3123, 17.9539], build_record.coordinates
  end

  private

  def build_record(**overrides)
    Record.new(
      postal_code: "86-010", city: "Jeziora",
      voivodeship: "kujawsko-pomorskie", voivodeship_teryt: "04",
      county: "Powiat bydgoski", county_teryt: "0403",
      commune: "Gmina Koronowo", commune_teryt: "040304",
      latitude: 53.3123, longitude: 17.9539, accuracy: 6, **overrides
    )
  end
end
