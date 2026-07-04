# Data Scrubbing

Rules for this service:

- do not export full customer names
- do not export account balances as metric labels
- do not log database credentials
- do not use account IDs as high-cardinality metric labels unless tokenised or carefully controlled
- avoid putting customer identifiers into trace attributes by default

Field-level scrubbing can still miss sensitive data inside free-text errors, stack traces, third-party library logs, and unexpected payloads.
