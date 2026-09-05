#!/bin/bash
# Auto-bootstrap aesop-xi's own orchestration stack on every fresh cloud
# session opened here. aesop-xi owns this logic directly (scripts/
# bootstrap-stack.sh) — it does not reach into any harness's own bootstrap
# script. Which agent harness(es) get installed is decided purely by which
# harness repo(s) (ECC-aesop, NovA-prime-agent) are attached as siblings this
# session — no separate variable to set.
set -uo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

echo '{"async": true, "asyncTimeout": 590000}'

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SCRIPT="$PROJECT_DIR/scripts/bootstrap-stack.sh"
LOG="$PROJECT_DIR/.session-start-bootstrap.log"

if [ -x "$SCRIPT" ]; then
  bash "$SCRIPT" >> "$LOG" 2>&1
else
  echo "[bootstrap] skip: $SCRIPT not found" >> "$LOG" 2>&1
fi
