#!/usr/bin/env bash
# ============================================================
# DNS Setup Script — Ubuntu 24.04
#
# Configures dnsmasq to resolve all *.test domains to 127.0.0.1
# so that every *.test domain routes to Traefik without any
# manual /etc/hosts editing.
#
# Ubuntu 24.04 note:
#   systemd-resolved runs a "stub resolver" that occupies port 53
#   on 127.0.0.53 AND on 127.0.0.1. We must disable that stub
#   listener BEFORE dnsmasq tries to bind port 53, otherwise
#   dnsmasq will fail to start with "bind: address already in use".
#
# Run once as root:
#   sudo ./scripts/setup-dns.sh
# ============================================================

set -euo pipefail

# -------------------------------------------------------
# Guard: must run as root
# -------------------------------------------------------
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root."
    echo "       Use: sudo ./scripts/setup-dns.sh"
    exit 1
fi

echo "=== Laravel Docker Platform — DNS Setup ==="
echo "    OS target : Ubuntu 24.04"
echo "    Strategy  : dnsmasq on 127.0.0.1:53 for *.test"
echo ""

# -------------------------------------------------------
# Step 1: Install dnsmasq
# -------------------------------------------------------
echo "[1/5] Installing dnsmasq..."
apt-get update -qq
apt-get install -y --no-install-recommends dnsmasq
echo "      dnsmasq installed."

# -------------------------------------------------------
# Step 2: Disable systemd-resolved stub listener
#
# systemd-resolved binds a stub listener on 127.0.0.53:53
# and, on some configurations, also on 127.0.0.1:53.
# Setting DNSStubListener=no frees port 53 for dnsmasq.
# -------------------------------------------------------
echo "[2/5] Disabling systemd-resolved stub listener..."
mkdir -p /etc/systemd/resolved.conf.d/
cat > /etc/systemd/resolved.conf.d/dnsmasq-coexist.conf << 'EOF'
[Resolve]
# Disable stub listener so dnsmasq can bind 127.0.0.1:53
DNSStubListener=no
# Forward all DNS through dnsmasq (dnsmasq handles upstream)
DNS=127.0.0.1
EOF
systemctl restart systemd-resolved
echo "      systemd-resolved restarted (stub listener disabled)."

# -------------------------------------------------------
# Step 3: Configure dnsmasq
# -------------------------------------------------------
echo "[3/5] Configuring dnsmasq for *.test domains..."
cat > /etc/dnsmasq.d/test-domains.conf << 'EOF'
# Resolve all *.test domains to localhost (Traefik reverse proxy)
address=/.test/127.0.0.1

# Listen only on loopback — do not compete with systemd-resolved
# for external interface traffic
listen-address=127.0.0.1
bind-interfaces

# Do not forward .test queries upstream — they are local-only
local=/.test/

# Do not consult /etc/hosts for .test resolution
no-hosts
EOF
echo "      dnsmasq configured."

# -------------------------------------------------------
# Step 4: Point /etc/resolv.conf to dnsmasq
#
# Ubuntu 24.04 may have /etc/resolv.conf as a symlink to
# /run/systemd/resolve/stub-resolv.conf (127.0.0.53).
# We replace it with a static file pointing to dnsmasq
# on 127.0.0.1, with upstream public DNS as fallback.
# -------------------------------------------------------
echo "[4/5] Updating /etc/resolv.conf..."
# Remove the existing file or symlink
if [ -L /etc/resolv.conf ] || [ -f /etc/resolv.conf ]; then
    cp /etc/resolv.conf /etc/resolv.conf.bak.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
    rm -f /etc/resolv.conf
fi
cat > /etc/resolv.conf << 'EOF'
# /etc/resolv.conf — managed by setup-dns.sh (Laravel Docker Platform)
# dnsmasq handles *.test; public DNS is the fallback for everything else.
nameserver 127.0.0.1
nameserver 1.1.1.1
nameserver 8.8.8.8
search local
EOF
echo "      /etc/resolv.conf updated."

# -------------------------------------------------------
# Step 5: Enable and start dnsmasq
# -------------------------------------------------------
echo "[5/5] Starting dnsmasq..."
systemctl enable dnsmasq
systemctl restart dnsmasq
echo "      dnsmasq started."

# -------------------------------------------------------
# Verification
# -------------------------------------------------------
echo ""
echo "=== DNS Setup Complete ==="
echo ""
echo "Verify resolution:"
echo "  dig +short project1.test @127.0.0.1"
echo "    → should return: 127.0.0.1"
echo ""
echo "  ping -c1 project1.test"
echo "    → should reply from: 127.0.0.1"
echo ""
echo "Verify external DNS still works:"
echo "  dig +short google.com"
echo "    → should return a public IP"
echo ""
echo "If dnsmasq fails to start:"
echo "  sudo systemctl status dnsmasq"
echo "  sudo lsof -i :53         # check what holds port 53"
