# frozen_string_literal: true

require "test_helper"

class DatasetTest < Minitest::Test
  def test_reads_back_everything_that_was_written
    with_dataset do |dataset|
      assert_equal 7, dataset.size
      assert_equal 7, dataset.count
    end
  end

  def test_finds_rows_by_postal_code_with_or_without_the_dash
    with_dataset do |dataset|
      assert_equal ["Koronowo"], dataset.find_by_postal_code("86-010").map(&:city)
      assert_equal ["Koronowo"], dataset.find_by_postal_code("86010").map(&:city)
      assert_empty dataset.find_by_postal_code("00-000")
      assert_empty dataset.find_by_postal_code("nonsense")
    end
  end

  # Two real places share this name in two voivodeships, which is exactly why
  # the city lookup cannot return a single record.
  def test_finds_every_place_sharing_a_name
    with_dataset do |dataset|
      assert_equal %w[86-010 64-111], dataset.find_by_city("Koronowo").map(&:postal_code)
    end
  end

  def test_narrows_a_shared_name_by_voivodeship
    with_dataset do |dataset|
      found = dataset.find_by_city("Koronowo", voivodeship: "wielkopolskie")

      assert_equal ["64-111"], found.map(&:postal_code)
    end
  end

  def test_city_lookup_ignores_case_and_diacritics
    with_dataset do |dataset|
      assert_equal 1, dataset.find_by_city("JEZIORA").size
      assert_equal 1, dataset.find_by_city("bydgoszcz").size
    end
  end

  def test_groups_rows_into_places
    with_dataset do |dataset|
      cities = dataset.cities

      assert_equal 7, cities.size
      assert_equal ["Bydgoszcz", "Jeziora", "Koronowo", "Koronowo", "Nowa Wieś", "Nowa Wieś", "Nowa Wieś Wielka"],
                   cities.map(&:name)
      assert_equal %w[04 04 04 30 04 04 04], cities.map(&:voivodeship_teryt)
    end
  end

  def test_a_place_carries_its_postal_codes_and_a_coordinate
    with_dataset do |dataset|
      koronowo = dataset.cities.find { |city| city.voivodeship_teryt == "04" && city.name == "Koronowo" }

      assert_equal ["86-010"], koronowo.postal_codes
      assert_in_delta 53.3123, koronowo.latitude, 0.0001
      assert_equal "kujawsko-pomorskie", koronowo.voivodeship
    end
  end

  def test_survives_polish_names_through_the_written_file
    with_dataset do |dataset|
      found = dataset.find_by_city("nowa wies wielka")

      assert_equal ["Nowa Wieś Wielka"], found.map(&:city)
      assert_equal Encoding::UTF_8, found.first.city.encoding
    end
  end

  def test_keeps_same_named_places_in_different_communes_apart
    with_dataset do |dataset|
      found = dataset.cities.select { |city| city.name == "Nowa Wieś" }

      assert_equal 2, found.size
      assert_equal %w[041105 046301], found.map(&:commune_teryt).sort
      refute_in_delta found[0].longitude, found[1].longitude, 0.5
    end
  end

  def test_a_city_carries_its_commune
    with_dataset do |dataset|
      bydgoszcz = dataset.cities.find { |city| city.name == "Bydgoszcz" }

      assert_equal "046101", bydgoszcz.commune_teryt
      assert_equal "Bydgoszcz", bydgoszcz.commune
    end
  end

  def test_refuses_to_load_a_dataset_that_is_not_there
    Dir.mktmpdir do |dir|
      error = assert_raises(PlZipCodes::DatasetError) { PlZipCodes::Dataset.load(File.join(dir, "missing.tsv")) }

      assert_match(/pl_zip_codes:update/, error.message)
    end
  end

  def test_refuses_a_file_whose_columns_are_not_the_expected_ones
    Dir.mktmpdir do |dir|
      path = File.join(dir, "wrong.tsv")
      File.write(path, "nope\tnope\n")

      assert_raises(PlZipCodes::DatasetError) { PlZipCodes::Dataset.load(path) }
    end
  end

  private

  def with_dataset
    Dir.mktmpdir do |dir|
      config = PlZipCodes::Configuration.new
      config.output_dir = dir
      source = TestHelpers::StubSource.new(archive: TestHelpers.geonames_archive)
      PlZipCodes::Builder.new(config: config, source: source).call

      yield PlZipCodes::Dataset.load(config.data_path)
    end
  end
end
