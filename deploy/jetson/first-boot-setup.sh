#!/bin/bash
# AESOP T3 — Jetson Orin Nano 8GB first-boot setup
#
# Run AFTER flashing JetPack 6.x, first boot, ubuntu user setup, and Tailscale.
# This script installs everything needed to stand up T3 services.
#
# Usage (on the Jetson, logged in as ubuntu):
#   curl -sSL <repo-raw-url>/deploy/jetson/first-boot-setup.sh | bash
#   OR:
#   git clone https://github.com/c10vis-poem/aesop ~/aesop
#   bash ~/aesop/deploy/jetson/first-boot-setup.sh

set -euo pipefail

echo "=== AESOP T3 — Jetson First Boot Setup ==="
echo "Device: Jetson Orin Nano Super 8GB"
echo "Role:   T3 Home Node (hub: memory, gateway, librarian)"
echo ""

# 1. System packages
echo ">>> Updating system packages..."
sudo apt update && sudo apt install -y curl git build-essential

# 2. Tailscale
if ! command -v tailscale &>/dev/null; then
    echo ">>> Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
    echo ">>> Tailscale installed. Run: sudo tailscale up"
    echo "    Note your 100.x.y.z IP after login."
else
    echo ">>> Tailscale already installed."
fi

# 3. Docker (comes with JetPack, but verify)
if ! command -v docker &>/dev/null; then
    echo ">>> Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
    echo ">>> Docker installed. Log out/in for group changes, then re-run."
    exit 0
else
    echo ">>> Docker already installed: $(docker --version)"
fi

# 4. Docker Compose plugin
if ! docker compose version &>/dev/null 2>&1; then
    echo ">>> Installing Docker Compose plugin..."
    sudo apt install -y docker-compose-plugin
else
    echo ">>> Docker Compose already available."
fi

# 5. Clone repos
AESOP_DIR="$HOME/aesop"
OMNIROUTE_DIR="$HOME/OmniRoute"

if [ ! -d "$AESOP_DIR" ]; then
    echo ">>> Cloning aesop repo..."
    git clone https://github.com/c10vis-poem/aesop "$AESOP_DIR"
else
    echo ">>> aesop repo already exists at $AESOP_DIR"
fi

if [ ! -d "$OMNIROUTE_DIR" ]; then
    echo ">>> Cloning OmniRoute repo..."
    git clone https://github.com/c10vis-poem/OmniRoute "$OMNIROUTE_DIR"
else
    echo ">>> OmniRoute repo already exists at $OMNIROUTE_DIR"
fi

# 6. Generate secrets if .env doesn't exist
ENV_FILE="$AESOP_DIR/deploy/jetson/.env"
if [ ! -f "$ENV_FILE" ]; then
    echo ">>> Generating secrets for .env..."
    PG_PASS=$(openssl rand -hex 32)
    JWT=$(openssl rand -base64 48)
    API_KEY=$(openssl rand -hex 32)
    cat > "$ENV_FILE" << EOF
POSTGRES_PASSWORD=$PG_PASS
JWT_SECRET=$JWT
API_KEY_SECRET=$API_KEY
INITIAL_PASSWORD=CHANGEME
OMNIROUTE_REPO_DIR=$OMNIROUTE_DIR
PHONE_TAILNET_IP=
EOF
    chmod 600 "$ENV_FILE"
    echo "    Secrets generated at $ENV_FILE"
    echo "    IMPORTANT: Change INITIAL_PASSWORD before first OmniRoute boot."
    echo "    IMPORTANT: Set PHONE_TAILNET_IP to the phone's Tailscale IP."
else
    echo ">>> .env already exists at $ENV_FILE"
fi

# 7. Vault sync setup
echo ">>> Setting up vault sync..."
bash "$AESOP_DIR/deploy/jetson/vault-sync-setup.sh" || echo "    (vault sync setup may need manual run)"

echo ""
echo "=== First boot setup complete ==="
echo ""
echo "Next steps:"
echo "  1. sudo tailscale up  (note your 100.x.y.z IP)"
echo "  2. cd ~/aesop/deploy/jetson && docker compose --profile t3 up -d"
echo "  3. Verify Postgres:    psql -h localhost -U aesop -d openbrain -c '\\dt'"
echo "  4. Verify OmniRoute:   curl http://localhost:20128"
echo "  5. From phone over Tailscale:"
echo "     psql -h <jetson-tailnet-ip> -U aesop -d openbrain -c '\\dt'"
echo "     curl http://<jetson-tailnet-ip>:20128"
echo "  6. Push vault from phone:"
echo "     cd ~/vault && git remote add jetson ubuntu@<jetson-tailnet-ip>:~/vault.git"
echo "     git push jetson main"
