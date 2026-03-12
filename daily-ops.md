# Laravel Docker Platform — Daily Operations Cheatsheet

> PHP 8.3 / 8.2 / 8.1 / 8.0 / 7.4 / 7.3 / 7.2 / 7.1 / 7.0 · MariaDB · Redis · Meilisearch · Mailhog

---

## 1. Managing Containers

### Start the environment

```bash
# Start ALL services (nginx, php, mariadb, redis, meilisearch, mailhog)
docker compose up -d

# Start SPECIFIC services only (saves RAM if you don't need everything)
docker compose up -d nginx mariadb redis php82
```

### Stop the environment

```bash
# Stop all — data is preserved in volumes
docker compose down

# Stop a single service
docker compose stop php80
```

### Restart / Refresh a container

```bash
# Restart one container (picks up new env vars)
docker compose restart php82

# Reload nginx config without restarting (apply new vhosts instantly)
docker exec nginx nginx -s reload

# Full rebuild of one image (after editing a Dockerfile)
docker compose build --no-cache php82
docker compose up -d php82
```

### Check status & logs

```bash
# See all running containers and their status
docker compose ps

# Tail logs for all services
docker compose logs -f

# Tail logs for a specific service
docker compose logs -f php82
docker compose logs -f nginx
docker compose logs -f mariadb
```

---

## 2. Running Artisan Commands

> Replace `php80` with any PHP container (`php83`, `php82`, `php81`...) and `myproject` with your folder name.

### Open a shell inside a PHP container

```bash
# Open bash — you are now inside the container
docker exec -it php80 bash

# Navigate to your project and run artisan normally
cd /var/www/myproject
php artisan migrate
php artisan db:seed
php artisan make:model Post -mrc
php artisan queue:work
php artisan tinker
```

### One-liner artisan (without entering the shell)

```bash
docker exec -it php80 bash -c "cd /var/www/myproject && php artisan migrate"
docker exec -it php82 bash -c "cd /var/www/myproject && php artisan cache:clear"
docker exec -it php83 bash -c "cd /var/www/myproject && php artisan optimize"
```

---

## 3. Composer

> Composer is installed inside every PHP container. Use the container that matches your project's PHP version.

### Install / Update packages

```bash
# Enter the container first
docker exec -it php82 bash
cd /var/www/myproject

# Standard install (from composer.lock)
composer install

# Update all packages
composer update

# Add a new package
composer require laravel/telescope
composer require spatie/laravel-permission

# Add a dev-only package
composer require --dev barryvdh/laravel-debugbar

# Remove a package
composer remove laravel/sanctum
```

### One-liner composer (without entering the shell)

```bash
docker exec -it php82 bash -c "cd /var/www/myproject && composer install --no-dev"
docker exec -it php80 bash -c "cd /var/www/myproject && composer require guzzlehttp/guzzle"
```

### Composer with unlimited memory (if you hit memory errors)

```bash
docker exec -it php82 bash -c "cd /var/www/myproject && php -d memory_limit=-1 /usr/bin/composer install"
```

---

## 4. Database Operations

> Single shared MariaDB instance.
> **User:** `laravel` | **Password:** `secret` | **Root password:** `secret`

### Access the database CLI

```bash
# Open MariaDB as root
docker exec -it mariadb mysql -uroot -psecret

# Open as the shared laravel user
docker exec -it mariadb mysql -ularavel -psecret
```

### Create a new database

```bash
docker exec -it mariadb mysql -uroot -psecret -e \
  "CREATE DATABASE newapp CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# Grant access to the shared laravel user
docker exec -it mariadb mysql -uroot -psecret -e \
  "GRANT ALL PRIVILEGES ON newapp.* TO 'laravel'@'%'; FLUSH PRIVILEGES;"
```

### Drop (delete) a database

```bash
docker exec -it mariadb mysql -uroot -psecret -e "DROP DATABASE IF EXISTS oldapp;"
```

### Import a `.sql` file into a database

```bash
# Import from your host machine
docker exec -i mariadb mysql -ularavel -psecret myapp < /path/on/host/dump.sql
```

### Export (backup) a database

```bash
docker exec mariadb mysqldump -ularavel -psecret myapp > backup-myapp.sql
```

---

## 5. Troubleshooting

### Quick reference table

| Problem | Symptom | Fix |
|---|---|---|
| Nginx shows 404 | White page or nginx 404 | Check vhost: `root /var/www/YOURPROJECT/public;` — must point to `/public` |
| Nginx 502 Bad Gateway | 502 in browser | PHP container is down. Run: `docker compose up -d php82` |
| Laravel can't connect to DB | `SQLSTATE[HY000]` | In `.env` set `DB_HOST=mariadb` (not `localhost`) |
| Redis connection refused | `Connection refused 127.0.0.1:6379` | In `.env` set `REDIS_HOST=redis` (not `localhost`) |
| Composer memory error | `Fatal error: memory exhausted` | `php -d memory_limit=-1 /usr/bin/composer install` |
| Composer permission denied | `Permission denied on vendor/` | `docker exec -it php82 bash -c "chown -R www-data:www-data /var/www/myproject/vendor"` |
| `*.test` not resolving | Browser: "This site can't be reached" | `sudo systemctl restart dnsmasq` then `ping project.test` |
| Nginx won't reload | Config error after editing vhost | `docker exec nginx nginx -t` (shows exact error line) |

---

### Nginx debug steps

```bash
# 1. Test config for syntax errors
docker exec nginx nginx -t

# 2. Reload without downtime
docker exec nginx nginx -s reload

# 3. Check what root path nginx resolved
docker exec nginx nginx -T | grep -A5 'server_name myproject'

# 4. Verify the public/ folder exists inside the container
docker exec nginx ls /var/www/myproject/public/
```

### Database connection debug steps

```bash
# 1. Confirm mariadb is healthy
docker compose ps mariadb

# 2. Test connection manually from inside the PHP container
docker exec -it php82 bash
mysql -h mariadb -ularavel -psecret

# 3. Keys to check in .env — must use container names as hosts
#    DB_HOST=mariadb   REDIS_HOST=redis   MAIL_HOST=mailhog

# 4. Clear Laravel config cache after editing .env
docker exec -it php82 bash -c "cd /var/www/myproject && php artisan config:clear"
```

### Composer debug steps

```bash
# Diagnose dependency conflicts
docker exec -it php82 bash -c "cd /var/www/myproject && composer diagnose"

# Clear composer cache
docker exec -it php82 bash -c "composer clear-cache"

# Force reinstall ignoring lock file
docker exec -it php82 bash -c "cd /var/www/myproject && composer install --no-cache"
```
