# Tash Chess

A small app for running club chess tournaments: keep a roster of players, create a tournament,
add its members, pair rounds with board numbers, enter results, and show live standings.

Rails 8.1 · PostgreSQL · Hotwire (Turbo + Stimulus, importmap). No build step and no login.

The interface is in **Russian by default**. The RU / EN switch in the top bar changes the language, and the
choice is kept in a cookie.

## Setup

```sh
sudo systemctl start postgresql            # the system cluster is disabled by default
sudo -u postgres createuser -s "$USER"     # only once, if your user has no Postgres role yet

bundle install
bin/rails db:setup                          # creates the DBs, loads the schema and sample data
bin/dev                                     # http://localhost:3000
```

The app connects with libpq defaults, so `PGHOST`, `PGPORT`, `PGUSER` and `PGPASSWORD` work as
usual (e.g. `PGPORT=5433` for the PostgreSQL 14 cluster).

Tests: `bin/rspec` (RSpec; first run `bin/rails db:test:prepare`). Lint: `bin/rubocop`, `bin/brakeman`.
The whole CI pipeline runs locally with `bin/ci`.

## How a tournament runs

1. **Players**: add people to the roster. The name and nickname are required, and the nickname must be unique
   (case-insensitive). The FIDE rating is optional (1000–3000) and is used for seeding.
2. **New tournament**: pick **Swiss** or **Round robin** and set the number of rounds (1–50). The count doesn't
   depend on the number of players: with more rounds than opponents, players simply meet again. For a round robin
   you can leave it blank for one full cycle.
3. **Members**: tick players in the roster (or register a new one in place) and add them.
4. **Start**: pairs round 1 (Swiss) or every round (round robin).
5. **Pairings**: each round lists board (desk) numbers, White, Black, and each player's points before the round.
   Click `1–0`, `½–½` or `0–1` to record a result, or `×` to clear it.
6. **Standings**: rank, round-by-round results, points and tie-breaks.
7. Swiss: when a round is complete, click **Pair round N**. When everything is in, click **Finish tournament**
   to lock the results.

Pairings and standings update live in every open browser (Turbo morph refreshes over Action Cable), so a
screen in the playing hall stays up to date while the arbiter enters results. **Print pairings** gives a
clean sheet for the wall.

## Pairing rules

**Round robin**: FIDE Berger tables. Members are seeded by rating. With an odd count, one player rests
each round (0 points). More rounds than one cycle repeat the cycle with colors reversed (10 rounds for 6 players is
a double round robin).

**Swiss**: a simplified FIDE Dutch system:
- players are ranked by score, then rating;
- inside a score group the top half meets the bottom half; odd players float down;
- players meet as rarely as possible: everyone meets everyone once before anyone meets twice, the same pair
  doesn't meet in consecutive rounds, and a pairing that would leave the next round stuck is avoided. The search
  backtracks to keep these rules and relaxes them only when nothing else fits;
- colors are balanced and alternated; pairings try to avoid three of the same color in a row or a color
  difference above 2;
- with an odd count, the lowest-ranked player among those with the fewest byes gets one (1 point), so byes
  rotate evenly.

**Tie-breaks**: Swiss uses Buchholz, then Sonneborn-Berger, then wins. Round robin uses Sonneborn-Berger,
then wins. Fully tied players share a rank.

## Corrections

- Results can be changed any time before the tournament is finished, including earlier rounds.
- Players can join while the tournament runs (**Добавить игрока / Add player**). In a Swiss they play from the
  next round with 0 points. In a round robin the rounds that haven't started yet are paired again to include
  them; raise the number of rounds if they should meet everyone.
- Swiss: the latest round can be deleted and paired again. Round robin: changing the number of rounds re-pairs
  the rounds that haven't started.
- **Undo start** (in the ••• menu) removes all pairings while no result has been entered yet.
- Players or members who already have games can't be deleted, so history stays consistent.

## Translations

All interface text is in `config/locales/ru.yml` and `config/locales/en.yml`, and both files must have the same
keys. Russian validation messages, month names and plural rules come from the `rails-i18n` gem. In development
and test a missing translation raises an error, and `spec/requests/locales_spec.rb` renders every screen in both
languages, so a forgotten key fails the specs.

## Data model

```
Player ─< Participation >─ Tournament ─< Round ─< Game (board, white, black, result)
```

A bye is stored as a game without a black player and with the result `bye`. Standings are calculated
from the games (`app/models/standings.rb`). The pairing code is in `app/models/pairing/`.
