# Changelog

All notable changes to Caelestia-CoolerControl are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added

- Panel placement presets (top, bottom, left, right and corners) with x/y nudges
- Panels ignore hover over fullscreen apps; a keybind opens them as a floating card
- Caelestia-style drawers that slide out from screen corners with filleted frame integration
- Drawer hover activation, always-on mode, and pin toggle (saved to config)
- Calendar widget with month grid, day selection, and upcoming events list
- CoolerControl system monitor with per-device cards (temperature, fan, power, frequency)
- Scrollable CoolerControl lists with configurable maxHeight
- Multiple ICS calendar feeds (Google Calendar, Nextcloud, etc.)
- Public holidays from Google Calendar or Nager API
- Thunderbird calendar integration with per-calendar colours
- Live Caelestia colour scheme integration (watches XDG_STATE_HOME/caelestia/scheme.json)
- Per-colour theme overrides in config
- Per-reading visibility toggle in CoolerControl edit mode
- Keybind-friendly IPC commands to toggle, open or close each panel
- Rename the CoolerControl title, devices and readings from edit mode
- JSON config hot-reload (no restart needed)
- Smooth drawer open/close animations
- Multi-monitor and per-widget monitor targeting
- Lucide icons (ISC licensed)

### Fixed

- Calendar panel no longer flickers while hovering its buttons
- CoolerControl bars animate from the previous value instead of restarting from zero
- Removed the faint line where a panel meets the Caelestia frame
- Panels stay above Caelestia and keep working after Caelestia restarts
