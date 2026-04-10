# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A multi-project, multi-PHP-version local development platform for Laravel applications. One Docker Compose stack runs all shared services; individual Laravel projects live in `projects/` and each gets its own Nginx vhost pointing to the appropriate PHP-FPM container.

## Common Commands

All commands run from the workspace root (`/home/fernando/docker/laravel-docker`).

```bash
# Start / stop
./scripts/dev.sh up
./scripts/dev.sh down

# Container status and logs
./scripts/dev.sh status
./scripts/dev.sh logs [service]

# Shell into a PHP container (as www-data — the container default)
./scripts/dev.sh shell php82
./scripts/dev.sh shell php82 myapp    # drops into /var/www/myapp

# Root shell — only for system tasks (apk add, chown, etc.)
./scripts/dev.sh root-shell php82
docker exec -it -u root php82 bash    # equivalent raw form

# Run artisan / composer
./scripts/dev.sh artisan php82 myapp migrate
./scripts/dev.sh composer php82 myapp install

# Database
./scripts/dev.sh db-create myapp
./scripts/dev.sh db-import myapp dump.sql    # file must be in docker/mariadb/dumps/

# Xdebug toggle (PHP 7.2+ / Xdebug 3.x only)
./scripts/dev.sh xdebug-on
./scripts/dev.sh xdebug-off

# Scaffold a new project
./scripts/dev.sh new-project myapp php83

# Rebuild a single PHP image
./scripts/dev.sh rebuild php82
```

Direct Docker commands used alongside dev.sh:

```bash
# Reload Nginx after editing a vhost (no restart needed)
docker exec nginx nginx -s reload
docker exec nginx nginx -t              # validate config first

# One-time DNS setup (Ubuntu — run once per machine)
sudo ./scripts/setup-dns.sh
```

## Architecture

### Request Flow

```
Browser → dnsmasq (*.test → 127.0.0.1) → Traefik :80 → Nginx → PHP-FPM container
```

Traefik forwards all `*.test` traffic to Nginx. Nginx dispatches by `server_name` to the correct PHP-FPM upstream (e.g. `fastcgi_pass php82`). Each PHP container runs a separate PHP-FPM process pool.

### PHP Container Tiers

Three Dockerfiles, selected by `docker-compose.yml` based on version:

| Dockerfile | PHP versions | Xdebug | Composer |
|---|---|---|---|
| `Dockerfile.8x` | 8.0, 8.1, 8.2, 8.3 | 3.x | 2.x |
| `Dockerfile.7x` | 7.2, 7.3, 7.4 | 3.x | 2.x |
| `Dockerfile.legacy` | 7.0, 7.1 | 2.x | 1.x |

### Xdebug Configuration Split (Critical)

- **PHP 7.2+ (Xdebug 3.x):** config in `docker/php/conf/xdebug-v3.ini`. Controlled via `XDEBUG_MODE` env var in `.env`. IDE port **9003**.
- **PHP 7.0/7.1 (Xdebug 2.x):** config in `docker/php/conf/xdebug-v2.ini`. `XDEBUG_MODE` env var has **no effect** — must edit the ini directly. IDE port **9000**.

### Static IP Map (subnet 172.20.0.0/16)

| IP | Service |
|---|---|
| 172.20.0.2 | Traefik |
| 172.20.0.3 | Nginx |
| 172.20.0.10–.13 | php83–php80 |
| 172.20.0.14–.16 | php74–php72 |
| 172.20.0.17–.18 | php71–php70 |
| 172.20.0.20 | MariaDB |
| 172.20.0.21 | Redis |
| 172.20.0.22 | Meilisearch |
| 172.20.0.23 | Mailhog |
| 172.20.0.24 | phpMyAdmin |

### Service URLs

| URL | Service |
|---|---|
| `http://<project>.test` | Laravel project |
| `http://traefik.test` | Traefik dashboard |
| `http://mail.test` | Mailhog web UI |
| `http://phpmyadmin.test` | phpMyAdmin |
| `http://meilisearch.test` | Meilisearch |

### MariaDB MCP Server

Claude Code can query the project databases directly via a containerized [MariaDB MCP server](https://github.com/mariadb/mcp). Setup is fully version-controlled:

- `docker/mariadb-mcp/Dockerfile` — builds the MCP image from the upstream repo
- `.mcp.json` — tells Claude Code to spawn the MCP as `docker run -i --rm` on `laravel-docker_laravel_network`, communicating over stdio
- `mcp_readonly` MariaDB user (created in `docker/mariadb/initdb.d/01-create-databases.sql`) enforces read-only access at the DB level; `MCP_READ_ONLY=true` in `.mcp.json` is a second safety layer

Build the image once with `docker build -t mariadb-mcp docker/mariadb-mcp/`. The MCP connects to the `mariadb` container by name over the shared Docker network — no host port needed. See README.md "MariaDB MCP Server" section for details.

### Key Files

- `docker-compose.yml` — all services; uses YAML anchors (`x-php-common`, `x-php-env`, `x-php-volumes-v3/v2`) to avoid per-container repetition
- `.env` (from `.env.example`) — root-level env vars for the platform (DB credentials, Xdebug mode, ports, host user mapping (WWWUSER/WWWGROUP))
- `docker/php/conf/php.ini` — shared PHP settings applied to all versions
- `docker/php/conf/xdebug-v3.ini` / `xdebug-v2.ini` — Xdebug config, version-split
- `docker/php/conf/www.conf` — PHP-FPM pool config (shared across all containers)
- `docker/php/Dockerfile.{8x,7x,legacy}` — bake host developer UID/GID into `www-data` at build time via `WWWUSER`/`WWWGROUP` build args, and set `USER www-data` so plain `docker exec -it <container> bash` defaults to that user (prevents root-owned files leaking onto the host). Root access requires explicit `-u root` or `./scripts/dev.sh root-shell`.
- `docker/php/entrypoint.sh` — runs on container start as `www-data`: copies SSH keys into `$HOME/.ssh`, sets `git safe.directory '*'`, creates Laravel storage directories if missing. UID remapping is no longer done here — it's baked at build time by the Dockerfiles.
- `docker/nginx/conf.d/` — one `.conf` per project; `_template.conf.example` is the source for new vhosts; `upstreams.conf` defines all PHP upstream blocks
- `docker/nginx/conf.d/_template.conf.example` — template with `PROJECTNAME` / `PHPVERSION` placeholders
- `docker/mariadb/initdb.d/01-create-databases.sql` — runs on first MariaDB start to pre-create databases
- `docker/mariadb/dumps/` — place `.sql` files here for `db-import`
- `docker/traefik/dynamic/config.yml` — Traefik static routes to services by static IP

### Adding a New Project

1. `./scripts/dev.sh new-project <name> <php-version>` — creates `projects/<name>/`, nginx vhost, `.env.example`
2. `./scripts/dev.sh db-create <name>` — creates the database
3. Place Laravel code in `projects/<name>/`
4. Edit `projects/<name>/.env` — use container names (`mariadb`, `redis`) not `localhost`
5. `docker exec nginx nginx -s reload`
6. Use a unique `REDIS_DB` / `REDIS_CACHE_DB` number per project (0–15 available)

### Modifying PHP Configuration

Shared config files in `docker/php/conf/` are bind-mounted into every container — changes take effect on `docker compose up -d` with no rebuild. Changes to `Dockerfile.8x`, `Dockerfile.7x`, or `Dockerfile.legacy` require `./scripts/dev.sh rebuild <service>`.

### First-Time Setup

```bash
cp .env.example .env
sudo ./scripts/setup-dns.sh   # one-time, Ubuntu only
./scripts/dev.sh up
```
