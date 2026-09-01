# Æsop-Xi — Session Resume / Handoff

Full rewrite, not an append — see `CLAUDE.md` for why. Owner: c10vis-poem
(nav@clovispoem.com). For anything not addressed this session, see `unresolved.md`
(repo-local) and `~/novae-xorpus/unresolved.md` (the real, durable, cross-repo
backlog — most of what changed this session is filed there, not here, since most
of today's work was global/cross-repo rather than aesop-xi-specific).

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

## Repo state (2026-09-01)

- `skills/aesop-voice-pipeline/` and `skills/termux-helper/` are now correctly
  version-controlled here (`<name>/SKILL.md` layout) and synced to
  `~/.claude/skills/` on this device — both had been phone-local-only before,
  invisible to the repo and to any other device/session. Fixed this session.
- **ECC is now actually installed and configured** — plugin at user scope
  (global, every project on this machine), hooks at `standard` profile (the
  default — hot-loading, review gates, memory persistence all active),
  `common`/`python`/`kotlin` rule packs copied to `~/.claude/rules/ecc/`. Was
  previously a ready-to-go plugin never installed via the plugin system; that's
  resolved. The `ECC-aesop` fork itself was 269 commits behind upstream (missed
  v2.2.0) — caught up clean, no conflicts, and a weekly upstream-sync GitHub
  Action was added so it doesn't drift again.
- **OpenWiki is built, linked, and confirmed working** (`openwiki --help` runs
  clean) — from the *correct* fork branch (`claude/wiki-quinn-npu-local-m1crql`,
  the one with the real NPU/voice commits), not the generic `main` it was
  mistakenly built from on the first pass this session. The `pnpm`-vs-`npm`
  ambiguity this file already flagged as a risk did materialize — `pnpm` isn't
  reachable from npm's own script runner on this device, so the build had to
  bypass the `prebuild` hook and invoke `tsc` from `node_modules` directly.
  `npm` is what actually works here; don't trust the `pnpm` lifecycle scripts.
- A large cross-repo cleanup happened this session — full detail in
  `~/novae-xorpus/unresolved.md`, not duplicated here. Short version: a
  previously-unknown 33-repo inventory under `~/repos/` was discovered (many of
  these were things this file's own "post-session targets" list treated as
  needing fresh installs — they were already cloned), 10 real forks were synced
  with their actual upstreams, and 4 redundant/outdated repos (`Novus-OpenBrain`,
  `OB1`, `SECOND-BRAIN`, `SuperClaude_Framework`) were identified for deletion —
  **that deletion is not yet confirmed done**; a safety gate blocked it from
  this session's tools and the command was handed to the operator to run
  directly. Verify before assuming it happened.
- A serious "is something still running unannounced" security concern was
  raised and fully investigated this session — resolved with a concrete answer,
  not a guess: no live cron job, scheduled task, rogue daemon, or unexpected
  installed app exists on this device. The real incident it was based on was
  found in `NovA-Corpus` (a now-superseded predecessor repo) — a session once
  reset `main` to an empty tree and substituted an incomplete 82-file partial
  without checking existing branches first; a later session caught it and
  restored the real 1300-file migration. It was a one-time, session-scoped
  mistake, already self-corrected in that repo's own history — not an ongoing
  process.

## Voice pipeline — status

Unchanged this session. Real-time engine (`voice-engine/scripts/live_voice_loop.py`
+ a fixed launcher, see the `aesop-voice-pipeline` skill) confirmed working
end-to-end via `--demo` (TTS -> speaker -> STT round-trip, text matched). Two real
bugs already fixed: Moonshine STT's ~10s hard input ceiling, and a two-part
PulseAudio/proot audio bridge issue. **Still not yet verified**: the live mic loop
itself (only `--demo` has been run) — confirm this before trusting it blind. The
LLM callback in `live_voice_loop.py` is still a hardcoded stub; wiring in a real
model is still unbuilt.

## Post-session targets, exact order — updated against what's actually done now

1. ~~Installation of OpenWiki~~ — **done this session** (see above). Still open:
   the OpenRouter API key + GLM-5.2 model wiring for actual use hasn't been
   exercised yet, only `--help`.
2. **Installation of DroidDesk** on phone + tablet — still not started on either
   device. Unchanged from before this session.
3. **Piping of the voice line** — still not touched. LLM callback stub, live mic
   verification: both still open.
4. ~~Installation of ECC~~ — **done this session** (see above, full config).
   **Pocock skills and honey-for-devs are still not installed** — honey-for-devs
   specifically needs an `upstream` remote identified before it can be synced
   the way the other 10 forks were.
5. **Grill session** (Pocock's grill-me skill) — not run yet, but real prep
   happened: the `d.drew.legrand@gmail.com` Drive folder `REPLITS_WORLD` (shared
   to this account this session) was found and partially processed. Real scope
   now known: ~25+ documents, most of them either duplicate raw chat-message
   fragments or a separate GCP credit-arbitrage side-project, not core
   architecture. Two authoritative documents identified as the actual
   reconciliation targets ("AESOP XI — GRILL SESSION MASTER DOCUMENT: Final
   Consolidated Version" and "AESOP XI Architecture Blueprint Update, v2.0").
   Two concrete contested claims already checked against real code and resolved:
   the planned model swap to Qwen 3.5 (0.8B/9B) was never actually executed —
   Gemma 4 12B is still the real running model per `termux-helper`; and OB1/
   OmniRoute's claimed Postgres backend contradicts the already-verified real
   SQLite implementation (`ARCHITECTURE.md` §10). Full reconciliation of the two
   master docs against code is still open — this is its own multi-hour task, not
   started beyond those two checks.
6. **On-device help desk** — not started.
7. **Salvaging the existing APK as a terminal daemon** — not started. See
   `~/novae-xorpus/unresolved.md` for the 6 already-merged remote commits
   (`aesopd` bridge daemon, `llamad`) directly relevant to this task.

Explicitly separate, deferred without a fixed slot: the HTTP/WebSocket server for
remote voice-engine invocation (still unbuilt). Full durable backlog — including
the dashboard-on-tablet SSH tunnel (given, unconfirmed working), the ECC
unified-memory-vault-vs-hand-built-#dumbass decision, and everything else — lives
in `~/novae-xorpus/unresolved.md`, not here.
