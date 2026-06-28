-- 071_remove_jwt_secret_from_settings.sql
-- Security: JWT signing secret moved to .env (JWT_SECRET). Remove the legacy
-- DB-stored secret so a database leak can no longer forge tokens.
-- See docs/security.md#jwt-secret

DELETE FROM settings
WHERE namespace = 'security' AND "key" = 'jwt_secret';
