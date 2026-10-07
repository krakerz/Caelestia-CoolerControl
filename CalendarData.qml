pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Runs scripts/events.py and indexes its events by "YYYY-MM-DD".
Singleton {
    id: root

    readonly property bool active: Config.loaded && (Config.calendar.enabled ?? true)
    readonly property string script: decodeURIComponent(Qt.resolvedUrl("scripts/events.py").toString().replace(/^file:\/\//, ""))
    property var byDate: ({})
    property var errors: []
    readonly property bool loading: proc.running
    property string lastCfg: ""

    function refresh() {
        if (active && !proc.running)
            proc.running = true;
    }

    function apply(text) {
        if (!text.trim())
            return;
        try {
            const d = JSON.parse(text);
            const m = {};
            for (const e of d.events ?? [])
                (m[e.date] = m[e.date] || []).push(e);
            byDate = m;
            errors = d.errors ?? [];
        } catch (e) {
            errors = ["events.py: bad output"];
        }
    }

    Process {
        id: proc

        command: [Config.calendar.python ?? "python3", root.script, Config.path]
        stdout: StdioCollector {
            onStreamFinished: root.apply(text)
        }
        stderr: StdioCollector {
            id: stderr
        }
        onExited: code => {
            if (code !== 0)
                root.errors = ["events.py failed: " + (stderr.text.trim().split("\n").pop() || "exit " + code)];
        }
    }

    Timer {
        interval: Math.max(1, Config.calendar.refreshMinutes ?? 30) * 60000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // Re-fetch only when the calendar section itself changed.
    Connections {
        target: Config

        function onCalendarChanged() {
            const s = JSON.stringify(Config.calendar);
            if (s !== root.lastCfg) {
                root.lastCfg = s;
                debounce.restart();
            }
        }
    }

    Timer {
        id: debounce

        interval: 500
        onTriggered: root.refresh()
    }
}
