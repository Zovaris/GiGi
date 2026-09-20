#!/usr/bin/env bash
set -euo pipefail

LABEL="com.codebuff.gigi"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
APP_DST="/Applications/GiGi.app"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
if [ -f "$PLIST" ]; then
  rm "$PLIST"
  echo "removed $PLIST"
else
  echo "no LaunchAgent was installed"
fi

if [ -d "$APP_DST" ]; then
  echo "app bundle left in place: $APP_DST (delete it manually if you want)"
fi

echo "check System Settings > General > Login Items for leftover entries"
