#!/bin/sh
set -e

# ---------------------------------------------------------------------------
# This entrypoint runs as www-data (uid baked into the image at build time
# via the WWWUSER/WWWGROUP build args — see Dockerfile.{8x,7x,legacy}).
# Nothing here requires root.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# SSH key setup
# ~/.ssh from the host (uid 1000) is mounted read-only at /ssh-host.
# SSH rejects keys not owned by the current user, so we copy them to
# $HOME/.ssh and apply the correct permissions on every startup.
# ---------------------------------------------------------------------------
if [ -d /ssh-host ]; then
    mkdir -p "$HOME/.ssh"
    cp -r /ssh-host/. "$HOME/.ssh/"
    chmod 700 "$HOME/.ssh"
    chmod 600 "$HOME/.ssh"/* 2>/dev/null || true
    chmod 644 "$HOME/.ssh"/*.pub 2>/dev/null || true
    chmod 644 "$HOME/.ssh/known_hosts" 2>/dev/null || true
    chmod 600 "$HOME/.ssh/config" 2>/dev/null || true
fi

# Ensure GitHub and Bitbucket host keys are trusted.
# ssh-keyscan was already run at build time into /etc/ssh/ssh_known_hosts,
# but this acts as a runtime fallback for machines that built without
# network access or have outdated keys.
mkdir -p "$HOME/.ssh"
ssh-keyscan github.com    >> "$HOME/.ssh/known_hosts" 2>/dev/null || true
ssh-keyscan bitbucket.org >> "$HOME/.ssh/known_hosts" 2>/dev/null || true
chmod 644 "$HOME/.ssh/known_hosts" 2>/dev/null || true

# ---------------------------------------------------------------------------
# Git safe directory
# Files under /var/www are owned by the host developer (uid baked into
# www-data at build time); git is happy, but set safe.directory as belt
# and suspenders in case the host uid differs from the build-time bake.
# ---------------------------------------------------------------------------
git config --global --add safe.directory '*'

# ---------------------------------------------------------------------------
# Laravel storage structure
# Ensure all required directories exist for every project. www-data owns
# /var/www (matched to host uid), so no chmod/chown is needed.
# ---------------------------------------------------------------------------
for project in /var/www/*/; do
    mkdir -p \
        "${project}storage/app/public" \
        "${project}storage/framework/cache/data" \
        "${project}storage/framework/sessions" \
        "${project}storage/framework/testing" \
        "${project}storage/framework/views" \
        "${project}storage/logs" \
        "${project}bootstrap/cache" 2>/dev/null || true
done

exec "$@"
