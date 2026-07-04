-- mal_account_app is the application runtime role, not an owner or migration role.
-- It can read/write only the tables needed by the service.
-- It deliberately cannot own objects, create DDL, manage roles, or act as a superuser.
DO $$
BEGIN
  CREATE ROLE mal_account_app
    LOGIN
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE
    NOINHERIT;
EXCEPTION WHEN duplicate_object THEN
  RAISE NOTICE 'Role mal_account_app already exists';
END
$$;

-- Allow connection and schema usage only.
GRANT CONNECT ON DATABASE mal_accounts TO mal_account_app;
GRANT USAGE ON SCHEMA public TO mal_account_app;

-- Domain read/write needed by GET /api/accounts/{id} and simple account updates.
GRANT SELECT, INSERT, UPDATE ON accounts TO mal_account_app;

-- Messaging side effects and idempotency keys.
GRANT SELECT, INSERT ON audit_events TO mal_account_app;
GRANT SELECT, INSERT ON processed_events TO mal_account_app;

-- audit_events.id uses BIGSERIAL; runtime can advance that sequence but cannot alter it.
GRANT USAGE ON SEQUENCE audit_events_id_seq TO mal_account_app;
