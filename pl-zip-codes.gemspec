# frozen_string_literal: true

require_relative "lib/pl_zip_codes/version"

Gem::Specification.new do |spec|
  spec.name = "pl-zip-codes"
  spec.version = PlZipCodes::VERSION
  spec.authors = ["Łukasz Kerl"]

  spec.summary = "Polskie kody pocztowe, miejscowości i województwa ze współrzędnymi"
  spec.description = "Buduje i odświeża lokalny zbiór polskich kodów pocztowych " \
                     "(PNA) wraz z miejscowością, województwem, kodami TERYT powiatu " \
                     "i gminy oraz współrzędnymi. PNA i współrzędne pochodzą z GeoNames " \
                     "(CC-BY 4.0), a nazwy administracyjne z Poczty Polskiej."
  spec.homepage = "https://github.com/carlos-1410/pl-zip-codes"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*.rb", "lib/**/*.rake", "data/*", "README.md", "README.pl.md", "LICENSE.txt"]
  spec.require_paths = ["lib"]

  spec.add_dependency "rubyzip", ">= 2.3", "< 4"
end
