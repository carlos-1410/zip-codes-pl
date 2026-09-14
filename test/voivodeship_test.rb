# frozen_string_literal: true

require "test_helper"

class VoivodeshipTest < Minitest::Test
  Voivodeship = PlZipCodes::Voivodeship

  def test_covers_all_sixteen_voivodeships
    assert_equal 16, Voivodeship.all.size
  end

  def test_codes_and_names_are_unique
    %i[teryt_code geonames_code name slug].each do |attribute|
      values = Voivodeship.all.map { |voivodeship| voivodeship.public_send(attribute) }
      assert_equal values.size, values.uniq.size, "duplicate #{attribute}"
    end
  end

  # The pairing is the join key for every other source of Polish data, so it is
  # asserted here rather than trusted.
  def test_geonames_codes_map_onto_official_teryt_codes
    expected = {
      "72" => "02", "73" => "04", "74" => "10", "75" => "06",
      "76" => "08", "77" => "12", "78" => "14", "79" => "16",
      "80" => "18", "81" => "20", "82" => "22", "83" => "24",
      "84" => "26", "85" => "28", "86" => "30", "87" => "32"
    }

    actual = Voivodeship.all.to_h { |v| [v.geonames_code, v.teryt_code] }

    assert_equal expected, actual
  end

  def test_teryt_codes_are_the_even_numbers_from_two_to_thirty_two
    assert_equal (1..16).map { |n| format("%02d", n * 2) }, Voivodeship.all.map(&:teryt_code).sort
  end

  def test_slugs_carry_no_polish_diacritics
    Voivodeship.all.each do |voivodeship|
      assert_match(/\A[a-z-]+\z/, voivodeship.slug, "#{voivodeship.name} has an unusable slug")
    end
  end

  def test_finds_by_either_code
    assert_equal "kujawsko-pomorskie", Voivodeship.find_by_geonames_code("73").name
    assert_equal "łódzkie", Voivodeship.find_by_teryt_code("10").name
    assert_nil Voivodeship.find_by_geonames_code("99")
  end

  def test_finds_by_name_or_slug_ignoring_case
    assert_equal "24", Voivodeship.find_by_name("Śląskie").teryt_code
    assert_equal "24", Voivodeship.find_by_name("slaskie").teryt_code
    assert_nil Voivodeship.find_by_name("Brandenburgia")
  end
end
