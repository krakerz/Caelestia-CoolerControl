pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Keybind hooks: qs -c caelestia-coolercontrol ipc call <calendar|coolercontrol> <toggle|open|close>
Singleton {
    id: root

    property var opened: ({})

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
}
