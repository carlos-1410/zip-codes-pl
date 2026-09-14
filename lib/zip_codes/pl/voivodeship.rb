# frozen_string_literal: true

module ZipCodes
  module PL
    # The sixteen voivodeships, pairing the GeoNames admin1 code that appears in
    # the source export with the official TERYT code and the Polish name.
    #
    # GeoNames ships English and inconsistent labels for every one of them
    # ("Lower Silesia", "Warmia-Masuria", "Łódź Voivodeship"), so the name used by
    # this gem is defined here rather than read from the download. The
    # geonames_code => teryt_code pairing is verified against the source data by
    # the test suite, because it is the join key everything else hangs off.
    class Voivodeship < Data.define(:teryt_code, :geonames_code, :name, :slug)
      ALL = [
        new(teryt_code: "02", geonames_code: "72", name: "dolnośląskie", slug: "dolnoslaskie"),
        new(teryt_code: "04", geonames_code: "73", name: "kujawsko-pomorskie", slug: "kujawsko-pomorskie"),
        new(teryt_code: "06", geonames_code: "75", name: "lubelskie", slug: "lubelskie"),
        new(teryt_code: "08", geonames_code: "76", name: "lubuskie", slug: "lubuskie"),
        new(teryt_code: "10", geonames_code: "74", name: "łódzkie", slug: "lodzkie"),
        new(teryt_code: "12", geonames_code: "77", name: "małopolskie", slug: "malopolskie"),
        new(teryt_code: "14", geonames_code: "78", name: "mazowieckie", slug: "mazowieckie"),
        new(teryt_code: "16", geonames_code: "79", name: "opolskie", slug: "opolskie"),
        new(teryt_code: "18", geonames_code: "80", name: "podkarpackie", slug: "podkarpackie"),
        new(teryt_code: "20", geonames_code: "81", name: "podlaskie", slug: "podlaskie"),
        new(teryt_code: "22", geonames_code: "82", name: "pomorskie", slug: "pomorskie"),
        new(teryt_code: "24", geonames_code: "83", name: "śląskie", slug: "slaskie"),
        new(teryt_code: "26", geonames_code: "84", name: "świętokrzyskie", slug: "swietokrzyskie"),
        new(teryt_code: "28", geonames_code: "85", name: "warmińsko-mazurskie", slug: "warminsko-mazurskie"),
        new(teryt_code: "30", geonames_code: "86", name: "wielkopolskie", slug: "wielkopolskie"),
        new(teryt_code: "32", geonames_code: "87", name: "zachodniopomorskie", slug: "zachodniopomorskie")
      ].freeze

      BY_GEONAMES_CODE = ALL.to_h { |voivodeship| [voivodeship.geonames_code, voivodeship] }.freeze
      BY_TERYT_CODE = ALL.to_h { |voivodeship| [voivodeship.teryt_code, voivodeship] }.freeze
      BY_LOOKUP_NAME = ALL.flat_map { |v| [[v.name, v], [v.slug, v]] }.to_h.freeze

      class << self
        def all = ALL

        def find_by_geonames_code(code) = BY_GEONAMES_CODE[code.to_s]

        def find_by_teryt_code(code) = BY_TERYT_CODE[code.to_s]

        def find_by_name(name) = BY_LOOKUP_NAME[name.to_s.strip.downcase]
      end
    end
  end
end
