# frozen_string_literal: true

module ZipCodes
  module PL
    # One postal code in one place. A place with several codes has several
    # records, and so does a code shared by several places.
    #
    # county and commune carry the source's own labels, which are uneven for
    # Poland ("Powiat bydgoski", "Leszno County"). The *_teryt codes are the
    # dependable identifiers and the join key for official names.
    class Record < Data.define(
      :postal_code, :city,
      :voivodeship, :voivodeship_teryt,
      :county, :county_teryt,
      :commune, :commune_teryt,
      :latitude, :longitude, :accuracy
    )
      COLUMNS = members.freeze

      def self.from_row(row)
        new(
          postal_code: row[0],
          city: row[1],
          voivodeship: row[2],
          voivodeship_teryt: row[3],
          county: presence(row[4]),
          county_teryt: presence(row[5]),
          commune: presence(row[6]),
          commune_teryt: presence(row[7]),
          latitude: row[8].to_f,
          longitude: row[9].to_f,
          accuracy: presence(row[10])&.to_i
        )
      end

      def self.presence(value)
        value.nil? || value.empty? ? nil : value
      end
      private_class_method :presence

      def to_row
        COLUMNS.map { |column| public_send(column) }
      end

      def coordinates
        [latitude, longitude]
      end
    end
  end
end
