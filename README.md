# Tash Chess

A small app for running club chess tournaments: keep a roster of players, create a tournament,
add its members, pair rounds with board numbers, enter results, and show live standings.

Rails 8.1 · PostgreSQL · Hotwire (Turbo + Stimulus, importmap). No build step and no login.

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

Tests: `bin/rails test`. Lint: `bin/rubocop`, `bin/brakeman`.

## How a tournament runs

1. **Players**: add people to the roster. The name and nickname are required, and the nickname must be unique
   (case-insensitive). The FIDE rating is optional (1000–3000) and is used for seeding.
2. **New tournament**: pick **Swiss** (set the number of rounds) or **Round robin**.
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
each round (0 points).

**Swiss**: a simplified FIDE Dutch system:
- players are ranked by score, then rating;
- inside a score group the top half meets the bottom half; odd players float down;
- no rematches, and nobody gets a second bye. The search backtracks to keep both rules and relaxes them only
  when no legal pairing exists;
- colors are balanced and alternated; pairings try to avoid three of the same color in a row or a color
  difference above 2;
- with an odd count, the lowest-ranked player without a bye gets one (1 point).

**Tie-breaks**: Swiss uses Buchholz, then Sonneborn-Berger, then wins. Round robin uses Sonneborn-Berger,
then wins. Fully tied players share a rank.

## Corrections

- Results can be changed any time before the tournament is finished, including earlier rounds.
- Swiss: the latest round can be deleted and paired again. Late entries can be added while the
  tournament runs and join the next round with 0 points.
- **Undo start** (in the ••• menu) removes all pairings while no result has been entered yet.
- Players or members who already have games can't be deleted, so history stays consistent.

## Data model

```
Player ─< Participation >─ Tournament ─< Round ─< Game (board, white, black, result)
```

A bye is stored as a game without a black player and with the result `bye`. Standings are calculated
from the games (`app/models/standings.rb`). The pairing code is in `app/models/pairing/`.
