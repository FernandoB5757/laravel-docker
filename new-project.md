# Laravel Docker Platform — New Project Setup Guide

> Follow these steps in order to have a fully working Laravel application on a custom `*.test` domain.

---

## Steps Overview

| # | Step | Command |
|---|---|---|
| 1 | Create project folder | `mkdir projects/myapp` |
| 2 | Clone or create Laravel app | `git clone` / `composer create-project` |
| 3 | Create the database | `./scripts/dev.sh db-create myapp` |
| 4 | Configure Nginx vhost | Copy template, set PHP version |
| 5 | Reload Nginx | `docker exec nginx nginx -s reload` |
| 6 | Copy and edit `.env` | Set DB, Redis, Mail, Meili hosts |
| 7 | Run composer install | `docker exec php82 composer install` |
| 8 | Generate app key | `php artisan key:generate` |
| 9 | Run migrations | `php artisan migrate` |
| 10 | Open browser | `http://myapp.test` ✓ |

---

## Step 0 — Register the Domain

Every new project needs its `*.test` domain to resolve to `127.0.0.1` on your machine. You have two options:

### Option A — Automatic (recommended, one-time setup)

If you already ran `setup-dns.sh` when you first installed the platform, **you don't need to do anything here**. All `*.test` domains resolve automatically — skip to Step 1.

```bash
# Verify dnsmasq is running and resolving *.test
ping -c1 myapp.test
# Expected: 64 bytes from 127.0.0.1
```

If it doesn't resolve, restart dnsmasq:

```bash
sudo systemctl restart dnsmasq
```

### Option B — Manual via `/etc/hosts` (quick alternative, per project)

If you skipped the dnsmasq setup or are on a machine where you can't run it, add the domain manually:

```bash
# Add the entry
echo "127.0.0.1   myapp.test" | sudo tee -a /etc/hosts

# Verify
ping -c1 myapp.test
```

To remove it later:

```bash
sudo sed -i '/myapp\.test/d' /etc/hosts
```

> **Note:** Option B requires one manual edit per project. Option A (dnsmasq) handles all current and future `*.test` domains with zero configuration. To set it up run `sudo ./scripts/setup-dns.sh` from the workspace root.

---

## Step 1 — Create the Project Folder

All projects live inside the `projects/` folder at the root of the Docker workspace. Each subfolder is one site.

```
workspace/
├── docker-compose.yml
├── docker/
└── projects/
    ├── myapp/          ← your new project goes here
    ├── project1/
    └── project2/
```

```bash
# From the workspace root
mkdir -p projects/myapp
```

---

## Step 2 — Add Your Laravel Code

### Option A — Clone from a Git repository

```bash
git clone https://github.com/yourorg/myapp.git projects/myapp

# Verify the structure — must have public/index.php
ls projects/myapp/public/index.php
```

### Option B — Create a new Laravel project via Composer

```bash
# Run composer create-project inside the php82 container
docker exec -it $PHP_VERSION bash -c \
  "composer create-project laravel/laravel /var/www/myapp"
```

> **Note:** The Nginx container mounts `projects/` as `/var/www/` (read-only). Your code on the host is instantly visible inside all containers — no rebuild needed.

### Configure git safe directory

```bash
docker exec -it $PHP_VERSION bash -c "git config --global --add safe.directory /var/www/myapp"
```

---

## Step 3 — Create the Database

> Single MariaDB instance, single shared user.
> **Username:** `laravel` | **Password:** `secret`

```bash
# Create the database
./scripts/dev.sh db-create myapp
```

> The `laravel` user is already created when the environment starts. You only need to create the database and grant access.

### Option — Import from a SQL dump

If you have an existing database dump, place it in `docker/mariadb/dumps/` and import it:

```bash
# 1. Copy the dump
cp /path/to/your/dump.sql docker/mariadb/dumps/

# 2. Create the database (if it doesn't exist yet)
./scripts/dev.sh db-create myapp

# 3. Import
./scripts/dev.sh db-import myapp dump.sql
```

> The `dumps/` folder is mounted at `/dumps` inside the MariaDB container. You can also exec in manually if needed:
>
> ```bash
> docker exec -i mariadb mariadb -u laravel -p secret myapp < docker/mariadb/dumps/dump.sql
> ```

---

## Step 4 — Configure Nginx Vhost

### Copy the template

```bash
cp docker/nginx/conf.d/_template.conf.example \
   docker/nginx/conf.d/myapp.conf
```

### Edit `docker/nginx/conf.d/myapp.conf`

Replace `PROJECTNAME` with `myapp` and `PHPVERSION` with the correct PHP upstream:

```nginx
server {
    listen 80;
    server_name myapp.test;

    root /var/www/myapp/public;   # ← MUST point to /public
    index index.php index.html;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass php82;               # ← PHP version for this project
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        fastcgi_hide_header X-Powered-By;
        fastcgi_read_timeout 300;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
```

### PHP version reference

| `fastcgi_pass` | PHP version | Laravel compatibility |
|---|---|---|
| `php83` | 8.3 | Laravel 10, 11 |
| `php82` | 8.2 | Laravel 9, 10, 11 |
| `php81` | 8.1 | Laravel 9, 10 |
| `php80` | 8.0 | Laravel 8, 9 |
| `php74` | 7.4 | Laravel 6, 7, 8 |
| `php73` | 7.3 | Laravel 5.x, 6, 7 |
| `php72` | 7.2 | Laravel 5.5 – 5.8 |
| `php71` | 7.1 | Laravel 5.4, 5.5 |
| `php70` | 7.0 | Laravel 5.2, 5.3, 5.4 |

### Reload Nginx

```bash
# No restart needed — just reload
docker exec nginx nginx -s reload

# Validate config syntax first if you want
docker exec nginx nginx -t
```

---

## Step 5 — Configure the Laravel `.env` File

```bash
cp projects/myapp/.env.example projects/myapp/.env
```

### Complete `.env` example — all services pre-wired

```env
APP_NAME="My App"
APP_ENV=local
APP_KEY=
APP_DEBUG=true
APP_URL=http://myapp.test

LOG_CHANNEL=stack
LOG_LEVEL=debug

# ── Database ────────────────────────────────────────────────────
# IMPORTANT: Use container name 'mariadb', NOT localhost
DB_CONNECTION=mysql
DB_HOST=mariadb
DB_PORT=3306
DB_DATABASE=myapp
DB_USERNAME=laravel
DB_PASSWORD=secret

# ── Redis ────────────────────────────────────────────────────────
# IMPORTANT: Use container name 'redis', NOT localhost or 127.0.0.1
CACHE_DRIVER=redis
QUEUE_CONNECTION=redis
SESSION_DRIVER=redis
REDIS_HOST=redis
REDIS_PASSWORD=null
REDIS_PORT=6379
REDIS_DB=0          # Use a unique number per project (0–15)
REDIS_CACHE_DB=1

# ── Mail — Mailhog ───────────────────────────────────────────────
# Mailhog catches ALL mail and never delivers it to real addresses.
# View caught emails at http://mail.test
MAIL_MAILER=smtp
MAIL_HOST=mailhog
MAIL_PORT=1025
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null
MAIL_FROM_ADDRESS=hello@myapp.test
MAIL_FROM_NAME="${APP_NAME}"

# ── Meilisearch (Laravel Scout) ──────────────────────────────────
SCOUT_DRIVER=meilisearch
MEILISEARCH_HOST=http://meilisearch:7700
MEILISEARCH_KEY=masterkey
```

> **After editing `.env`** always run:
>
> ```bash
> php artisan config:clear && php artisan cache:clear
> ```

### Redis DB isolation

Redis has 16 databases (0–15). Use different numbers per project to avoid key collisions:

| Project | `REDIS_DB` | `REDIS_CACHE_DB` |
|---|---|---|
| project1 | 0 | 1 |
| project2 | 2 | 3 |
| myapp | 4 | 5 |

---

## Step 6 — Install Dependencies with Composer

Use the PHP container that matches your project's version.

```bash
# Enter the container
docker exec -it php82 bash
cd /var/www/myapp

# Install from composer.lock
composer install

# If no composer.lock exists yet (fresh project)
composer update
```

**One-liner:**

```bash
docker exec -it php82 bash -c "cd /var/www/myapp && composer install"
```

---

## Step 7 — Final Laravel Setup Commands

```bash
docker exec -it php82 bash
cd /var/www/myapp

# 1. Generate application encryption key
php artisan key:generate

# 2. Run database migrations
php artisan migrate

# 3. (Optional) Seed the database
php artisan db:seed

# 4. Create the storage symlink
php artisan storage:link

# 5. Set correct folder permissions
chmod -R 775 storage bootstrap/cache

# 6. Clear all caches
php artisan optimize:clear
```

Then open your browser at **<http://myapp.test>** ✓

---

## Full Setup — Copy-Paste Block

Run these commands from the workspace root to set up a new project from scratch:

```bash
# 1. Create folder and clone code
mkdir -p projects/myapp
git clone https://github.com/yourorg/myapp.git projects/myapp

# 2. Create database
./scripts/dev.sh db-create myapp

# 3. Create nginx vhost (then edit it — set server_name, root, fastcgi_pass)
cp docker/nginx/conf.d/_template.conf.example docker/nginx/conf.d/myapp.conf

# 4. Reload nginx
docker exec nginx nginx -s reload

# 5. Configure .env (set DB_DATABASE=myapp and a unique REDIS_DB number)
cp projects/myapp/.env.example projects/myapp/.env

# 6. Install dependencies, generate key, migrate
docker exec -it php82 bash -c "cd /var/www/myapp && composer install"
docker exec -it php82 bash -c "cd /var/www/myapp && php artisan key:generate"
docker exec -it php82 bash -c "cd /var/www/myapp && php artisan migrate"
docker exec -it php82 bash -c "cd /var/www/myapp && php artisan storage:link"

# Done — open http://myapp.test
```
