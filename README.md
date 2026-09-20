<h1 align="center">GiGi</h1>

<p align="center">
  <img src="./assets/brand/gigi-icon.png" alt="GiGi" width="112" height="112" />
</p>

<p align="center">
  <strong>Keeps your Mac awake, and keeps it looking busy.</strong><br />
  A native macOS menu bar app and CLI for scheduled display assertions and small cursor movements.
</p>

<p align="center">
  <a href="#install">Install</a>
  ·
  <a href="#usage">Usage</a>
  ·
  <a href="#configuration">Configuration</a>
</p>

---

GiGi keeps the display awake without changing global power settings. When Accessibility is
enabled, it also sends a small cursor movement after a configurable period of inactivity. Both
features share the same Swift engine and schedule.

## Install

Requires macOS 13+ and Xcode Command Line Tools.

```bash
./build.sh              # creates bin/gigi and app/GiGi.app
./install.sh --app      # installs and opens the menu bar app
./install.sh            # installs the CLI as a LaunchAgent
```

Grant Accessibility to `GiGi.app` or `bin/gigi`, depending on which one you use:

**System Settings → Privacy & Security → Accessibility**

The LaunchAgent logs to `~/Library/Logs/GiGi/`. The app and daemon should not run together;
the CLI prevents duplicate engines unless `--force` is used.

## Usage

Click GiGi in the menu bar to open its control panel. The main switch starts or stops
cursor movement and display wakefulness. Choose **No limit**, a duration, or an end time;
the selection is remembered for the next session. Confirm edited minutes or an end time with **Apply timer**; presets apply immediately.
Changing the timer during a session updates its deadline. When the timer expires, GiGi stays off, including after relaunch.

The panel also includes display, schedule mode, Accessibility, and login controls.
**Movement** and **Settings** open as drawers that slide over the panel, so the list keeps a
fixed size instead of growing and pushing the footer around. The drawer header repeats the
section name and closes with the ✕, the Escape key, or the *Movement*/*Settings* row closing
behind it. Right-click the menu bar icon for the original command menu and recent activity.

The **Movement** drawer sets how long GiGi waits for you to go idle and how often it moves;
**Apply movement** writes both back to the JSON configuration and applies them immediately.
The **Settings** drawer holds Start at login, display wakefulness, the global **Shortcut**,
Language, Appearance, Open log and, under **Advanced**, reload and open the configuration
folder. Schedule windows remain configurable in the JSON file. The **Shortcut** row in there
records a global key combination that turns GiGi on and off from any app; press Delete while
recording to disable it, or Escape to keep the current one.

**Clicks** and **Scroll** add a synthetic click or scroll to every move, which keeps presence
services happy when a 2px cursor nudge is not enough. Both are off by default, and both land
wherever the pointer happens to be: a click really does click, and a scroll really does scroll.
The `ping` scroll mode moves one line down and one line up, so the content ends up where it
started.


```bash
./bin/gigi help
./bin/gigi run                 # run until stopped
./bin/gigi once                # send one movement
./bin/gigi probe               # show diagnostics
./bin/gigi probe --test        # test the idle timer reset
```

When the menu bar app is running, the CLI can control it:

```bash
./bin/gigi status
./bin/gigi start | stop | toggle | jiggle
./bin/gigi duration 240
./bin/gigi until 18:00
./bin/gigi reload
./bin/gigi panel               # open the control panel
./bin/gigi panel movement      # open the panel on a drawer: movement | settings
./bin/gigi quit-app
```

Useful options for `run`, `once`, and `probe`:

```text
--config PATH             config file (default ~/.config/gigi/config.json)
--interval-min SECONDS    minimum delay between movements
--interval-max SECONDS    maximum delay between movements
--distance PIXELS         cursor movement distance
--idle-threshold SECONDS  minimum idle time before moving
--until HH:MM             stop at a time
--duration MINUTES        stop after a duration
--click MODE              extra click per move: none|single|double|right
--scroll MODE             extra scroll per move: none|ping|down|up
--no-assert               do not keep the display awake
--ignore-schedule         ignore schedule windows
--force                   run while the app is open
```

## Configuration

The default file is `~/.config/gigi/config.json`. `./install.sh` creates it from
[`config.example.json`](config.example.json).

```json
{
  "intervalSeconds": [45, 90],
  "idleThresholdSeconds": 40,
  "jiggleDistancePixels": 2,
  "preventDisplaySleep": true,
  "wakeDisplayOnWindowStart": true,
  "clickMode": "none",
  "scrollMode": "none",
  "hotkey": "ctrl+cmd+j",
  "schedule": {
    "enabled": true,
    "days": ["mon", "tue", "wed", "thu", "fri"],
    "windows": [{ "start": "09:00", "end": "18:00" }]
  }
}
```

`clickMode` accepts `none`, `single`, `double`, and `right`; `scrollMode` accepts `none`, `ping`,
`down`, and `up`; `hotkey` is a combination such as `ctrl+cmd+j`, `opt+shift+f9`, or `none`. Keys
can be letters, digits, `space`, `tab`, `return`, `delete`, the four arrows, and `f1`–`f12`.
Missing keys fall back to their defaults, so an older config file keeps working.

Windows can cross midnight, for example `{ "start": "22:00", "end": "06:00" }`. Reload the
app with `./bin/gigi reload`; restart the LaunchAgent after editing its config.

## Architecture

- `Sources/Core`: engine, schedule, power assertion, cursor events, IPC, and logging.
- `Sources/app`: AppKit menu bar and SwiftUI control panel.
- `Sources/cli`: CLI and LaunchAgent frontend.
- `Resources`: bundle metadata, icon, and localizations.

The menu bar app exposes `CFMessagePort` as `com.codebuff.gigi.control` for CLI control.

## Limits

Accessibility may be blocked by macOS or MDM. A locked Mac can prevent synthetic cursor events,
and presence services may use signals beyond the local idle timer. Keeping the display awake also
uses battery. Click and scroll modes fire wherever the pointer is, so leave them off unless you
need them, and prefer `ping` over `down` or `up`.

```bash
./uninstall.sh            # removes the LaunchAgent; keeps app, config, and logs
```

---

<p align="center"><sub>Native Swift macOS utility</sub></p>
