pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Loads and hot-reloads the user's config.json; every widget reads its section from here.
Singleton {
    id: root

    readonly property string path: Quickshell.env("CAELESTIA_COOLERCONTROL_CONFIG")
        || (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/caelestia-coolercontrol/config.json"
    property var data: ({})
    property bool loaded: false
    property string error: ""

    readonly property var theme: data.theme ?? ({})
    readonly property var calendar: data.calendar ?? ({})
    readonly property var coolercontrol: data.coolercontrol ?? ({})

    // monitor: "all", "primary", a name like "DP-1", or a list of names.
    function screensFor(monitor) {
        const all = Quickshell.screens;
        if (!monitor || monitor === "all")
            return all;
        if (monitor === "primary")
            return all.slice(0, 1);
        const names = Array.isArray(monitor) ? monitor : [monitor];
        return all.filter(s => names.includes(s.name));
    }

    // Shows/hides CoolerControl readings; whitelist mode when newReadingsVisible is false.
    function setReadingsVisible(keys, visible) {
        const d = JSON.parse(JSON.stringify(data));
        const cc = d.coolercontrol = d.coolercontrol ?? {};
        const whitelist = cc.newReadingsVisible === false;
        const list = whitelist ? "shown" : "hidden";
        const add = whitelist ? visible : !visible;
        let l = (cc[list] ?? []).filter(k => !keys.includes(k));
        if (add)
            l = l.concat(keys);
        cc[list] = l;
        write(d);
    }

    function setValue(section, key, value) {
        const d = JSON.parse(JSON.stringify(data));
        d[section] = d[section] ?? {};
        d[section][key] = value;
        write(d);
    }

    // device null: order of device cards; otherwise order of that device's reading keys.
    function setOrder(device, list) {
        const d = JSON.parse(JSON.stringify(data));
        const cc = d.coolercontrol = d.coolercontrol ?? {};
        if (device === null) {
            cc.deviceOrder = list;
        } else {
            cc.readingOrder = cc.readingOrder ?? {};
            cc.readingOrder[device] = list;
        }
        write(d);
    }

    // Empty text restores the default label.
    function setLabel(key, text) {
        const d = JSON.parse(JSON.stringify(data));
        const cc = d.coolercontrol = d.coolercontrol ?? {};
        const l = cc.labels = cc.labels ?? {};
        if (text.trim())
            l[key] = text.trim();
        else
            delete l[key];
        write(d);
    }

    function write(d) {
        data = d;
        file.setText(JSON.stringify(d, null, 2) + "\n");
    }

    FileView {
        id: file

        path: root.path
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.data = JSON.parse(text());
                root.error = "";
            } catch (e) {
                root.error = "config.json: " + e.message;
            }
            root.loaded = true;
        }
        onLoadFailed: {
            root.error = "Can't read " + root.path;
            root.loaded = true;
        }
    }
}
