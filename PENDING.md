# PENDING.md — aesop-xi

Durable cross-session backlog. Not rewritten each session — items persist until resolved or explicitly dropped. See `unresolved.md` for the older version of this convention; this file supersedes it going forward.

- **Orphaned `Novus-Agenti/` nested checkout.** Not a registered git submodule (no `.gitmodules`), just a dirty embedded `.git` sitting in the tree. Duplicates content that also lives in the standalone `horizons-ui` repo and in `raw-databank`'s salvage. Resolve once the new standalone Horizons UI repo is built (2026-09-15 decision) — likely just delete this once confirmed redundant.
- **ECC plugin never installed** (`~/repos/ECC-aesop`) — ready-to-go `.claude-plugin/plugin.json`, confirmed via `~/.claude/plugins/installed_plugins.json` it's not active. Deferred, no urgency flagged yet.
