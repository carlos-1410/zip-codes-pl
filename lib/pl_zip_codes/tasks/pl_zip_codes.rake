# frozen_string_literal: true

namespace :pl_zip_codes do
  desc "Pobiera i odświeża zbiór kodów pocztowych (rake pl_zip_codes:update[katalog])"
  task :update, [:output_dir] do |_task, args|
    require "pl_zip_codes"

    result = PlZipCodes.update(output_dir: args[:output_dir])
    manifest = result.manifest

    if result.up_to_date?
      puts "Bez zmian w źródle - zbiór pozostaje aktualny: #{result.data_path}"
    else
      puts "Zapisano #{manifest.row_count} wierszy do #{result.data_path}"
    end
    puts "Źródło: #{manifest.attribution}" if manifest
  end

  desc "Pokazuje stan zbudowanego zbioru"
  task :info, [:output_dir] do |_task, args|
    require "pl_zip_codes"

    PlZipCodes.config.output_dir = args[:output_dir] if args[:output_dir]
    manifest = PlZipCodes.manifest

    if manifest.nil?
      puts "Brak zbioru w #{PlZipCodes.config.output_dir} - uruchom rake pl_zip_codes:update"
      next
    end

    puts "Plik:       #{PlZipCodes.config.data_path}"
    puts "Wierszy:    #{manifest.row_count}"
    puts "Zbudowano:  #{manifest.built_at}"
    puts "Źródło:     #{manifest.source_url}"
    puts "Zmienione:  #{manifest.last_modified}"
    puts "Atrybucja:  #{manifest.attribution}"
  end
end
