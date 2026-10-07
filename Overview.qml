import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

// KDE "Present Windows"-style overview of the focused monitor's current workspace (or its open special workspace).
// Live thumbnails; click / Enter focuses, middle-click closes, typing filters, Esc or the backdrop closes.
PanelWindow {
    id: root

    required property var modelData

    readonly property var cfg: Config.data.overview ?? ({})
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(modelData)
    readonly property bool shown: (Ipc.opened.overview ?? false) && Hyprland.focusedMonitor?.name === modelData.name
    // The window's own width/height don't track the anchored size, so use the screen's.
    readonly property real sw: modelData.width
    readonly property real sh: modelData.height
    property string filter: ""
    property int selected: 0
    property real appear: 0

    readonly property int wsId: {
        const special = monitor?.lastIpcObject?.specialWorkspace;
        return special && special.id ? special.id : (monitor?.activeWorkspace?.id ?? 0);
    }
    readonly property var windows: Hyprland.toplevels.values.filter(t => t.workspace?.id === wsId && t.lastIpcObject?.mapped !== false && !t.lastIpcObject?.hidden).sort((a, b) => {
        const pa = a.lastIpcObject?.at ?? [0, 0], pb = b.lastIpcObject?.at ?? [0, 0];
        return pa[1] - pb[1] || pa[0] - pb[0];
    })
    readonly property var shownWindows: {
        const f = filter.toLowerCase();
        return f ? windows.filter(t => (t.title + " " + (t.lastIpcObject?.class ?? "")).toLowerCase().includes(f)) : windows;
    }

    readonly property int margin: cfg.margin ?? 80
    readonly property int gap: cfg.gap ?? 28
    readonly property int labelH: 34
    readonly property int headerH: 40

    // Row packing: try every row count, keep the one giving the largest thumbnails, preserve aspect ratios.
    readonly property var layout: {
        const n = shownWindows.length;
        if (!n)
            return [];
        const W = sw - margin * 2, H = sh - margin * 2 - headerH;
        const ar = shownWindows.map(t => {
            const s = t.lastIpcObject?.size;
            return s && s[1] > 0 ? s[0] / s[1] : 16 / 9;
        });
        let best = null;
        for (let r = 1; r <= n; r++) {
            const per = Math.ceil(n / r), rows = [];
            for (let i = 0; i < n; i += per)
                rows.push(Array.from({
                    length: Math.min(per, n - i)
                }, (_, k) => i + k));
            let h = (H - gap * (rows.length - 1)) / rows.length - labelH;
            for (const row of rows)
                h = Math.min(h, (W - gap * (row.length - 1)) / row.reduce((s, i) => s + ar[i], 0));
            if (!best || h > best.h)
                best = {
                    h,
                    rows
                };
        }
        const h = Math.max(40, Math.min(best.h, H * (cfg.maxThumbHeight ?? 0.55)));
        const out = [];
        const totalH = best.rows.length * (h + labelH) + gap * (best.rows.length - 1);
        let y = margin + headerH + (H - totalH) / 2;
        best.rows.forEach((row, ri) => {
            const rowW = row.reduce((s, i) => s + ar[i] * h, 0) + gap * (row.length - 1);
            let x = margin + (W - rowW) / 2;
            for (const i of row) {
                out[i] = {
                    x,
                    y,
                    w: ar[i] * h,
                    h,
                    row: ri
                };
                x += ar[i] * h + gap;
            }
            y += h + labelH + gap;
        });
        return out;
    }

    function close() {
        Ipc.set("overview", false);
    }

    // Close first: while the overlay holds exclusive keyboard focus, Hyprland only warps the cursor and the
    // window never gets focus (so the scrolling layout doesn't scroll to it either).
    property string pendingFocus: ""

    function focusWindow(t) {
        pendingFocus = t.address;
        close();
        focusDelay.restart();
    }

    function closeWindow(t) {
        Hyprland.dispatch(`hl.dsp.window.close({ window = "address:0x${t.address}" })`);
        Qt.callLater(Hyprland.refreshToplevels);
    }

    // Up/down: nearest thumbnail (by centre x) in the neighbouring row.
    function step(dir) {
        const cur = layout[selected];
        if (!cur)
            return;
        const cx = cur.x + cur.w / 2;
        let best = -1, bestD = Infinity;
        layout.forEach((l, i) => {
            if (l.row !== cur.row + dir)
                return;
            const d = Math.abs(l.x + l.w / 2 - cx);
            if (d < bestD) {
                bestD = d;
                best = i;
            }
        });
        if (best >= 0)
            selected = best;
    }

    function iconFor(t) {
        const cls = t.lastIpcObject?.class ?? "";
        const entry = DesktopEntries.heuristicLookup ? DesktopEntries.heuristicLookup(cls) : DesktopEntries.byId(cls);
        return Quickshell.iconPath(entry?.icon ?? cls.toLowerCase(), "application-x-executable");
    }

    onShownChanged: {
        if (shown) {
            Hyprland.refreshMonitors();
            Hyprland.refreshToplevels();
            filter = "";
            appear = 0;
            appearAnim.restart();
            Qt.callLater(() => {
                const i = shownWindows.indexOf(Hyprland.activeToplevel);
                selected = Math.max(0, i);
                keys.forceActiveFocus();
            });
        }
    }
    onShownWindowsChanged: selected = Math.min(selected, Math.max(0, shownWindows.length - 1))

    screen: modelData
    visible: shown
    color: "transparent"
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "caelestia-coolercontrol-overview"
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Timer {
        id: focusDelay

        interval: 120
        onTriggered: {
            if (root.pendingFocus)
                Hyprland.dispatch(`hl.dsp.focus({ window = "address:0x${root.pendingFocus}" })`);
            root.pendingFocus = "";
        }
    }

    NumberAnimation {
        id: appearAnim

        target: root
        property: "appear"
        to: 1
        duration: 220
        easing.type: Easing.OutCubic
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.m3surface, root.cfg.dim ?? 0.7)
        opacity: root.appear

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    Item {
        id: keys

        anchors.fill: parent
        focus: true
        opacity: root.appear
        scale: 0.96 + 0.04 * root.appear

        Keys.onPressed: e => {
            const n = root.shownWindows.length;
            if (e.key === Qt.Key_Escape) {
                if (root.filter)
                    root.filter = "";
                else
                    root.close();
            } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                if (n)
                    root.focusWindow(root.shownWindows[root.selected]);
            } else if (e.key === Qt.Key_Right || e.key === Qt.Key_Tab) {
                if (n)
                    root.selected = (root.selected + 1) % n;
            } else if (e.key === Qt.Key_Left || e.key === Qt.Key_Backtab) {
                if (n)
                    root.selected = (root.selected - 1 + n) % n;
            } else if (e.key === Qt.Key_Down) {
                root.step(1);
            } else if (e.key === Qt.Key_Up) {
                root.step(-1);
            } else if (e.key === Qt.Key_Backspace) {
                root.filter = root.filter.slice(0, -1);
            } else if (e.text && e.text.trim() && !(e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                root.filter += e.text;
                root.selected = 0;
            } else {
                return;
            }
            e.accepted = true;
        }

        StyledText {
            x: 0
            y: root.margin / 2
            width: root.sw
            horizontalAlignment: Text.AlignHCenter
            text: root.filter ? "Filter: " + root.filter : (root.cfg.showHint ?? true) ? "Type to filter · arrows / Tab to move · Enter to focus · middle-click to close a window · Esc to exit" : ""
            color: root.filter ? Theme.m3primary : Theme.m3onSurfaceVariant
            font.pixelSize: root.filter ? Theme.fontLarge : Theme.fontSmall
            font.weight: root.filter ? 600 : 400
        }

        StyledText {
            anchors.centerIn: parent
            visible: root.shownWindows.length === 0
            text: root.filter ? "No windows match" : "No windows on this workspace"
            color: Theme.m3onSurfaceVariant
            font.pixelSize: Theme.fontLarge
        }

        Repeater {
            model: root.shownWindows

            Item {
                id: tile

                required property var modelData
                required property int index
                readonly property var l: root.layout[index] ?? {
                    x: 0,
                    y: 0,
                    w: 0,
                    h: 0
                }
                readonly property bool current: index === root.selected

                x: l.x
                y: l.y
                width: l.w
                height: l.h + root.labelH

                Behavior on x {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on y {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on width {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }

                ClippingRectangle {
                    id: thumb

                    width: parent.width
                    height: tile.l.h
                    radius: Theme.cardRounding
                    color: Theme.m3surfaceContainer

                    ScreencopyView {
                        id: capture

                        anchors.fill: parent
                        captureSource: root.shown ? (tile.modelData.wayland ?? null) : null
                        live: root.cfg.live ?? true
                        constraintSize: Qt.size(width, height)
                    }

                    // Fallback when capture isn't available (e.g. the client hasn't drawn yet).
                    IconImage {
                        anchors.centerIn: parent
                        visible: !capture.hasContent
                        implicitSize: Math.min(parent.width, parent.height) * 0.35
                        source: root.iconFor(tile.modelData)
                    }
                }

                Rectangle {
                    width: thumb.width
                    height: thumb.height
                    radius: Theme.cardRounding
                    color: "transparent"
                    border.width: tile.current ? 3 : mouse.containsMouse ? 2 : 0
                    border.color: tile.current ? Theme.m3primary : Theme.alpha(Theme.m3onSurface, 0.4)
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: tile.l.h + 8
                    spacing: 8
                    width: Math.min(implicitWidth, tile.width)

                    IconImage {
                        implicitSize: 18
                        source: root.iconFor(tile.modelData)
                    }

                    StyledText {
                        width: Math.min(implicitWidth, tile.width - 26)
                        text: tile.modelData.title || (tile.modelData.lastIpcObject?.class ?? "")
                        color: tile.current ? Theme.m3primary : Theme.m3onSurface
                        font.weight: tile.current ? 600 : 400
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: mouse

                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.selected = tile.index
                    onClicked: e => {
                        if (e.button === Qt.MiddleButton)
                            root.closeWindow(tile.modelData);
                        else
                            root.focusWindow(tile.modelData);
                    }
                }
            }
        }
    }

    // Window list changes while open (a window closed or opened): refresh IPC data.
    Connections {
        target: Hyprland
        enabled: root.shown

        function onRawEvent(event) {
            if (["openwindow", "closewindow", "movewindow", "movewindowv2", "windowtitle", "windowtitlev2"].includes(event.name))
                Hyprland.refreshToplevels();
        }
    }
}
