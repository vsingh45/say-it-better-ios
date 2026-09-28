#!/bin/bash
# Stops and removes the launchd service installed by install.sh.
set -euo pipefail

PLIST_DEST="$HOME/Library/LaunchAgents/com.sayitbetter.backend.plist"

if [[ -f "$PLIST_DEST" ]]; then
  launchctl unload "$PLIST_DEST" 2>/dev/null || true
  rm "$PLIST_DEST"
  echo "Stopped and removed $PLIST_DEST."
else
  echo "Nothing installed at $PLIST_DEST."
fi
