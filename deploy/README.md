# AESOP Deploy — T3 Home Node Bring-Up

Infrastructure deployment files for the T3 (Home Node) tier per `profiles/nav.yaml`.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  T1 — Edge (Phone)                                               │
│  Termux on Motorola Razr Ultra 2025                              │
│  Tailscale VPN ─────────────────────────────────────────────┐    │
│                                                              │    │
│  ~/vault (canonical markdown) ─── git push ──┐               │    │
│  ~/repos/aesop (this repo)                  │               │    │
└──────────────────────────────────────────────┼───────────────┼────┘
                                               │               │
                    ┌──────────────────────────┼───────────────┘
                    │                          │
┌───────────────────┼──────────────────────────┼───────────────────┐
│  T3 — Home Node (Jetson Orin Nano Super 8GB)  │                   │
│                                                │                   │
│  ┌─────────────────────┐  ┌──────────────────┐ │                   │
│  │ Postgres + pgvector │  │ OmniRoute        │ │                   │
│  │ (OB1 recall memory) │  │ (gateway, audit) │ │                   │
│  │ :5432               │  │ :20128           │ │                   │
│  └─────────────────────┘  └──────────────────┘ │                   │
│  ┌─────────────────────┐  ┌──────────────────┐ │                   │
│  │ Redis               │  │ Vault bare git   │ │                   │
│  │ (rate limiter)      │  │ ~/vault.git      │ │                   │
│  └─────────────────────┘  └──────────────────┘ │                   │
│                                                │                   │
│  LATER: onnxruntime + gemma-4-E2B (executive)  │                   │
└────────────────────────────────────────────────┼───────────────────┘
                                                 │
┌────────────────────────────────────────────────┼───────────────────┐
│  T3 — Audio Node (Rubik Pi / Dragonwing)       │                   │
│                                                │                   │
│  ┌────────────────────────────────────────────┐│                   │
│  │ sherpa-onnx + Kokoro TTS                  ││                   │
│  │ Desktop OS + audio output                 ││                   │
│  │ systemd service :8080                     ││                   │
│  └────────────────────────────────────────────┘│                   │
│  Shared ~/models/ (kokoro, moonshine, silero)  │                   │
└────────────────────────────────────────────────┴───────────────────┘
```

## Directory Structure

```
deploy/
  README.md                ← this file
  jetson/
    FLASHING.md            ← Jetson flashing guide (JetPack 6.x, firmware check)
    first-boot-setup.sh    ← One-shot setup script (Tailscale, Docker, secrets, repos)
    vault-sync-setup.sh    ← Bare git repo setup for phone→Jetson vault sync
    docker-compose.yml     ← T3 services: Postgres+pgvector, Redis, OmniRoute
    .env.example           ← Environment template (secrets)
  rubik-pi/
    SETUP.md               ← Rubik Pi flashing + sherpa-onnx TTS endpoint setup
  init/
    ob1-schema.sql         ← OB1/Open Brain schema (thoughts + strategies + audit_log)
```

## Bring-Up Order

1. **Tailscale on phone** — install the Android APK (Play Store / F-Droid),
   log in, note the phone's 100.x.y.z tailnet IP. Enable MagicDNS in admin console.

2. **Jetson Orin Nano** — follow `jetson/FLASHING.md` to flash JetPack 6.x.
   After first boot, run `jetson/first-boot-setup.sh`.
   Start services with `docker compose --profile t3 up -d`.
   Success: phone can reach Postgres (:5432) and OmniRoute (:20128) over tailnet.

3. **Rubik Pi** — follow `rubik-pi/SETUP.md` to flash, install sherpa-onnx,
   set up TTS endpoint. Success: phone can generate speech over tailnet.

## Memory Budget (Jetson 8GB)

| Service | Memory Cap | Purpose |
|---|---|---|
| Postgres + pgvector | 512MB | OB1 recall memory (thoughts + strategies tables) |
| Redis | 96MB | OmniRoute rate limiter backend |
| OmniRoute | 1280MB | Gateway, combo routing, audit log |
| OS + Docker overhead | ~1GB | Ubuntu + container runtime |
| **Available for executive-small** | **~5GB** | Future: onnxruntime + gemma-4-E2B ONNX |

## What Lives Where

| Data | Location | Backup |
|---|---|---|
| Canonical markdown vault | Phone `~/vault` | Pushed to Jetson `~/vault.git` (bare) + `~/vault-mirror` |
| Recall memory (thoughts) | Jetson Postgres `openbrain` DB | Cloud object store (T4, later) |
| Strategic memory (strategies) | Jetson Postgres `openbrain` DB | Cloud object store (T4, later) |
| Audit log | Jetson Postgres `audit_log` table | Cloud object store (T4, later) |
| OmniRoute state | Jetson Docker volume `aesop-omniroute-data` | Not backed up (rebuildable) |
| Model files | Phone `~/models/` (shared, ABI-agnostic) | Copied to Rubik Pi `~/models/` |

## Constraints

- Do not push to Novus-Agenti branches. aesop repo: main only, docs only.
- No tokens/secrets in any commit.
- If docs conflict with reality (firmware, image names), verify against official source.
- Log outcomes in aesop/RESUME.md after each work session.
