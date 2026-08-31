---
name: termux-helper
description: "Termux on-device AI stack for Snapdragon 8 Elite. Use when working with Termux on Android: the llamad GGML plane (llama-server, Gemma 4 12B Q4_0, port 8081), the aesopd WebSocket bridge to the Horizons app (port 8765), termux-services daemon supervision, wake-lock persistence, and voice pipeline wiring. Also standard Termux operations: package management, $PREFIX paths, storage access, background services. Read Part 2 before proposing any NPU/Hexagon work — Termux cannot reach the DSP and this skill explains what to do instead."
---

# Termux Helper — On-Device AI Stack, Snapdragon 8 Elite

## Part 1: Termux Core

### 1.1 Packages

- `pkg install <pkg>`, never `apt-get`. Run `pkg up` first when dependencies fail.
- Build chain: `pkg install build-essential clang lld cmake`
- Python: `pkg install python python-dev python-pip`
- Net/tools: `pkg install openssh curl wget git jq tmux`

### 1.2 Paths

`$PREFIX` = `/data/data/com.termux/files/usr`. Binaries live there, not `/usr/bin`.

- Shebang: `#!/data/data/com.termux/files/usr/bin/bash`
- Convert foreign scripts: `termux-fix-shebang <script>`
- Never hardcode `/bin/bash`, `/usr/bin`, `/etc` — expand `$PREFIX`.

### 1.3 Storage

- One-time grant: `termux-setup-storage`
- Shared storage: `~/storage/shared/` → `/storage/emulated/0/`
- Downloads: `~/storage/downloads/` — where sideloaded GGUFs usually land.

## Part 2: What Termux Can and Cannot Reach

**This is the section that matters. Get it wrong and you waste a night.**

Android sandboxes filesystems but **shares loopback**. Every process on the
device sees the same `127.0.0.1`. That single fact is what the whole stack
is built on.

**Termux CANNOT reach the Hexagon DSP.** The FastRPC vendor libraries live
outside the Termux sandbox, and SELinux keeps them there. No llama.cpp build
flag fixes this — not `GGML_HEXAGON=ON`, not a QNN-enabled binary, not
`LD_LIBRARY_PATH` gymnastics. If a plan requires Termux to load QNN, GENIE,
or QAIRT, the plan is wrong. Say so instead of trying it.

**The app CAN.** Horizons (Kotlin/WebView) runs `ort_engine` in app context,
which has vendor lib access, and serves GENIE-compiled contexts (Gemma 4
E4B, Qwen 2B QAI) over HTTP on port 8080.

So the division of labor is:

| Plane | Owner | Port | Runs |
|-------|-------|------|------|
| NPU / HTP v79 | **App** (Horizons) | 8080 | `ort_engine`, GENIE ctx binaries |
| GGML | **Termux** | 8081 | `llamad` → llama-server, Gemma 4 12B Q4_0 |
| Media (STT/TTS) | **App** | 8091 | Moonshine / Kokoro |
| Control / events | **Termux** | 8765 | `aesopd` WebSocket bridge |

**Port discipline:** Termux must never bind 8080 or 8091. The app must never
bind 8081 or 8765. A collision here is silent and miserable to debug.

Termux reaches the NPU by *asking the app over HTTP*, never by loading it.
That's what the bridge is for.

## Part 3: The GGML Plane (`llamad`)

llama-server on 8081, supervised by runit. Backend ladder inside Termux is
Adreno 830 via OpenCL if the build carries it, CPU big cores otherwise.

**Model: Gemma 4 12B IT QAT, Q4_0 quant specifically.** llama.cpp
runtime-repacks Q4_0 into the i8mm/dotprod aarch64 layout on this SoC;
K-quants (Q4_K_XL etc.) don't get that. If both files are on disk, Q4_0 wins.

**Models are already on device.** Discover, never download. Never quantize —
these are pre-quantized and plug-and-play. If asked about quantization,
the answer is almost always "not needed, route it correctly instead."

Memory posture that survives a phone that bloats:

- Use mmap (the default). File-backed pages are reclaimable, so pressure
  evicts pages instead of the low-memory killer taking the whole daemon.
  `--no-mmap` turns a slowdown into a death.
- `-fa -ctk q8_0 -ctv q8_0` roughly halves KV cache at 4k ctx.
- `-t 6` — big cores only; more threads just fight the LITTLE cluster.
- Resident cost is ~7GB model + ~0.5-1GB cache while up. Every weight is
  touched per token, so there is no partial-load trick. `sv down llamad`
  returns all of it instantly.

## Part 4: The Bridge (`aesopd`)

Pure-stdlib RFC 6455 WebSocket server on 8765. One JSON object per text
frame; `id` correlates requests to streamed replies.

Routing:

- `llm.generate` with `backend: "ggml"` → `POST 127.0.0.1:8081/v1/chat/completions`
- `llm.generate` with `backend: "npu"` → `POST 127.0.0.1:8080/api/v1/generate`

llama-server applies the **GGUF's own chat template** server-side. Never
hand-roll Gemma turn markers on the client.

The data planes are independent of the control plane — killing `aesopd`
never interrupts a generation already running over direct HTTP.

Full wire spec: `aesop-xi/protocol/bridge-protocol.md`.

## Part 5: Persistence

The device reboots and the low-memory killer is aggressive, so supervision
is not optional.

```bash
pkg install termux-services      # then fully restart Termux
bash ~/repos/aesop-xi/deploy/phone/daemons/install-daemons.sh
sv status llamad aesopd
```

- `sv up|down|restart <svc>` — manual control
- `tail -f $PREFIX/var/log/llamad/current` — svlogd output
- `termux-wake-lock` before long runs; `termux-wake-unlock` after
- tmux is the fallback when services aren't installed, not the primary path

## Part 6: Debugging

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Port 8081 refused | `llamad` down or no GGUF found | `sv status llamad`, check log for "no .gguf found" |
| Daemon restart loop | Model missing; script exits, runit re-runs | Set `AESOP_MODEL=/path/to/q4_0.gguf` |
| Two processes fighting a port | Termux bound an app-owned port | Re-read the port table in Part 2 |
| Killed mid-generation | LMK under pressure | Confirm mmap is on; close background apps |
| Very slow first token | Pages evicted, re-reading from UFS | Free RAM; this is degraded-not-dead by design |
| Bridge won't connect | `aesopd` down | `sv status aesopd`; direct HTTP to 8081 still works |
| Any "enable HTP in Termux" idea | Category error | See Part 2 — route to the app instead |

## Part 7: Where This Lives

Canonical copy: `aesop-xi/skills/termux-helper/SKILL.md` (version controlled).

The local `~/.claude/skills/` copy is a **working copy, not the source of
truth** — not literally ephemeral on this phone (a persistent device, not a
disposable sandbox); it just silently drifts out of sync with the repo if
edited without committing, and other devices/sessions never see local-only
edits. On a disposable cloud sandbox editing this same repo, that local copy
is wiped outright when the container is reclaimed. Either way: when updating
this skill, commit to the repo.
