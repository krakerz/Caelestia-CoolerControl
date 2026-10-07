# Caelestia-CoolerControl

Quickshell/QML widgets for Hyprland + Caelestia shell.

## Description

Caelestia-CoolerControl provides a suite of desktop widgets for the Hyprland window manager and Caelestia shell, built with Quickshell and QML. Widgets are Caelestia-style drawers that slide out from the screen frame and integrate with Caelestia's live colour scheme. Features include a calendar with multiple event sources, live system monitoring via CoolerControl, and a KDE-style window overview of the current workspace.

## Features

- Drawers that slide out from screen edges (top, bottom, left, right) or corners with positioning presets and x/y nudges
- Three drawer modes: hover (appears on frame edge hover), always (stays open), or pinned (user-controllable)
- Keybind-friendly IPC commands to toggle, open or close each panel
- Hover is ignored over fullscreen apps; a keybind opens a floating card instead
- Calendar widget with month grid and upcoming events list
- Multiple ICS calendar feeds (Google Calendar, Outlook / Microsoft 365, Nextcloud, etc.)
- Public holidays for multiple countries via Google Calendar or Nager API
- Thunderbird calendar integration with per-calendar colour customization
- CoolerControl system monitor: temperature, fan speed, power, frequency readings; show/hide, rename and reorder devices and readings in edit mode
- Window overview (KDE "Present Windows" style): live thumbnails of the current workspace, click or Enter to focus, type to filter
- Live Caelestia colour scheme integration with per-colour config overrides
- JSON configuration file with hot reload (no restart needed)
- Per-widget monitor targeting, layer control, and styling
- Lucide icons (ISC licensed)

## Installation

No build required; needs Quickshell (qs) >= 0.3 and Python 3.

```bash
git clone https://github.com/krakerz/Caelestia-CoolerControl ~/Caelestia-CoolerControl
cd ~/Caelestia-CoolerControl
./install.sh
```

This creates a symlink at `~/.config/quickshell/caelestia-coolercontrol` and seeds a default config at `~/.config/caelestia-coolercontrol/config.json`.

## Usage

### Running

Edit `~/.config/caelestia-coolercontrol/config.json`, then start the widgets:

```bash
qs -c caelestia-coolercontrol
```

### Autostart

Add to `~/.config/caelestia/hypr-user.lua` inside the `hyprland.start` handler:

```lua
hl.exec_cmd("sleep 3 && qs -c caelestia-coolercontrol -n -d")
```

The `-n` flag disables focus, `-d` runs headless (no Caelestia terminal).

### Keybinds

Each panel can be toggled, opened, or closed via command-line IPC calls. Opened this way, a panel stays open until toggled or closed again:

```bash
qs -c caelestia-coolercontrol ipc call calendar toggle    # Toggle calendar visibility
qs -c caelestia-coolercontrol ipc call calendar open      # Open calendar
qs -c caelestia-coolercontrol ipc call calendar close     # Close calendar

qs -c caelestia-coolercontrol ipc call coolercontrol toggle    # Toggle CoolerControl visibility
qs -c caelestia-coolercontrol ipc call coolercontrol open      # Open CoolerControl
qs -c caelestia-coolercontrol ipc call coolercontrol close     # Close CoolerControl
```

Example keybinds for `~/.config/caelestia/hypr-user.lua` (this is an example, not installed automatically):

```lua
hl.bind("SUPER + G", hl.dsp.exec_cmd("qs -c caelestia-coolercontrol ipc call calendar toggle"))
hl.bind("SUPER + H", hl.dsp.exec_cmd("qs -c caelestia-coolercontrol ipc call coolercontrol toggle"))
hl.bind("SUPER + W", hl.dsp.exec_cmd("qs -c caelestia-coolercontrol ipc call overview toggle"))
```

### Window overview

`qs -c caelestia-coolercontrol ipc call overview toggle` shows every window on the focused monitor's current workspace (or its open special workspace) as a live thumbnail, KDE "Present Windows" style.

- Click or Enter focuses a window and closes the overview; middle-click closes a window.
- Arrow keys / Tab move the selection, typing filters by title or app, Backspace edits the filter.
- Esc clears the filter, then closes; clicking the backdrop closes too.

| Key | Default | Meaning |
|-----|---------|---------|
| overview.enabled | `true` | Enable the overview |
| overview.live | `true` | Live thumbnails (false = a still frame per window) |
| overview.dim | `0.7` | Backdrop opacity |
| overview.margin | `80` | Screen margin around the thumbnails |
| overview.gap | `28` | Gap between thumbnails |
| overview.maxThumbHeight | `0.55` | Max thumbnail height as a fraction of the screen |
| overview.showHint | `true` | Show the key hint line at the top |

### Configuration

All settings live in `~/.config/caelestia-coolercontrol/config.json`. Changes are applied instantly without restarting.

#### Placement

Panels are positioned on the screen frame edge, with presets for edges and corners. Use `position` to select the preset, then `x` and `y` to nudge from there:

- **Edge positions** (attached to the middle of the edge):
  - `"top"`, `"bottom"`: use `x` to shift left/right, `y` is ignored
  - `"left"`, `"right"`: use `y` to shift up/down, `x` is ignored
- **Corner positions** (attached to the top or bottom edge, flush against the side):
  - `"top-left"`, `"top-right"`, `"bottom-left"`, `"bottom-right"`: use `x` to shift away from corner along the edge, `y` is ignored
- **Side positions anchored to one end** (attached to the left/right edge):
  - `"left-top"`, `"right-top"`: `y` is the distance from the top, the panel grows downward
  - `"left-bottom"`, `"right-bottom"`: negative `y` lifts it from the bottom, the panel grows upward

Nudges are in screen directions (positive = right / down). With a centred preset (`"left"`, `"right"`, `"top"`, `"bottom"`) the nudge is relative to the centre, so the panel's ends move when its content grows; use an anchored preset to keep one end fixed.

Example: calendar on the right edge, its top 70 px below the frame:
```json
{
  "position": "right-top",
  "y": 70
}
```

Example: calendar centred on the top edge, nudged 200 pixels right:
```json
{
  "position": "top",
  "x": 200
}
```

| Section | Key | Default | Meaning |
|---------|-----|---------|---------|
| **theme** | source | `"caelestia"` | Colour scheme source: `"caelestia"` (live), or `"custom"` for config-only |
| | schemePath | (XDG_STATE_HOME)/caelestia/scheme.json | Path to Caelestia's scheme.json (with fallback to ~/.local/state/caelestia/scheme.json) |
| | colours | `{}` | Per-colour overrides as `{name: "#RRGGBB" or "RRGGBB"}` |
| | font | `"Rubik"` | UI font name |
| | monoFont | `"JetBrains Mono NF"` | Monospace font for values |
| | fontSize | `13` | Base font size in pixels |
| | panelRounding | `25` | Corner radius for drawer panels |
| | cardRounding | `17` | Corner radius for cards inside panels |
| | padding | `15` | Internal padding of drawers |
| | cardPadding | `14` | Internal padding of cards |
| | spacing | `12` | Spacing between items in drawers |
| | animDuration | `400` | Animation duration in milliseconds for drawer open/close |
| | frame.barWidth | `60` | Width of Caelestia's bar (must match Caelestia config) |
| | frame.thickness | `10` | Thickness of Caelestia's screen edge (must match Caelestia config) |
| **calendar** | enabled | `true` | Enable the calendar widget |
| | monitor | `"DP-1"` | Monitor name, `"all"`, `"primary"`, or list of names |
| | position | `"top-left"` | Drawer position: `"top"`, `"bottom"`, `"left"`, `"right"` (attached to edge middle) or `"top-left"`, `"top-right"`, `"bottom-left"`, `"bottom-right"` (corners) |
| | x | `0` | Horizontal pixel nudge from preset position (positive = right); ignored for left/right edges |
| | y | `0` | Vertical pixel nudge from preset position (positive = down); ignored for top/bottom edges |
| | mode | `"hover"` | Activation mode: `"hover"` (appears on frame edge hover), `"always"` (always visible) |
| | pinned | `false` | Persist the drawer open (user-toggleable via pin button) |
| | closeDelay | `300` | Milliseconds to wait before auto-closing after mouse leaves |
| | triggerSize | `10` | Hover strip depth from screen edge in pixels (default = frame thickness) |
| | triggerArea | `"grid"` | Calendar on a left/right edge: hover strip only alongside the month grid (`"grid"`) or the whole panel (`"panel"`), keeping the rest of the edge free for Caelestia |
| | layer | `"overlay"` | Wayland layer: `"overlay"` (above Caelestia, survives its restarts) or `"top"` |
| | hideOnFullscreen | `true` | Ignore hover and pinning while a fullscreen app is open; a keybind still opens the panel as a floating card |
| | fullscreenMargin | `10` | Gap between the floating card and the screen edge over fullscreen apps |
| | width | `360` | Drawer width in pixels |
| | locale | `""` | Locale for date/time display (e.g. `"en_US"`, empty = system default) |
| | firstDayOfWeek | `1` | First weekday: 0 = Sunday, 1 = Monday |
| | weekendDays | `[0, 6]` | Weekend days (0 = Sunday, 6 = Saturday) |
| | timeFormat | `"24h"` | Time display: `"24h"` or `"12h"` |
| | showEventList | `true` | Show upcoming events list below calendar |
| | showEventDetails | `true` | Show time and source for each event |
| | showErrors | `true` | Display fetch/parse errors in the widget |
| | upcomingDays | `14` | Lookahead range for upcoming events |
| | maxUpcoming | `8` | Maximum events to show in the list |
| | refreshMinutes | `30` | How often to re-fetch calendar data |
| | monthsBack | `2` | Months of history to load |
| | monthsAhead | `12` | Months of future data to load |
| | ics | `[{name: "Google", url: "", color: "", enabled: true}]` | Array of ICS feeds; `url` accepts webcal:// and https://, `color` is optional hex, `enabled` controls inclusion |
| | holidays.provider | `"google"` | Holiday data source: `"google"` or `"nager"` |
| | holidays.countries | `["ID"]` | ISO country codes (e.g. `["US", "GB", "DE"]`); custom codes used verbatim as Google Calendar slugs |
| | holidays.language | `"en"` | Language for holiday names (e.g. `"en"`, `"de"`, `"fr"`) |
| | holidays.includeObservances | `false` | Include observance days (e.g. observed holidays not on the official date) |
| | holidays.color | `""` | Colour for holiday events (optional hex) |
| | holidays.refreshHours | `168` | Cache TTL for holiday data |
| | thunderbird.enabled | `true` | Import Thunderbird calendars |
| | thunderbird.profile | `"auto"` | Profile path or `"auto"` to auto-detect |
| | thunderbird.calendars | `"all"` | Calendar names to include or `"all"` |
| | thunderbird.colors | `{}` | Per-calendar colour overrides as `{name: "#RRGGBB"}` |
| **coolercontrol** | enabled | `true` | Enable the CoolerControl widget |
| | monitor | `"DP-1"` | Monitor for the widget |
| | position | `"top-right"` | Drawer position: `"top"`, `"bottom"`, `"left"`, `"right"` (attached to edge middle) or `"top-left"`, `"top-right"`, `"bottom-left"`, `"bottom-right"` (corners) |
| | x | `0` | Horizontal pixel nudge from preset position (positive = right); ignored for left/right edges |
| | y | `0` | Vertical pixel nudge from preset position (positive = down); ignored for top/bottom edges |
| | mode | `"hover"` | Activation mode: `"hover"` or `"always"` |
| | pinned | `false` | Persist the drawer open (user-toggleable) |
| | closeDelay | `300` | Milliseconds to wait before auto-closing after mouse leaves |
| | triggerSize | `10` | Hover strip depth from screen edge in pixels (default = frame thickness) |
| | layer | `"overlay"` | Wayland layer: `"overlay"` (above Caelestia, survives its restarts) or `"top"` |
| | hideOnFullscreen | `true` | Ignore hover and pinning while a fullscreen app is open; a keybind still opens the panel as a floating card |
| | fullscreenMargin | `10` | Gap between the floating card and the screen edge over fullscreen apps |
| | width | `340` | Drawer width |
| | title | `"CoolerControl"` | Widget title |
| | url | `"http://127.0.0.1:11987"` | CoolerControl REST API base URL |
| | token | `""` | API bearer token (see FAQ) |
| | pollSeconds | `2` | Update interval |
| | columns | `1` | Layout columns for readings |
| | showDeviceNames | `true` | Show device name headers |
| | showBars | `true` | Show progress bars for readings |
| | showEditButton | `true` | Show gear icon to toggle edit mode |
| | tempUnit | `"C"` | Temperature unit: `"C"` or `"F"` |
| | tempDecimals | `1` | Decimal places for temperatures |
| | warnTemp | `75` | Warning threshold for temperatures (°C) |
| | critTemp | `90` | Critical threshold for temperatures (°C) |
| | thresholds | `{}` | Per-reading overrides as `{"Device/Label": {warn: 70, crit: 85}}` |
| | barMax | `{}` | Per-reading bar ceiling as `{"Device/Label": 100}` |
| | labels | `{}` | Per-reading display name overrides as `{"Device/Label": "Custom Name"}` |
| | deviceOrder | `[]` | Device card order (device names); set by the arrows in edit mode. Unlisted devices follow in their natural order |
| | readingOrder | `{}` | Reading order per device: `{"<Device>": ["<Device>/<Label>", ...]}`; set by the arrows in edit mode |
| | newReadingsVisible | `true` | New readings visible by default; set to `false` for whitelist mode |
| | hidden | `[]` | Hidden readings in default mode as `["Device/Label", ...]` |
| | shown | `[]` | Shown readings in whitelist mode as `["Device/Label", ...]` |
| | maxHeight | `900` | Maximum height of the readings list in pixels (scrolls if exceeded) |

## FAQ

### How do I get a Google Calendar secret iCal address?

1. Open Google Calendar and go to Settings.
2. Find the calendar in the left sidebar, click the three dots, and select "Settings and sharing".
3. Scroll to "Integrate calendar" and copy the "Secret address in iCalendar format" (the https:// link ending in .ics).
4. Paste it into `calendar.ics[].url` in config.json.

Outlook / Microsoft 365 works the same way: Settings → Calendar → Shared calendars → Publish a calendar, then copy the ICS link (`webcal://` links are fine). Each feed is an object; a bare URL string also works:

```json
"ics": [
  { "name": "Outlook", "url": "webcal://outlook.office365.com/owa/calendar/.../reachcalendar.ics", "color": "" },
  "https://calendar.google.com/calendar/ical/.../basic.ics"
]
```

### How do I create a CoolerControl access token?

1. Open the CoolerControl daemon UI (default http://127.0.0.1:11987).
2. Go to Settings → Access Tokens.
3. Create a new token (or use an existing one).
4. Paste the token into `coolercontrol.token` in config.json.

### How do I hide or show CoolerControl readings?

Click the gear icon in the widget header to enter edit mode. Tick boxes show or hide a whole device or individual readings, and the up/down arrows move a device card or a reading within its card. The panel title, device names, and reading names become editable text fields — type to rename, press Enter or click away to save, or press Esc to cancel. Empty names restore their defaults. Changes are written to `coolercontrol.hidden`, `coolercontrol.shown`, `coolercontrol.title`, `coolercontrol.labels`, `coolercontrol.deviceOrder` and `coolercontrol.readingOrder` in config.json. The panel stays open while editing.

### What is the reading key format?

Each reading has a unique key in the form `"<Device name>/<Label>"`, e.g. `"GPU 0/Memory"` or `"CPU/Package"`. Use this key format in `thresholds`, `barMax`, `hidden`, and `shown`. For custom names in `coolercontrol.labels`, device names are stored under keys like `"@GPU 0"`, while reading labels use the full key `"GPU 0/Memory"`.

### Can I use a different holidays provider?

Yes. Set `calendar.holidays.provider` to:
- `"google"` (default): Fetches from Google Calendar public holiday calendars. Country codes map to Google slugs (e.g. `"US"` → `"usa"`, `"DE"` → `"german"`). Custom codes are used verbatim as slugs.
- `"nager"`: Fetches from the Nager.Date API. Country codes must be ISO 3166-1 alpha-2 (e.g. `"US"`, `"DE"`).

### Does config reload without restarting?

Yes. Any change to `~/.config/caelestia-coolercontrol/config.json` is applied instantly. Calendar feeds and CoolerControl settings re-sync, and the UI updates live.

### Credits

Uses [Lucide icons](https://lucide.dev) (ISC licensed, see `icons/LICENSE-lucide.txt`).

---

### Notes

Built and maintained with the help of AI.
