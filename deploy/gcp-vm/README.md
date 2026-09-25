# GCP VM — OmniRoute control plane host

VM: `omniroute-x86` · project `project-alchemist-490416` · zone `us-central1-a`
e2-standard-4 (4 vCPU / 16 GB, x86_64) · Ubuntu 24.04 · 50 GB pd-balanced.
~$0.134/hr while running + ~$5/mo disk. External IP is ephemeral.

## Cost guards (install first, every rebuild)

| File | What it does |
|---|---|
| `idle-shutdown` → `/usr/local/bin/` | Powers off after 30 min with no inbound connection and load < 0.5 |
| `idle-shutdown.service` / `.timer` → `/etc/systemd/system/` | Runs the check every 5 min |
| Resource policy `nightly-stop-4am` | Hard stop 4 AM America/Los_Angeles (needs compute service-agent `roles/compute.instanceAdmin.v1`) |

## Base system

`01-base.sh` — Docker + Compose, Tailscale, Node 22, VS Code, Chrome,
Chrome Remote Desktop (XFCE session), Obsidian, Arc-Dark theme. Idempotent.

```sh
gcloud compute scp deploy/gcp-vm/01-base.sh omniroute-x86:/tmp/ --zone us-central1-a
gcloud compute ssh omniroute-x86 --zone us-central1-a --command 'bash /tmp/01-base.sh'
```

## Phone (Termux) controls — copy to `~/bin/`

| Script | Use |
|---|---|
| `phone/vm` | `vm on \| off \| status \| ssh \| desktop` (old ARM VM: `VM_NAME=omniroute-brain vm ...`) |
| `phone/close-firewall` | Deletes public firewall rules; leaves SSH only |

## Network

Firewall: SSH (22), ICMP, and GCP-internal only. Everything else is reached over Tailscale.

An on-device copy of these scripts lives at `Documents/vm-setup/` (shared storage).
