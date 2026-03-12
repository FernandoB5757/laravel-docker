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
# Laravel storage/cache permissions
# php-fpm runs as www-data (uid 82); files on the host are owned by uid 1000.
# www-data is not in group 1000, so 775 only gives it r-x (no write).
# We use 777 on these two directories so www-data can write regardless of owner.
# ---------------------------------------------------------------------------
for project in /var/www/*/; do
    [ -d "${project}storage" ]         && chmod -R 777 "${project}storage"
    [ -d "${project}bootstrap/cache" ] && chmod -R 777 "${project}bootstrap/cache"
done

exec "$@"
