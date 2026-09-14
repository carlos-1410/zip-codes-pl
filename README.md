# pl-zip-codes

Polish postal codes, places and voivodeships **with coordinates**, built and
refreshed by a single rake task.

*(Dokumentacja po polsku: [README.pl.md](README.pl.md))*

The gem ships no data. On first run it downloads the source, turns it into one
compressed TSV file in a directory you choose, and records where it came from.
Every later run asks the server with `If-None-Match` and downloads nothing when
the source has not changed.

The current dataset is **72,899 rows**, **20,299 postal codes** and **45,511
places** across 16 voivodeships, in a file of about 980 kB.

## Why this exists

GeoNames is an excellent source of Polish postal codes and coordinates, and a
poor source of Polish *names*. It labels all sixteen voivodeships in English and
inconsistently — `Lower Silesia`, `Warmia-Masuria`, `Łódź Voivodeship` — which is
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

## Building the dataset

```bash
rake pl_zip_codes:update            # into the default directory (data/)
rake pl_zip_codes:update[db/pna]    # into a directory you choose
rake pl_zip_codes:info[db/pna]      # what is built, and when
```

In a Rails application a railtie loads the tasks for you. Elsewhere, add one
line to your `Rakefile`:

```ruby
load Gem::Specification.find_by_name("pl-zip-codes").gem_dir + "/lib/pl_zip_codes/tasks/pl_zip_codes.rake"
```

The output directory can also be set once:

```ruby
PlZipCodes.configure do |config|
  config.output_dir = Rails.root.join("db/pna").to_s
end
```

or through the `PL_ZIP_CODES_DIR` environment variable.

## Usage

```ruby
PlZipCodes.find_by_postal_code("86-010")   # "86010" works too
# => [#<data PlZipCodes::Record postal_code="86-010", city="Koronowo", ...>, ...]

PlZipCodes.find_by_city("zlotow")          # case and diacritics insensitive
PlZipCodes.find_by_city("Koronowo", voivodeship: "wielkopolskie")

PlZipCodes.voivodeships
# => 16 records: TERYT code, Polish name, ASCII slug
```

One record is one postal code in one place. A town with several codes has
several records, and so does a code shared by several villages — `86-010` covers
42 places around Koronowo.

When you want **places rather than codes**, there is a ready aggregation:

```ruby
PlZipCodes.cities.first
# => #<data PlZipCodes::Dataset::City
#      name="Adamów", voivodeship="lubelskie", voivodeship_teryt="06",
#      latitude=50.6..., longitude=22.5..., postal_codes=["21-412"]>
```

A place's coordinate is the mean of its rows, because the source gives one point
per postal code and Bydgoszcz has 679 of them.

### Importing into a database

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

`pl-zip-codes.tsv.gz` — tab separated with a header row, next to
`pl-zip-codes.manifest.json` holding the source ETag, build time and row count.

| column | example | note |
|---|---|---|
| `postal_code` | `86-010` | |
| `city` | `Nowa Wieś Wielka` | |
| `voivodeship` | `kujawsko-pomorskie` | from this gem, not from the source |
| `voivodeship_teryt` | `04` | official TERYT code |
| `county` / `county_teryt` | `Powiat bydgoski` / `0403` | name as received, see below |
| `commune` / `commune_teryt` | `Gmina Koronowo` / `040304` | name as received |
| `latitude` / `longitude` | `53.3123` / `17.9539` | WGS84 |
| `accuracy` | `6` | as reported by the source |

The file is written to a temporary path and renamed, so an interrupted download
never replaces a complete dataset with half of one.

## What this gem does not pretend to do

**Voivodeship names are corrected; county and commune names are not.** Below the
first level the labels are passed through as received, and 36 of 374 counties
carry artefacts such as `Leszno County`. **The `*_teryt` columns are the
dependable identifiers**, not the names.

The natural next step is pulling official Polish names from the Polish national
mapping agency's SLN dictionary
(`mapy.geoportal.gov.pl/wss/service/SLN/guest/sln`), which returns them together
with TERYT codes — the whole administrative dictionary is about 397 JSON
requests, and the join key is already in every row.

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

The data comes from [GeoNames](https://www.geonames.org) under
**CC BY 4.0**. If you redistribute a built dataset, or ship an application using
one, you must credit that source. The manifest carries a ready attribution
string.

The code is MIT licensed.
