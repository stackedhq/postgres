#!/usr/bin/env bash
#
# Configure system-level GUCs that need to be in place before users start
# enabling extensions. Runs once on first boot, against an empty data dir,
# from the upstream postgres entrypoint.
#
# We append to $PGDATA/postgresql.conf rather than using `ALTER SYSTEM SET`
# because list-type GUCs (notably `shared_preload_libraries`) round-trip
# through ALTER SYSTEM as a single quoted token in postgresql.auto.conf,
# which Postgres then fails to split on commas at the next start:
#
#     FATAL: could not access file "pg_stat_statements,pg_cron,…":
#            No such file or directory
#
# Appending verbatim to postgresql.conf avoids the round-trip entirely and
# matches the pattern used by Bitnami / postgis / supabase / every other
# batteries-included Postgres image. The values land before the entrypoint
# restarts Postgres into its final foreground process, so they're picked
# up by the time the database is accepting connections.

set -euo pipefail

cat >> "$PGDATA/postgresql.conf" <<'EOF'

# ---- stackedhq/postgres: extension preload + tuning ----
shared_preload_libraries = 'pg_stat_statements,pg_cron,pgaudit,auto_explain'

# pg_stat_statements
pg_stat_statements.track = 'all'
pg_stat_statements.max = 10000

# auto_explain — log plans for queries slower than 1s. Cheap and very
# useful for surfacing slow queries in the (future) monitoring tab.
auto_explain.log_min_duration = '1s'
auto_explain.log_analyze = off
auto_explain.log_buffers = on

# pg_cron — must point at a specific database. Stacked's provisioning
# code always creates the user database as `stk_db` (see
# src/lib/database-utils.ts in stackedhq/stacked). If that ever changes,
# update this too.
cron.database_name = 'stk_db'
EOF
