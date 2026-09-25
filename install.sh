#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
LABEL="com.justcallmebryan.gigi"
BIN="$ROOT/bin/gigi"
APP_SRC="$ROOT/app/GiGi.app"
APP_DST="/Applications/GiGi.app"
CONFIG_DIR="$HOME/.config/gigi"
CONFIG="$CONFIG_DIR/config.json"
LOG_DIR="$HOME/Library/Logs/GiGi"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

"$ROOT/build.sh"

mkdir -p "$CONFIG_DIR" "$LOG_DIR"
if [ ! -f "$CONFIG" ]; then
  cp "$ROOT/config.example.json" "$CONFIG"
  echo "created $CONFIG (edit it, then use 'Reload config' or 'gigi reload')"
fi

for stale in "$HOME/Library/LaunchAgents"/*.gigi.plist; do
  [ -e "$stale" ] || continue
  [ "$(basename "$stale")" = "$LABEL.plist" ] && continue
  launchctl bootout "gui/$(id -u)/$(basename "$stale" .plist)" 2>/dev/null || true
  rm -f "$stale"
  echo "removed the stale agent $(basename "$stale")"
done

if [ "${1:-}" = "--app" ]; then
  echo "==> installing the menu bar app to $APP_DST"
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  rm -f "$PLIST"
  rm -rf "$APP_DST"
  cp -R "$APP_SRC" "$APP_DST"
  codesign --force --sign - --identifier "$LABEL" "$APP_DST" >/dev/null 2>&1 || true
  open "$APP_DST" || true

  cat <<MSG

app installed and opened: $APP_DST
log:                      $LOG_DIR/app.log

ONE-TIME STEP: grant Accessibility to the app
  System Settings > Privacy & Security > Accessibility
  enable "GiGi" (the app opens that pane from its menu).
  Without it the display stays awake but the cursor never moves.

CLI control of the same app (over IPC):
  $BIN status | start | stop | toggle | jiggle | menu
  $BIN until 18:00 | duration 240 | reload | quit-app
MSG
  exit 0
fi

cat > "$PLIST" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$BIN</string>
        <string>run</string>
        <string>--config</string>
        <string>$CONFIG</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    <key>ProcessType</key>
    <string>Background</string>
    <key>StandardOutPath</key>
    <string>$LOG_DIR/out.log</string>
    <key>StandardErrorPath</key>
    <string>$LOG_DIR/err.log</string>
</dict>
</plist>
PLIST_EOF

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
launchctl enable "gui/$(id -u)/$LABEL" 2>/dev/null || true

cat <<MSG

daemon installed: $PLIST
log:              $LOG_DIR/out.log   (tail -f)

ONE-TIME STEP: grant Accessibility to the binary
  System Settings > Privacy & Security > Accessibility > "+"
  press Cmd+Shift+G and paste:
      $ROOT/bin
  then pick "gigi".
  Without it the display stays awake but the cursor never moves.

control:
  launchctl kickstart -k gui/$(id -u)/$LABEL
  launchctl bootout   gui/$(id -u)/$LABEL
  tail -f $LOG_DIR/out.log
MSG
