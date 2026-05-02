-- Mirror Supabase's `extensions` schema convention: keep `public` clean
-- so application schemas don't collide with extension objects, and so a
-- pg_dump of the user's data is portable.
--
-- We only auto-enable the three extensions every Postgres user effectively
-- expects to be there: pg_stat_statements (so we can surface slow queries
-- the moment monitoring ships), pgcrypto (gen_random_uuid + crypto helpers),
-- and uuid-ossp (legacy uuid_generate_v4 — still in heavy use).
--
-- Everything else in the image is a no-op until the user enables it via
-- the dashboard, which runs CREATE EXTENSION through an agent op.

\connect stk_db

CREATE SCHEMA IF NOT EXISTS extensions;
GRANT USAGE ON SCHEMA extensions TO PUBLIC;

-- Extensions schema goes on the search_path so unqualified calls like
-- `gen_random_uuid()` resolve without forcing every app to schema-qualify.
ALTER DATABASE stk_db SET search_path TO "$user", public, extensions;

CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pgcrypto           WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp"        WITH SCHEMA extensions;
