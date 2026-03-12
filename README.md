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
                        │         │  PHP 8.2  │    │  PHP 5.6  │  │
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
├── .env                        # Root environment variables
├── docker-compose.yml          # Main service definitions
│
├── docker/
│   ├── nginx/
│   │   ├── nginx.conf          # Main Nginx config
│   │   └── conf.d/
│   │       ├── upstreams.conf  # PHP-FPM upstream pool definitions
│   │       ├── project1.conf   # project1.test → PHP 8.2
│   │       ├── project2.conf   # project2.test → PHP 5.6
│   │       └── _template.conf.example  # Template for new projects
│   │
│   ├── php/
│   │   ├── php83/              # PHP 8.3 FPM container
│   │   │   ├── Dockerfile
│   │   │   ├── php.ini
│   │   │   ├── xdebug.ini
│   │   │   └── www.conf
│   │   ├── php82/              # PHP 8.2 FPM container
│   │   ├── php81/              # PHP 8.1 FPM container
│   │   ├── php80/              # PHP 8.0 FPM container
│   │   ├── php74/              # PHP 7.4 FPM container
│   │   ├── php73/              # PHP 7.3 FPM container
│   │   ├── php72/              # PHP 7.2 FPM container
│   │   ├── php71/              # PHP 7.1 FPM container
│   │   ├── php70/              # PHP 7.0 FPM container
│   │   └── php56/              # PHP 5.6 FPM container (Debian)
│   │
│   ├── mariadb/
│   │   ├── conf.d/my.cnf       # MariaDB tuning config
│   │   └── initdb.d/           # SQL scripts run on first init
│   │
│   ├── redis/
│   │   └── redis.conf          # Redis config
│   │
│   └── traefik/
│       ├── dynamic/config.yml  # Traefik dynamic config (TLS, middleware)
│       └── certs/              # SSL certificate storage
│
├── projects/                   # Your Laravel projects live here
│   ├── project1/               # project1.test (PHP 8.2)
│   └── project2/               # project2.test (PHP 5.6)
│
└── scripts/
    ├── dev.sh                  # Developer helper CLI
    └── setup-dns.sh            # One-time DNS setup script
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
cp docker/.env.example .env
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

```bash
# Open bash in a specific PHP container
docker exec -it php82 bash

# Or with the helper — opens in your project directory
./scripts/dev.sh shell php82 project1
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
2. Add `myapp` database to `docker/mariadb/initdb.d/01-create-databases.sql`
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

**2. Add the database** in `docker/mariadb/initdb.d/01-create-databases.sql`:

```sql
CREATE DATABASE IF NOT EXISTS `myapp` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON `myapp`.* TO 'laravel'@'%';
FLUSH PRIVILEGES;
```

If MariaDB is already running, execute directly:

```bash
docker exec -it mariadb mysql -uroot -psecret -e \
  "CREATE DATABASE IF NOT EXISTS myapp CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; \
   GRANT ALL PRIVILEGES ON myapp.* TO 'laravel'@'%'; \
   FLUSH PRIVILEGES;"
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

| Service        | Container     | Internal Host  | Exposed Port    | URL                          |
|---------------|---------------|----------------|-----------------|------------------------------|
| Traefik        | `traefik`     | `traefik`      | 80, 443, 8080   | http://traefik.test          |
| Nginx          | `nginx`       | `nginx`        | (via Traefik)   | http://project1.test         |
| PHP 8.3        | `php83`       | `php83`        | 9000 (internal) | -                            |
| PHP 8.2        | `php82`       | `php82`        | 9000 (internal) | -                            |
| PHP 8.1        | `php81`       | `php81`        | 9000 (internal) | -                            |
| PHP 8.0        | `php80`       | `php80`        | 9000 (internal) | -                            |
| PHP 7.4        | `php74`       | `php74`        | 9000 (internal) | -                            |
| PHP 7.3        | `php73`       | `php73`        | 9000 (internal) | -                            |
| PHP 7.2        | `php72`       | `php72`        | 9000 (internal) | -                            |
| PHP 7.1        | `php71`       | `php71`        | 9000 (internal) | -                            |
| PHP 7.0        | `php70`       | `php70`        | 9000 (internal) | -                            |
| PHP 5.6        | `php56`       | `php56`        | 9000 (internal) | -                            |
| MariaDB        | `mariadb`     | `mariadb`      | 3306            | (DB client: localhost:3306)  |
| Redis          | `redis`       | `redis`        | 6379            | (Redis client: localhost:6379)|
| Meilisearch    | `meilisearch` | `meilisearch`  | 7700            | http://meilisearch.test      |
| Mailhog        | `mailhog`     | `mailhog`      | 1025, 8025      | http://mail.test             |

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
2. Set **Debug port** to `9003` (Xdebug 3.x) or `9000` (PHP 5.6/7.0/7.1)
3. Enable **Listen for PHP Debug Connections** (phone icon in toolbar)
4. Configure **path mappings**:
   - Local path: `/your/local/workspace/projects/project1`
   - Remote path: `/var/www/project1`

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
# Start core services + only PHP 8.2 and 5.6
docker compose up -d traefik nginx mariadb redis meilisearch mailhog php82 php56
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

---

## PHP Extension Summary

All modern PHP containers (7.2+) include:

`bcmath` `exif` `gd` `intl` `mbstring` `opcache` `pdo` `pdo_mysql` `pcntl` `sockets` `zip` `redis` `imagick` `xdebug`

PHP 5.6 additionally includes: `mcrypt`

PHP 7.0 does not include `imagick` (compatibility).

---

## Contributing / Extending

### Add a new PHP version

1. Create `docker/php/phpXX/` directory with `Dockerfile`, `php.ini`, `xdebug.ini`, `www.conf`
2. Add the service to `docker-compose.yml` following the existing pattern
3. Add the upstream to `docker/nginx/conf.d/upstreams.conf`
4. Rebuild: `docker compose build phpXX`

### Add a new service (e.g. PostgreSQL)

1. Add the service block to `docker-compose.yml`
2. Add it to `laravel_network` with a static IP
3. Mount config files and volumes as needed
4. Reference via container name in Laravel `.env`

---

## License

MIT — free for personal and commercial use.
