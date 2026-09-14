# frozen_string_literal: true

require "test_helper"

class NormalizeTest < Minitest::Test
  Normalize = PlZipCodes::Normalize

  def test_folds_case_and_polish_diacritics
    assert_equal "zlotow", Normalize.key("Złotów")
    assert_equal "zlotow", Normalize.key("ZŁOTÓW")
    assert_equal "zlotow", Normalize.key("  złotów  ")
  end

  def test_folds_every_polish_diacritic
    assert_equal "acelnoszz", Normalize.key("ąćęłńóśźż")
  end

  def test_keeps_multi_word_names_distinct
    assert_equal "nowa wies wielka", Normalize.key("Nowa Wieś Wielka")
  end

  def test_accepts_postal_codes_with_and_without_the_dash
    assert_equal "86-010", Normalize.postal_code("86-010")
    assert_equal "86-010", Normalize.postal_code("86010")
    assert_equal "86-010", Normalize.postal_code(" 86-010 ")
  end

  def test_rejects_anything_that_is_not_a_postal_code
    assert_nil Normalize.postal_code("86-01")
    assert_nil Normalize.postal_code("8601")
    assert_nil Normalize.postal_code("abc-def")
    assert_nil Normalize.postal_code(nil)
  end
end
