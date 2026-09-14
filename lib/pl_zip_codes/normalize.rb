# frozen_string_literal: true

module PlZipCodes
  # Folding used for lookups only. Stored names keep their diacritics; this is
  # what makes "zlotow", "Złotów" and "ZŁOTÓW" find the same rows.
  module Normalize
    DIACRITICS = {
      "ą" => "a", "ć" => "c", "ę" => "e", "ł" => "l", "ń" => "n",
      "ó" => "o", "ś" => "s", "ź" => "z", "ż" => "z"
    }.freeze

    POSTAL_CODE_PATTERN = /\A(\d{2})-?(\d{3})\z/

    module_function

    def key(value)
      value.to_s.strip.downcase.gsub(/[ąćęłńóśźż]/, DIACRITICS)
    end

    # Accepts "86-010" and "86010"; returns nil for anything that is not a PNA.
    def postal_code(value)
      match = POSTAL_CODE_PATTERN.match(value.to_s.strip)
      return nil if match.nil?

      "#{match[1]}-#{match[2]}"
    end
  end
end
