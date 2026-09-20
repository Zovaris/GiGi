<h1 align="center">GiGi</h1>
<p align="center">
<img src="./assets/brand/gigi-icon.png" alt="GiGi" width="112" height="112" />
</p>
<p align="center">
<strong>Keeps the Mac awake, and keeps it looking busy.</strong>
</p>
<p align="center">
Two different signals keep a Mac alive: the display sleep assertion, and real input events.<br />
GiGi handles both, on a schedule you set.<br />
A menu bar app and a CLI over one shared engine.
</p>
<p align="center">
<a href="#get-it">Get it</a>
·
<a href="#what-it-actually-does">What it does</a>
·
<a href="#architecture">Architecture</a>
</p>
---
GiGi holds a power assertion so the display never sleeps on idle. It also posts real HID cursor
events, which is the only way to reset the idle timer that Slack, Teams and Zoom read.
Nothing moves while you are typing. Outside your schedule windows, GiGi releases the assertion and
the Mac sleeps normally.
---
## What it actually does
**Two signals, not one**
`IOPMAssertionCreateWithName` keeps the display awake with no permissions. A 2px `CGEvent`
mouse move resets the system idle timer and needs Accessibility. GiGi does both, and degrades to
the first when the second is missing.
**Verified, not assumed**
Measured on macOS 27.0 (26A428): a single 2px move took idle time from `114.1s` to `0.4s` in
`CGEventSource.secondsSinceLastEventType(.hidSystemState)` and in the kernel `HIDIdleTime`.
`caffeinate -u -t 1` did not reset either counter (0.6s → 2.8s), so sleep prevention alone is not
enough for presence apps.
**Schedule windows**
Inside `schedule.windows` GiGi asserts the display and wakes it if it already slept. Outside, it
releases everything. Several ranges per day, ranges that cross midnight, and per-weekday filters.
**It gets out of your way**
GiGi only moves when the user has been idle for `idleThresholdSeconds`, so it never fights with
real input. The cursor returns to its exact pixel, so it drifts zero. It stays inside the current
display bounds.
**Your system stays yours**
No `pmset -a`, no changed power settings, no background daemon beyond the one you install. The
assertion lives in the process and is released on `SIGTERM` and on `⌘Q`.
---
## Built for
- Long downloads, renders and remote sessions that should not be interrupted by a sleeping display
- Presence indicators that flip to Away while you read, watch or think
- Anyone who wants the daemon scriptable and the UI out of the way
---
## Get it
```bash
./build.sh          # bin/gigi and app/GiGi.app
./install.sh        # daemon as a LaunchAgent, starts at login
./install.sh --app  # app copied to /Applications and opened
```

| | |
|---|---|
| **Menu bar app** | `open app/GiGi.app` |
| **Daemon** | `./install.sh` then `tail -f ~/Library/Logs/GiGi/out.log` |
| **Icon** | `swift tools/make-icon.swift --preview` |
| **Uninstall** | `./uninstall.sh` |

Give Accessibility to whichever frontend you run: the app bundle, the daemon binary, or your
terminal if you launch the CLI by hand. Without it the display still stays awake and only the
cursor stays still. GiGi says so in the menu and in the log.
---
## Two frontends, one engine
```bash
./bin/gigi probe --test    # idle before/after, permissions, kernel counter
./bin/gigi run             # blocking loop, this is what launchd runs
./bin/gigi once            # one move, then exit

./bin/gigi status          # asks the running app over IPC
./bin/gigi toggle
./bin/gigi until 18:00
./bin/gigi duration 240
./bin/gigi menu            # prints the live menu with its state
```
Flags: `--config`, `--interval-min`, `--interval-max`, `--distance`, `--idle-threshold`,
`--until HH:MM`, `--duration MIN`, `--no-assert`, `--ignore-schedule`, `--source nil|private`,
`--force`.
---
## Config
Lives at `~/.config/gigi/config.json`, created by `install.sh` from `config.example.json`.

```json
{
  "intervalSeconds": [45, 90],
  "idleThresholdSeconds": 40,
  "jiggleDistancePixels": 2,
  "preventDisplaySleep": true,
  "wakeDisplayOnWindowStart": true,
  "schedule": {
    "enabled": true,
    "days": ["mon", "tue", "wed", "thu", "fri"],
    "windows": [{ "start": "09:00", "end": "18:00" }]
  }
}
```

`{"start": "22:00", "end": "06:00"}` crosses midnight. Several entries in `windows` are fine.
Reload without restarting from the menu or with `./bin/gigi reload`.
---
## How the schedule is wired
One LaunchAgent, `RunAtLoad` plus `KeepAlive`, with the window logic inside the process. No pair of
start/stop jobs, no `pkill`, no races.

| | |
|---|---|
| **Agent** | `~/Library/LaunchAgents/com.codebuff.gigi.plist` |
| **IPC port** | `com.codebuff.gigi.control` |
| **Config** | `~/.config/gigi/config.json` |
| **Logs** | `~/Library/Logs/GiGi/` (app) and `out.log` (daemon) |
| **Start early** | `sudo pmset repeat wakeorpoweron MTWRF 08:58:00` if the Mac is asleep at window start |

The daemon refuses to start when the app is already running, so there is never more than one
assertion. `--force` overrides.
---
## Architecture
- `Sources/Core`: the engine. Config, schedule windows, power assertions, cursor events, idle
  detection, the IPC channel and logging.
- `Sources/app`: AppKit menu bar app. A 1 Hz `Timer` on the main run loop drives `Engine.tick()`.
- `Sources/cli`: the CLI. A `Thread.sleep` loop drives the same `Engine.tick()`.
- `Sources/Core/IPC.swift`: `CFMessagePort` server in the app, client in the CLI, registered in
  `.commonModes` so it keeps answering while the menu is open.
- `Resources`: `Info.plist` and the `en`/`es` string tables. `tools/make-icon.swift` draws the icon
  with CoreGraphics and assembles the `.icns`.

The engine has no loop of its own: each frontend decides how to drive the heartbeat. That is the
whole difference between a daemon and a menu bar app.
---
## Limits worth knowing
- A password-locked screen beats any jiggler.
- MDM tools that block Accessibility leave software with no options; only a physical mover works.
- Presence apps watch more than local idle time, so this avoids the Away-on-idle transition, not
  pattern analysis. Check your employer's policy before you rely on it.
- Keeping the display awake costs battery. The assertion overrides `displaysleep` while active.
- Rebuilding the app changes its signature, and macOS may ask for Accessibility again. `build.sh`
  signs with your Developer ID when one exists, otherwise ad-hoc.
---
## Style
No comments in the source; names carry the meaning. English identifiers, logs, CLI output and
commit messages. User-facing app strings go through `NSLocalizedString` with the English sentence
as the key, so a new language is one `.lproj` folder plus a line in `build.sh`.
