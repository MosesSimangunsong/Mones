---
paths:
  - "**/migrations/**"
  - "**/migrate/**"
  - "**/alembic/versions/**"
---

# Migrations

- Copy the naming pattern from the newest file already in the directory. Do not invent a format.
- The name must sort into execution order. Most runners apply files in lexical order.
- Never edit a migration that has already run anywhere. Write a new one that corrects it.
- Every migration ships with its reversal, or a written reason it cannot be reversed.
- Keep a schema change and a data backfill in separate migrations.
