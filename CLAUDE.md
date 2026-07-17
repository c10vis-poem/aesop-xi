# CLAUDE.md — AESOP

## What this is

**AESOP** (Agentic Executions Split Operations Protocol) — split agent stack across
phone / workstation / home node / cloud behind one shared, auditable memory.

Canonical repo: `c10vis-poem/aesop`. Owner: nav@clovispoem.com.

## State of the Union — 2026-07-17

### STT/TTS Voice Layer — DONE

The voice layer is fully working end-to-end on the Motorola Razr Ultra 2025 (Termux):

- **STT**: Silero VAD + Moonshine base int8 via sherpa-onnx (in Debian proot)
- **TTS**: Kokoro multi-lang v1.0 via sherpa-onnx (in Debian proot)
- **Audio I/O**: `termux-microphone-record` / `termux-media-player` (native Termux:API)
- **OpenWiki integration**: Ctrl+R to record, Enter to transcribe, text lands in chat
  bar. Responses auto-spoken via Kokoro TTS. `/voice` command shows setup diagnostics.

**One-command setup**: `bash ~/aesop/deploy/phone/setup-voice.sh`
Installs everything: proot debian, sherpa-onnx, ffmpeg, Silero VAD (~2MB),
Moonshine (~288MB), Kokoro (~326MB). Idempotent, safe to re-run.

**Architecture decision**: sherpa-onnx runs inside the Debian proot (glibc wheels),
audio I/O stays in native Termux (bionic). Models live in `~/models/` shared via
`--bind`. No PulseAudio bridge needed — ffmpeg converts the recording in native
Termux before passing to proot, and TTS writes WAV to the shared home dir for
`termux-media-player` to play natively.

### Files

```
deploy/phone/
  setup-voice.sh        # one-command full setup (STT + TTS + models + OpenWiki)
  setup-stt.sh          # STT-only setup (subset of above)
  stt_process.py        # VAD + Moonshine STT processor (runs in proot)
  tts_speak.py          # Kokoro TTS (runs in proot)
  record_transcribe.sh  # standalone mic → STT
  speak.sh              # standalone TTS
  voice.sh              # full voice loop using openwiki -p
  voice_loop.sh         # raw curl voice loop (deprecated, use voice.sh)
```

OpenWiki voice integration lives in the openwiki repo:
```
openwiki/src/
  voice.ts              # async STT/TTS wrapper + diagnostics
  cli.tsx               # ChatInput modified: Ctrl+R recording, /voice command
```

### Models on device (inside proot, at ~/models/)

| Model | Size | Path |
|-------|------|------|
| Silero VAD | ~2MB | `~/models/silero_vad.onnx` |
| Moonshine base int8 | ~288MB | `~/models/sherpa-onnx-moonshine-base-en-int8/` |
| Kokoro multi-lang v1.0 | ~326MB | `~/models/kokoro-multi-lang-v1.0/` |

### Key technical decisions

- **No PulseAudio bridge**: Recording and playback happen in native Termux via
  termux-api commands. Only the inference (STT/TTS) crosses into proot. This
  avoids the complexity of bridging audio between bionic and glibc.
- **Kokoro v1.0 requires**: `lexicon=lexicon-us-en.txt`, `lang=en-us`,
  `dict_dir=dict` — without these params sherpa-onnx errors on "pass --kokoro-lexicon".
- **Voice is opt-in**: OpenWiki auto-detects Termux + AESOP scripts. On desktop
  or in CI, voice features are completely invisible — no new dependencies.
- **Cross-platform TTS**: Pinned for future — `say` (macOS), `espeak` (Linux),
  PowerShell (Windows) as lightweight alternatives to Kokoro. Not implemented yet.

### Pending — in order

1. **Phone deploy**: Pull branches on device, run setup-voice.sh, test end-to-end
2. **OpenWiki sources**: Add the 15 repos as OpenWiki sources on device
3. **Persist env vars in .zshrc**: `OPENROUTER_API_KEY`, `LANGCHAIN_TRACING_V2=false`,
   `LANGSMITH_TRACING=false`, `unset LANGSMITH_API_KEY`
4. **Voice switching**: Kokoro supports multiple voices via `sid` param — add a
   `/voice sid <N>` command or env var
5. **Graphify**: Install in proot, index the vault
6. **notebooklm auth**: proot + VNC desktop → Playwright login → headless thereafter
7. **obsidian-skills**: Clone into vault
8. **protocol/ docs**: `gateway.md` (OmniRoute as AESOP's gateway), fold Graphify
   into `memory.md`

### Standing decisions

- sherpa-onnx in proot, audio in native Termux — settled, working
- Moonshine base int8 for STT (not tiny) — quality matters more than 50ms
- Kokoro multi-lang v1.0 for TTS — the only multi-lang option in sherpa-onnx
- OpenWiki IS the agent interface — not a separate voice bot
- Desktop voice: OS-level dictation already works in terminal; AESOP voice
  solves the Termux/Android-specific raw-mode IME problem

## Branch

Active: `claude/aesop-stt-tts-layer-0v6c83` — PR #1 (aesop), PR #2 (openwiki)

## Repos in play (all c10vis-poem)

- **aesop** — this repo, umbrella + deploy scripts
- **openwiki** — fork, voice integration in src/voice.ts + cli.tsx
- **Novus-Agenti** — Omni Claw Android app (separate track)
- **memary, graphify, notebooklm-py, obsidian-skills, reasoning-bank, OB1,
  OmniRoute, silero-vad, aider, docker-pkg-build, termux-packages,
  tmux-assistant-resurrect** — cloned/available

## Device

Motorola Razr Ultra 2025 · Snapdragon 8 Elite SM8750 · 16GB RAM
Termux + Debian proot · Node 22+ · Python 3.x (proot)

## Hard rules

- Never hardcode tokens/keys — env vars only
- Audio I/O in native Termux, inference in proot — don't mix
- OpenWiki is the agent interface, not a dumb chatbot wrapper
- Models at ~/models/ shared via --bind, never duplicated
