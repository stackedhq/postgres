-- Configure system-level GUCs that need to be in place before users start
-- enabling extensions. ALTER SYSTEM writes to postgresql.auto.conf inside
-- $PGDATA, so these survive container restarts and image upgrades.
--
-- Order: this file runs FIRST (filename prefix `00-`) so the values are
-- already set by the time `01-extensions.sql` issues CREATE EXTENSION,
-- and by the time the upstream entrypoint restarts Postgres into its
-- final foreground process.

ALTER SYSTEM SET shared_preload_libraries =
    'pg_stat_statements,pg_cron,pgaudit,pg_stat_monitor,auto_explain';

-- pg_stat_statements
ALTER SYSTEM SET pg_stat_statements.track = 'all';
ALTER SYSTEM SET pg_stat_statements.max = '10000';

-- auto_explain — log plans for queries slower than 1s. Cheap, very
-- useful for surfacing slow queries in the (future) monitoring tab.
ALTER SYSTEM SET auto_explain.log_min_duration = '1s';
ALTER SYSTEM SET auto_explain.log_analyze = 'off';
ALTER SYSTEM SET auto_explain.log_buffers = 'on';

-- pg_cron — must run in a specific database. Stacked's provisioning code
-- always creates the user database as `stk_db` (see generateCredentials in
-- src/lib/database-utils.ts). If that ever changes, update this too.
ALTER SYSTEM SET cron.database_name = 'stk_db';
