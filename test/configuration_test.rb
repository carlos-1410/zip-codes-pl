# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  # A relative path into the gem's own data directory breaks silently the moment
  # a file moves, and the fallback it feeds has no other guard.
  def test_bundled_dataset_is_where_the_configuration_says
    config = ZipCodes::PL::Configuration.new

    assert_path_exists config.bundled_data_path
    assert_equal "zip-codes-pl.tsv", File.basename(config.bundled_data_path)
  end

  def test_reads_fall_back_to_the_bundled_dataset
    Dir.mktmpdir do |dir|
      config = ZipCodes::PL::Configuration.new
      config.output_dir = dir

      assert_equal config.bundled_data_path, config.readable_data_path
    end
  end

  def test_a_refreshed_copy_wins_over_the_bundled_one
    Dir.mktmpdir do |dir|
      config = ZipCodes::PL::Configuration.new
      config.output_dir = dir
      File.write(config.data_path, "")

      assert_equal config.data_path, config.readable_data_path
    end
  end
end
