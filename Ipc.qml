pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Keybind hooks: qs -c caelestia-coolercontrol ipc call <calendar|coolercontrol|overview|timer> <toggle|open|close>
// Timer extras: start <minutes> (0 = current duration), playPause, reset
Singleton {
    id: root

    property var opened: ({})

    // Drawers read the frame from each monitor's reserved area, which changes without an event
    // (e.g. Caelestia's bar switching between persistent and auto-hide).
    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: Hyprland.refreshMonitors()
    }

    function set(ns, value) {
        const o = Object.assign({}, opened);
        o[ns] = value;
        opened = o;
    }

    IpcHandler {
        target: "calendar"

        function toggle(): void {
            root.set("calendar", !root.opened.calendar);
        }

        function open(): void {
            root.set("calendar", true);
        }

        function close(): void {
            root.set("calendar", false);
        }
    }

    IpcHandler {
        target: "coolercontrol"

        function toggle(): void {
            root.set("coolercontrol", !root.opened.coolercontrol);
        }

        function open(): void {
            root.set("coolercontrol", true);
        }

        function close(): void {
            root.set("coolercontrol", false);
        }
    }

    IpcHandler {
        target: "overview"

        function toggle(): void {
            root.set("overview", !root.opened.overview);
        }

        function open(): void {
            root.set("overview", true);
        }

        function close(): void {
            root.set("overview", false);
        }
    }

    IpcHandler {
        target: "timer"

        function toggle(): void {
            root.set("timer", !root.opened.timer);
        }

        function open(): void {
            root.set("timer", true);
        }

        function close(): void {
            root.set("timer", false);
        }

        function start(minutes: int): void {
            if (minutes > 0)
                TimerState.setDuration(minutes * 60);
            TimerState.start();
        }

        function playPause(): void {
            TimerState.toggle();
        }

        function reset(): void {
            TimerState.reset();
        }
    }
}
