# frozen_string_literal: true

require "minitest/autorun"
require "stringio"
require "tmpdir"
require "zip"

require "zip_codes/pl"

module TestHelpers
  # Two real rows plus one with an empty commune, which the live export contains
  # exactly once and which used to be the easiest thing to crash on.
  SAMPLE_ROWS = [
    "PL\t86-010\tKoronowo\tKujawsko-Pomorskie\t73\tPowiat bydgoski\t0403\tGmina Koronowo\t040304\t53.3123\t17.9539\t6",
    "PL\t85-000\tBydgoszcz\tKujawsko-Pomorskie\t73\tBydgoszcz\t0461\tBydgoszcz\t046101\t53.1502\t17.9778\t6",
    "PL\t64-111\tKoronowo\tGreater Poland\t86\tLeszno_County\t3013\tLipno\t301302\t51.9277\t16.6163\t6",
    "PL\t88-420\tJeziora\tKujawsko-Pomorskie\t73\t\t\t\t\t52.6545\t17.7599\t6",
    "PL\t86-060\tNowa Wieś Wielka\tKujawsko-Pomorskie\t73\tPowiat bydgoski\t0403" \
    "\tGmina Nowa Wieś Wielka\t040305\t53.0167\t18.0167\t6",
    "PL\t87-100\tNowa Wieś\tKujawsko-Pomorskie\t73\tToruń\t0463\tToruń\t046301\t53.0138\t18.5984\t6",
    "PL\t89-200\tNowa Wieś\tKujawsko-Pomorskie\t73\tPowiat żniński\t0411\tŻnin\t041105\t52.8500\t17.7167\t6"
  ].freeze

  module_function

  def geonames_archive(rows: SAMPLE_ROWS, entry: ZipCodes::PL::Sources::Geonames::ENTRY)
    buffer = Zip::OutputStream.write_buffer(StringIO.new(+"")) do |zip|
      zip.put_next_entry(entry)
      zip.write("#{rows.join("\n")}\n")
    end
    buffer.string
  end

  # Stands in for the network so the suite never reaches GeoNames.
  class StubSource
    attr_reader :requested_etags

    def initialize(archive:, etag: "\"abc\"", not_modified_for: nil)
      @archive = archive
      @etag = etag
      @not_modified_for = not_modified_for
      @requested_etags = []
      @real = ZipCodes::PL::Sources::Geonames.new
    end

    def download(etag: nil)
      @requested_etags << etag
      return nil if @not_modified_for && etag == @not_modified_for

      ZipCodes::PL::Sources::Geonames::Download.new(
        body: @archive, etag: @etag, last_modified: "Mon, 14 Sep 2026 03:05:00 GMT"
      )
    end

    def each_record(archive, &) = @real.each_record(archive, &)
  end
end
