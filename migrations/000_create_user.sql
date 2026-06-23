-- Create database user if not exists (PostgreSQL)
-- This migration is tracked by schema_migrations.
-- The actual user/database creation happens in docker-entrypoint-initdb.d/01-init-multiple-databases.sh
-- and the DB_USERNAME env var in docker-compose.yml.
-- Nothing to do here for PostgreSQL: users and grants are handled at container init time.
SELECT 1; -- no-op, kept for schema_migrations tracking
