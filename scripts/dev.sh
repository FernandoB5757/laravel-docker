#!/usr/bin/env bash
# ============================================================
# Laravel Docker Platform — Developer Helper Script
# Usage: ./dev.sh <command> [options]
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}=== Laravel Docker Platform ===${NC}"
}

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_warn()    { echo -e "${YELLOW}⚠ $1${NC}"; }
print_error()   { echo -e "${RED}✗ $1${NC}"; }

print_header

case "$1" in
    # -------------------------------------------------------
    # Start all services
    # -------------------------------------------------------
    up)
        echo "Starting all services..."
        cd "$ROOT_DIR"
        docker compose up -d "${@:2}"
        print_success "Environment started"
        echo ""
        echo "Available services:"
        echo "  Traefik dashboard: http://traefik.test (or http://localhost:8080)"
        echo "  Mailhog:           http://mail.test"
        echo "  Meilisearch:       http://meilisearch.test"
        ;;

    # -------------------------------------------------------
    # Stop all services
    # -------------------------------------------------------
    down)
        echo "Stopping all services..."
        cd "$ROOT_DIR"
        docker compose down "${@:2}"
        print_success "Environment stopped"
        ;;

    # -------------------------------------------------------
    # Shell into a PHP container
    # Usage: ./dev.sh shell php82
    # -------------------------------------------------------
    shell)
        PHP_CONTAINER="${2:-php82}"
        PROJECT="${3:-}"
        echo "Opening shell in ${PHP_CONTAINER}..."
        if [ -n "$PROJECT" ]; then
            docker exec -it "$PHP_CONTAINER" bash -c "cd /var/www/$PROJECT && exec bash"
        else
            docker exec -it "$PHP_CONTAINER" bash
        fi
        ;;

    # -------------------------------------------------------
    # Run artisan command
    # Usage: ./dev.sh artisan php82 project1 migrate
    # -------------------------------------------------------
    artisan)
        PHP_CONTAINER="${2:?Usage: artisan <container> <project> <command>}"
        PROJECT="${3:?Usage: artisan <container> <project> <command>}"
        shift 3
        echo "Running: php artisan $@ in $PROJECT via $PHP_CONTAINER"
        docker exec -it "$PHP_CONTAINER" bash -c "cd /var/www/$PROJECT && php artisan $*"
        ;;

    # -------------------------------------------------------
    # Run composer command
    # Usage: ./dev.sh composer php82 project1 install
    # -------------------------------------------------------
    composer)
        PHP_CONTAINER="${2:?Usage: composer <container> <project> <command>}"
        PROJECT="${3:?Usage: composer <container> <project> <command>}"
        shift 3
        echo "Running: composer $@ in $PROJECT via $PHP_CONTAINER"
        docker exec -it "$PHP_CONTAINER" bash -c "cd /var/www/$PROJECT && composer $*"
        ;;

    # -------------------------------------------------------
    # Enable Xdebug
    # -------------------------------------------------------
    xdebug-on)
        echo "Enabling Xdebug (step debugger)..."
        sed -i 's/^XDEBUG_MODE=.*/XDEBUG_MODE=debug/' "$ROOT_DIR/.env"
        cd "$ROOT_DIR"
        docker compose up -d "${@:2}"
        print_success "Xdebug enabled. Listen on port 9003 in your IDE."
        ;;

    # -------------------------------------------------------
    # Disable Xdebug
    # -------------------------------------------------------
    xdebug-off)
        echo "Disabling Xdebug..."
        sed -i 's/^XDEBUG_MODE=.*/XDEBUG_MODE=off/' "$ROOT_DIR/.env"
        cd "$ROOT_DIR"
        docker compose up -d "${@:2}"
        print_success "Xdebug disabled."
        ;;

    # -------------------------------------------------------
    # Add a new project
    # Usage: ./dev.sh new-project myapp php83
    # -------------------------------------------------------
    new-project)
        PROJECT_NAME="${2:?Usage: new-project <name> <php-version>}"
        PHP_VERSION="${3:?Usage: new-project <name> <php-version>}"
        VHOST_FILE="$ROOT_DIR/docker/nginx/conf.d/${PROJECT_NAME}.conf"
        ENV_FILE="$ROOT_DIR/projects/$PROJECT_NAME/.env.example"

        echo "Creating project: ${PROJECT_NAME} (${PHP_VERSION})"

        # Create project directory
        mkdir -p "$ROOT_DIR/projects/$PROJECT_NAME"
        print_success "Created projects/$PROJECT_NAME"

        # Create nginx vhost from template
        sed \
            -e "s/PROJECTNAME/$PROJECT_NAME/g" \
            -e "s/PHPVERSION/$PHP_VERSION/g" \
            "$ROOT_DIR/docker/nginx/conf.d/_template.conf.example" \
            > "$VHOST_FILE"
        print_success "Created nginx vhost: $VHOST_FILE"

        # Generate a project-specific .env.example from scratch
        cat > "$ENV_FILE" << ENVEOF
APP_NAME="${PROJECT_NAME}"
APP_ENV=local
APP_KEY=base64:GENERATE_WITH_php_artisan_key_generate
APP_DEBUG=true
APP_URL=http://${PROJECT_NAME}.test

LOG_CHANNEL=stack
LOG_LEVEL=debug

# Database — shared MariaDB container
DB_CONNECTION=mysql
DB_HOST=mariadb
DB_PORT=3306
DB_DATABASE=${PROJECT_NAME}
DB_USERNAME=laravel
DB_PASSWORD=secret

# Redis — shared Redis container (use unique DB numbers per project)
CACHE_DRIVER=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis

REDIS_HOST=redis
REDIS_PASSWORD=null
REDIS_PORT=6379
REDIS_DB=0
REDIS_CACHE_DB=1

# Mail — Mailhog SMTP catcher
MAIL_MAILER=smtp
MAIL_HOST=mailhog
MAIL_PORT=1025
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null
MAIL_FROM_ADDRESS="hello@${PROJECT_NAME}.test"
MAIL_FROM_NAME="\${APP_NAME}"

# Meilisearch — Laravel Scout
SCOUT_DRIVER=meilisearch
MEILISEARCH_HOST=http://meilisearch:7700
MEILISEARCH_KEY=masterkey
ENVEOF
        print_success "Created .env.example"

        echo ""
        print_warn "Next steps:"
        echo "  1. Create database:  ./dev.sh db-create ${PROJECT_NAME}"
        echo "  2. Reload nginx:     docker exec nginx nginx -s reload"
        echo "  3. Place Laravel in: projects/${PROJECT_NAME}"
        echo "  4. Open:             http://${PROJECT_NAME}.test"
        ;;

    # -------------------------------------------------------
    # Create a new database on the running MariaDB instance
    # Usage: ./dev.sh db-create myapp
    # -------------------------------------------------------
    db-create)
        DB_NAME="${2:?Usage: db-create <database-name>}"
        DB_ROOT_PASS="$(grep '^DB_ROOT_PASSWORD=' "$ROOT_DIR/.env" | cut -d= -f2)"
        DB_USER="$(grep '^DB_USERNAME=' "$ROOT_DIR/.env" | cut -d= -f2)"
        if [ -z "$DB_ROOT_PASS" ]; then
            DB_ROOT_PASS="secret"
        fi
        if [ -z "$DB_USER" ]; then
            DB_USER="laravel"
        fi
        echo "Creating database: ${DB_NAME}..."
        docker exec mariadb mysql -uroot -p"${DB_ROOT_PASS}" -e \
            "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; \
             GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%'; \
             FLUSH PRIVILEGES;"
        print_success "Database '${DB_NAME}' created and granted to '${DB_USER}'"
        ;;

    # -------------------------------------------------------
    # Rebuild a specific PHP image
    # Usage: ./dev.sh rebuild php82
    # -------------------------------------------------------
    rebuild)
        SERVICE="${2:?Usage: rebuild <service>}"
        echo "Rebuilding $SERVICE..."
        cd "$ROOT_DIR"
        docker compose build --no-cache "$SERVICE"
        docker compose up -d "$SERVICE"
        print_success "$SERVICE rebuilt and restarted"
        ;;

    # -------------------------------------------------------
    # Show logs
    # -------------------------------------------------------
    logs)
        SERVICE="${2:-}"
        cd "$ROOT_DIR"
        docker compose logs -f --tail=100 $SERVICE
        ;;

    # -------------------------------------------------------
    # Status
    # -------------------------------------------------------
    status)
        cd "$ROOT_DIR"
        docker compose ps
        ;;

    # -------------------------------------------------------
    # Help
    # -------------------------------------------------------
    *)
        echo "Usage: ./dev.sh <command> [options]"
        echo ""
        echo "Commands:"
        echo "  up                              Start all services"
        echo "  down                            Stop all services"
        echo "  shell <container> [project]     Open bash shell"
        echo "  artisan <container> <project> <cmd>   Run php artisan"
        echo "  composer <container> <project> <cmd>  Run composer"
        echo "  xdebug-on                       Enable Xdebug (PHP 7.2+ only)"
        echo "  xdebug-off                      Disable Xdebug"
        echo "  new-project <name> <php>        Scaffold a new project"
        echo "  db-create <database>            Create DB on running MariaDB"
        echo "  rebuild <service>               Rebuild and restart a service"
        echo "  logs [service]                  Tail service logs"
        echo "  status                          Show container status"
        echo ""
        echo "PHP Containers: php83 php82 php81 php80 php74 php73 php72 php71 php70"
        ;;
esac
