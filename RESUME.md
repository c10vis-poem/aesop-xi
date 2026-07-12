# AESOP — Session Resume / Handoff

Snapshot for continuing the build. Owner: c10vis-poem (nav@clovispoem.com).

## What this is
**AESOP** (Agentic Executions Split Operations Protocol) — a device-agnostic split
agent stack + personal knowledge-vault, running on Termux (Android phone) now, with
planned home nodes (Jetson Orin Nano 8GB, Rubik Pi / Dragonwing) and cloud (walled GCP,
OpenRouter GLM-5.2). Naming: **AESOP** = umbrella · **Omni-Claw** = device client
(the Novus-Agenti Kotlin app) · **Novus Agenti** = the agent protocol.

## Repos in play (all `c10vis-poem`; branch `claude/clone-wiki-obsidian-omni-6dtz7i`, except `aesop` = `main`)
- **aesop** — NEW umbrella repo. Spine pushed: `README.md`, `ARCHITECTURE.md`,
  `protocol/tiers.md`, `profiles/_example.yaml`, `profiles/nav.yaml` (his rig).
  4 subagents were writing `protocol/roles.md`, `protocol/memory.md`, `protocol/audit.md`,
  `deploy/README.md` — see below for status. **TODO: fold Graphify into `memory.md`
  as the graph-recall backend.**
- **openwiki** (fork) — target of the checkpointer PR (below). NOT started.
- **notebooklm-py, obsidian-skills, reasoning-bank, graphify, OmniRoute, claude-skills,
  tmux, termux-gui-bash, termux-packages** — all cloned in session.

## Device stack (Termux on phone) — STATUS
**DONE**
- OpenWiki = **upstream npm** `openwiki` (NOT the fork). Generates + updates the wiki
  cleanly. Output lives at `~/.openwiki/wiki`. Kill LangSmith 403 noise with:
  `export LANGCHAIN_TRACING_V2=false; export LANGSMITH_TRACING=false; unset LANGSMITH_API_KEY`
- Vault at `~/vault`. `~/.openwiki/wiki` symlinked to `~/vault/notes/novus-agenti`
  (live, self-updating). The Novus-Agenti wiki is in the vault.
- `notebooklm-py` 0.7.3 installed (pure-python, clean). NOT logged in.

**PENDING**
- **obsidian-skills** into vault (run in a SHELL, not inside the OpenWiki TUI):
  `git clone https://github.com/c10vis-poem/obsidian-skills ~/vault/.claude/skills/obsidian-skills`
- **notebooklm auth (no browser needed at runtime):** supports `NOTEBOOKLM_AUTH_JSON`
  env var and `--storage <storage_state.json>`. No fork needed. Get the cookies ONCE via
  proot + VNC desktop (Playwright's chromium runs on glibc in the proot):
  `proot-distro login debian` → `pip install "notebooklm-py[browser]" --break-system-packages`
  → `playwright install chromium` → `notebooklm login` (sign in on the XFCE/VNC screen) →
  copy `~/.notebooklm/` into Termux home. Runs headless thereafter.
- **Graphify** — native Termux install FAILS (tree-sitter grammars won't build on
  Python 3.14 / bionic). Install in proot:
  `proot-distro login debian --bind ~/vault:/root/vault` →
  `apt install -y python3-pip pipx && pipx ensurepath && export PATH=$PATH:~/.local/bin` →
  `pipx install graphifyy && graphify /root/vault`
- **STT/TTS (TOP PRIORITY — "huge help right now")** — sherpa-onnx (Silero VAD +
  Moonshine STT + Kokoro TTS). `pip install sherpa-onnx` fails on Termux (no cp314 wheel;
  manylinux/glibc wheels don't load on bionic). Two routes: (1) sherpa-onnx in the Debian
  proot (glibc → wheel installs) + PulseAudio bridge for mic/speaker; (2) **prebuilt
  Android/bionic sherpa-onnx binaries in Termux + `termux-api` audio (better — audio is
  the hard part).** OPEN: what's in `~/sherpa-kok*` and `~/kokoro` — built sherpa-onnx or
  just Kokoro model files? Answer decides finish-vs-start.

## Environment gotchas (why native builds fail on Termux)
- **Python 3.14 + Node 26 are too new** → no prebuilt wheels/prebuilds → source builds →
  fail on bionic libc. Reliable native compiles belong in the **Debian proot** (glibc).
  Hit by: better-sqlite3 (openwiki), tree-sitter (graphify), onnxruntime (sherpa).
- **VNC:** avoid `:1`/5901 (phone squats it). `:2`/5902 = portrait `600x1280`;
  `:3`/5903 = landscape `1280x600`. AVNC → `127.0.0.1:590X`. xstartup must be a plain
  shell script; vncserver options as flags, never `#` comments in `~/.vnc/config`.
- **proot:** `pkg install proot-distro` FIRST, then `proot-distro login debian` (prompt
  flips to `root@`). Debian pkgs are in `main` (no universe/multiverse — that's Ubuntu).

## AESOP design (full spec in ARCHITECTURE.md)
- **4 roles:** query/tool-exec (edge), executive (home→cloud), librarian/switchboard
  (home; the flywheel write-back), auditor/red (cloud, out-of-band).
- **3 memory types:** declarative (wiki markdown = source of truth), recall (OB1/Open
  Brain, Postgres+vector+MCP), strategic (reasoning-bank). **Graphify = 4th index:
  graph-recall.** Markdown canonical; all indexes derived/rebuildable.
- **Flywheel:** OpenWiki writes → notebooklm feeds → obsidian-skills operate → graphify
  indexes → all over one `~/vault`. Librarian distills learnings back through the audit
  gate → markdown → re-index.
- **Audit gate:** Tier0 read (free) · Tier1 reversible (self-audit) · Tier2
  irreversible/memory-commit (independent audit; edge → queue for reconnect).
- **reasoning-bank:** auditor = the autoeval judge; executor emits trajectory
  `{query,think_list,action_list}`, auditor-blind; verdict→reward→distilled strategy.
  Retrieval read-free (Tier0); distillation write-gated (Tier2). Swap
  `gemini-embedding-001` → local embedder for max-privacy.
- **Tiers:** edge/personal/home/cloud = capability classes (not devices); roles bind with
  fallback; profiles map hardware. `profiles/nav.yaml` = his 4-tier rig.
- **Omni-Claw WebView OAuth** = the device-native login (Android WebView + CookieManager →
  storage_state) for notebooklm/Claude/Gemini — one auth mechanism.

## Open decisions
- Auditor: in-stack-isolated vs strictly out-of-band (leaning cloud GLM-5.2).
- OpenWiki PR: MemorySaver fallback (safe, mergeable) vs node:sqlite saver (better,
  untestable in the cloud container).
- Recall + Strategic share one vector backend (namespaces) or stay separate?
- Home executive binds to Jetson vs phone Qwen (per profile).

## Immediate next actions
1. Commit any subagent-produced `aesop/protocol/*.md` + `deploy/README.md` (check
   `/workspace/aesop`); fold Graphify into `memory.md`.
2. Device: clone obsidian-skills into vault; do the notebooklm proot+VNC login.
3. **STT/TTS**: confirm contents of `~/sherpa-kok*` / `~/kokoro`, then install sherpa-onnx
   (proot or Android binaries) and wire `termux-api` audio.
4. OpenWiki fork: make the fallback checkpointer patch → open draft PR upstream (then
   `npm update -g openwiki` on device inherits the fix).
