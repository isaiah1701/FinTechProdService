# Local Postgres

Docker Compose starts Postgres with the `mal_accounts` database and runs the SQL and shell bootstrap files in lexical order.

The `mal_account_app` runtime role is local-only and deliberately least privilege. It can read and write the application rows it needs, but it cannot create tables, drop tables, alter schema, manage roles, or own database objects.

No password is committed. `004_runtime_role_password.sh` sets the local runtime role password from `MAL_ACCOUNT_APP_PASSWORD` at container bootstrap time.
