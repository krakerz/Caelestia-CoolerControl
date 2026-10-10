pragma Singleton

import QtQuick
import Quickshell

// Shared countdown so every monitor's timer panel shows the same state.
// Counts against a wall-clock end time, so it stays accurate if the UI stalls.
Singleton {
    id: root

    readonly property var cfg: Config.data.timer ?? ({})
    property int duration: 300 // seconds, as set by presets / manual adjust
    property real remaining: duration
    property string state: "idle" // idle | running | paused | finished
    property real endAt: 0
    readonly property real progress: duration > 0 ? remaining / duration : 0

    function format(s) {
        s = Math.ceil(s);
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), sec = s % 60;
        const mm = String(m).padStart(h ? 2 : 1, "0"), ss = String(sec).padStart(2, "0");
        return h ? `${h}:${mm}:${ss}` : `${mm}:${ss}`;
    }

    // Accepts "m", "m:ss" or "h:mm:ss"; returns seconds or -1.
    function parse(text) {
        const parts = text.trim().split(":").map(p => p.trim());
        if (!parts.length || parts.some(p => !/^\d+$/.test(p)) || parts.length > 3)
            return -1;
        const n = parts.map(Number);
        if (n.length === 1)
            return n[0] * 60;
        if (n.length === 2)
            return n[0] * 60 + n[1];
        return n[0] * 3600 + n[1] * 60 + n[2];
    }

    function setDuration(s) {
        duration = Math.max(1, Math.min(Math.round(s), 99 * 3600));
        remaining = duration;
        state = "idle";
    }

    function adjust(ds) {
        if (state === "running") {
            endAt = Math.max(Date.now() + 1000, endAt + ds * 1000);
            tick();
        } else if (state === "paused") {
            remaining = Math.max(1, remaining + ds);
        } else {
            setDuration(duration + ds);
        }
    }

    function start() {
        if (state === "running")
            return;
        if (state !== "paused")
            remaining = duration;
        endAt = Date.now() + remaining * 1000;
        state = "running";
    }

    function pause() {
        if (state !== "running")
            return;
        tick();
        state = "paused";
    }

    function toggle() {
        state === "running" ? pause() : start();
    }

    function reset() {
        state = "idle";
        remaining = duration;
    }

    function tick() {
        remaining = Math.max(0, (endAt - Date.now()) / 1000);
        if (remaining <= 0 && state === "running")
            finish();
    }

    function finish() {
        state = "finished";
        remaining = 0;
        if (cfg.notify ?? true)
            Quickshell.execDetached(["notify-send", "-a", cfg.title ?? "Timer", "-i", "alarm-symbolic", cfg.title ?? "Timer", `${format(duration)} is up`]);
        const cmd = cfg.command ?? "";
        if (Array.isArray(cmd) ? cmd.length : cmd)
            Quickshell.execDetached(Array.isArray(cmd) ? cmd : ["sh", "-c", cmd]);
        hideDelay.restart();
    }

    Component.onCompleted: setDuration((cfg.defaultMinutes ?? 5) * 60)

    Timer {
        interval: 200
        repeat: true
        running: root.state === "running"
        onTriggered: root.tick()
    }

    // After finishing, stay up (flashing) for hideAfter seconds, then go back to idle and auto-hide.
    Timer {
        id: hideDelay

        interval: Math.max(1, root.cfg.hideAfter ?? 10) * 1000
        onTriggered: if (root.state === "finished")
            root.reset()
    }
}
