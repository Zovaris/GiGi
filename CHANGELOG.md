# Changelog

Newest first. Versions match the `vX.Y.Z` tags and the app's `Info.plist`; dates are ISO 8601.
Cut a release with `make version`, which writes the section for you.

## 0.4.0 - 2026-09-20

**Added**

- Let the dim level go down to 0 instead of stopping at 5%
- Add gigi version and gigi update
- Check for a newer release and show it in the settings drawer

**Fixed**

- Measure the changelog from the last release commit when its tag is gone
- Clear any other GiGi agent before installing or removing one
- Adopt the com.justcallmebryan.gigi bundle identifier (grant Accessibility once more)

## 0.3.0 - 2026-09-20

**Added**

- Pick the movement pattern and its radius in the drawer
- Expose the motion pattern and the radius as flags
- Move the cursor along a circle, square or figure eight

**Fixed**

- Apply the movement numbers when a field loses focus

## 0.2.0 - 2026-09-20

First public release.

**Added**

- Cursor jiggle and display dimming, keeping an idle Mac awake
- Schedule window with weekday chips and hour and minute pickers
- Safety stops: timer, battery threshold, or a chosen app not running or in front
- Notifications when GiGi stops on its own
- Menu bar control, global shortcut, CLI, LaunchAgent installer
