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
miejscowości** w 16 województwach, w pliku TSV o rozmiarze 6,6 MB. Wyszukiwanie
skanuje plik bez budowania indeksu i bez trzymania całego zbioru w pamięci.

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

Kiedy zrzut GeoNames się zmienił, build dociąga z publicznej wyszukiwarki
Poczty Polskiej nazwy powiatów i gmin po kodach TERYT.
Zapytania idą sekwencyjnie, domyślnie nie częściej niż co 0,25 s; odpowiedź
`429` wstrzymuje kolejne zapytanie zgodnie z `Retry-After`. Pełne wzbogacenie
zajmuje obecnie około pięciu minut. Przy odpowiedzi `304 Not Modified` Poczta
Polska nie jest odpytywana.

W aplikacji Rails zadanie podpina się samo przez railtie. Poza Railsami dodaj do
swojego `Rakefile`:

```ruby
load Gem::Specification.find_by_name("pl-zip-codes").gem_dir + "/lib/pl_zip_codes/tasks/pl_zip_codes.rake"
```

Katalog wyjściowy ustawia się też na stałe:

```ruby
PlZipCodes.configure do |config|
  config.output_dir = Rails.root.join("db/pna").to_s
  config.poczta_request_interval = 0.5 # opcjonalnie jeszcze wolniej
end
```

albo zmienną `PL_ZIP_CODES_DIR`. Odczyt najpierw zagląda tam, a w razie braku
pliku sięga po zbiór z gema - ustawienie katalogu, którego jeszcze nie
odświeżyłeś, niczego nie psuje.

## Użycie

```ruby
PlZipCodes.find_by_postal_code("86-010")   # działa też "86010"
# => [#<data PlZipCodes::Record postal_code="86-010", city="Koronowo", ...>, ...]

PlZipCodes.find_by_city("zlotow")          # bez ogonków i wielkości liter
PlZipCodes.find_by_city("Koronowo", voivodeship: "kujawsko-pomorskie")
PlZipCodes.search_by_city("wie")           # fragment nazwy, np. "Nowa Wieś"
PlZipCodes.search_by_city("OS")            # dokładnie "Oś"

PlZipCodes.voivodeships
# => 16 rekordów: kod TERYT, nazwa, slug bez polskich znaków
```

Wyszukiwanie fragmentu ignoruje wielkość liter i polskie znaki. Od trzech
znaków działa jak `%LIKE%`; dwuznakowa fraza dopasowuje tylko całą nazwę, dzięki
czemu nadal można znaleźć najkrótszą miejscowość „Oś”. Jednoznakowe zapytania
zwracają pusty wynik bez skanowania pliku.

Jeden rekord to jeden kod pocztowy w jednej miejscowości. Miejscowość z kilkoma
kodami ma kilka rekordów, tak samo kod dzielony przez kilka wsi - `86-010` to
42 miejscowości wokół Koronowa.

Kiedy potrzebujesz **miejscowości, a nie kodów**, jest gotowa agregacja:

```ruby
PlZipCodes.cities.first
# => #<data PlZipCodes::City
#      name="Adamów", voivodeship="lubelskie", voivodeship_teryt="06",
#      commune="Adamów", commune_teryt="061103",
#      latitude=51.7429, longitude=22.263, postal_codes=["21-412"]>
```

Współrzędne miejscowości to średnia z jej wierszy, bo źródło daje punkt na kod
pocztowy, a Bydgoszcz ma ich 679.

Miejscowość jest identyfikowana nazwą **i gminą**, nie samą nazwą. W Polsce jest
119 wsi „Nowa Wieś", z czego 28 w jednym województwie; sklejenie ich po nazwie
wystawia punkt w polu, nawet 158 km od najdalszej z nich.

### Import do bazy

Surowe rekordy można importować partiami bez wczytywania całego pliku:

```ruby
PlZipCodes.each_record.each_slice(1000) do |batch|
  PostalCode.upsert_all(batch.map(&:to_h))
end
```

Albo zapisać zagregowane miejscowości:

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

`pl-zip-codes.tsv` - TSV z nagłówkiem, obok `pl-zip-codes.manifest.json` z
ETagiem źródła, datą budowy i liczbą wierszy. Celowo nieskompresowany: plik jest
commitowany, więc odświeżenie ma dawać diff do przejrzenia, a nie nowy nieczytelny
blob. Kolumny:

| kolumna | przykład | uwagi |
|---|---|---|
| `postal_code` | `86-010` | |
| `city` | `Nowa Wieś Wielka` | |
| `voivodeship` | `kujawsko-pomorskie` | nazwa z tego gema, nie ze źródła |
| `voivodeship_teryt` | `04` | urzędowy kod TERYT |
| `county` / `county_teryt` | `powiat bydgoski` / `0403` | nazwa z Poczty Polskiej po kodzie TERYT |
| `commune` / `commune_teryt` | `Koronowo` / `040304` | nazwa z Poczty Polskiej po kodzie TERYT |
| `latitude` / `longitude` | `53.3123` / `17.9539` | WGS84 |
| `accuracy` | `6` | pole źródła - patrz niżej |

Plik jest zapisywany przez plik tymczasowy i `rename`. Błąd pobierania GeoNames,
odpowiedzi Poczty Polskiej, parsowania albo walidacji zostawia poprzedni TSV i
manifest bez zmian.

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

**Nazwy administracyjne są ujednolicone po kodach TERYT.** Gem ma własną tabelę
16 województw, a podczas odświeżenia pobiera z Poczty Polskiej aktualne nazwy
powiatów i gmin. Jedynym jawnym wyjątkiem jest historyczny kod `320304` dawnej
gminy Ostrowice, zniesionej 1 stycznia 2019, który nadal występuje w GeoNames.
**Pewnym identyfikatorem pozostają kolumny `*_teryt`**, nie nazwy.

Gem nie zawiera ulic ani numerów budynków i nie jest geokoderem adresów. Do
adresu z dokładnością do numeru służy darmowe UUG GUGiK
(`services.gugik.gov.pl/uug`).

## Źródło i licencja

Dane PNA i współrzędne pochodzą z [GeoNames](https://www.geonames.org) na
licencji **CC BY 4.0**. Nazwy powiatów i gmin są pobierane z publicznej
wyszukiwarki [Poczty Polskiej](https://www.poczta-polska.pl/znajdz-kod-pocztowy/).
Manifest niesie gotową formułkę atrybucji.

Sam kod jest na licencji MIT.
