# Æsop-Xi — Session Resume / Handoff

Full rewrite, not an append — see `CLAUDE.md` for why. Owner: c10vis-poem
(nav@clovispoem.com). For anything not addressed this session, see `unresolved.md`,
not this file.

## What this is

**Æsop-Xi** (formerly "AESOP", renamed 2026-08-31) — a device-agnostic split agent
stack + personal knowledge-vault. Two scopes currently live in one repo, temporarily:

1. **The on-device terminal agent / voice pipeline** — this repo's original
   foundation. Termux + Debian proot on this phone, real-time mic->VAD->STT->TTS
   (see `aesop-voice-pipeline` Claude Code skill for the working tools). **Will be
   extracted into the Æsc and Æyre daemon APKs once those exist, then wiped from
   this repo** — not permanent architecture, don't build on the assumption it
   stays here.
2. **The protocol/orchestration/memory-recall layer** — roles, tiers, the 4 memory
   types (`ARCHITECTURE.md` §4), OmniRoute-as-gateway, reasoning-bank. This is the
   actual long-term scope of Æsop-Xi as a protocol.

## Repo state (2026-08-31)

- Directory renamed `~/repos/aesop` → `~/repos/aesop-xi`. The **separate, independent
  clone inside the Debian proot** (`/root/repos/aesop`, not a bind-mount — a real
  second copy from the original setup) was also renamed to `/root/repos/aesop-xi` for
  consistency. Both were required for the voice pipeline to keep working; confirmed
  via a live `--demo` run after each rename.
- Naming convention (user-specified 2026-08-31): **Æsop-Xi** for branding/docs/public-
  facing, **aesop-xi** (lowercase, hyphenated, no ligature) for anything machine-fetched
  — repo names, URLs, paths, package names. Applies across the whole naming family:
  NovÆcorpus/novae-xorpus, NovusÆxenti/novus-aexenti, NovÆxopia/novaexopia,
  Æsop-Xi/aesop-xi.
- `RESUME.md` previously had **unresolved git conflict markers checked into the file**
  (`<<<<<<< Updated upstream` / `=======` / `>>>>>>> Stashed changes`) from a stash
  that was never cleanly finished — resolved this session by full rewrite (this file).
  `git status` confirmed it as `UU` (genuinely unmerged) before this rewrite.
- `CLAUDE.md` (repo-level Claude Code conventions) and `unresolved.md` (durable
  backlog) created for the first time this session — neither existed before, despite
  RESUME.md implying a handoff process was already established.
- `protocol/memory.md` created for real this session — RESUME.md had claimed it was
  "in progress" (subagent-authored) in an earlier session, but it was never actually
  written; only `protocol/tiers.md` had landed. It's a pointer to `ARCHITECTURE.md`
  §4, not a duplicate of it.
- `ARCHITECTURE.md` §4 updated from 3 memory types to 4: added **Working/Ephemeral**
  (transient session/task state, deliberately not persisted), backed by the Redis
  container `deploy/jetson/docker-compose.yml` already provisions for OmniRoute rate
  limiting but never named as a memory type until now. `README.md` updated to match.
- A stray broken self-referential symlink (`aesop-xi/aesop` -> old pre-rename path)
  found and removed — leftover from 2026-07-22, no dependents.

## Voice pipeline — status

Real-time engine (`voice-engine/scripts/live_voice_loop.py` + a fixed launcher, see
the `aesop-voice-pipeline` skill) confirmed working end-to-end via `--demo`
(TTS -> speaker -> STT round-trip, text matched). Two real bugs found and fixed:
Moonshine STT's ~10s hard input ceiling (silent failure past 9.5-10s, no error), and
a two-part PulseAudio/proot audio bridge issue (missing ALSA-over-Pulse routing +
required client-side SHM disable). Full detail in the skill's `SKILL.md`, not
repeated here. **Not yet verified**: the live mic loop itself (only `--demo` has been
run) — confirm this before trusting it blind next session.

## Post-session targets, exact order (user-specified 2026-08-31)

This is the authoritative order — supersedes any earlier "today vs. next session"
framing in prior drafts of this file. Do not re-sequence without the user's say-so.

1. **Installation of OpenWiki.** Get it running with an OpenRouter key + GLM-5.2
   model hooked in. Note: `~/openwiki` is a real custom fork
   (`c10vis-poem/openwiki`, upstream `langchain-ai/openwiki`) on branch
   `claude/wiki-quinn-npu-local-m1crql` with genuine NPU/voice commits — not
   vanilla upstream. It had uncommitted changes (accidentally deleted
   `.gitignore`/`README.md`) restored 2026-08-29; separately there's both
   `package-lock.json` and `pnpm-lock.yaml` present, worth resolving which
   package manager is actually canonical before relying on either.
2. **Installation of DroidDesk** on both the phone and the tablet — not yet
   started on either device. Confirmed: DroidDesk itself renders via Termux:X11
   directly, not VNC (VNC is only an optional external-monitor bridge in its own
   docs). Decided: standalone real desktops on each device independently, not
   phone->tablet mirroring — scrcpy (already forked) was considered and
   explicitly ruled out for this purpose.
3. **Piping of the voice line.** Real-time engine confirmed working via
   `--demo` (see below) — this step is wiring it into actual use (the LLM
   callback stub, live mic verification), not building it from scratch.
4. **Installations of ECC, Pocock skills, and honey-for-devs.** Note: ECC is a
   ready-to-go plugin (`.claude-plugin/plugin.json` in `~/repos/ECC-aesop`)
   never actually installed via the plugin system — confirmed against
   `~/.claude/plugins/installed_plugins.json` (only 3 unrelated plugins listed).
   One-command install once reached.
5. **Grill session** (Pocock's grill-me skill).
6. **On-device help desk.**
7. **Salvaging the existing APK as a terminal daemon** — ties to the planned
   Æsc/Æyre daemon APKs (see "What this is" above).

Explicitly separate from this list, deferred without a fixed slot: the
HTTP/WebSocket server for remote voice-engine invocation (extension point noted
in the `aesop-voice-pipeline` skill, not built). See `unresolved.md` for the full
durable backlog (obsidian-skills into vault, notebooklm login path, OpenWiki
upstream PR, open architectural decisions, T3 hardware bring-up, Tailscale status,
the OmniRoute/OB1/ReasoningBank routing question).
