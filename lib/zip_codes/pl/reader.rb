# frozen_string_literal: true

module ZipCodes
  module PL
    # Reads the dataset by streaming the file, holding nothing between calls.
    #
    # One scan of 72 899 rows costs about 15 ms and 1.6 MB, against 222 ms and
    # 99 MB to hold the same rows in indexed memory. The break-even is around
    # fifteen lookups and the ordinary use of this gem is three, so there is no
    # in-memory mode: past that point the rows belong in the caller's own database,
    # and `cities` is the shape to import.
    class Reader
      HEADER = Record::COLUMNS.map(&:to_s).freeze
      MIN_CITY_FRAGMENT_LENGTH = 3

      attr_reader :path

      def initialize(path)
        @path = path
      end

      def each(&block)
        return enum_for(:each) unless block

        open_data do |file|
          file.each_line { |line| block.call(Record.from_row(line.chomp.split("\t", -1))) }
        end
      end

      include Enumerable

      def find_by_postal_code(code)
        normalized = Normalize.postal_code(code)
        return [] if normalized.nil?

        prefix = "#{normalized}\t"
        scan { |line| line.start_with?(prefix) }
      end

      def find_by_city(name, voivodeship: nil)
        wanted_name = Normalize.key(name)
        wanted_teryt = resolve_voivodeship(voivodeship)
        # Asked to narrow to a voivodeship that does not exist: nothing matches.
        # Treating it as "no filter" would answer with every place of that name.
        return [] if wanted_teryt == :unknown

        scan do |line|
          fields = line.split("\t", 5)
          # Folding every name costs more than reading the file, and the folding
          # used here is length preserving (ł->l, ó->o, NFD plus mark stripping),
          # so a length mismatch rules a row out before any of that work.
          fields[1].length == wanted_name.length &&
            Normalize.key(fields[1]) == wanted_name &&
            (wanted_teryt.nil? || fields[3] == wanted_teryt)
        end
      end

      def search_by_city(fragment, voivodeship: nil)
        wanted_fragment = Normalize.key(fragment)
        return [] if wanted_fragment.length < 2

        wanted_teryt = resolve_voivodeship(voivodeship)
        return [] if wanted_teryt == :unknown

        scan do |line|
          fields = line.split("\t", 5)
          name = Normalize.key(fields[1])
          matches = if wanted_fragment.length < MIN_CITY_FRAGMENT_LENGTH
                      name == wanted_fragment
                    else
                      name.include?(wanted_fragment)
                    end

          matches && (wanted_teryt.nil? || fields[3] == wanted_teryt)
        end
      end

      # Accumulates as it streams, so the 72 899 source rows are never all resident
      # at once - only the 52 325 places they collapse into.
      def cities
        accumulators = {}
        each { |record| (accumulators[City.group_key(record)] ||= City::Accumulator.new(record)).add(record) }
        accumulators.each_value.map(&:to_city).sort_by { |city| City.sort_key(city) }
      end

      private

      def resolve_voivodeship(name)
        return nil if name.nil?

        Voivodeship.find_by_name(name)&.teryt_code || :unknown
      end

      def scan
        found = []
        open_data do |file|
          file.each_line do |line|
            found << Record.from_row(line.chomp.split("\t", -1)) if yield(line)
          end
        end
        found
      end

      def open_data
        raise DatasetError, "brak zbioru danych: #{path} (uruchom `rake zip_codes:pl:update`)" unless File.exist?(path)

        File.open(path) do |file|
          header = file.gets&.chomp&.split("\t")
          raise DatasetError, "nieoczekiwany nagłówek w #{path}" unless header == HEADER

          yield file
        end
      end
    end
  end
end
