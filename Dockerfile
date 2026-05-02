# syntax=docker/dockerfile:1.7
#
# stackedhq/postgres — batteries-included Postgres for Stacked-managed databases.
#
# Built on the official `postgres:${PG_MAJOR}-bookworm` image (which already
# wires up the PGDG apt source). We layer a curated set of extensions from
# PGDG, drop in init scripts that create the `extensions` schema and enable
# the always-on basics, and let the upstream entrypoint handle everything else.
#
# Extensions in this image (v1):
#
#   contrib (always available, just need CREATE EXTENSION):
#     pg_stat_statements, pgcrypto, uuid-ossp, auto_explain, pg_trgm,
#     btree_gin, btree_gist, hstore, citext, ltree, intarray, tablefunc,
#     unaccent
#
#   PGDG packages:
#     pgvector, postgis, pg_cron, pgaudit, pg_repack, pg_partman, hypopg
#
# `shared_preload_libraries` and other system-level GUCs are set via
# ALTER SYSTEM in `init.d/00-shared-preload.sql`, which the official
# entrypoint runs against the temporary init server. The persisted values
# land in `postgresql.auto.conf` inside $PGDATA and survive restarts.
#
# Non-goals for v1:
#   - pgrx-built extensions (pg_graphql, pg_net, pg_jsonschema, pgmq)
#   - TimescaleDB, OrioleDB (separate upstream images, exposed as flavors)
#   - supautils / supabase_vault / pg_tle (multi-tenant primitives we
#     don't need on single-tenant VPS deploys)

ARG PG_MAJOR=17
FROM postgres:${PG_MAJOR}-bookworm

# Re-declare so it's available in this stage.
ARG PG_MAJOR

LABEL org.opencontainers.image.source="https://github.com/stackedhq/postgres"
LABEL org.opencontainers.image.title="stackedhq/postgres"
LABEL org.opencontainers.image.description="Batteries-included Postgres ${PG_MAJOR} for Stacked"
LABEL org.opencontainers.image.licenses="BUSL-1.1"

# Install PGDG extensions. We pin neither package versions nor the apt
# snapshot — the weekly CI rebuild keeps us tracking PGDG security updates.
# If we need stricter pinning later, switch this to apt-mark hold + explicit
# `pkg=version` selectors.
RUN set -eux \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        "postgresql-${PG_MAJOR}-pgvector" \
        "postgresql-${PG_MAJOR}-postgis-3" \
        "postgresql-${PG_MAJOR}-cron" \
        "postgresql-${PG_MAJOR}-pgaudit" \
        "postgresql-${PG_MAJOR}-repack" \
        "postgresql-${PG_MAJOR}-partman" \
        "postgresql-${PG_MAJOR}-hypopg" \
    && rm -rf /var/lib/apt/lists/*

# Init scripts run once on first boot against an empty data directory,
# via the upstream `docker-entrypoint.sh`. Subsequent boots skip them.
COPY init.d/ /docker-entrypoint-initdb.d/
