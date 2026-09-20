# Changelog

Newest first. Versions match the `vX.Y.Z` tags and the app's `Info.plist`; dates are ISO 8601.
Cut a release with `make version`, which writes the section for you.

## 0.2.0 - 2026-09-20

First public release.

**Added**

- Notifications when GiGi stops on its own: timer, battery limit, missing permission
- Battery limit, stopping at a threshold picked in the panel
- Only while an app: gated on it running or being in front
- Schedule window with hour and minute pickers plus weekday chips
- Dimming while GiGi keeps the screen awake
- Global shortcut to toggle GiGi, plus language and appearance
- CLI and menu bar control, diagnostics, LaunchAgent installer

**Fixed**

- The panel reads its icon from the bundle, not the system lookup
- `gigi status` reports waiting for an app instead of active

**Changed**

- Every hour, minute and battery picker moves in steps of five
