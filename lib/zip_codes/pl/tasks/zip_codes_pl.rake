# frozen_string_literal: true

namespace :zip_codes do
  namespace :pl do
    desc "Pobiera i odświeża zbiór kodów pocztowych (rake zip_codes:pl:update[katalog])"
    task :update, [:output_dir] do |_task, args|
      require "zip_codes/pl"

      result = ZipCodes::PL.update(output_dir: args[:output_dir])
      manifest = result.manifest

      if result.up_to_date?
        puts "Bez zmian w źródle - zbiór pozostaje aktualny: #{result.data_path}"
      else
        puts "Zapisano #{manifest.row_count} wierszy do #{result.data_path}"
      end
      puts "Źródło: #{manifest.attribution}" if manifest
    end

    desc "Sprawdza spójność dołączonego zbioru z manifestem i modelem"
    task :verify, [:output_dir] do |_task, args|
      require "set"
      require "zip_codes/pl"

      ZipCodes::PL.config.output_dir = args[:output_dir] if args[:output_dir]
      path = ZipCodes::PL.config.readable_data_path
      manifest = ZipCodes::PL.manifest
      abort("Brak zbioru w #{path}") unless File.exist?(path)
      abort("Brak manifestu obok #{path}") if manifest.nil?

      header = File.open(path, &:gets).to_s.chomp.split("\t")
      expected = ZipCodes::PL::Record::COLUMNS.map(&:to_s)
      abort("Nagłówek #{header.inspect} zamiast #{expected.inspect}") unless header == expected

      rows = ZipCodes::PL.reader.count
      unless rows == manifest.row_count
        abort("Manifest deklaruje #{manifest.row_count} wierszy, plik ma #{rows}")
      end

      known = ZipCodes::PL::Voivodeship.all.map(&:teryt_code).to_set
      unknown = ZipCodes::PL.reader.reject { |record| known.include?(record.voivodeship_teryt) }
      abort("Nieznane kody województw: #{unknown.first(5).map(&:voivodeship_teryt).uniq.inspect}") if unknown.any?

      puts "Zbiór spójny: #{rows} wierszy, #{known.size} województw, zbudowany #{manifest.built_at}"
    end

    desc "Pokazuje stan zbudowanego zbioru"
    task :info, [:output_dir] do |_task, args|
      require "zip_codes/pl"

      ZipCodes::PL.config.output_dir = args[:output_dir] if args[:output_dir]
      manifest = ZipCodes::PL.manifest

      if manifest.nil?
        puts "Brak zbioru w #{ZipCodes::PL.config.output_dir} - uruchom rake zip_codes:pl:update"
        next
      end

      puts "Plik:       #{ZipCodes::PL.config.data_path}"
      puts "Wierszy:    #{manifest.row_count}"
      puts "Zbudowano:  #{manifest.built_at}"
      puts "Źródło:     #{manifest.source_url}"
      puts "Zmienione:  #{manifest.last_modified}"
      puts "Atrybucja:  #{manifest.attribution}"
    end
  end
end
