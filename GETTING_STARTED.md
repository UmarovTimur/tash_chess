# Getting started

How to run Tash Chess on your computer, run the tests, and start it in production.
For what the app does, see the [README](README.md).

## What you need

| | Version | Notes |
|---|---|---|
| Ruby | 3.4.9 | Pinned in `.ruby-version`; `mise install` or `rbenv install` picks it up |
| PostgreSQL | 14 or newer | Plus the libpq headers for the `pg` gem (`libpq-dev` on Debian/Ubuntu) |

No Node.js, Yarn or asset build: JavaScript is served through import maps.

## 1. Start PostgreSQL and create your role

```sh
sudo systemctl start postgresql             # the service may be disabled at boot
sudo -u postgres createuser -s "$USER"      # once: a superuser role with your login name
```

The role must be a **superuser**: when the specs load test data, Rails checks foreign keys in a way only a
superuser may. If your role already exists without it:

```sh
sudo -u postgres psql -c "ALTER ROLE \"$USER\" SUPERUSER"
```

The app connects with libpq defaults (local socket, port 5432, your login name). The usual variables
point it elsewhere: `PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD`. For example, `export PGPORT=5433` for a
second cluster.

## 2. Install and set up

```sh
git clone <repository-url> tash_chess
cd tash_chess
bin/setup
```

`bin/setup` installs the gems, creates the database with the schema and sample data, and starts the server.
Run it again after pulling changes: it installs new gems and runs new migrations.

- `bin/setup --skip-server`: everything except starting the server.
- `bin/setup --reset`: also wipes the database and reloads the sample data.

The same steps by hand:

```sh
bundle install
bin/rails db:setup      # create the database, load the schema and the sample data
bin/dev
```

## 3. Open the app

Go to <http://localhost:3000>. Use `localhost`, not `127.0.0.1`: in development, live updates only
connect from `localhost`.

The sample data is a roster of 10 players and a Swiss tournament, "Club Rapid Open" (8 members, 5 rounds),
that hasn't started yet. The interface is in Russian; the RU / EN switch is in the top bar.

`bin/dev -p 4000` runs on another port. Ctrl+C stops the server.

### The login

The app is open unless both login variables are set. To try the login (HTTP Basic auth):

```sh
BASIC_AUTH_USERNAME=arbiter BASIC_AUTH_PASSWORD=secret bin/dev
```

## Tests and checks

```sh
bin/rails db:test:prepare               # once, and again after new migrations
bin/rspec                               # all specs
bin/rspec spec/requests/players_spec.rb # one file
bin/rubocop                             # style
bin/brakeman                            # security scan
bin/ci                                  # everything CI runs, starting with bin/setup --skip-server
```

## Everyday commands

| Task | Command |
|---|---|
| Start the server | `bin/dev` |
| Rails console | `bin/rails console` |
| Run new migrations | `bin/rails db:migrate` |
| Wipe the database and reload the sample data | `bin/rails db:reset` |
| Add the sample data again, keeping everything else | `bin/rails db:seed` |

## Running in production

The `Dockerfile` builds a production image, and `config/deploy.yml` deploys it with Kamal. The container
needs these variables:

| Variable | Purpose |
|---|---|
| `RAILS_MASTER_KEY` | Contents of `config/master.key`, which is not in git: get it from whoever set up the app |
| `BASIC_AUTH_USERNAME`, `BASIC_AUTH_PASSWORD` | The shared login. Optional: without them the app is open to everyone |
| `PGHOST` (and `PGPORT` if not 5432) | The PostgreSQL server. Kamal points it at its own `tash_chess-db` container |
| `TASH_CHESS_DATABASE_PASSWORD` | Password of the `tash_chess` database role |
| `SOLID_QUEUE_IN_PUMA=true` | Runs background jobs inside the web server. Live updates are sent by a job, so without it screens don't refresh |

On start the container runs `bin/rails db:prepare`, which creates four databases: `tash_chess_production`,
plus `_cache`, `_queue` and `_cable`. So the `tash_chess` role needs the `CREATEDB` right, or create them
beforehand.

**With plain Docker:**

```sh
docker build -t tash_chess .
docker run -d -p 80:80 --name tash_chess \
  -e RAILS_MASTER_KEY="$(cat config/master.key)" \
  -e BASIC_AUTH_USERNAME=arbiter -e BASIC_AUTH_PASSWORD=... \
  -e PGHOST=db.example.lan -e TASH_CHESS_DATABASE_PASSWORD=... \
  -e SOLID_QUEUE_IN_PUMA=true \
  tash_chess
```

**With Kamal:** `config/deploy.yml` deploys to the VPS as the `deploy` user, runs PostgreSQL 16 next to the app
(the `tash_chess-db` accessory), and sets everything in the table above. kamal-proxy serves the app over HTTPS
with a Let's Encrypt certificate, and production forces HTTPS. The settings that differ per deploy live in
`.env.deploy`, which is not in git:

```sh
TASH_CHESS_HOST="guide64.org"
TASH_CHESS_DATABASE_PASSWORD="..."
# BASIC_AUTH_USERNAME=...   # uncomment both to turn on the login
# BASIC_AUTH_PASSWORD=...
```

`config/deploy.yml` loads it, so you can deploy right away (variables already set in the shell win):

```sh
bin/kamal setup     # first time: starts the database, then deploys
bin/kamal deploy    # after that
```

Kamal builds the image from the last commit, so commit your changes before deploying. Production doesn't load
the sample data. Useful afterwards: `bin/kamal logs`, `bin/kamal console`, `bin/kamal dbc`.

## Troubleshooting

| Problem | Fix |
|---|---|
| `connection to server on socket "/var/run/postgresql/.s.PGSQL.5432" failed` | PostgreSQL isn't running (`sudo systemctl start postgresql`), or it listens on another port (`PGPORT`) |
| `role "..." does not exist` | Create your role (step 1) |
| Specs fail with `PG::InsufficientPrivilege: permission denied for table pg_constraint` | Make your role a superuser (step 1) |
| The `pg` gem fails to build and can't find `libpq-fe.h` | `sudo apt install libpq-dev`, then `bundle install` |
| A page fails with `Translation missing` | Development and test raise on missing text. Add the key to both `config/locales/ru.yml` and `config/locales/en.yml` |
| Live updates don't arrive in development | Open the app at `localhost`, not `127.0.0.1` |