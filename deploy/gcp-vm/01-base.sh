#!/bin/bash
# Base system for the x86 VM: Docker, XFCE desktop, Chrome Remote Desktop,
# Tailscale, Chrome, VS Code, Obsidian, Node 22. Safe to re-run.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
K=/etc/apt/keyrings
L=/etc/apt/sources.list.d

sudo apt-get update -qq
sudo apt-get install -y -qq ca-certificates curl gnupg git jq unzip
sudo install -m 0755 -d $K

key() { curl -fsSL "$1" | sudo gpg --dearmor --yes -o "$K/$2.gpg"; }
src() { echo "deb [arch=amd64 signed-by=$K/$1.gpg] $2" | sudo tee "$L/$1.list" >/dev/null; }

key https://download.docker.com/linux/ubuntu/gpg docker
src docker "https://download.docker.com/linux/ubuntu noble stable"
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg | sudo tee $K/tailscale.gpg >/dev/null
src tailscale "https://pkgs.tailscale.com/stable/ubuntu noble main"
key https://dl.google.com/linux/linux_signing_key.pub google
src google "https://dl.google.com/linux/chrome/deb/ stable main"
echo "deb [arch=amd64 signed-by=$K/google.gpg] https://dl.google.com/linux/chrome-remote-desktop/deb stable main" \
  | sudo tee $L/chrome-remote-desktop.list >/dev/null
key https://packages.microsoft.com/keys/microsoft.asc microsoft
src microsoft "https://packages.microsoft.com/repos/code stable main"
key https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key nodesource
src nodesource "https://deb.nodesource.com/node_22.x nodistro main"

sudo apt-get update -qq
sudo apt-get install -y -qq \
  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
  tailscale nodejs code google-chrome-stable chrome-remote-desktop \
  xfce4 xfce4-goodies dbus-x11 arc-theme papirus-icon-theme fonts-noto-core

# Obsidian: newest official release that ships a Linux .deb (some releases are Android-only)
url=$(curl -fsSL "https://api.github.com/repos/obsidianmd/obsidian-releases/releases?per_page=20" \
  | jq -r '[.[].assets[] | select(.name | endswith("_amd64.deb")) | .browser_download_url][0]')
curl -fsSL -o /tmp/obsidian.deb "$url"
sudo apt-get install -y -qq /tmp/obsidian.deb

sudo usermod -aG docker "$USER"
echo "exec /etc/X11/Xsession /usr/bin/xfce4-session" | sudo tee /etc/chrome-remote-desktop-session >/dev/null
sudo systemctl disable --now lightdm 2>/dev/null || true  # headless VM; CRD provides the display

d=~/.config/xfce4/xfconf/xfce-perchannel-xml
mkdir -p $d
cat > $d/xsettings.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Arc-Dark"/>
    <property name="IconThemeName" type="string" value="Papirus-Dark"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="FontName" type="string" value="Noto Sans 11"/>
  </property>
</channel>
EOF
cat > $d/xfwm4.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="theme" type="string" value="Arc-Dark"/>
  </property>
</channel>
EOF

echo "--- versions ---"
docker --version; docker compose version; tailscale version | head -1; node -v
code --version | head -1; google-chrome --version; dpkg -l obsidian chrome-remote-desktop | awk '/^ii/{print $2, $3}'
