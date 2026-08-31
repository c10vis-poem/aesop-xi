# Jetson Orin Nano Super 8GB — Flashing Guide

**Role in AESOP:** T3 Home Node — hub (memory, gateway, librarian, small executive).
See `profiles/nav.yaml` and `ARCHITECTURE.md` §2 for tier contracts.

## Before You Start — Shopping List

| Item | Spec | Why |
|---|---|---|
| microSD card | 128GB+ A2 U3 (256GB preferred) | JetPack + Docker + models eat space |
| Power supply | USB-C PD 65W+ (or barrel jack 19V) | Orin Nano Super power requirement |
| USB-C cable | Data-capable | Only needed for SDK Manager recovery-mode flashing |

## Critical: Firmware Check

The Orin Nano Super Dev Kit needs a **one-time QSPI firmware update** to boot JetPack 6.x.
If the board is new or has older firmware:

1. **Option A (no x86 host):** First boot with JetPack 5.1.3 SD image,
   let it update QSPI firmware automatically, then reflash with JetPack 6.x.
2. **Option B (x86 host):** Use NVIDIA SDK Manager over USB-C recovery mode
   to flash firmware + image in one pass.

**Check firmware version on first boot** — do not assume it's already updated:
```bash
# On the Jetson after first boot:
cat /etc/nv_tegra_release
# Look for version >= R36.x for JetPack 6.x compatibility
```

If version is R35.x or lower, flash JetPack 5.1.3 first to update QSPI, then reflash 6.x.

## Flashing Steps

### Step 1: Download JetPack 6.x SD Card Image

Download from developer.nvidia.com:
- Search "JetPack 6.x SD Card Image for Orin Nano Super Dev Kit"
- File: `jetson-orin-nano-super-devkit-sd-card-image-r36.x.x.zip`
- Size: ~15-20 GB

### Step 2: Flash to microSD

Use **Balena Etcher** (recommended) or `dd`:

```bash
# On a Linux/Mac host:
# Identify the SD card device:
lsblk
# Flash (replace /dev/sdX with your SD card):
sudo dd if=jetson-orin-nano-super-devkit-sd-card-image.img of=/dev/sdX bs=4M status=progress
sync
```

With Balena Etcher: select the .zip directly, select SD card, Flash.

### Step 3: First Boot

1. Insert the flashed microSD into the Jetson.
2. Connect: USB-C power, HDMI, keyboard, mouse.
3. Power on — first boot takes 2-5 minutes (rootfs expansion).
4. Ubuntu setup wizard: create `ubuntu` user, set password, connect WiFi.

### Step 4: Post-First-Boot Setup

```bash
# System update
sudo apt update && sudo apt install -y curl git

# Tailscale (VPN tunnel for phone ↔ Jetson over LAN/internet)
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
# Note your 100.x.y.z tailnet IP — the phone will use this to reach T3 services.

# Enable MagicDNS in Tailscale admin console for name resolution (jetson, rubik-pi, phone).

# Docker (comes with JetPack, verify):
docker --version
# If missing: curl -fsSL https://get.docker.com | sh && sudo usermod -aG docker $USER
```

### Step 5: Stand Up T3 Services

```bash
# Clone the repos
git clone https://github.com/c10vis-poem/aesop ~/aesop
git clone https://github.com/c10vis-poem/OmniRoute ~/OmniRoute

# Run the first-boot setup script (generates secrets, sets up vault sync)
bash ~/aesop/deploy/jetson/first-boot-setup.sh

# Start T3 services
cd ~/aesop/deploy/jetson
docker compose --profile t3 up -d

# Verify:
docker compose ps
docker compose logs -f --tail=50
```

### Step 6: Verify from Phone

From the phone over Tailscale:
```bash
# Postgres reachable?
psql -h <jetson-tailnet-ip> -U aesop -d openbrain -c '\dt'

# OmniRoute dashboard loads?
curl http://<jetson-tailnet-ip>:20128

# Vault push works?
cd ~/vault
git remote add jetson ubuntu@<jetson-tailnet-ip>:~/vault.git
git push jetson main
```

## Success Criteria

- [ ] Jetson boots JetPack 6.x with R36.x firmware
- [ ] Tailscale connected, 100.x.y.z IP noted
- [ ] `docker compose --profile t3 up -d` — all 3 containers healthy
- [ ] Phone can `psql` to jetson:5432
- [ ] Phone can load http://jetson:20128 (OmniRoute dashboard)
- [ ] Phone can `git push jetson:~/vault.git`
- [ ] MagicDNS enabled in Tailscale admin (nodes resolve by name)

## Troubleshooting

**QSPI firmware too old:**
Flash JetPack 5.1.3 SD image first. It updates QSPI on first boot. Then reflash 6.x.

**Docker not pre-installed:**
```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# Log out and back in for group change
```

**Out of memory (OOM):**
8GB is tight. OmniRoute is capped at 1024MB in docker-compose.yml.
If building the Docker image OOMs:
```bash
# Add swap
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile && sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

**OmniRoute build fails (better-sqlite3 native compile):**
JetPack 6.x (Ubuntu 22.04 aarch64) should compile fine — it has glibc.
```bash
sudo apt install -y python3 make g++
```
