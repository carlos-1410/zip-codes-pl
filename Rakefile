# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test" << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

$LOAD_PATH.unshift File.expand_path("lib", __dir__)
load File.expand_path("lib/zip_codes/pl/tasks/zip_codes_pl.rake", __dir__)

task default: :test
