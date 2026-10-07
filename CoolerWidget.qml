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
        return out;
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
        text: win.editing ? "Tick to show / hide, edit names in place (empty = default)" : Config.error || CoolerControl.error || (CoolerControl.entries.length ? "" : "Waiting for CoolerControl…")
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
