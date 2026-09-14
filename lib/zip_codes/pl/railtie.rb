# frozen_string_literal: true

module ZipCodes
  module PL
    class Railtie < Rails::Railtie
      rake_tasks do
        load File.expand_path("tasks/zip_codes_pl.rake", __dir__)
      end
    end
  end
end
