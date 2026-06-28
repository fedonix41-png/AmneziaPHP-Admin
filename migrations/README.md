# Database Migrations

Migration files are **PostgreSQL** SQL scripts applied by `update.sh` using `psql`.

## Execution

Migrations run in **numerical order** (sorted by filename).
`update.sh` tracks applied migrations in the `schema_migrations` table (database `amnezia_panel`):

```sql
CREATE TABLE IF NOT EXISTS schema_migrations (
    id SERIAL PRIMARY KEY,
    filename VARCHAR(255) UNIQUE NOT NULL,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    checksum VARCHAR(64)
);
```

Each migration runs exactly once (skip if `filename` already recorded).

## Migration files

Files are numbered `000_*` through `072_*`, written in **PostgreSQL syntax**:

- `SERIAL` / `BIGSERIAL` for auto-increment
- `ON CONFLICT ... DO UPDATE` for upserts (instead of `ON DUPLICATE KEY UPDATE`)
- `ADD COLUMN IF NOT EXISTS` for safe alterations
- `DO $$ ... END $$` blocks for procedural logic
- `CREATE INDEX IF NOT EXISTS` for idempotent index creation

## Adding new migrations

1. Choose next available number (e.g., `071_add_feature.sql`)
2. Write the migration in PostgreSQL dialect
3. Use `IF NOT EXISTS` / `ON CONFLICT` to make it idempotent
4. Run `./update.sh` to apply

## Manual execution

```bash
# Single migration
docker compose exec -T db sh -c "PGPASSWORD='$DB_PASSWORD' psql -U amnezia -d amnezia_panel" < migrations/000_create_user.sql

# All pending migrations
./update.sh
```

## Database initialisation

On **first** container start, PostgreSQL entrypoint scripts in `docker-entrypoint-initdb.d/` create both databases:

1. `01-init-multiple-databases.sh` — creates `amnezia_panel` and `telegram_bot`
2. `02-baseline-schema.sql` — full schema + seeds for `amnezia_panel`
3. `03-telegram-bot-schema.sql` — schema for `telegram_bot`

These init scripts only run on an empty data volume. For subsequent updates, use `./update.sh`.
