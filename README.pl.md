# pl-zip-codes

*(English documentation: [README.md](README.md))*

Polskie kody pocztowe, miejscowości i województwa **ze współrzędnymi**, budowane
i odświeżane jednym zadaniem rake.

**Zbiór jedzie razem z gemem, więc nie trzeba niczego budować przed pierwszym
użyciem.** Zadanie rake odświeża go do wskazanego katalogu, pytając serwer
nagłówkiem `If-None-Match`, więc powtórne uruchomienie nie pobiera ani bajta,
kiedy źródło się nie zmieniło. Twoja odświeżona kopia ma pierwszeństwo przed
tą z gema.

Zbiór to **72 899 wierszy**, **20 299 kodów pocztowych** i **52 325
miejscowości** w 16 województwach, w pliku TSV o rozmiarze 6,6 MB. Wczytuje się
w niecałe 200 ms.

## Instalacja

```ruby
gem "pl-zip-codes"
```

## Odświeżanie zbioru

GeoNames publikuje codziennie. Żeby wziąć nowszy zrzut niż ten w twojej wersji:

```bash
rake pl_zip_codes:update            # do katalogu domyślnego (data/)
rake pl_zip_codes:update[db/pna]    # do wskazanego katalogu
rake pl_zip_codes:info[db/pna]      # co jest zbudowane i z kiedy
```

W aplikacji Rails zadanie podpina się samo przez railtie. Poza Railsami dodaj do
swojego `Rakefile`:

```ruby
load Gem::Specification.find_by_name("pl-zip-codes").gem_dir + "/lib/pl_zip_codes/tasks/pl_zip_codes.rake"
```

Katalog wyjściowy ustawia się też na stałe:

```ruby
PlZipCodes.configure do |config|
  config.output_dir = Rails.root.join("db/pna").to_s
end
```

albo zmienną `PL_ZIP_CODES_DIR`. Odczyt najpierw zagląda tam, a w razie braku
pliku sięga po zbiór z gema — ustawienie katalogu, którego jeszcze nie
odświeżyłeś, niczego nie psuje.

## Użycie

```ruby
PlZipCodes.find_by_postal_code("86-010")   # działa też "86010"
# => [#<data PlZipCodes::Record postal_code="86-010", city="Koronowo", ...>, ...]

PlZipCodes.find_by_city("zlotow")          # bez ogonków i wielkości liter
PlZipCodes.find_by_city("Koronowo", voivodeship: "kujawsko-pomorskie")

PlZipCodes.voivodeships
# => 16 rekordów: kod TERYT, nazwa, slug bez polskich znaków
```

Jeden rekord to jeden kod pocztowy w jednej miejscowości. Miejscowość z kilkoma
kodami ma kilka rekordów, tak samo kod dzielony przez kilka wsi — `86-010` to
42 miejscowości wokół Koronowa.

Kiedy potrzebujesz **miejscowości, a nie kodów**, jest gotowa agregacja:

```ruby
PlZipCodes.cities.first
# => #<data PlZipCodes::Dataset::City
#      name="Adamów", voivodeship="lubelskie", voivodeship_teryt="06",
#      commune="Gmina Adamów", commune_teryt="060302",
#      latitude=50.6..., longitude=22.5..., postal_codes=["21-412"]>
```

Współrzędne miejscowości to średnia z jej wierszy, bo źródło daje punkt na kod
pocztowy, a Bydgoszcz ma ich 679.

Miejscowość jest identyfikowana nazwą **i gminą**, nie samą nazwą. W Polsce jest
119 wsi „Nowa Wieś", z czego 28 w jednym województwie; sklejenie ich po nazwie
wystawia punkt w polu, nawet 158 km od najdalszej z nich.

### Import do bazy

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

## Format pliku

`pl-zip-codes.tsv` — TSV z nagłówkiem, obok `pl-zip-codes.manifest.json` z
ETagiem źródła, datą budowy i liczbą wierszy. Celowo nieskompresowany: plik jest
commitowany, więc odświeżenie ma dawać diff do przejrzenia, a nie nowy nieczytelny
blob. Kolumny:

| kolumna | przykład | uwagi |
|---|---|---|
| `postal_code` | `86-010` | |
| `city` | `Nowa Wieś Wielka` | |
| `voivodeship` | `kujawsko-pomorskie` | nazwa z tego gema, nie ze źródła |
| `voivodeship_teryt` | `04` | urzędowy kod TERYT |
| `county` / `county_teryt` | `Powiat bydgoski` / `0403` | nazwa ze źródła, patrz niżej |
| `commune` / `commune_teryt` | `Gmina Koronowo` / `040304` | nazwa ze źródła |
| `latitude` / `longitude` | `53.3123` / `17.9539` | WGS84 |
| `accuracy` | `6` | pole źródła — patrz niżej |

Plik jest zapisywany przez plik tymczasowy i `rename`, więc przerwane pobieranie
nigdy nie zostawia połowicznego zbioru w miejscu kompletnego.

## Czego ten gem nie udaje

**To są centroidy kodów pocztowych, a nie punkty z pomiaru.** GeoNames wylicza
wiele z nich algorytmicznie z nazw miejscowości, a tam gdzie nie znajdzie
dopasowania, bierze średnią sąsiednich kodów. Nadają się do sortowania po
odległości i do mapy; nie są współrzędnymi geodezyjnymi. Kolumna `accuracy`
pochodzi ze źródła i dla Polski ma obecnie wartość `6` we **wszystkich** 72 899
wierszach, więc nie niesie żadnej informacji.

**To jest zbiór pocztowy, nie urzędowy rejestr miejscowości.** Obejmuje
miejscowości, które mają kod pocztowy w zrzucie GeoNames, w pisowni GeoNames.
Urzędowy TERYT SIMC jest większy i to on rozstrzyga o nazwach; różnicy między
nimi tutaj nie zmierzyłem.

**Nazwy województw są poprawione, nazwy powiatów i gmin nie.** Źródło podaje
wszystkie 16 województw po angielsku i niespójnie (`Lower Silesia`,
`Warmia-Masuria`, `Łódź Voivodeship`), więc gem ma własną, zweryfikowaną tabelę
i mapuje ją na kody TERYT. Na poziomie powiatu i gminy nazwy zostają takie, jakie
przyszły — 36 z 374 powiatów ma artefakty w rodzaju `Leszno County`. **Pewnym
identyfikatorem są kolumny `*_teryt`**, nie nazwy.

Naturalnym następnym krokiem jest dociągnięcie urzędowych polskich nazw z GUGiK
SLN (`mapy.geoportal.gov.pl/wss/service/SLN/guest/sln`), który zwraca je razem z
kodami TERYT — cały słownik to ok. 397 zapytań JSON-em, a join idzie po kodzie,
który już mamy w każdym wierszu.

Gem nie zawiera ulic ani numerów budynków i nie jest geokoderem adresów. Do
adresu z dokładnością do numeru służy darmowe UUG GUGiK
(`services.gugik.gov.pl/uug`).

## Źródło i licencja

Dane pochodzą z [GeoNames](https://www.geonames.org) na licencji
**CC BY 4.0**. Jeśli publikujesz zbudowany zbiór albo aplikację, która go
używa, musisz podać to źródło. Manifest niesie gotową formułkę atrybucji.

Sam kod jest na licencji MIT.
