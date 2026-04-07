#!/bin/sh
set -e

# ---------------------------------------------------------------------------
# SSH key setup
# ~/.ssh from the host (uid 1000) is mounted read-only at /ssh-host.
# SSH rejects keys not owned by the current user, so we copy them to
# /root/.ssh and apply the correct permissions on every startup.
# ---------------------------------------------------------------------------
if [ -d /ssh-host ]; then
    mkdir -p /root/.ssh
    cp -r /ssh-host/. /root/.ssh
    chmod 700 /root/.ssh
    chmod 600 /root/.ssh/* 2>/dev/null || true
    chmod 644 /root/.ssh/*.pub 2>/dev/null || true
    chmod 644 /root/.ssh/known_hosts 2>/dev/null || true
    chmod 600 /root/.ssh/config 2>/dev/null || true
fi

# Ensure GitHub and Bitbucket host keys are trusted.
# ssh-keyscan was already run at build time into /etc/ssh/ssh_known_hosts,
# but this acts as a runtime fallback for machines that built without
# network access or have outdated keys.
mkdir -p /root/.ssh
ssh-keyscan github.com    >> /root/.ssh/known_hosts 2>/dev/null || true
ssh-keyscan bitbucket.org >> /root/.ssh/known_hosts 2>/dev/null || true
chmod 644 /root/.ssh/known_hosts 2>/dev/null || true

# ---------------------------------------------------------------------------
# Git safe directory
# Files are owned by the host user (uid 1000); git refuses to run in
# directories owned by a different user unless explicitly allowed.
# ---------------------------------------------------------------------------
git config --global --add safe.directory '*'

# ---------------------------------------------------------------------------
# UID/GID remapping (Laravel Sail strategy)
#
# PHP-FPM runs as www-data. Files on the host are owned by the developer
# (typically uid/gid 1000). Instead of chmod-ing everything (which pollutes
# git's tracked file modes), we remap www-data to match the host developer's
# uid/gid so the process owns the files naturally.
#
# WWWUSER and WWWGROUP are injected via docker-compose environment and
# written to .env by scripts/setup-dns.sh on first-time setup.
# ---------------------------------------------------------------------------
WWWUSER=${WWWUSER:-1000}
WWWGROUP=${WWWGROUP:-1000}

CURRENT_GID=$(id -g www-data)
CURRENT_UID=$(id -u www-data)

if [ "$CURRENT_GID" != "$WWWGROUP" ]; then
    groupmod -g "$WWWGROUP" www-data
fi
if [ "$CURRENT_UID" != "$WWWUSER" ]; then
    usermod -u "$WWWUSER" www-data
fi

# ---------------------------------------------------------------------------
# Laravel storage structure
# Ensure all required directories exist for every project.
# No chmod needed — www-data is now remapped to the host uid/gid and
# therefore already owns every file under /var/www.
# ---------------------------------------------------------------------------
for project in /var/www/*/; do
    mkdir -p \
        "${project}storage/app/public" \
        "${project}storage/framework/cache/data" \
        "${project}storage/framework/sessions" \
        "${project}storage/framework/testing" \
        "${project}storage/framework/views" \
        "${project}storage/logs" \
        "${project}bootstrap/cache"

    # Fix any root-owned files in storage AND bootstrap/cache
    # (e.g. from docker exec as root running artisan/composer)
    find "${project}storage" "${project}bootstrap/cache" \
        \( -not -user "$WWWUSER" -o -not -group "$WWWGROUP" \) \
        -exec chown www-data:www-data {} + 2>/dev/null || true
done

exec "$@"
