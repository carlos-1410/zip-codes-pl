# Changelog

## [Unreleased]

## [0.1.0]

First release.

- Builds the Polish postal-code dataset from GeoNames into a directory of your
  choosing, as a compressed TSV plus a manifest.
- Refreshes with a conditional `If-None-Match` request, so a repeated run
  downloads nothing when the source is unchanged.
- Replaces the source's English voivodeship labels with a verified Polish table
  mapped onto official TERYT codes, and refuses to build on an unknown code
  rather than dropping the row.
- Reads back by postal code or by place name, ignoring case and diacritics, and
  aggregates rows into places with a mean coordinate.
- Ships `pl_zip_codes:update` and `pl_zip_codes:info` rake tasks, loaded
  automatically in Rails.
