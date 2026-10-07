import QtQuick
import QtQuick.Layouts
import Quickshell

Drawer {
    id: win

    readonly property var loc: Qt.locale(cfg.locale ?? "")
    readonly property int firstDay: cfg.firstDayOfWeek ?? 1 // 0 = Sunday
    readonly property var weekend: cfg.weekendDays ?? [0, 6]
    readonly property date today: clock.date
    readonly property string todayKey: key(today)
    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()
    property string selected: ""
    readonly property real cellW: (panelW - Theme.padding * 2 - Theme.cardPadding * 2) / 7
    readonly property real cellH: cfg.cellHeight ?? Math.round(cellW * 0.8)

    readonly property var cells: {
        const first = new Date(viewYear, viewMonth, 1);
        const offset = (first.getDay() - firstDay + 7) % 7;
        const out = [];
        for (let i = 0; i < 42; i++)
            out.push(new Date(viewYear, viewMonth, 1 - offset + i));
        return out;
    }

    // Flat list of {header} and {ev} rows for the selected day or the upcoming range.
    readonly property var listRows: {
        const rows = [];
        if (selected) {
            for (const e of CalendarData.byDate[selected] ?? [])
                rows.push({
                    ev: e
                });
            return rows;
        }
        const max = cfg.maxUpcoming ?? 8;
        let n = 0;
        for (let i = 0; i < (cfg.upcomingDays ?? 14) && n < max; i++) {
            const d = new Date(today.getFullYear(), today.getMonth(), today.getDate() + i);
            const evs = CalendarData.byDate[key(d)] ?? [];
            if (!evs.length)
                continue;
            rows.push({
                header: i === 0 ? "Today" : i === 1 ? "Tomorrow" : d.toLocaleDateString(loc, cfg.dateFormat ?? "ddd d MMM")
            });
            for (const e of evs) {
                if (n++ >= max)
                    break;
                rows.push({
                    ev: e
                });
            }
        }
        return rows;
    }

    function key(d) {
        return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0");
    }

    function shift(n) {
        const m = viewMonth + n;
        viewYear += Math.floor(m / 12);
        viewMonth = (m % 12 + 12) % 12;
        selected = "";
    }

    function resetView() {
        viewYear = today.getFullYear();
        viewMonth = today.getMonth();
        selected = "";
    }

    function evColour(e) {
        return e.color || (e.holiday ? Theme.holiday : Theme.m3primary);
    }

    function hm(s) {
        if (!s || cfg.timeFormat !== "12h")
            return s;
        const [h, m] = s.split(":").map(Number);
        return (h % 12 || 12) + ":" + String(m).padStart(2, "0") + (h < 12 ? " AM" : " PM");
    }

    function timeText(e) {
        if (e.allDay)
            return "All day";
        if (!e.start)
            return e.end ? "until " + hm(e.end) : "continues";
        return hm(e.start) + (e.end ? " – " + hm(e.end) : "");
    }

    cfg: Config.calendar
    ns: "calendar"

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    Card {
        RowLayout {
            width: parent.width
            spacing: 2

            StyledText {
                Layout.fillWidth: true
                text: win.loc.standaloneMonthName(win.viewMonth) + " " + win.viewYear
                font.pixelSize: Theme.fontLarge
                font.weight: 600

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: win.resetView()
                }
            }

            IconButton {
                icon: "refresh-cw"
                size: 15
                opacity: CalendarData.loading ? 0.4 : 1
                onClicked: CalendarData.refresh()
            }

            IconButton {
                icon: "chevron-left"
                onClicked: win.shift(-1)
            }

            IconButton {
                icon: "chevron-right"
                onClicked: win.shift(1)
            }

            PinButton {
                pinned: win.pinned
                visible: (win.cfg.mode ?? "hover") !== "always"
                onClicked: win.togglePin()
            }
        }

        Row {
            Repeater {
                model: 7

                StyledText {
                    required property int index
                    readonly property int dow: (win.firstDay + index) % 7

                    width: win.cellW
                    horizontalAlignment: Text.AlignHCenter
                    text: win.loc.dayName(dow, Locale.ShortFormat)
                    color: win.weekend.includes(dow) ? Theme.holiday : Theme.m3onSurfaceVariant
                    font.pixelSize: Theme.fontSmall
                    font.weight: 600
                }
            }
        }

        Grid {
            columns: 7

            WheelHandler {
                onWheel: e => win.shift(e.angleDelta.y > 0 ? -1 : 1)
            }

            Repeater {
                model: win.cells

                Item {
                    id: cell

                    required property var modelData
                    readonly property string k: win.key(modelData)
                    readonly property var evs: CalendarData.byDate[k] ?? []
                    readonly property bool inMonth: modelData.getMonth() === win.viewMonth
                    readonly property bool isToday: k === win.todayKey
                    readonly property bool holiday: evs.some(e => e.holiday)

                    width: win.cellW
                    height: win.cellH

                    Rectangle {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -2
                        width: Math.min(parent.width, parent.height) - 4
                        height: width
                        radius: width / 2
                        color: cell.isToday ? Theme.m3primary : hover.hovered ? Theme.alpha(Theme.m3onSurface, 0.08) : "transparent"
                        border.width: cell.k === win.selected ? 1.5 : 0
                        border.color: Theme.m3primary
                    }

                    StyledText {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -2
                        text: cell.modelData.getDate()
                        opacity: cell.inMonth ? 1 : 0.35
                        font.weight: cell.isToday ? 700 : 400
                        color: cell.isToday ? Theme.m3onPrimary : cell.holiday || win.weekend.includes(cell.modelData.getDay()) ? Theme.holiday : Theme.m3onSurface
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 1
                        spacing: 2
                        opacity: cell.inMonth ? 1 : 0.35

                        Repeater {
                            model: cell.evs.slice(0, 3)

                            Rectangle {
                                required property var modelData

                                width: 4
                                height: 4
                                radius: 2
                                color: win.evColour(modelData)
                            }
                        }
                    }

                    HoverHandler {
                        id: hover

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: win.selected = win.selected === cell.k ? "" : cell.k
                    }
                }
            }
        }
    }

    Card {
        visible: win.cfg.showEventList ?? true
        spacing: 6

        StyledText {
            text: win.selected ? new Date(win.selected + "T00:00").toLocaleDateString(win.loc, "dddd d MMMM yyyy") : "Upcoming"
            font.weight: 600
        }

        StyledText {
            visible: win.listRows.length === 0
            text: "No events"
            color: Theme.m3onSurfaceVariant
            font.pixelSize: Theme.fontSmall
        }

        Repeater {
            model: win.listRows

            Item {
                id: entry

                required property var modelData

                width: parent.width
                implicitHeight: modelData.header ? headerText.implicitHeight + 2 : evRow.implicitHeight

                StyledText {
                    id: headerText

                    visible: !!entry.modelData.header
                    text: entry.modelData.header ?? ""
                    color: Theme.m3primary
                    font.pixelSize: Theme.fontSmall
                    font.weight: 600
                }

                RowLayout {
                    id: evRow

                    visible: !!entry.modelData.ev
                    width: parent.width
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: 3
                        Layout.fillHeight: true
                        radius: 2
                        color: entry.modelData.ev ? win.evColour(entry.modelData.ev) : "transparent"
                    }

                    Column {
                        Layout.fillWidth: true

                        StyledText {
                            width: parent.width
                            text: entry.modelData.ev?.title ?? ""
                            elide: Text.ElideRight
                        }

                        StyledText {
                            width: parent.width
                            visible: win.cfg.showEventDetails ?? true
                            text: entry.modelData.ev ? win.timeText(entry.modelData.ev) + " · " + entry.modelData.ev.source : ""
                            color: Theme.m3onSurfaceVariant
                            font.pixelSize: Theme.fontSmall
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }

    StyledText {
        width: parent.width
        visible: (win.cfg.showErrors ?? true) && (CalendarData.errors.length > 0 || Config.error !== "")
        text: [Config.error].concat(CalendarData.errors).filter(s => s).join("\n")
        color: Theme.m3error
        font.pixelSize: Theme.fontSmall - 1
        wrapMode: Text.Wrap
    }
}
