# Changelog

## [Unreleased]

### Fixed

- Places are grouped by commune as well as name. Grouping by name and
  voivodeship alone merged distinct villages sharing a name into one averaged
  point — 2,936 places sat more than 25 km from a row they claimed to cover, and
  6,814 real places were hidden entirely. No place is now further than 25 km from
  its own rows, and the median is 0.

### Changed

- The built dataset ships with the gem, so reads work with no setup. A refreshed
  copy in your own directory takes precedence.
- The dataset is a plain TSV instead of gzip, so a committed refresh produces a
  reviewable diff.
- `Dataset::City` carries `commune` and `commune_teryt`.

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
