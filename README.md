# pl-zip-codes

Polish postal codes, places and voivodeships **with coordinates**, built and
refreshed by a single rake task.

*(Dokumentacja po polsku: [README.pl.md](README.pl.md))*

**The dataset ships with the gem, so there is nothing to build before first
use.** A rake task refreshes it into a directory of your choosing, asking the
server with `If-None-Match` so a repeated run downloads nothing when the source
has not changed. Your refreshed copy takes precedence over the bundled one.

The dataset holds **72,899 rows**, **20,299 postal codes** and **52,325 places**
across 16 voivodeships, as a 6.6 MB tab separated file. Lookups scan the file
without building an index or retaining the whole dataset in memory.

## Why this exists

GeoNames is an excellent source of Polish postal codes and coordinates, and a
poor source of Polish *names*. It labels all sixteen voivodeships in English and
inconsistently - `Lower Silesia`, `Warmia-Masuria`, `Łódź Voivodeship` - which is
not something you can put in front of a Polish user.

This gem carries its own verified table of the sixteen voivodeships, mapped onto
the official **TERYT** codes used by Polish public administration, and replaces
the upstream labels with it. The TERYT county and commune codes that GeoNames
does carry are passed through, so the result joins cleanly against any other
Polish register.

## Installation

```ruby
gem "pl-zip-codes"
```

## Refreshing the dataset

GeoNames republishes daily. To pick up a newer extract than the one bundled with
your installed version:

```bash
rake pl_zip_codes:update            # into the default directory (data/)
rake pl_zip_codes:update[db/pna]    # into a directory you choose
rake pl_zip_codes:info[db/pna]      # what is built, and when
```

When the GeoNames extract has changed, the build fetches county and commune
names by TERYT code from the public Poczta Polska search.
Requests are sequential and spaced by at least 0.25 seconds by default; a `429`
response delays the next request according to `Retry-After`. A full enrichment
currently takes about five minutes. Poczta Polska is not queried after a
`304 Not Modified` response from GeoNames.

In a Rails application a railtie loads the tasks for you. Elsewhere, add one
line to your `Rakefile`:

```ruby
load Gem::Specification.find_by_name("pl-zip-codes").gem_dir + "/lib/pl_zip_codes/tasks/pl_zip_codes.rake"
```

The output directory can also be set once:

```ruby
PlZipCodes.configure do |config|
  config.output_dir = Rails.root.join("db/pna").to_s
  config.poczta_request_interval = 0.5 # optionally go even slower
end
```

or through the `PL_ZIP_CODES_DIR` environment variable. Reads look there first
and fall back to the bundled dataset, so configuring a directory that has not
been refreshed yet changes nothing.

## Usage

```ruby
PlZipCodes.find_by_postal_code("86-010")   # "86010" works too
# => [#<data PlZipCodes::Record postal_code="86-010", city="Koronowo", ...>, ...]

PlZipCodes.find_by_city("zlotow")          # case and diacritics insensitive
PlZipCodes.find_by_city("Koronowo", voivodeship: "kujawsko-pomorskie")
PlZipCodes.search_by_city("wie")           # name fragment, e.g. "Nowa Wieś"
PlZipCodes.search_by_city("OS")            # exactly "Oś"

PlZipCodes.voivodeships
# => 16 records: TERYT code, Polish name, ASCII slug
```

Fragment searches ignore case and Polish diacritics. Queries of three or more
characters behave like `%LIKE%`; a two-character query only matches a complete
name, so the shortest place, `Oś`, remains searchable. One-character queries
return an empty result without scanning the file.

One record is one postal code in one place. A town with several codes has
several records, and so does a code shared by several villages - `86-010` covers
42 places around Koronowo.

When you want **places rather than codes**, there is a ready aggregation:

```ruby
PlZipCodes.cities.first
# => #<data PlZipCodes::City
#      name="Adamów", voivodeship="lubelskie", voivodeship_teryt="06",
#      commune="Adamów", commune_teryt="061103",
#      latitude=51.7429, longitude=22.263, postal_codes=["21-412"]>
```

A place's coordinate is the mean of its rows, because the source gives one point
per postal code and Bydgoszcz has 679 of them.

Places are identified by name **and commune**, not by name alone. Poland has 119
villages called `Nowa Wieś`, 28 of them in a single voivodeship; collapsing them
by name puts the resulting point in a field up to 158 km from the farthest one.

### Importing into a database

Raw records can be imported in batches without loading the entire file:

```ruby
PlZipCodes.each_record.each_slice(1000) do |batch|
  PostalCode.upsert_all(batch.map(&:to_h))
end
```

Or import the aggregated places:

```ruby
PlZipCodes.cities.each_slice(1000) do |batch|
  City.upsert_all(
    batch.map do |city|
      { name: city.name, province: city.voivodeship,
        latitude: city.latitude, longitude: city.longitude }
    end,
    unique_by: %i[name province]
  )
end
```

## File format

`pl-zip-codes.tsv` - tab separated with a header row, next to
`pl-zip-codes.manifest.json` holding the source ETag, build time and row count.
It is left uncompressed on purpose: the file is committed, and a refresh should
produce a reviewable diff rather than a fresh opaque blob.

| column | example | note |
|---|---|---|
| `postal_code` | `86-010` | |
| `city` | `Nowa Wieś Wielka` | |
| `voivodeship` | `kujawsko-pomorskie` | from this gem, not from the source |
| `voivodeship_teryt` | `04` | official TERYT code |
| `county` / `county_teryt` | `powiat bydgoski` / `0403` | Poczta Polska name joined by TERYT code |
| `commune` / `commune_teryt` | `Koronowo` / `040304` | Poczta Polska name joined by TERYT code |
| `latitude` / `longitude` | `53.3123` / `17.9539` | WGS84 |
| `accuracy` | `6` | as reported by the source - see below |

The file is written to a temporary path and renamed. A GeoNames download,
Poczta Polska response, parsing or validation failure leaves the previous TSV
and manifest unchanged.

## What this gem does not pretend to do

**These are postal-code centroids, not surveyed points.** GeoNames derives many
of them algorithmically from place names, and falls back to an average of
neighbouring postal codes where no match is found. They are good enough to sort
by distance or draw on a map; they are not property-grade coordinates. The
`accuracy` column is a source field, and for Poland it is currently `6` on all
72,899 rows, so it carries no usable signal.

**This is a postal dataset, not the official place register.** It covers places
that have a postal code in the GeoNames extract, under GeoNames' spelling. The
official Polish register (TERYT SIMC) is larger and authoritative on names; the
gap between the two has not been measured here.

**Administrative names are normalized by TERYT code.** The gem carries its own
table for the 16 voivodeships and fetches current county and commune names from
Poczta Polska during a refresh. The one explicit exception is historical code
`320304` for the former Ostrowice commune, abolished on 1 January 2019, which is
still present in GeoNames. **The `*_teryt` columns remain the dependable
identifiers**, not the names.

There are no streets or building numbers here, and this is not an address
geocoder. For address-level lookups Poland has a free official service at
`services.gugik.gov.pl/uug`.

## Development

```bash
bin/setup        # or: bundle install
bundle exec rake test
bundle exec rubocop
```

The test suite never touches the network: the source archive is generated in
memory and the HTTP transport is exercised against stubbed responses.

## Source and licence

Postal data and coordinates come from [GeoNames](https://www.geonames.org)
under **CC BY 4.0**. County and commune names are fetched from the public
[Poczta Polska search](https://www.poczta-polska.pl/znajdz-kod-pocztowy/).
The manifest carries a ready attribution string.

The code is MIT licensed.
