# frozen_string_literal: true

module PlZipCodes
  # A place rather than a postal code: what a "cities" table wants.
  class City < Data.define(
    :name, :voivodeship, :voivodeship_teryt, :commune, :commune_teryt,
    :latitude, :longitude, :postal_codes
  )
    class << self
      # Keyed by commune as well as name, because a voivodeship can hold dozens
      # of distinct villages sharing one - mazowieckie has 28 called "Nowa Wieś".
      # Collapsing them by name alone puts the averaged point in a field, up to
      # 158 km from the farthest place it claims to be.
      def group_key(record)
        [record.city, record.voivodeship_teryt, record.commune_teryt]
      end

      def sort_key(city)
        [Normalize.key(city.name), city.voivodeship_teryt, city.commune_teryt.to_s]
      end
    end

    # Holds running sums rather than the rows behind them, so building every
    # place in the country does not mean holding every postal code first. The
    # coordinate ends up the mean of the group's rows, because the source gives
    # one point per postal code and Bydgoszcz has 679 of them.
    class Accumulator
      def initialize(record)
        # Copies the identity fields instead of holding the row, so the rest of
        # each Record can be collected while the country is being aggregated.
        @name = record.city
        @voivodeship = record.voivodeship
        @voivodeship_teryt = record.voivodeship_teryt
        @commune = record.commune
        @commune_teryt = record.commune_teryt
        @latitude = 0.0
        @longitude = 0.0
        @count = 0
        @postal_codes = {}
      end

      def add(record)
        @latitude += record.latitude
        @longitude += record.longitude
        @count += 1
        @postal_codes[record.postal_code] = true
        self
      end

      def to_city
        City.new(
          name: @name,
          voivodeship: @voivodeship,
          voivodeship_teryt: @voivodeship_teryt,
          commune: @commune,
          commune_teryt: @commune_teryt,
          latitude: (@latitude / @count).round(6),
          longitude: (@longitude / @count).round(6),
          postal_codes: @postal_codes.keys.sort.freeze
        )
      end
    end
  end
end
