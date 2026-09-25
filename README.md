# GiGi

<p align="center">
  <img src="./assets/brand/gigi-icon.png" alt="GiGi" width="112" height="112" />
</p>

<p align="center">
  <strong>Keeps your Mac awake, and keeps it looking busy.</strong><br />
  A native macOS menu bar app and CLI for scheduled display assertions and small cursor movements.
</p>

GiGi keeps the display awake without changing global power settings. When Accessibility is
enabled, it can also move the cursor after a period of inactivity. The menu bar app and CLI use
the same Swift engine and configuration.

## Requirements

- macOS 13 or later
- Xcode Command Line Tools, when building from source
- Accessibility permission for `GiGi.app` or `bin/gigi`

## Install

Install the latest release with Homebrew:

```bash
brew install --cask sthbryan/tap/gigi
```

Or build and install locally:

```bash
./build.sh
./install.sh --app    # menu bar app
./install.sh          # CLI as a LaunchAgent
```

Grant permission in **System Settings > Privacy & Security > Accessibility**. Do not run the app
and LaunchAgent at the same time; the CLI prevents duplicate engines unless `--force` is used.

Downloaded app bundles may be quarantined by macOS. Open the app once from Finder, or remove the
attribute manually:

```bash
xattr -dr com.apple.quarantine GiGi.app
```

## Use

Click the menu bar icon to open the control panel. Start GiGi, then choose a timer, schedule, or
**Always** mode. The panel also controls cursor movement, display wakefulness, dimming, the keyboard
backlight, battery limits, notifications, updates, the global shortcut, and optional click or
scroll events.

The CLI can control a running app:

```bash
./bin/gigi status
./bin/gigi start
./bin/gigi stop
./bin/gigi toggle
./bin/gigi jiggle
./bin/gigi duration 240
./bin/gigi until 18:00
./bin/gigi panel
```

Run the engine directly when the app is not open:

```bash
./bin/gigi run                 # run until stopped
./bin/gigi once                # move once
./bin/gigi probe               # show diagnostics
./bin/gigi update              # check the latest release
./bin/gigi help
```

## Configuration

The default configuration file is `~/.config/gigi/config.json`. A starter file is provided in
[`config.example.json`](config.example.json). The most useful settings are:

```json
{
  "intervalSeconds": [45, 90],
  "idleThresholdSeconds": 40,
  "jiggleDistancePixels": 2,
  "motionPattern": "jiggle",
  "motionRadiusPixels": 40,
  "preventDisplaySleep": true,
  "dimWhileActive": false,
  "dimBrightness": 0.35,
  "turnOffKeyboardLight": false,
  "batteryLimitEnabled": false,
  "batteryLimitPercent": 20,
  "hotkey": "ctrl+cmd+j",
  "schedule": {
    "enabled": true,
    "days": ["mon", "tue", "wed", "thu", "fri"],
    "windows": [{ "start": "09:00", "end": "18:00" }]
  }
}
```

Patterns are `jiggle`, `circle`, `square`, and `figureEight`. Schedule windows may cross midnight.
The app edits its configuration when you change settings in the panel; after editing the file by
hand, reload the app or restart the LaunchAgent:

```bash
./bin/gigi reload
```

## Build and test

```bash
make build       # build bin/gigi and app/GiGi.app
make test        # compile and run tests
make strings     # validate metadata and localizations
make check       # build, test, and lint
make icon        # redraw the app icon
```

## Logs and limits

The LaunchAgent logs to `~/Library/Logs/GiGi/`; the app log is `~/Library/Logs/GiGi/app.log`.
Synthetic cursor events require Accessibility and may be blocked on a locked Mac or by MDM.
Click and scroll modes act wherever the pointer is. Dimming uses a private macOS framework and
may not work with external displays or after a macOS update. Turning off the keyboard light does
too, and it only applies to Macs with a backlit keyboard: the panel disables the switch when there
is no keyboard to control. `gigi probe` reports whether both are controllable on this Mac.

## License

GiGi is licensed under the GNU General Public License, version 3 or any later version. See
[`LICENSE`](LICENSE).