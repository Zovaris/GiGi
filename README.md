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

```bash
make build      # the same as ./build.sh
make test       # compile and run the test harness
make strings    # lint the Info.plist and the localization tables
make check      # build, test and lint: what CI runs on every pull request
make icon       # redraw Resources/GiGi.icns
```

## Usage

Click GiGi in the menu bar to open its control panel. The main switch starts or stops
cursor movement and display wakefulness. Choose **No limit**, a duration, or an end time;
the selection is remembered for the next session. Duration and end-time menu selections apply immediately, just like schedule hours.
The timer keeps a stable height when switching to **No limit** to avoid resizing the popover.
Changing the timer during a session updates its deadline. When the timer expires, GiGi stays off, including after relaunch.

The panel also includes display, schedule mode, Accessibility, and login controls. The **Schedule**
card turns schedule windows on with its own switch and sets the window with **From** and **To**
hour and minute pickers plus a **Repeat** row of day chips, so the days and the hours no longer
need the JSON file. Adjusting any of them applies immediately and rewrites the configuration.
The same card includes a compact **Timer** menu and **Mode** selector. Enabling **Schedule**
sets Timer to **No limit** and clears any active deadline. Choosing **For** or **Until** turns
Schedule off; its hours and weekdays are preserved. **Mode** set to **Always** overrides the
window at runtime: the hours stay editable and the card says the window is being ignored, so the
schedule takes effect again as soon as Mode returns to **Schedule**. The choice lives in the app,
not in the configuration file, and `--ignore-schedule` does the same for `gigi run`.
**Battery limit** stops GiGi when the internal battery reaches the selected percentage (or lower),
only while running on battery power. It defaults to off, and the panel offers 5% to 50% in steps
of five; the configuration
file accepts anything between 1% and 100%, and a threshold written there keeps showing in the
panel. It works with
Timer, Schedule, and Always mode. It clears the session deadline and stays stopped until
you start GiGi again; it never shuts down the Mac. Missing battery readings and AC power do
not stop the session.

**Movement** and **Settings** open as drawers that slide over the panel, so the list keeps a
fixed size instead of growing and pushing the footer around. The drawer header repeats the
section name and closes with the ✕, the Escape key, or the *Movement*/*Settings* row closing
behind it. Right-click the menu bar icon for the original command menu and recent activity.

The **Movement** drawer sets how long GiGi waits for you to go idle and how often it moves;
**Apply movement** writes both back to the JSON configuration and applies them immediately.
The **Settings** drawer holds Start at login, display wakefulness and dimming, the global
**Shortcut**, Language, Appearance, Open log and, under **Advanced**, reload and open the
configuration folder. The **Shortcut** row in there
records a global key combination that turns GiGi on and off from any app; press Delete while
recording to disable it, or Escape to keep the current one.

**Dim the display** lowers the screen brightness while GiGi keeps it awake, which saves power
and is easier on the eyes during long unattended runs. The row has its own switch and a slider
from 5% to 100%; dragging the slider dims the screen as you move it and writes the configuration
once you let go. Brightness returns to the value it had before as soon as GiGi stops or the
switch goes off, and a brightness you change by hand during a run is left alone. Dimming needs
**Keep display awake**, since a display macOS is allowed to sleep is already dark, so the switch
stays disabled until that row is on.

**Notifications** tells you when GiGi stops on its own: the timer running out, the battery limit,
or the missing Accessibility permission that keeps the cursor still while the display stays awake.
The row in the **Settings** drawer has its own switch, and macOS asks for permission the first time
it is on. If you deny it, the row says **Blocked in System Settings** instead of promising a banner
it cannot show. Turning GiGi off yourself posts nothing, and a notice is raised once per session,
so a missing permission does not nag on every move.

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
--dim LEVEL               dim the display to LEVEL while active (0.05-1, or 5-100)
--no-dim                  keep the display at full brightness
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
  "dimWhileActive": false,
  "dimBrightness": 0.35,
  "notificationsEnabled": true,
  "hotkey": "ctrl+cmd+j",
  "schedule": {
    "enabled": true,
    "days": ["mon", "tue", "wed", "thu", "fri"],
    "windows": [{ "start": "09:00", "end": "18:00" }]
  }
}
```

`clickMode` accepts `none`, `single`, `double`, and `right`; `scrollMode` accepts `none`, `ping`,
`down`, and `up`; `dimBrightness` is a level between `0.05` and `1`; `notificationsEnabled`
turns the system notifications off without touching the rest; `hotkey` is a combination
such as `ctrl+cmd+j`, `opt+shift+f9`, or `none`. Keys
can be letters, digits, `space`, `tab`, `return`, `delete`, the four arrows, and `f1`–`f12`.
Missing keys fall back to their defaults, so an older config file keeps working.

Windows can cross midnight, for example `{ "start": "22:00", "end": "06:00" }`. The panel edits
the first window and keeps any others, showing a note when the file holds more than one. Reload
the app with `./bin/gigi reload`; restart the LaunchAgent after editing its config.

## Releasing

`Resources/Info.plist` holds the version, and `make version` raises it, writes the matching
[`CHANGELOG.md`](CHANGELOG.md) section, commits, tags `vX.Y.Z` and pushes both, so the tag always
carries the version the app reports:

```bash
make version                 # patch: 0.2.0 -> 0.2.1
make version BUMP=minor      # minor: -> 0.3.0
make version BUMP=major      # breaking: -> 1.0.0
make version VERSION=3.0.0   # pick the number yourself
make version DRY=1           # print the plan and the new section, change nothing
make version NO_PUSH=1       # commit and tag locally only
```

The changelog entry groups the commits since the last tag into **Added**, **Fixed** and
**Changed** from their `feat`, `fix` and `perf`/`refactor`/`revert` prefixes, and titles are
capitalized. Review it with `make version DRY=1` before you cut the release.

The release workflow runs on the tag: it checks the tag against the Info.plist, runs `make check`,
builds, packages `GiGi-<version>-macos-<arch>.zip` next to its SHA-256, verifies the signature of
the bundle inside the archive and publishes the GitHub release with the `CHANGELOG.md` section for
that version as its notes. The bundle is ad-hoc signed, so Gatekeeper asks for a right-click →
**Open** the first time.

## Architecture

- `Sources/Core`: engine, schedule, power assertion, cursor events, brightness, notices, IPC, and logging.
- `Tests`: the harness that `make test` compiles against the core.
- `tools`: the icon generator, the localization lint and the release script.
- `Sources/app`: AppKit menu bar and SwiftUI control panel.
- `Sources/cli`: CLI and LaunchAgent frontend.
- `Resources`: bundle metadata, icon, and localizations.

The menu bar app exposes `CFMessagePort` as `com.codebuff.gigi.control` for CLI control.

## Limits

Accessibility may be blocked by macOS or MDM. A locked Mac can prevent synthetic cursor events,
and presence services may use signals beyond the local idle timer. Keeping the display awake also
uses battery. Click and scroll modes fire wherever the pointer is, so leave them off unless you
need them, and prefer `ping` over `down` or `up`. Dimming drives the real backlight through a
private framework, so it can stop working after a macOS update; `./bin/gigi probe` reports whether
the display allows brightness control. External displays often do not. Notifications are delivered
by the system, so a Focus mode or a notification style set to *None* can hide a banner that GiGi
did post; `~/Library/Logs/GiGi/app.log` records every one it hands over.

```bash
./uninstall.sh            # removes the LaunchAgent; keeps app, config, and logs
```

---

<p align="center"><sub>Native Swift macOS utility</sub></p>
