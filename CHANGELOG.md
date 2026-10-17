# Changelog

All notable changes to Caelestia-CoolerControl are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added

- Workspace tabs in the window overview, optionally with special workspaces and other monitors
- Timer panel with presets, manual adjust, finish notification/command and a configurable flashing alert
- Panels follow Caelestia's bar when it auto-hides (frame size read from the reserved screen edges)
- Side-edge presets anchored to one end: left-top, left-bottom, right-top, right-bottom
- Calendar on a side edge only reacts to hover alongside its month grid (`triggerArea`)
- Reorder CoolerControl devices and readings with arrows in edit mode
- Window overview (KDE Present Windows style) with live thumbnails of the current workspace, keyboard navigation and type-to-filter

### Fixed

- Recurring events from another time zone keep the right local time across that zone's daylight-saving changes
- Outlook events with time zones like "(UTC+08:00) Kuala Lumpur, Singapore" are no longer dropped
- Panel buttons no longer overwrite config.json while it has a syntax error
- Identical CoolerControl devices (e.g. two of the same SSD) get separate cards
- Calendar follows the date into a new month while showing the current one
- Horizontal scrolling no longer flips the calendar month
- Calendar settings changed during a refresh are no longer missed
- A single Thunderbird calendar name in `calendars` matches only that calendar
- Example config shows the panels on all monitors instead of only DP-1

## [0.1.0] — 2026-10-07

### Added

- Calendar panel with month grid, day selection and upcoming events list
- Multiple ICS calendar feeds (Google, Outlook/Microsoft 365, Nextcloud, …), as objects or plain URLs
- Outlook/Exchange event times converted from Windows time zones
- Public holidays for multiple countries from Google Calendar or Nager.Date
- Thunderbird calendars with their own colours
- CoolerControl panel with per-device cards for temperatures, fans, power, load and clocks
- Show/hide each reading or device and rename the title, devices and readings from edit mode
- Scrollable CoolerControl list with configurable max height
- Caelestia-style drawers that grow out of the screen frame and blend into it
- Placement presets (top, bottom, left, right and corners) with x/y nudges
- Hover, always-on and pinned modes, plus IPC commands for keybinds
- Panels stay above Caelestia, also after it restarts
- Hover ignored over fullscreen apps; a keybind opens a floating card instead
- Live Caelestia colour scheme with per-colour overrides
- JSON config with hot reload
- Multi-monitor targeting per panel
