# frozen_string_literal: true

module PlZipCodes
  class Railtie < Rails::Railtie
    rake_tasks do
      load File.expand_path("tasks/pl_zip_codes.rake", __dir__)
    end
  end
end
