# Laravel Docker Platform

A professional, production-grade local development environment for Laravel teams working with **multiple projects and multiple PHP versions simultaneously**.

Designed as a complete replacement for Laravel Homestead — faster, more modular, and fully containerized.

---

## Architecture Overview

```
                        ┌─────────────────────────────────────────┐
                        │           Ubuntu 24.04 Host              │
                        │                                          │
  Browser               │  ┌─────────┐   ┌──────────────────────┐ │
  project1.test  ──────►│  │ dnsmasq │──►│  Traefik (Port 80)   │ │
  project2.test  ──────►│  │ *.test  │   │  Reverse Proxy       │ │
  mail.test      ──────►│  └─────────┘   └────────┬─────────────┘ │
                        │                          │               │
                        │               ┌──────────▼─────────┐    │
                        │               │   Nginx (Port 80)  │    │
                        │               │   Virtual Hosts    │    │
                        │               └──┬──────────────┬──┘    │
                        │                  │              │        │
                        │         ┌────────▼──┐    ┌──────▼────┐  │
                        │         │  PHP 8.2  │    │  PHP 7.0  │  │
                        │         │  FPM      │    │  FPM      │  │
                        │         │ (project1)│    │ (project2)│  │
                        │         └─────┬─────┘    └─────┬─────┘  │
                        │               │                │         │
                        │         ┌─────▼────────────────▼──────┐  │
                        │         │          Shared Services     │  │
                        │         │  MariaDB │ Redis │ Meili     │  │
                        │         └──────────────────────────────┘  │
                        └─────────────────────────────────────────┘
```

---

## Requirements

- Ubuntu 24.04
- Docker Engine 24+
- Docker Compose v2.20+
- Git

Node.js is **not** containerized — manage it locally via [NVM](https://github.com/nvm-sh/nvm) for legacy project compatibility.

---

## Directory Structure

```
workspace/
├── .env                        # Root environment variables (copy from .env.example)
├── docker-compose.yml          # Main service definitions
│
├── docker/
│   ├── nginx/
│   │   ├── nginx.conf          # Main Nginx config
│   │   └── conf.d/
│   │       ├── upstreams.conf          # PHP-FPM upstream pool definitions
│   │       ├── _template.conf.example  # Template for new project vhosts
│   │       └── myapp.conf              # One file per project (you create these)
│   │
│   ├── php/
│   │   ├── Dockerfile.8x       # PHP 8.0, 8.1, 8.2, 8.3 — Alpine + Xdebug 3.x
│   │   ├── Dockerfile.7x       # PHP 7.2, 7.3, 7.4 — Alpine + Xdebug 3.x
│   │   ├── Dockerfile.legacy   # PHP 7.0, 7.1 — Alpine + Xdebug 2.x
│   │   ├── entrypoint.sh       # Startup: SSH keys, git safe.directory, Laravel storage dirs
│   │   └── conf/
│   │       ├── php.ini         # Shared PHP settings (all versions)
│   │       ├── www.conf        # PHP-FPM pool config (all versions)
│   │       ├── xdebug-v3.ini   # Xdebug 3.x config (PHP 7.2+) — uses XDEBUG_MODE
│   │       └── xdebug-v2.ini   # Xdebug 2.x config (PHP 7.0/7.1) — edit directly
│   │
│   ├── mariadb/
│   │   ├── conf.d/my.cnf       # MariaDB tuning config
│   │   ├── initdb.d/           # SQL scripts run on first MariaDB init
│   │   └── dumps/              # Place .sql files here for db-import
│   │
│   ├── mariadb-mcp/
│   │   └── Dockerfile          # MariaDB MCP server image for Claude Code
│   │
│   ├── redis/
│   │   └── redis.conf          # Redis config
│   │
│   └── traefik/
│       ├── dynamic/config.yml  # Traefik dynamic config (TLS, middleware, routes)
│       └── certs/              # SSL certificate storage
│
├── projects/                   # Your Laravel projects live here
│   └── myapp/                  # myapp.test → whichever PHP version you configure
│
└── scripts/
    ├── dev.sh                  # Developer helper CLI
    └── setup-dns.sh            # One-time DNS setup script (Ubuntu)
```

---

## Initial Setup

### 1. Clone this repository

```bash
git clone <repository-url> ~/workspace
cd ~/workspace
```

### 2. Install Docker

```bash
# Install Docker Engine
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
newgrp docker

# Verify
docker --version
docker compose version
```

### 3. Configure DNS for *.test domains

Run the DNS setup script once to configure `dnsmasq` on your host:

```bash
sudo ./scripts/setup-dns.sh
```

This installs and configures `dnsmasq` to resolve all `*.test` domains to `127.0.0.1` — **no `/etc/hosts` editing required** for new projects.

Verify it works:
```bash
ping project1.test    # Should reply from 127.0.0.1
```

### 4. Configure environment variables

```bash
cp .env.example .env
# Edit .env if needed (database passwords, ports, etc.)
```

### 5. Build and start the environment

```bash
# First time — builds all PHP images (takes 5-15 minutes)
docker compose build

# Start everything
docker compose up -d
```

### 6. Open your project

Navigate to [http://project1.test](http://project1.test)

---

## Daily Workflow

### Start / Stop

```bash
# Start all services
docker compose up -d

# Stop all services (preserves data)
docker compose down

# Using the helper script
./scripts/dev.sh up
./scripts/dev.sh down
```

### Shell Access

PHP containers default to the **`www-data`** user (remapped to your host UID at build time), so any files you create from inside the container are owned by your host developer — no sudo in the editor, no root-owned migrations.

```bash
# Open bash as www-data (the default)
docker exec -it php82 bash

# Or with the helper — cd's into your project and uses www-data
./scripts/dev.sh shell php82 project1
```

#### Accessing the container as root

Use root only for system tasks (installing packages, debugging permissions). Artisan, composer and any file creation should **always** run as `www-data`, otherwise new files land owned by `root` and VSCode will ask for sudo to save them.

```bash
# Preferred — use the helper
./scripts/dev.sh root-shell php82

# Equivalent raw docker command
docker exec -it -u root php82 bash

# One-shot root command without a shell
docker exec -u root php82 apk add --no-cache some-package
```

If you accidentally create a root-owned file, fix it with:

```bash
docker exec -u root php82 chown www-data:www-data /var/www/<project>/path/to/file
```

### Running Artisan

```bash
# Direct
docker exec -it php82 bash -c "cd /var/www/project1 && php artisan migrate"

# Via helper
./scripts/dev.sh artisan php82 project1 migrate
./scripts/dev.sh artisan php82 project1 "make:model Post -mrc"
./scripts/dev.sh artisan php83 project2 queue:work
```

### Running Composer

```bash
# Direct
docker exec -it php82 bash -c "cd /var/www/project1 && composer install"

# Via helper
./scripts/dev.sh composer php82 project1 install
./scripts/dev.sh composer php82 project1 "require laravel/telescope"
```

### Viewing Logs

```bash
# All services
docker compose logs -f

# Single service
docker compose logs -f nginx
docker compose logs -f php82
docker compose logs -f mariadb

# Via helper
./scripts/dev.sh logs php82
```

---

## Adding a New Project

### Option A — Automated (recommended)

```bash
./scripts/dev.sh new-project myapp php83
```

This creates:
- `projects/myapp/` directory
- `docker/nginx/conf.d/myapp.conf` vhost
- `projects/myapp/.env.example`

Then:
1. Place your Laravel app in `projects/myapp/`
2. Create the database: `./scripts/dev.sh db-create myapp`
3. Reload Nginx: `docker exec nginx nginx -s reload`
4. Open [http://myapp.test](http://myapp.test)

### Option B — Manual

**1. Copy the Nginx vhost template:**

```bash
cp docker/nginx/conf.d/_template.conf.example docker/nginx/conf.d/myapp.conf
```

Edit the new file — replace `PROJECTNAME` with `myapp` and `PHPVERSION` with the target PHP upstream (e.g. `php83`):

```nginx
server {
    listen 80;
    server_name myapp.test;
    root /var/www/myapp/public;
    ...
    fastcgi_pass php83;    # ← your PHP version
    ...
}
```

**2. Create the database:**

```bash
./scripts/dev.sh db-create myapp
```

Or to import from a dump (place the file in `docker/mariadb/dumps/` first):

```bash
./scripts/dev.sh db-import myapp dump.sql
```

**3. Reload Nginx** (no restart needed):

```bash
docker exec nginx nginx -s reload
```

**4. Configure your Laravel `.env`:**

```env
DB_HOST=mariadb
DB_DATABASE=myapp
REDIS_HOST=redis
REDIS_DB=4               # Use a unique DB number per project (0-15)
MAIL_HOST=mailhog
MAIL_PORT=1025
MEILISEARCH_HOST=http://meilisearch:7700
```

---

## Service Reference

| Service        | Container     | Internal Host  | Exposed Port    | URL                           |
|---------------|---------------|----------------|-----------------|-------------------------------|
| Traefik        | `traefik`     | `traefik`      | 80, 8080        | http://traefik.test           |
| Nginx          | `nginx`       | `nginx`        | (via Traefik)   | http://myapp.test             |
| PHP 8.3        | `php83`       | `php83`        | 9000 (internal) | -                             |
| PHP 8.2        | `php82`       | `php82`        | 9000 (internal) | -                             |
| PHP 8.1        | `php81`       | `php81`        | 9000 (internal) | -                             |
| PHP 8.0        | `php80`       | `php80`        | 9000 (internal) | -                             |
| PHP 7.4        | `php74`       | `php74`        | 9000 (internal) | -                             |
| PHP 7.3        | `php73`       | `php73`        | 9000 (internal) | -                             |
| PHP 7.2        | `php72`       | `php72`        | 9000 (internal) | -                             |
| PHP 7.1        | `php71`       | `php71`        | 9000 (internal) | -                             |
| PHP 7.0        | `php70`       | `php70`        | 9000 (internal) | -                             |
| MariaDB        | `mariadb`     | `mariadb`      | 3306            | (DB client: localhost:3306)   |
| Redis          | `redis`       | `redis`        | 6379            | (Redis client: localhost:6379)|
| Meilisearch    | `meilisearch` | `meilisearch`  | 7700            | http://meilisearch.test       |
| Mailhog        | `mailhog`     | `mailhog`      | 1025, 8025      | http://mail.test              |
| phpMyAdmin     | `phpmyadmin`  | `phpmyadmin`   | (via Traefik)   | http://phpmyadmin.test        |

---

## Xdebug Configuration

Xdebug is **installed but disabled by default**. This keeps performance high during normal development.

### Enable step debugging

```bash
# Via helper
./scripts/dev.sh xdebug-on

# Manually — set in .env then restart
XDEBUG_MODE=debug
docker compose up -d
```

### Disable Xdebug

```bash
./scripts/dev.sh xdebug-off
```

### IDE Setup (PhpStorm)

1. Go to **Settings → PHP → Debug**
2. Set **Debug port** to `9003` (PHP 7.2+ / Xdebug 3.x) or `9000` (PHP 7.0/7.1 / Xdebug 2.x)
3. Enable **Listen for PHP Debug Connections** (phone icon in toolbar)
4. Configure **path mappings**:
   - Local path: `/your/local/workspace/projects/myapp`
   - Remote path: `/var/www/myapp`

> **PHP 7.0 / 7.1 note:** `XDEBUG_MODE` has no effect on Xdebug 2.x. To enable debugging, edit `docker/php/conf/xdebug-v2.ini` directly and set `xdebug.remote_enable = 1`, then restart the container.

### Xdebug Modes

Set `XDEBUG_MODE` in `.env` to one of:

| Mode       | Purpose                          |
|------------|----------------------------------|
| `off`      | Disabled (default, best perf)    |
| `debug`    | Step debugging                   |
| `profile`  | Generate cachegrind profiles     |
| `coverage` | Code coverage for tests          |
| `develop`  | Enhanced error display           |

---

## Database Access

Connect to MariaDB from any database client:

```
Host:     127.0.0.1
Port:     3306
User:     laravel
Password: secret
```

Root access:
```
User:     root
Password: secret
```

### phpMyAdmin

Browse and administer the databases from a browser at **http://phpmyadmin.test**.

phpMyAdmin auto-logs in as **`root`** so you have full admin privileges out of the box — `CREATE` / `DROP DATABASE`, edit user privileges, manage grants, etc. This is intended for local development only; do not expose this stack to a network you don't control.

The credentials come from `.env`:

| phpMyAdmin var | Sourced from   | Default  |
|----------------|----------------|----------|
| `PMA_USER`     | hardcoded      | `root`   |
| `PMA_PASSWORD` | `DB_ROOT_PASSWORD` | `secret` |

If you change `DB_ROOT_PASSWORD` in `.env`, recreate the container so it picks up the new value:

```bash
docker compose up -d phpmyadmin
```

---

## MariaDB MCP Server (Claude Code Integration)

The stack ships with a containerized [MariaDB MCP server](https://github.com/mariadb/mcp) that lets [Claude Code](https://claude.com/claude-code) query your project databases directly — inspect schemas, run `SELECT`s, explore data — without leaving the terminal.

### How it works

- **Dockerfile** at `docker/mariadb-mcp/Dockerfile` builds an image from the upstream MariaDB MCP repo
- **`.mcp.json`** at the project root tells Claude Code to spawn the MCP as an ephemeral `docker run -i --rm` container on the shared `laravel_network`, communicating over stdio
- A dedicated **`mcp_readonly`** MariaDB user (created automatically in `docker/mariadb/initdb.d/01-create-databases.sql`) enforces read-only access at the database level — the MCP can only `SELECT` and `SHOW DATABASES`
- `MCP_READ_ONLY=true` is also set in `.mcp.json` as a second safety layer

### First-time setup

```bash
# 1. Build the MCP image (only needed once, or to update)
docker build -t mariadb-mcp docker/mariadb-mcp/

# 2. If MariaDB is already running from before this feature was added,
#    create the read-only user manually (fresh installs get it automatically):
docker exec mariadb mysql -uroot -psecret -e "
  CREATE USER IF NOT EXISTS 'mcp_readonly'@'%' IDENTIFIED BY 'mcp_readonly';
  GRANT SELECT, SHOW DATABASES ON *.* TO 'mcp_readonly'@'%';
  FLUSH PRIVILEGES;
"

# 3. Restart Claude Code (or run /mcp) so it picks up .mcp.json
```

### How to use it

Once Claude Code is restarted and the MCP shows up under `/mcp`, you can ask natural-language questions and Claude will translate them into SQL, run them via the MCP, and summarize the results. You don't need to write SQL yourself.

**Exploring a database you don't know:**

> "What databases exist?"
> "What tables are in `myapp`?"
> "Describe the `users` table in `myapp`."
> "What foreign keys does `myapp.orders` have?"

**Inspecting data:**

> "How many rows are in `myapp.users`?"
> "What are the distinct values in the `status` column of `myapp.orders`?"
> "Show me the 10 most recent orders from `myapp`."
> "Find all users whose email ends in `@example.com`."

**Schema / migration state:**

> "Has the `2024_06_add_status_to_orders` migration run on `myapp`?"
> "Compare the columns of `posts` between `myapp` and `myapp_staging`."
> "Which tables in `myapp` don't have an index on `created_at`?"

**Cross-database questions:**

> "List every database on this MariaDB instance with its table count."
> "Which project databases have a `users` table?"

**Debugging:**

> "The user with id 42 in `myapp` — what's their full row?"
> "Why is `myapp.jobs` growing? Show me the oldest 5 rows and their `attempts` count."

**What you can't do:**

The MCP user is strictly read-only (`SELECT` and `SHOW DATABASES` only). If you ask Claude to insert, update, delete, drop, or alter anything, it will refuse or the query will fail. For writes, use `./scripts/dev.sh shell` or a Laravel migration.

**Under the hood:**

Claude Code spawns a fresh MCP container per session (~3s startup), connects to the `mariadb` container by name over `laravel_network`, and tears it down when the session ends. Queries run as the `mcp_readonly` user, enforced both at the database level (grants) and at the MCP level (`MCP_READ_ONLY=true`).

### Claude Code skill

The project also ships a Claude Code skill at `.claude/skills/mariadb-mcp/SKILL.md` that teaches Claude when to reach for the MCP, safe query patterns, and how to report results. The skill is loaded automatically by Claude Code when working in this repo — no manual activation needed.

### Rebuilding to update the MCP

The Dockerfile clones the upstream repo at build time, so rebuild to pick up upstream changes:

```bash
docker build --no-cache -t mariadb-mcp docker/mariadb-mcp/
```

### Security notes

- The `mcp_readonly` user is intentionally weak (`SELECT` only, wildcard host) for local-dev convenience. **Do not** reuse this Dockerfile or credentials outside of local development.
- `.mcp.json` is committed so the setup is reproducible across machines. If you add sensitive env vars, put them in `.env` and reference them instead.
- The MCP container runs ephemerally (`--rm`) — nothing persists between sessions.

---

## Redis Isolation Between Projects

Redis ships with 16 databases (0–15). Use separate database numbers per project to prevent cache/session/queue key collisions:

```env
# project1/.env
REDIS_DB=0
REDIS_CACHE_DB=1

# project2/.env
REDIS_DB=2
REDIS_CACHE_DB=3

# project3/.env
REDIS_DB=4
REDIS_CACHE_DB=5
```

---

## Mail Testing with Mailhog

All outbound email is caught by Mailhog and **never delivered** to real addresses.

Configure Laravel to send to Mailhog:

```env
MAIL_MAILER=smtp
MAIL_HOST=mailhog
MAIL_PORT=1025
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null
```

View caught emails at [http://mail.test](http://mail.test)

---

## Meilisearch + Laravel Scout

Configure Scout in your Laravel project:

```bash
composer require laravel/scout
php artisan vendor:publish --provider="Laravel\Scout\ScoutServiceProvider"
```

```env
SCOUT_DRIVER=meilisearch
MEILISEARCH_HOST=http://meilisearch:7700
MEILISEARCH_KEY=masterkey
```

Meilisearch dashboard is available at [http://meilisearch.test](http://meilisearch.test)

---

## Only Running Specific PHP Versions

You do not need to start all 10 PHP containers. Start only what you need:

```bash
# Start core services + only PHP 8.2
docker compose up -d traefik nginx mariadb redis meilisearch mailhog php82
```

---

## Rebuilding Images

After modifying a Dockerfile or adding extensions:

```bash
# Rebuild a single PHP version
docker compose build --no-cache php82
docker compose up -d php82

# Via helper
./scripts/dev.sh rebuild php82

# Rebuild everything
docker compose build --no-cache
```

---

## Persistent Data

Data survives `docker compose down` but is removed by `docker compose down -v`.

| Volume            | Contents                        |
|-------------------|---------------------------------|
| `mariadb_data`    | All databases                   |
| `redis_data`      | Redis persistence files         |
| `meilisearch_data`| Search index data               |
| `composer_cache`  | Shared Composer package cache   |

**Backup databases:**

```bash
docker exec mariadb mysqldump -uroot -psecret project1 > backup-project1.sql
```

**Restore:**

```bash
docker exec -i mariadb mysql -uroot -psecret project1 < backup-project1.sql
```

---

## Troubleshooting

### *.test domains not resolving

```bash
# Re-run the DNS setup
sudo ./scripts/setup-dns.sh

# Verify dnsmasq is running
systemctl status dnsmasq

# Test resolution
dig project1.test @127.0.0.1
```

### Nginx returns 502 Bad Gateway

The PHP-FPM container is unreachable. Check:

```bash
# Is the PHP container running?
docker compose ps php82

# Check PHP logs
docker compose logs php82

# Test FastCGI connection from nginx container
docker exec nginx wget -qO- http://php82:9000  # will fail but confirms network
```

### "Connection refused" to MariaDB

```bash
# Check MariaDB health
docker compose ps mariadb
docker compose logs mariadb

# Connect directly
docker exec -it mariadb mysql -uroot -psecret
```

### Xdebug not connecting

1. Ensure `XDEBUG_MODE=debug` in `.env` and containers are restarted
2. Verify IDE is listening on port 9003
3. Check `host.docker.internal` resolves inside container:
   ```bash
   docker exec php82 ping host.docker.internal
   ```

### Port conflicts

If port 80, 3306, or 6379 are in use:

```bash
# Find what's using port 80
sudo lsof -i :80

# Change ports in .env
DB_PORT=33060
REDIS_PORT=63790
```

### Storage / bootstrap/cache permission errors in Laravel

This should not happen with a correct setup — PHP-FPM runs as your host user (`WWWUSER`) so it owns the files directly. If you see permission errors, the most likely cause is that `WWWUSER`/`WWWGROUP` in `.env` do not match your actual UID/GID.

Verify your UID:
```bash
id -u && id -g
```

Then update `.env` and restart:
```bash
# In .env
WWWUSER=1000   # replace with your actual UID
WWWGROUP=1000  # replace with your actual GID

docker compose up -d
```

If you need an immediate fix without restarting:
```bash
# From the host — no container exec needed
chmod -R 775 projects/myapp/storage projects/myapp/bootstrap/cache
```

---

## PHP Extension Summary

All modern PHP containers (7.2+) include:

`bcmath` `exif` `gd` `intl` `mbstring` `opcache` `pdo` `pdo_mysql` `pcntl` `sockets` `zip` `redis` `imagick` `xdebug`


PHP 7.0 does not include `imagick` (compatibility).

---

## Contributing / Extending

### Add a new PHP version

1. Add the service to `docker-compose.yml` following the existing pattern, pointing `dockerfile` to `Dockerfile.8x`, `Dockerfile.7x`, or `Dockerfile.legacy` as appropriate
2. Assign a static IP in the `172.20.0.0/16` subnet
3. Add the upstream to `docker/nginx/conf.d/upstreams.conf`
4. Build: `docker compose build phpXX && docker compose up -d phpXX`

Shared config (`docker/php/conf/`) is bind-mounted into every container — no changes to the Dockerfiles needed for PHP/FPM settings.

### Add a new service (e.g. PostgreSQL)

1. Add the service block to `docker-compose.yml`
2. Add it to `laravel_network` with a static IP
3. Mount config files and volumes as needed
4. Reference via container name in Laravel `.env`

---

## License

MIT — free for personal and commercial use.
