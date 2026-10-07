import QtQuick
import QtQuick.Layouts

Drawer {
    id: win

    property bool editing: false
    readonly property bool whitelist: cfg.newReadingsVisible === false
    readonly property var labels: cfg.labels ?? ({})
    readonly property var thresholds: cfg.thresholds ?? ({})
    // Built from entries only (not values), so it's stable across polls.
    readonly property var groups: {
        const out = [], idx = {};
        for (const r of CoolerControl.entries) {
            if (!editing && !shown(r.key))
                continue;
            if (!(r.device in idx)) {
                idx[r.device] = out.length;
                out.push({
                    device: r.device,
                    items: []
                });
            }
            out[idx[r.device]].items.push(r);
        }
        const readingOrder = cfg.readingOrder ?? {};
        for (const g of out)
            g.items = ordered(g.items, r => r.key, readingOrder[g.device]);
        return ordered(out, g => g.device, cfg.deviceOrder);
    }

    // Listed keys first in their saved order; anything unlisted (e.g. a new sensor) keeps its natural order after.
    function ordered(items, keyOf, order) {
        const rank = k => {
            const i = (order ?? []).indexOf(k);
            return i < 0 ? Infinity : i;
        };
        return items.map((x, n) => [x, n]).sort((a, b) => (rank(keyOf(a[0])) - rank(keyOf(b[0]))) || a[1] - b[1]).map(p => p[0]);
    }

    function swapped(list, i, dir) {
        const l = list.slice();
        [l[i], l[i + dir]] = [l[i + dir], l[i]];
        return l;
    }

    function shown(key) {
        return whitelist ? (cfg.shown ?? []).includes(key) : !(cfg.hidden ?? []).includes(key);
    }

    function limits(key) {
        const t = thresholds[key] ?? {};
        return {
            warn: t.warn ?? cfg.warnTemp ?? 75,
            crit: t.crit ?? cfg.critTemp ?? 90
        };
    }

    function valueText(r, v) {
        if (!v)
            return "–";
        switch (r.kind) {
        case "temp":
            {
                const f = cfg.tempUnit === "F";
                return (f ? v.value * 9 / 5 + 32 : v.value).toFixed(cfg.tempDecimals ?? 1) + (f ? "°F" : "°C");
            }
        case "fan":
            return Math.round(v.value) + " rpm" + (v.duty != null ? " · " + Math.round(v.duty) + "%" : "");
        case "power":
            return v.value.toFixed(0) + " W";
        case "freq":
            return v.value >= 1000 ? (v.value / 1000).toFixed(2) + " GHz" : Math.round(v.value) + " MHz";
        default:
            return Math.round(v.value) + "%";
        }
    }

    // 0..1 bar fill, or -1 for no bar.
    function barValue(r, v) {
        if (!v)
            return -1;
        const max = (cfg.barMax ?? {})[r.key];
        if (max)
            return v.value / max;
        switch (r.kind) {
        case "temp":
            return v.value / limits(r.key).crit;
        case "fan":
            return v.duty != null ? v.duty / 100 : -1;
        case "duty":
            return v.value / 100;
        default:
            return -1;
        }
    }

    function levelColour(r, v) {
        if (r.kind !== "temp" || !v)
            return Theme.m3primary;
        const l = limits(r.key);
        return v.value >= l.crit ? Theme.m3error : v.value >= l.warn ? Theme.m3tertiary : Theme.m3primary;
    }

    cfg: Config.coolercontrol
    ns: "coolercontrol"
    holdOpen: editing
    keyboard: editing

    RowLayout {
        width: parent.width

        EditableText {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            text: win.cfg.title ?? "CoolerControl"
            editing: win.editing
            pixelSize: Theme.fontLarge
            weight: 600
            onEdited: t => Config.setValue("coolercontrol", "title", t)
        }

        IconButton {
            icon: win.editing ? "check" : "settings-2"
            colour: win.editing ? Theme.m3primary : Theme.m3onSurfaceVariant
            visible: win.cfg.showEditButton ?? true
            onClicked: win.editing = !win.editing
        }

        PinButton {
            pinned: win.pinned
            visible: (win.cfg.mode ?? "hover") !== "always"
            onClicked: win.togglePin()
        }
    }

    StyledText {
        width: parent.width
        visible: text !== ""
        text: win.editing ? "Tick to show / hide, arrows to reorder, edit names in place (empty = default)" : Config.error || CoolerControl.error || (CoolerControl.entries.length ? "" : "Waiting for CoolerControl…")
        color: !win.editing && (Config.error || CoolerControl.error) ? Theme.m3error : Theme.m3onSurfaceVariant
        font.pixelSize: Theme.fontSmall
        wrapMode: Text.Wrap
    }

    Flickable {
        width: parent.width
        height: Math.min(cards.implicitHeight, win.cfg.maxHeight ?? Math.round(win.modelData.height * 0.75))
        contentHeight: cards.implicitHeight
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: cards

            width: parent.width
            spacing: Theme.spacing / 2

            Repeater {
                model: win.groups

                Card {
                    id: group

                    required property var modelData
                    required property int index
                    readonly property string deviceKey: "@" + modelData.device

                    spacing: 6

                    RowLayout {
                        width: parent.width
                        visible: win.editing || (win.cfg.showDeviceNames ?? true)
                        spacing: 8

                        CheckIcon {
                            visible: win.editing
                            checked: group.modelData.items.some(r => win.shown(r.key))
                            onClicked: Config.setReadingsVisible(group.modelData.items.map(r => r.key), !checked)
                        }

                        EditableText {
                            Layout.fillWidth: true
                            text: win.labels[group.deviceKey] ?? group.modelData.device
                            editing: win.editing
                            colour: Theme.m3primary
                            pixelSize: Theme.fontSmall
                            weight: 600
                            onEdited: t => Config.setLabel(group.deviceKey, t)
                        }

                        MoveButtons {
                            visible: win.editing
                            canUp: group.index > 0
                            canDown: group.index < win.groups.length - 1
                            onMoved: dir => Config.setOrder(null, win.swapped(win.groups.map(g => g.device), group.index, dir))
                        }
                    }

                    GridLayout {
                        width: parent.width
                        columns: win.cfg.columns ?? 1
                        columnSpacing: 14
                        rowSpacing: 6

                        Repeater {
                            model: group.modelData.items

                            ColumnLayout {
                                id: row

                                required property var modelData
                                required property int index
                                readonly property var v: CoolerControl.values[modelData.key]
                                readonly property bool on: win.shown(modelData.key)
                                readonly property real bar: win.barValue(modelData, v)

                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                spacing: 3
                                opacity: on ? 1 : 0.45

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    CheckIcon {
                                        visible: win.editing
                                        checked: row.on
                                        onClicked: Config.setReadingsVisible([row.modelData.key], !checked)
                                    }

                                    EditableText {
                                        Layout.fillWidth: true
                                        text: win.labels[row.modelData.key] ?? row.modelData.label
                                        editing: win.editing
                                        colour: Theme.m3onSurfaceVariant
                                        onEdited: t => Config.setLabel(row.modelData.key, t)
                                    }

                                    StyledText {
                                        text: win.valueText(row.modelData, row.v)
                                        color: row.modelData.kind === "temp" ? win.levelColour(row.modelData, row.v) : Theme.m3onSurface
                                        font.family: Theme.monoFont
                                        font.weight: 600
                                    }

                                    MoveButtons {
                                        visible: win.editing
                                        canUp: row.index > 0
                                        canDown: row.index < group.modelData.items.length - 1
                                        onMoved: dir => Config.setOrder(group.modelData.device, win.swapped(group.modelData.items.map(r => r.key), row.index, dir))
                                    }
                                }

                                Rectangle {
                                    visible: (win.cfg.showBars ?? true) && row.bar >= 0
                                    Layout.fillWidth: true
                                    implicitHeight: 4
                                    radius: 2
                                    color: Theme.m3surfaceContainerHigh

                                    Rectangle {
                                        width: parent.width * Math.max(0, Math.min(1, row.bar))
                                        height: parent.height
                                        radius: 2
                                        color: win.levelColour(row.modelData, row.v)

                                        Behavior on width {
                                            NumberAnimation {
                                                duration: 400
                                                easing.type: Easing.OutCubic
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
