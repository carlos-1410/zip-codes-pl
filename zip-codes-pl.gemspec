# frozen_string_literal: true

require_relative "lib/zip_codes/pl/version"

Gem::Specification.new do |spec|
  spec.name = "zip-codes-pl"
  spec.version = ZipCodes::PL::VERSION
  spec.authors = ["Łukasz Kerl"]

  spec.summary = "Polish postal codes, localities, voivodeships, and coordinates"
  spec.description = "Builds and refreshes a local dataset of Polish postal codes " \
                     "(PNA), including locality, voivodeship, county and commune TERYT " \
                     "codes, and coordinates. PNA and coordinates come from GeoNames " \
                     "(CC BY 4.0), while administrative names come from Poczta Polska."
  spec.homepage = "https://github.com/carlos-1410/zip-codes-pl"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*.rb", "lib/**/*.rake", "data/*", "README.md", "README.pl.md", "LICENSE.txt"]
  spec.require_paths = ["lib"]

  spec.add_dependency "rubyzip", ">= 2.3", "< 4"
end
