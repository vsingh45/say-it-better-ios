#!/bin/bash
# Installs the Say It Better backend as a launchd user service: it starts automatically when you
# log in to your Mac and restarts itself if it ever crashes, so you don't have to keep a terminal
# open or remember to start it before using the app.
#
# Usage (run once, from the backend/ directory):
#   ./launchd/install.sh
#
# Prerequisites: you've already run `pip install -r requirements.txt` in a venv (see ../README.md)
# and have a Claude Code OAuth token from `claude setup-token`.

set -euo pipefail

BACKEND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLIST_SRC="$BACKEND_DIR/launchd/com.sayitbetter.backend.plist"
PLIST_DEST="$HOME/Library/LaunchAgents/com.sayitbetter.backend.plist"
PYTHON_BIN="$BACKEND_DIR/.venv/bin/python3"
LABEL="com.sayitbetter.backend"

if [[ ! -x "$PYTHON_BIN" ]]; then
  echo "error: $PYTHON_BIN not found." >&2
  echo "Run this first, from the backend/ directory:" >&2
  echo "  python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt" >&2
  exit 1
fi

if [[ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]]; then
  echo "error: CLAUDE_CODE_OAUTH_TOKEN is not set." >&2
  echo "Run 'claude setup-token', then re-run this script as:" >&2
  echo "  CLAUDE_CODE_OAUTH_TOKEN=<token> ./launchd/install.sh" >&2
  exit 1
fi

mkdir -p "$HOME/Library/LaunchAgents"

sed \
  -e "s#__BACKEND_DIR__#$BACKEND_DIR#g" \
  -e "s#__PYTHON__#$PYTHON_BIN#g" \
  -e "s#__OAUTH_TOKEN__#$CLAUDE_CODE_OAUTH_TOKEN#g" \
  "$PLIST_SRC" > "$PLIST_DEST"

# Reload in case it's already installed (e.g. re-running after a token refresh).
launchctl unload "$PLIST_DEST" 2>/dev/null || true
launchctl load "$PLIST_DEST"

echo "Installed and started. It will now start automatically at login."
echo
echo "Check it:      curl http://localhost:8765/health"
echo "View logs:     tail -f $BACKEND_DIR/launchd/backend.log"
echo "Stop it:       launchctl unload $PLIST_DEST"
echo "Uninstall:     ./launchd/uninstall.sh"
