pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Caelestia's live scheme (if present) with per-colour overrides from config.theme.colours.
Singleton {
    id: root

    readonly property var cfg: Config.theme
    readonly property var over: cfg.colours ?? ({})
    property var scheme: ({})

    function c(name, fallback) {
        const v = over[name] ?? (cfg.source === "custom" ? undefined : scheme[name]);
        if (!v)
            return fallback;
        const s = String(v);
        return s.startsWith("#") ? s : "#" + s;
    }

    // Fallbacks are Caelestia's default palette; Caelestia's scheme.json stores bare hex without "#".
    readonly property color m3surface: c("surface", "#191114")
    readonly property color m3surfaceContainer: c("surfaceContainer", "#261d20")
    readonly property color m3surfaceContainerHigh: c("surfaceContainerHigh", "#31282a")
    readonly property color m3onSurface: c("onSurface", "#efdfe2")
    readonly property color m3onSurfaceVariant: c("onSurfaceVariant", "#d5c2c6")
    readonly property color m3primary: c("primary", "#ffb0ca")
    readonly property color m3onPrimary: c("onPrimary", "#541d34")
    readonly property color m3tertiary: c("tertiary", "#f0bc95")
    readonly property color m3error: c("error", "#ffb4ab")
    readonly property color m3outlineVariant: c("outlineVariant", "#514347")
    readonly property color holiday: c("holiday", m3error)

        readonly property string font: cfg.font ?? "Rubik"
    readonly property string monoFont: cfg.monoFont ?? "JetBrains Mono NF"
    readonly property int fontSize: cfg.fontSize ?? 13
    readonly property int fontSmall: fontSize - 2
    readonly property int fontLarge: fontSize + 3
    readonly property int panelRounding: cfg.panelRounding ?? 25
    readonly property int cardRounding: cfg.cardRounding ?? 17
    readonly property int padding: cfg.padding ?? 15
    readonly property int cardPadding: cfg.cardPadding ?? 14
    readonly property int spacing: cfg.spacing ?? 12

    function alpha(col, a) {
        return Qt.rgba(col.r, col.g, col.b, a);
    }

    // A file created after startup isn't caught by watchChanges, so retry until it exists.
    Timer {
        id: retry

        interval: 3000
        onTriggered: schemeFile.reload()
    }

    FileView {
        id: schemeFile

        path: root.cfg.schemePath ?? (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/caelestia/scheme.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const j = JSON.parse(text());
                root.scheme = j.colours ?? j;
            } catch (e) {
                root.scheme = {};
            }
        }
        onLoadFailed: {
            root.scheme = {};
            retry.restart();
        }
    }
}
