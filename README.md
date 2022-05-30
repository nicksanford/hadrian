# Hadrian Server Instructions

Hadrian is an Elixir CDC (Change Data Capture) library. It can be used listen
to `INSERT`, `UPDATE` and `DELETE` changes in a Postgres database via logical
replication and forward them to downstream systems or components.

It supports either at most once or at least once delivery.

The postgres features it uses to accomplish this are:
1. Replication Slots
2. Logical Replication 
3. Publicaitions

It is a lean subset of the features provided by https://debezium.io/documentation/reference/stable/development/engine.html
which provides the following bennefits:

1. Able to be embeded in elixir applications for integration with phoneix channels
or other elixir features without any 3rd party systems such as kafka or a jvm.
2. Only supports postgres (doesn't need to support other debezium supported dbs)
and as a result has much less indirection compared with debezium.
3. Provides a solution which runs on the BEAM for teams who are already invested
in the Erlang/Elixir ecosystem.


It is a fork of https://github.com/supabase/Hadrian prior to the projects
introduction of row level security which itself is hevily based on 
https://github.com/cainophile/cainophile. More information on the philosophy
which lead to the development of a CDC tool in elixir can be found [here](https://bbhoss.io/posts/announcing-cainophile/).

## Database set up
The following are requirements for your database:

1. It must be Postgres 10+ as it uses logical replication
2. Set up your DB for replication
    1. It must have the wal_level set to logical. You can check this by running SHOW wal_level;. To set the wal_level, you can call `ALTER SYSTEM SET wal_level = logical`; Be sure to reboot your postgres server after doing so.
    2. You must set max_replication_slots to at least 1: `ALTER SYSTEM SET max_replication_slots = 10`;
3. Create a PUBLICATION for this server to listen to: `CREATE PUBLICATION hadrian FOR ALL TABLES`;
4. [OPTIONAL] If you want to receive the old record (previous values) on UPDATE and DELETE, you can set the REPLICA IDENTITY to FULL like this: ALTER TABLE your_table REPLICA IDENTITY FULL;. This has to be set for each table unfortunately.


Executing `pqsl -f ./sql/00-init.sql` against your postgres db will perform 2.1, 2.2 and 3 for you. Restart your db after doing so.

## Run with docker:
```sh
docker run                                   \
   -e DB_HOST='localhost'                    \
   -e DB_NAME='postgres'                     \
   -e DB_USER='postgres'                     \
   -e DB_PASSWORD='postgres'                 \
   -e DB_PORT=5432                           \
   -e DB_SSL=false                           \
   -e SLOT_NAME=Hadrian_at_least_once       \
```

## Modes:

### At least once delivery:

E.G. Idempotent Change Data Capture

```
MIX_ENV=prod mix release --overwrite && \
DB_USER=postgres \
DB_HOST=localhost \
DB_PASSWORD=postgres \
DB_NAME=hestia_dev \
DB_SSL=false \
DB_PORT=5432 \
SLOT_NAME=Hadrian_at_least_once
_build/prod/rel/Hadrian/bin/hadrian start_iex
```

### At most once delivery:

E.G. Maybe Hadrian web uis which can tolerate dropped data as worst case
the user can refresh.

```
MIX_ENV=prod mix release --overwrite && \
DB_USER=postgres \
DB_HOST=localhost \
DB_PASSWORD=postgres \
DB_NAME=hestia_dev \
DB_SSL=false \
DB_PORT=5432 \
MAX_REPLICATION_LAG_MB=5 \
_build/prod/rel/Hadrian/bin/hadrian start_iex
```

Nick's edit
```
MIX_ENV=prod mix release --overwrite && \
DB_USER=postgres \
DB_HOST=localhost \
DB_PASSWORD=postgres \
DB_NAME=hestia_dev \
DB_SSL=false \
DB_PORT=5432 \
SLOT_NAME=Hadrian_at_least_once \
MAX_REPLICATION_LAG_MB=0 \
_build/prod/rel/Hadrian/bin/hadrian start_iex
```

## Run locally via mix

```sh
PORT=4000            \
DB_USER=postgres     \
DB_HOST=localhost    \
DB_PASSWORD=postgres \
DB_NAME=postgres     \
DB_PORT=5432         \
SLOT_NAME=TEST_SLOT  \
MIX_ENV=dev          \
mix phx.server
```


## Run locally via releases

1. Create the release:

```sh
PORT=4000            \
DB_USER=postgres     \
DB_HOST=localhost    \
DB_PASSWORD=postgres \
DB_NAME=postgres     \
DB_PORT=5432         \
MIX_ENV=prod         \
mix release
```

2. Start the release:

```sh
PORT=4000 \
DB_USER=postgres \
DB_HOST=localhost \
DB_PASSWORD=postgres \
DB_NAME=postgres \
DB_PORT=5432 \
JWT_SECRET=SOMETHING_SECRET \
SECURE_CHANNELS=false
_build/prod/rel/Hadrian/bin/hadrian start
```

**ALL OPTIONS**

```sh
DB_HOST                 # {string}      Database host URL
DB_NAME                 # {string}      Postgres database name
DB_USER                 # {string}      Database user
DB_PASSWORD             # {string}      Database password
DB_PORT                 # {number}      Database port
DB_IP_VERSION           # {string}      (options: 'IPv4'/'IPv6') Connect to database via either IPv4 or IPv6. Disregarded if database host is an IP address (e.g. '127.0.0.1') and recommended if database host is a name (e.g. 'db.abcd.supabase.co') to prevent potential non-existent domain (NXDOMAIN) errors.
SLOT_NAME               # {string}      A unique name for Postgres to track where this server has "listened until". If the server dies, it can pick up from the last position. This should be lowercase.
MAX_REPLICATION_LAG_MB  # {number}      If set, when the replication lag exceeds MAX_REPLICATION_LAG_MB (value must be a positive integer in megabytes), then replication slot is dropped, Hadrian is restarted, and a new slot is created. Warning: setting MAX_REPLICATION_SLOT_MB could cause database changes to be lost when the replication slot is dropped.
```


Helpful resources

- [Deploy a Phoenix app with Docker stack](https://dev.to/ilsanto/deploy-a-phoenix-app-with-docker-stack-1j9c)
