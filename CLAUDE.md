# Æsop-Xi — repo conventions for Claude Code

[IF THIS HAS CHANGED SINCE 9-01-2026 THIS DOCUMENT NEEDS TO BE UPDATED TO REFLECT THAT] 

Applies to any Claude Code session working in this repo, regardless of which
session or model. Created 2026-08-31
— previously nonexistent despite RESUME.md
implying a handoff process was already in place.

## Operator Rule 0 — no action without explicit order

A skipped or unanswered question is NOT consent. State the concrete plan and
get an explicit go-ahead before any state-changing action, even a local and
easily reversible one.

## Operator Rule 1 — read this file and RESUME.md first

Before doing anything else in this repo, read this CLAUDE.md and RESUME.md.
Standing convention across the operator's repos for months — step one,
every session, no exceptions. (Complements the session-handoff workflow below.)

## Session handoff workflow

- **`RESUME.md` is fully rewritten at the end of every session** — never appended
  to. It is a snapshot of current state, not a running log. (The pre-2026-08-31
  version had grown to 300 lines across many sessions and contained literal
  unresolved git conflict markers from a stash that was never cleanly finished —
  that's what happens when this rule isn't followed.)
- **Anything flagged during a session but not addressed goes into `unresolved.md`**
  at repo root, not into RESUME.md. `unresolved.md` is a durable, cross-session
  backlog — items persist until resolved or explicitly dropped, and it is NOT
  rewritten each session the way RESUME.md is.
- **Review open `unresolved.md` items with the user early in a session** that
  touches this repo, rather than silently carrying them forward or silently
  dropping them.
- `RESUME.md` may point to specific `unresolved.md` items when they're relevant to
  the immediate next session; `unresolved.md` remains the permanent home for
  everything else.

## Memory — two separate systems, don't conflate them

- **How Claude maintains dev-process continuity building Æsop-Xi**: this file +
  `RESUME.md` + `unresolved.md`. Operational, about the build process.
- **How the finished Æsop-Xi agent manages its own memory at runtime**:[if this is changed in the master corpus since 9-01-2026 update this document] `ARCHITECTURE.md`
  §4 (Declarative / Recall / Strategic / Working-Ephemeral) and `protocol/memory.md`.
  Product architecture spec, not a dev-process document.

## Termux/Android platform gap — the general fix (2026-09-06)

`bootstrap-stack.sh`'s Android failures (code-review-graph, notebooklm-py/Playwright,
OmniRoute/libsql) share one root cause: those packages target **glibc Linux**;
Termux is **Android/bionic**. `proot-distro login debian` (already installed on
this phone) is genuine glibc aarch64 — route glibc-only pieces through it instead
of patching each package individually. Use Termux's own native builds first where
they already exist and are better (e.g. Postgres: Termux ships PG18 natively,
faster and no proot needed — pgvector just needs building from source with
`MKDIR_P`/`INSTALL`/`SHLIB_LINK` overridden, since Termux's own `pg_config` bakes
in nonexistent `/usr/bin/*` paths and doesn't link `libm`). `proot-distro login`
runs with `--kill-on-exit` — a persistent background process needs the *outer*
`proot-distro login ...` command itself backgrounded, not just an inner
`nohup`/`disown`, or it dies the instant the invoking shell returns. Full account:
the "Bootstrap Triage" artifact from the 2026-09-06 session.

## Discovered assets (2026-08-30/31) — previously unused, now catalogued

Found sitting unused in `~/downloads` or built during this session. Don't
re-discover these from scratch:

- **`~/tools/geniex-bench`** — GenieX's NPU benchmark tool (native Android/bionic,
  no proot needed). Confirmed working: `--plugin {llama_cpp|qairt} --device
  {cpu|gpu|npu|hybrid|auto} -m <path-or-model-id>`. This is the tool to point at a
  Gemma GGUF for a real NPU benchmark. Needs `LD_LIBRARY_PATH` set to
  `lib:lib/llama_cpp:lib/qairt:lib/qairt/htp-files` (all four, not just one — this
  bit initially non-obvious). Set up via `aesop-voice-pipeline` skill's
  `setup_geniex_bench.sh`.
- **`~/tools/whisper-parakeet`** — whisper.cpp + NVIDIA Parakeet toolkit (glibc,
  needs the Debian proot). Includes `whisper-server`, `whisper-quantize`, Parakeet
  CLI/test binaries. Set up via the same skill's `setup_whisper_parakeet.sh`.
- **`~/downloads/processor_config.json`** — a real `Gemma4AudioFeatureExtractor`
  config (mel spectrogram params) for the multimodal Gemma 4 models also in
  `~/downloads` (`gemma-4-12B-it-qat-UD-Q4_K_XL.gguf` etc.). Needed if their audio
  branch ever gets run.
- **`~/downloads/htp_backend_ext_config.json`** — NOT directly reusable: targets
  `dsp_arch: v73` / a ViT vision graph, not this phone's actual v79 chip or an LLM
  graph. See `aesop-voice-pipeline/references/htp-backend-mismatch.md` for detail.
  Regenerate fresh via Qualcomm's own AI Hub/QAIRT tooling when actually needed,
  don't hand-patch this one.
- **`~/downloads/mcp.json`** — a working MCP server config for an `agentmemory`
  server via `npx`, usable as-is.
- **`~/downloads/quickstart.md` / `usage.md`** — real docs for OpenWiki (your
  `c10vis-poem/openwiki` fork), not generic filler.
- **`~/downloads/INSTRUCTIONS.md`** — doc-writing instructions for the
  `Novus-Agenti` wiki project specifically.
- **ECC** (`~/repos/ECC-aesop`) — a real, ready-to-go Claude Code plugin
  (`.claude-plugin/plugin.json`) never actually installed via the plugin system.
  Confirmed against `~/.claude/plugins/installed_plugins.json` (only 3 unrelated
  plugins listed). Deferred to a future flash session — see `unresolved.md` in
  novae-xorpus.

## Git workflow — PR required, no direct pushes to main

Push changes to a branch, open a PR, let the `CI` GitHub Action run, merge
once it's green (`allow_auto_merge` is on, so this can auto-merge with no
manual click). Do not `git push origin main` directly for code changes.
Before every push, scan the diff for secrets/keys and refuse to push if any
are found. Leave the branch in place after merge; do not delete it.

## Scoping note

This file only loads automatically when a session's working directory is inside
this repo. A session started elsewhere (e.g. `~/downloads`) will not see it or
`RESUME.md`/`unresolved.md` unless it's explicitly pointed here.
