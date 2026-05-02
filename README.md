# Stacked Postgres

The default Postgres image for [Stacked](https://stacked.rest)-managed
databases. Published to `ghcr.io/stackedhq/postgres:<major>`.

It's a thin layer on top of the official `postgres:<major>-bookworm`
image: a curated set of PGDG extensions, sensible defaults for
`shared_preload_libraries`, and a few always-on extensions
(`pg_stat_statements`, `pgcrypto`, `uuid-ossp`) installed into a
dedicated `extensions` schema.

This image runs as the actual database engine on user VPSes connected to
Stacked. It's published in the open so anyone running Stacked can audit
exactly what's inside the container they're trusting with their data —
the same trust principle behind [`stackedhq/agent`](https://github.com/stackedhq/agent).

## Using it

Pull the latest Postgres 17 build:

```bash
docker pull ghcr.io/stackedhq/postgres:17
```

Run it the same way you'd run upstream `postgres`:

```bash
docker run --rm \
  -e POSTGRES_USER=stk_user \
  -e POSTGRES_PASSWORD=secret \
  -e POSTGRES_DB=stk_db \
  -p 5432:5432 \
  ghcr.io/stackedhq/postgres:17
```

Then enable any of the bundled extensions:

```sql
CREATE EXTENSION vector;
CREATE EXTENSION postgis;
CREATE EXTENSION pg_partman;
```

> [!NOTE]
> The init scripts hardcode the database name `stk_db` — that's the
> name Stacked's provisioning code uses. If you run the image standalone
> with a different `POSTGRES_DB`, the `extensions` schema and the
> auto-enabled extensions won't be created for that database. Run the
> SQL in `init.d/01-extensions.sql` manually against your database.

## What's inside

Base: `postgres:<major>-bookworm` (Debian, official upstream).

Bundled extensions (PGDG packages):

- `pgvector` — vector similarity search
- `postgis` — geospatial
- `pg_cron` — in-database job scheduling
- `pgaudit` — session/object audit logging
- `pg_repack` — online table reorganisation
- `pg_partman` — partition management
- `hypopg` — hypothetical indexes
- `pg_stat_monitor` — query performance monitoring

Plus everything in `postgresql-contrib` (already shipped with the base
image): `pg_trgm`, `btree_gin`, `btree_gist`, `hstore`, `citext`,
`ltree`, `intarray`, `tablefunc`, `unaccent`, `uuid-ossp`, `pgcrypto`,
`pg_stat_statements`, `auto_explain`, etc.

Preloaded via `shared_preload_libraries`:
`pg_stat_statements`, `pg_cron`, `pgaudit`, `pg_stat_monitor`, `auto_explain`.

Auto-enabled on first boot in the `extensions` schema:
`pg_stat_statements`, `pgcrypto`, `uuid-ossp`.

## Tags

| Tag | Mutability | Use |
|---|---|---|
| `:<major>` (e.g. `:17`) | mutable | what the Stacked agent pulls |
| `:<major>-stk.<short-sha>` | immutable | sha-pinned, for staging |
| `:<major>-stk.<yyyymmdd>` | immutable | date-pinned snapshot |

## Build cadence

- On push to `master`: rebuild and publish.
- Weekly cron (Mondays 03:00 UTC): rebuild even with no changes, to pick
  up upstream `postgres:<major>-bookworm` security updates and PGDG
  extension patches.

## Building locally

```bash
docker build --build-arg PG_MAJOR=17 -t stackedhq/postgres:17 .
```

Smoke-test:

```bash
docker run --rm -d --name pgtest \
  -e POSTGRES_USER=stk_user \
  -e POSTGRES_PASSWORD=test \
  -e POSTGRES_DB=stk_db \
  -p 15432:5432 \
  stackedhq/postgres:17

docker exec pgtest psql -U stk_user -d stk_db -c \
  "SELECT extname FROM pg_extension ORDER BY extname;"

docker rm -f pgtest
```

## Adding a new extension

1. Confirm the package exists in PGDG:
   `docker run --rm postgres:17-bookworm apt-cache search "postgresql-17-"`.
2. Add the `postgresql-${PG_MAJOR}-<name>` line to `Dockerfile`.
3. If it requires preloading, append to `shared_preload_libraries` in
   `init.d/00-shared-preload.sql`.
4. If every Postgres user expects it on (rare — be conservative), add a
   `CREATE EXTENSION IF NOT EXISTS …` line to `init.d/01-extensions.sql`.
5. Open a PR. CI publishes a sha-pinned tag you can test against before
   the mutable major tag rolls forward.

Pgrx-built extensions (e.g. `pg_graphql`, `pg_net`, `pg_jsonschema`) are
intentionally out of scope for this image — they require a separate
build pipeline. If you need one, open an issue rather than wedging it in
here.

## Adding a new Postgres major

1. Add to the `pg_major` matrix in `.github/workflows/build.yml`.
2. Verify each `postgresql-<major>-<ext>` package exists on PGDG before
   adding it to the matrix — drop laggards rather than blocking the
   rollout.

We do not auto-upgrade existing data directories across majors. That's a
`pg_upgrade` job handled at the Stacked-agent level, not here.

## License

[Business Source License 1.1](./LICENSE) — same terms as
[`stackedhq/agent`](https://github.com/stackedhq/agent).
Free for non-production use; production use is allowed except for
offering the Licensed Work as a competing commercial hosted/managed
service.

For commercial licensing arrangements: `hello@stacked.rest`.
