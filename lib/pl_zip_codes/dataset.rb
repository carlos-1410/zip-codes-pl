# frozen_string_literal: true

module PlZipCodes
  # The built dataset, read into memory once. Roughly 73 000 rows, so the whole
  # thing plus its indexes is small enough to keep resident rather than query.
  class Dataset
    # A place rather than a postal code: what a "cities" table wants. The
    # coordinate is the mean of the place's rows, because GeoNames gives one
    # point per postal code and a town can hold dozens.
    City = Data.define(
      :name, :voivodeship, :voivodeship_teryt, :commune, :commune_teryt,
      :latitude, :longitude, :postal_codes
    )

    attr_reader :records

    def self.load(path)
      raise DatasetError, "brak zbioru danych: #{path} (uruchom `rake pl_zip_codes:update`)" unless File.exist?(path)

      records = []
      File.open(path) do |file|
        header = file.gets&.chomp&.split("\t")
        raise DatasetError, "nieoczekiwany nagłówek w #{path}" unless header == Record::COLUMNS.map(&:to_s)

        file.each_line { |line| records << Record.from_row(line.chomp.split("\t", -1)) }
      end

      new(records)
    end

    def initialize(records)
      @records = records.freeze
    end

    def size = records.size

    def each(&) = records.each(&)

    include Enumerable

    # Every row carrying this postal code; several places can share one.
    def find_by_postal_code(code)
      normalized = Normalize.postal_code(code)
      return [] if normalized.nil?

      by_postal_code.fetch(normalized, [])
    end

    # Case and diacritics insensitive: "zlotow" finds "Złotów".
    def find_by_city(name, voivodeship: nil)
      found = by_city.fetch(Normalize.key(name), [])
      return found if voivodeship.nil?

      wanted = Voivodeship.find_by_name(voivodeship)
      found.select { |record| record.voivodeship_teryt == wanted&.teryt_code }
    end

    def cities
      @cities ||= begin
        grouped = records.group_by { |record| [record.city, record.voivodeship_teryt, record.commune_teryt] }
        built = grouped.map { |_key, group| build_city(group) }
        built.sort_by { |city| [Normalize.key(city.name), city.voivodeship_teryt, city.commune_teryt.to_s] }.freeze
      end
    end

    private

    def by_postal_code
      @by_postal_code ||= records.group_by(&:postal_code).freeze
    end

    def by_city
      @by_city ||= records.group_by { |record| Normalize.key(record.city) }.freeze
    end

    # Grouped by commune as well as name, because a voivodeship can hold dozens
    # of distinct villages sharing a name - mazowieckie has 28 called "Nowa Wieś",
    # and averaging them lands the point in a field 158 km from the farthest one.
    def build_city(group)
      first = group.first
      City.new(
        name: first.city,
        voivodeship: first.voivodeship,
        voivodeship_teryt: first.voivodeship_teryt,
        commune: first.commune,
        commune_teryt: first.commune_teryt,
        latitude: mean(group.map(&:latitude)),
        longitude: mean(group.map(&:longitude)),
        postal_codes: group.map(&:postal_code).uniq.sort.freeze
      )
    end

    def mean(values)
      (values.sum / values.size).round(6)
    end
  end
end
