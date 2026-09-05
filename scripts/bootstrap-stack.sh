#!/usr/bin/env bash
# aesop-xi's own orchestration bootstrap: everything that ISN'T a specific
# agent harness's own install (that's the harness dispatch below), plus
# picking which harness gets installed for this session/agent.
#
# aesop-xi owns this logic directly — it is not inherited from any harness's
# bootstrap script. ECC's own script (ECC-aesop/scripts/
# bootstrap-prime-agent-stack.sh) only installs ECC itself; it does not touch
# any of the assets below.
#
# Harness selection: no separate variable — whichever harness repo(s) are
# actually attached as siblings get installed, same convention as every
# other asset below (present = run, absent = skipped, not fatal). Attach
# ECC-aesop to get ECC; attach NovA-prime-agent to get Prime Agent; attach
# both to get both.
#
# Usage: bash scripts/bootstrap-stack.sh [base-dir]
#   base-dir defaults to the directory aesop-xi itself was cloned into — the
#   directory every sibling repo (ECC-aesop, NovA-prime-agent, NovA-skills,
#   etc.) is expected alongside. A repo not present in this session is
#   skipped, not fatal.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AESOP_ROOT="$(dirname "$SCRIPT_DIR")"
BASE_DIR="${1:-$(dirname "$AESOP_ROOT")}"

log() { echo "[bootstrap] $*"; }
skip() { echo "[bootstrap] skip: $* (not cloned in this session)"; }

sync_repo() {
  # Always pull from origin/main — every repo, every session, unless a
  # special one-off command overrides it. Resets the given dir to exactly
  # origin/main; no-op if it's not a git repo.
  local dir="$1"
  [ -d "$dir/.git" ] || return 0
  log "Syncing $(basename "$dir") to origin/main ..."
  git -C "$dir" fetch origin main 2>&1 | sed 's/^/  /' \
    && git -C "$dir" checkout -B main origin/main 2>&1 | sed 's/^/  /' \
    || log "sync to main failed for $(basename "$dir") — continuing with whatever's on disk"
}

# Known SHARED-ASSET sibling repos only, "<dir-name>:<github-slug>" — HTTPS,
# no auth needed, every one a public fork. Deliberately excludes harness
# repos (ECC-aesop, NovA-prime-agent, etc.): every agent benefits from these
# regardless of which harness it uses, so they auto-clone unconditionally.
# Harness repos stay opt-in (presence-based only, see section 1 below) --
# auto-cloning ECC-aesop here would install ECC for every agent every
# session, defeating "not every agent is going to use ECC".
KNOWN_SIBLINGS="
NovA-skills:c10vis-poem/NovA-skills
obsidian-skills:c10vis-poem/obsidian-skills
NoVa-reverse-skill:c10vis-poem/NoVa-reverse-skill
NovA-clean-my-ai-harness:c10vis-poem/NovA-clean-my-ai-harness
NoVa-honey-for-devs:c10vis-poem/NoVa-honey-for-devs
NovA-code-review-graph:c10vis-poem/NovA-code-review-graph
notebooklm-py:c10vis-poem/notebooklm-py
OmniRoute:c10vis-poem/OmniRoute
NovA-terrestrial-brain:c10vis-poem/NovA-terrestrial-brain
"

ensure_siblings_cloned() {
  local entry name slug dir
  for entry in $KNOWN_SIBLINGS; do
    name="${entry%%:*}"
    slug="${entry#*:}"
    dir="$BASE_DIR/$name"
    if [ ! -d "$dir/.git" ]; then
      log "Cloning $name (not present this session) ..."
      git clone --depth 1 "https://github.com/$slug.git" "$dir" 2>&1 | sed 's/^/  /' \
        || log "clone failed for $name — will skip its section below"
    fi
  done
}

# --- -1. Clone whatever sibling repos aren't already attached this session
ensure_siblings_cloned

# --- 0. Sync aesop-xi itself to origin/main before doing anything else ----
sync_repo "$AESOP_ROOT"

# --- 1. Harness install — presence-based, same as every other asset -------
if [ -x "$BASE_DIR/ECC-aesop/scripts/bootstrap-prime-agent-stack.sh" ]; then
  log "ECC-aesop attached — installing ECC ..."
  bash "$BASE_DIR/ECC-aesop/scripts/bootstrap-prime-agent-stack.sh" || log "ECC bootstrap failed — see output above"
else
  skip "ECC-aesop"
fi

if [ -d "$BASE_DIR/NovA-prime-agent" ]; then
  sync_repo "$BASE_DIR/NovA-prime-agent"
  log "NovA-prime-agent attached — building Prime Agent ..."
  (cd "$BASE_DIR/NovA-prime-agent" && npm install && npm run build) || log "Prime Agent build failed — see output above"
else
  skip "NovA-prime-agent"
fi

# --- 2. Skill repos: use each repo's own linker where it has one ----------
mkdir -p "$HOME/.claude/skills" "$HOME/.agents/skills"

if [ -d "$BASE_DIR/NovA-skills" ]; then
  sync_repo "$BASE_DIR/NovA-skills"
fi
if [ -x "$BASE_DIR/NovA-skills/scripts/link-skills.sh" ]; then
  log "Linking NovA-skills (repo's own script) ..."
  bash "$BASE_DIR/NovA-skills/scripts/link-skills.sh"
else
  skip "NovA-skills"
fi

link_flat_skills_dir() {
  # For repos with a skills/ dir but no linker script of their own.
  local repo="$1" src="$BASE_DIR/$1/skills"
  if [ ! -d "$src" ]; then skip "$repo"; return; fi
  sync_repo "$BASE_DIR/$repo"
  log "Linking skills from $repo ..."
  for d in "$src"/*/; do
    name="$(basename "$d")"
    for dest in "$HOME/.claude/skills" "$HOME/.agents/skills"; do
      target="$dest/$name"
      [ -e "$target" ] && [ ! -L "$target" ] && rm -rf "$target"
      ln -sfn "${d%/}" "$target"
    done
  done
}
link_flat_skills_dir "obsidian-skills"

if [ -d "$BASE_DIR/NoVa-reverse-skill" ]; then
  sync_repo "$BASE_DIR/NoVa-reverse-skill"
fi
if [ -f "$BASE_DIR/NoVa-reverse-skill/README_AI.md" ]; then
  log "NoVa-reverse-skill: refreshing tool index ..."
  bash "$BASE_DIR/NoVa-reverse-skill/skills/scripts/refresh-tool-index.sh" || log "tool-index refresh failed"
else
  skip "NoVa-reverse-skill"
fi

if [ -d "$BASE_DIR/NovA-clean-my-ai-harness" ]; then
  sync_repo "$BASE_DIR/NovA-clean-my-ai-harness"
fi
if [ -f "$BASE_DIR/NovA-clean-my-ai-harness/clean-my-ai-harness-claude.zip" ]; then
  log "Installing clean-my-ai-harness skill ..."
  rm -rf "$HOME/.claude/skills/clean-my-ai-harness"
  mkdir -p /tmp/cmah-bootstrap
  unzip -oq "$BASE_DIR/NovA-clean-my-ai-harness/clean-my-ai-harness-claude.zip" -d /tmp/cmah-bootstrap
  cp -r /tmp/cmah-bootstrap/claude-edition "$HOME/.claude/skills/clean-my-ai-harness"
else
  skip "NovA-clean-my-ai-harness"
fi

# --- 3. Honey: real plugin install, then symlink for same-session hot-load
if [ -d "$BASE_DIR/NoVa-honey-for-devs" ]; then
  sync_repo "$BASE_DIR/NoVa-honey-for-devs"
  log "Installing Honey ..."
  (cd "$BASE_DIR/NoVa-honey-for-devs" && node bin/install.js --only claude --yes) || log "Honey install failed"
  HONEY_CACHE=$(find "$HOME/.claude/plugins/cache/greenpt/honey" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort -V | tail -1)
  if [ -n "${HONEY_CACHE:-}" ]; then
    for d in "$HONEY_CACHE"/skills/*/; do
      name="$(basename "$d")"
      target="$HOME/.claude/skills/$name"
      [ -e "$target" ] && [ ! -L "$target" ] && rm -rf "$target"
      ln -sfn "${d%/}" "$target"
    done
  fi
else
  skip "NoVa-honey-for-devs"
fi

# --- 4. code-review-graph: install, build self, register+build for repos --
if [ -d "$BASE_DIR/NovA-code-review-graph" ]; then
  sync_repo "$BASE_DIR/NovA-code-review-graph"
  log "Installing code-review-graph ..."
  (cd "$BASE_DIR/NovA-code-review-graph" && uv sync) || log "code-review-graph install failed"
  CRG="$BASE_DIR/NovA-code-review-graph/.venv/bin/code-review-graph"
  if [ -x "$CRG" ]; then
    log "Building code-review-graph's own graph ..."
    (cd "$BASE_DIR/NovA-code-review-graph" && "$CRG" build) || true
    if [ -d "$BASE_DIR/NovA-terrestrial-brain" ]; then
      sync_repo "$BASE_DIR/NovA-terrestrial-brain"
      log "Registering + building graph for NovA-terrestrial-brain ..."
      "$CRG" register "$BASE_DIR/NovA-terrestrial-brain" || true
      (cd "$BASE_DIR/NovA-terrestrial-brain" && "$CRG" build) || true
    fi
    log "Registering + building graph for aesop-xi ..."
    "$CRG" register "$AESOP_ROOT" || true
    (cd "$AESOP_ROOT" && "$CRG" build) || true
  fi
else
  skip "NovA-code-review-graph"
fi

# --- 5. notebooklm-py: install deps, headless auth via master token -------
if [ -d "$BASE_DIR/notebooklm-py" ]; then
  sync_repo "$BASE_DIR/notebooklm-py"
  log "Installing notebooklm-py ..."
  (cd "$BASE_DIR/notebooklm-py" && uv sync --frozen --extra browser --extra dev --extra markdown --extra headless --extra mcp) || log "notebooklm-py install failed"

  if [ -n "${NOTEBOOKLM_MASTER_TOKEN_JSON:-}" ]; then
    log "notebooklm-py: materializing master token, re-minting cookies (headless, no browser) ..."
    NLM_PROFILE_DIR="$HOME/.notebooklm/profiles/default"
    mkdir -p "$NLM_PROFILE_DIR"
    printf '%s' "$NOTEBOOKLM_MASTER_TOKEN_JSON" > "$NLM_PROFILE_DIR/master_token.json"
    chmod 600 "$NLM_PROFILE_DIR/master_token.json"
    (cd "$BASE_DIR/notebooklm-py" && uv run notebooklm login --master-token-refresh) \
      || log "notebooklm-py: master-token re-mint failed — token may be revoked, needs a fresh bootstrap"
  else
    log "notebooklm-py: NOTEBOOKLM_MASTER_TOKEN_JSON not set — skipping headless auth, run 'notebooklm login' interactively once to bootstrap a master token"
  fi
else
  skip "notebooklm-py"
fi

# --- 6. OmniRoute: install + start dev server ------------------------------
if [ -d "$BASE_DIR/OmniRoute" ]; then
  sync_repo "$BASE_DIR/OmniRoute"
  log "Installing OmniRoute ..."
  (cd "$BASE_DIR/OmniRoute" && npm install) || log "OmniRoute install failed"
  log "Starting OmniRoute dev server (:20128) ..."
  nohup npm --prefix "$BASE_DIR/OmniRoute" run dev < /dev/null > "$BASE_DIR/OmniRoute/.bootstrap-dev.log" 2>&1 &
  disown
else
  skip "OmniRoute"
fi

# --- 7. NovA-terrestrial-brain: obsidian plugin + local MCP server --------
if [ -d "$BASE_DIR/NovA-terrestrial-brain" ]; then
  sync_repo "$BASE_DIR/NovA-terrestrial-brain"
  log "Installing + building terrestrial-brain obsidian plugin ..."
  (cd "$BASE_DIR/NovA-terrestrial-brain/obsidian-plugin" && npm install && npm run build) || log "obsidian-plugin build failed"
  log "Starting terrestrial-brain obsidian plugin dev watcher ..."
  nohup npm --prefix "$BASE_DIR/NovA-terrestrial-brain/obsidian-plugin" run dev < /dev/null > "$BASE_DIR/NovA-terrestrial-brain/obsidian-plugin/.bootstrap-dev.log" 2>&1 &
  disown
  if [ -x "$BASE_DIR/NovA-terrestrial-brain/local-mcp/setup.sh" ]; then
    log "Standing up terrestrial-brain's local Postgres-backed MCP server ..."
    bash "$BASE_DIR/NovA-terrestrial-brain/local-mcp/setup.sh" || log "terrestrial-brain local MCP setup failed"
  fi
else
  skip "NovA-terrestrial-brain"
fi

cat <<'EOF'

[bootstrap] aesop-xi orchestration done. Harness install status is above —
each harness installs iff its repo was attached this session. Shared assets
below are attempted regardless of which harness(es) are attached:
  - skills: NovA-skills, obsidian-skills, NoVa-reverse-skill, clean-my-ai-harness
  - Honey, code-review-graph, notebooklm-py, OmniRoute, terrestrial-brain
Any repo not cloned in this session was skipped, not fatal — see the
[bootstrap] lines above for what actually ran vs. was skipped.
EOF
