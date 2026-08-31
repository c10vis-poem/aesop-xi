#!/bin/bash
# AESOP T3 — Vault bare git repo setup on Jetson
#
# Creates a bare git repo at ~/vault.git that the phone can push to over Tailscale.
# The canonical markdown vault lives on the phone (~) and syncs here as backup.
#
# Run ONCE on the Jetson after first boot + Tailscale setup:
#   bash ~/aesop/deploy/jetson/vault-sync-setup.sh
#
# Then on the phone, add the Jetson as a remote:
#   cd ~/vault
#   git remote add jetson ubuntu@jetson:~/vault.git
#   git push jetson main

set -euo pipefail

VAULT_BARE="$HOME/vault.git"
VAULT_MIRROR="$HOME/vault-mirror"

echo "=== AESOP Vault Sync Setup ==="

if [ ! -d "$VAULT_BARE" ]; then
    git init --bare "$VAULT_BARE"
    echo "Created bare repo at $VAULT_BARE"
else
    echo "Bare repo already exists at $VAULT_BARE"
fi

if [ ! -d "$VAULT_MIRROR" ]; then
    git clone "$VAULT_BARE" "$VAULT_MIRROR"
    echo "Created mirror at $VAULT_MIRROR"
else
    echo "Mirror already exists at $VAULT_MIRROR"
fi

CRON_LINE="*/30 * * * * cd $VAULT_MIRROR && git pull --ff-only >> /tmp/vault-sync.log 2>&1"
if crontab -l 2>/dev/null | grep -q "vault-mirror"; then
    echo "Cron job already set"
else
    (crontab -l 2>/dev/null; echo "$CRON_LINE") | crontab -
    echo "Added cron job for periodic vault sync"
fi

echo ""
echo "=== Vault sync setup complete ==="
echo "Phone should add remote:"
echo "  git remote add jetson ubuntu@$(hostname):$VAULT_BARE"
echo "  git push jetson main"
