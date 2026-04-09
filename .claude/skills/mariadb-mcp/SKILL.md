---
name: mariadb-mcp
description: "Use the MariaDB MCP server to inspect schemas, explore data, and answer questions about project databases in this Laravel Docker stack. Use PROACTIVELY whenever the user asks about database contents, table structure, row counts, relationships, migrations state, or 'what's in the database'."
category: database
risk: low
---

# MariaDB MCP Skill

This project ships with a containerized MariaDB MCP server (see `docker/mariadb-mcp/Dockerfile` and `.mcp.json` at project root). When it's connected, Claude Code gains direct read-only access to the running MariaDB instance via tools prefixed `mcp__mariadb__*`.

## When to invoke this skill

Reach for the MCP whenever the user's question is faster and more accurate to answer by querying the live database than by reading code or guessing:

- "What tables does `myapp` have?"
- "Show me the schema for `users`"
- "How many rows are in `orders`?"
- "What are the foreign keys on `products`?"
- "Is column X nullable?"
- "Has this migration run? Check the `migrations` table"
- "What's in `sessions` right now?"
- "Compare the schema of `posts` between `myapp` and `myapp_staging`"
- "What values does the `status` column actually contain?"

Do NOT reach for the MCP when:
- The answer is a code/schema question answerable from migration files — read the files directly
- The user is asking about data that doesn't exist yet (design questions)
- The user asks to WRITE data — the MCP user is read-only and will fail

## Preflight check

Before running queries, verify the MCP is actually connected. If you don't see `mcp__mariadb__*` tools available:

1. Check `.mcp.json` exists at project root
2. Check the image is built: `docker images mariadb-mcp`
3. Check MariaDB is running: `docker ps --filter name=mariadb`
4. Check the `mcp_readonly` user exists: `docker exec mariadb mysql -uroot -psecret -e "SELECT user FROM mysql.user WHERE user='mcp_readonly';"`
5. Tell the user to restart Claude Code or run `/mcp` to reconnect

If the MCP is connected but queries fail with "access denied", the `mcp_readonly` user is missing or has wrong grants — see the README's "MariaDB MCP Server" section for the SQL to recreate it.

## Usage patterns

### 1. Discovering what's there

Start broad, narrow down:

```
list_databases                    → see all project DBs
list_tables(database='myapp')     → see tables in a project
describe_table('myapp.users')     → see columns, types, keys
```

Never guess database or table names — always list first when the user hasn't named one explicitly.

### 2. Running SELECT queries

The MCP allows `SELECT`, `SHOW`, `DESCRIBE`. Keep queries targeted:

- **Always** add `LIMIT` when exploring unknown tables — some may have millions of rows
- Use `COUNT(*)` before `SELECT *` when you don't know the size
- Prefer `INFORMATION_SCHEMA` for metadata questions over parsing `SHOW CREATE TABLE` output

Examples:

```sql
-- Row counts across all tables in a database
SELECT table_name, table_rows
FROM information_schema.tables
WHERE table_schema = 'myapp'
ORDER BY table_rows DESC;

-- Find all foreign keys pointing to a table
SELECT table_name, column_name, constraint_name
FROM information_schema.key_column_usage
WHERE referenced_table_name = 'users'
  AND referenced_table_schema = 'myapp';

-- Has a migration run?
SELECT migration, batch FROM myapp.migrations
WHERE migration LIKE '%add_status_to_orders%';

-- What distinct values live in an enum-like column?
SELECT status, COUNT(*) FROM myapp.orders
GROUP BY status ORDER BY COUNT(*) DESC;
```

### 3. Cross-database questions

All project DBs share the same MariaDB instance, so you can query across them:

```sql
SELECT table_schema, COUNT(*) AS tables
FROM information_schema.tables
WHERE table_schema NOT IN ('mysql','information_schema','performance_schema','sys')
GROUP BY table_schema;
```

## Safety rules

- **Never** attempt `INSERT`, `UPDATE`, `DELETE`, `DROP`, `CREATE`, `ALTER`, `TRUNCATE` — the MCP user has only `SELECT, SHOW DATABASES`. If the user asks you to modify data, tell them to use `./scripts/dev.sh shell` or a proper migration instead.
- **Do not** run `SELECT *` on tables you haven't checked the row count for first.
- **Do not** query system schemas (`mysql`, `performance_schema`) unless explicitly asked.
- **Do not** expose user credentials, API tokens, or password hashes in your responses when querying `users` or similar tables. Project `mcp_readonly` has read access to everything — behave responsibly.

## Reporting results

When you've queried the database, summarize what you found in plain language first, then show the relevant rows/columns. Don't dump large result sets — truncate with `LIMIT` at query time, not after the fact.

When the user asks a schema question, return:
1. Column name, type, nullable, default
2. Primary key and unique indexes
3. Foreign keys and what they reference
4. Any notable defaults or generated columns

Skip things the user didn't ask for. If they asked "what columns does `users` have?" don't also volunteer the row count.

## Related files

- `docker/mariadb-mcp/Dockerfile` — MCP image definition
- `.mcp.json` — Claude Code MCP config
- `docker/mariadb/initdb.d/01-create-databases.sql` — creates the `mcp_readonly` user on fresh MariaDB installs
- README.md "MariaDB MCP Server" section — user-facing setup docs
- CLAUDE.md "MariaDB MCP Server" section — architecture summary
