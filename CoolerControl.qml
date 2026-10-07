pragma Singleton

import QtQuick
import Quickshell

// Polls the coolercontrold REST API (no streaming endpoint exists).
Singleton {
    id: root

    readonly property var cfg: Config.coolercontrol
    readonly property bool active: Config.loaded && (cfg.enabled ?? true)
    readonly property string base: (cfg.url ?? "http://127.0.0.1:11987").replace(/\/+$/, "")
    property var info: ({}) // uid -> {name, temps: {raw: label}, channels: {raw: label}}
    // entries only changes when the set of readings does, so delegates (and bar animations) survive polls.
    property var entries: [] // [{key, device, label, kind}]
    property var values: ({}) // key -> {value, duty}
    property string error: ""

    function request(path, cb) {
        const xhr = new XMLHttpRequest();
        xhr.open("GET", base + path);
        if (cfg.token)
            xhr.setRequestHeader("Authorization", "Bearer " + cfg.token);
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (xhr.status === 200) {
                try {
                    cb(JSON.parse(xhr.responseText));
                    root.error = "";
                } catch (e) {
                    root.error = "Bad response from CoolerControl: " + e.message;
                }
            } else if (xhr.status === 0) {
                root.error = "CoolerControl daemon unreachable at " + root.base;
            } else if (xhr.status === 401 || xhr.status === 403 || /Credentials/.test(xhr.responseText)) {
                root.error = "CoolerControl rejected the token (set coolercontrol.token)";
            } else {
                root.error = "CoolerControl HTTP " + xhr.status;
            }
        };
        xhr.send();
    }

    function loadDevices() {
        request("/devices", d => {
            const m = {};
            for (const dev of d.devices ?? []) {
                const temps = {}, channels = {};
                for (const [k, v] of Object.entries(dev.info?.temps ?? {}))
                    temps[k] = v?.label || k;
                for (const [k, v] of Object.entries(dev.info?.channels ?? {}))
                    channels[k] = v?.label || k;
                m[dev.uid] = {
                    name: dev.name,
                    temps,
                    channels
                };
            }
            root.info = m;
        });
    }

    function parse(d) {
        const out = [];
        const add = (dev, label, kind, value, duty) => out.push({
                key: dev + "/" + label,
                device: dev,
                label,
                kind,
                value,
                duty
            });
        for (const dev of d.devices ?? []) {
            const i = info[dev.uid] ?? {
                name: dev.type + " " + dev.type_index,
                temps: {},
                channels: {}
            };
            const h = dev.status_history ?? [];
            const s = h[h.length - 1];
            if (!s)
                continue;
            for (const t of s.temps ?? [])
                add(i.name, i.temps[t.name] ?? t.name, "temp", t.temp);
            for (const ch of s.channels ?? []) {
                const label = i.channels[ch.name] ?? ch.name;
                if (ch.rpm != null)
                    add(i.name, label, "fan", ch.rpm, ch.duty);
                else if (ch.watts != null)
                    add(i.name, label, "power", ch.watts);
                else if (ch.freq != null)
                    add(i.name, label, "freq", ch.freq);
                else if (ch.duty != null)
                    add(i.name, label, "duty", ch.duty);
            }
        }
        return out;
    }

    function poll() {
        if (Object.keys(info).length === 0)
            loadDevices();
        request("/status", d => {
            const list = root.parse(d);
            const v = {};
            for (const r of list)
                v[r.key] = {
                    value: r.value,
                    duty: r.duty
                };
            const e = list.map(r => ({
                        key: r.key,
                        device: r.device,
                        label: r.label,
                        kind: r.kind
                    }));
            if (JSON.stringify(e) !== JSON.stringify(root.entries))
                root.entries = e;
            root.values = v;
        });
    }

    Timer {
        interval: Math.max(0.5, root.cfg.pollSeconds ?? 2) * 1000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: root.poll()
    }

    // Labels can change in CoolerControl's UI; refresh them now and then.
    Timer {
        interval: 60000
        running: root.active
        repeat: true
        onTriggered: root.loadDevices()
    }
}
