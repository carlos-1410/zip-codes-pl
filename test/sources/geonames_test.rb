# frozen_string_literal: true

require "test_helper"

class GeonamesTest < Minitest::Test
  def setup
    @source = PlZipCodes::Sources::Geonames.new
  end

  def test_reads_every_row_of_the_archive
    records = @source.each_record(TestHelpers.geonames_archive).to_a

    assert_equal 7, records.size
    assert_equal %w[86-010 85-000 64-111 88-420 86-060 87-100 89-200], records.map(&:postal_code)
  end

  # The whole point of the gem: GeoNames says "Kujawsko-Pomorskie" for one row
  # and "Greater Poland" for another, and both come out as Polish names here.
  def test_replaces_source_voivodeship_names_with_polish_ones
    records = @source.each_record(TestHelpers.geonames_archive).to_a

    assert_equal "kujawsko-pomorskie", records[0].voivodeship
    assert_equal "04", records[0].voivodeship_teryt
    assert_equal "wielkopolskie", records[2].voivodeship
    assert_equal "30", records[2].voivodeship_teryt
  end

  def test_turns_underscores_in_source_names_into_spaces
    records = @source.each_record(TestHelpers.geonames_archive).to_a

    assert_equal "Leszno County", records[2].county
  end

  def test_reads_coordinates_as_numbers
    record = @source.each_record(TestHelpers.geonames_archive).first

    assert_in_delta 53.3123, record.latitude, 0.0001
    assert_in_delta 17.9539, record.longitude, 0.0001
    assert_equal 6, record.accuracy
  end

  def test_keeps_a_row_whose_county_and_commune_are_missing
    record = @source.each_record(TestHelpers.geonames_archive).find { |r| r.postal_code == "88-420" }

    assert_equal "Jeziora", record.city
    assert_nil record.county
    assert_nil record.commune_teryt
    assert_equal "kujawsko-pomorskie", record.voivodeship
  end

  def test_reads_polish_names_as_utf8
    record = @source.each_record(TestHelpers.geonames_archive).find { |r| r.postal_code == "86-060" }

    assert_equal "Nowa Wieś Wielka", record.city
    assert_equal Encoding::UTF_8, record.city.encoding
    assert_equal "Gmina Nowa Wieś Wielka", record.commune
  end

  # Silently dropping the row would corrupt the output without anyone noticing.
  def test_refuses_an_unknown_voivodeship_code
    rows = ["PL\t00-001\tNigdzie\tAtlantis\t99\t\t\t\t\t50.0\t20.0\t6"]

    error = assert_raises(PlZipCodes::DownloadError) do
      @source.each_record(TestHelpers.geonames_archive(rows: rows)).to_a
    end

    assert_match(/99/, error.message)
  end

  def test_refuses_an_archive_without_the_expected_entry
    archive = TestHelpers.geonames_archive(entry: "SOMETHING_ELSE.txt")

    assert_raises(PlZipCodes::DownloadError) { @source.each_record(archive).to_a }
  end

  def test_skips_blank_lines
    rows = [TestHelpers::SAMPLE_ROWS.first, ""]

    assert_equal 1, @source.each_record(TestHelpers.geonames_archive(rows: rows)).to_a.size
  end

  def test_refuses_a_short_row
    rows = [TestHelpers::SAMPLE_ROWS.first, "PL\t86-010"]

    assert_raises(PlZipCodes::DownloadError) do
      @source.each_record(TestHelpers.geonames_archive(rows: rows)).to_a
    end
  end
end
