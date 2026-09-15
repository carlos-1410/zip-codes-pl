# frozen_string_literal: true

namespace :zip_codes do
  namespace :pl do
    desc "Download and refresh the postal code dataset (rake zip_codes:pl:update[directory])"
    task :update, [:output_dir] do |_task, args|
      require "zip_codes/pl"

      result = ZipCodes::PL.update(output_dir: args[:output_dir])
      manifest = result.manifest

      if result.up_to_date?
        puts "Source unchanged - the dataset is already current: #{result.data_path}"
      else
        puts "Wrote #{manifest.row_count} rows to #{result.data_path}"
      end
      puts "Source: #{manifest.attribution}" if manifest
    end

    desc "Check the bundled dataset against its manifest and the record columns"
    task :verify, [:output_dir] do |_task, args|
      require "zip_codes/pl"

      ZipCodes::PL.config.output_dir = args[:output_dir] if args[:output_dir]
      path = ZipCodes::PL.config.readable_data_path
      manifest = ZipCodes::PL.manifest
      abort("No dataset at #{path}") unless File.exist?(path)
      abort("No manifest next to #{path}") if manifest.nil?

      header = File.open(path, &:gets).to_s.chomp.split("\t")
      expected = ZipCodes::PL::Record::COLUMNS.map(&:to_s)
      abort("Header is #{header.inspect}, expected #{expected.inspect}") unless header == expected

      rows = ZipCodes::PL.reader.count
      abort("Manifest claims #{manifest.row_count} rows, the file holds #{rows}") unless rows == manifest.row_count

      known = ZipCodes::PL::Voivodeship.all.to_h { |voivodeship| [voivodeship.teryt_code, true] }
      unknown = ZipCodes::PL.reader.reject { |record| known.key?(record.voivodeship_teryt) }
      abort("Unknown voivodeship codes: #{unknown.first(5).map(&:voivodeship_teryt).uniq.inspect}") if unknown.any?

      puts "Dataset consistent: #{rows} rows, #{known.size} voivodeships, built #{manifest.built_at}"
    end

    desc "Show the state of the built dataset"
    task :info, [:output_dir] do |_task, args|
      require "zip_codes/pl"

      ZipCodes::PL.config.output_dir = args[:output_dir] if args[:output_dir]
      manifest = ZipCodes::PL.manifest

      if manifest.nil?
        puts "No dataset in #{ZipCodes::PL.config.output_dir} - run rake zip_codes:pl:update"
        next
      end

      puts "File:       #{ZipCodes::PL.config.data_path}"
      puts "Rows:       #{manifest.row_count}"
      puts "Built:      #{manifest.built_at}"
      puts "Source:     #{manifest.source_url}"
      puts "Modified:   #{manifest.last_modified}"
      puts "Attribution: #{manifest.attribution}"
    end
  end
end
