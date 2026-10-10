import QtQuick
import QtQuick.Layouts

// Countdown timer. Stays out (no auto-hide) from Start until it has finished and flashed for hideAfter seconds.
Drawer {
    id: win

    readonly property var t: TimerState
    readonly property bool idle: t.state === "idle"
    readonly property bool finished: t.state === "finished"
    readonly property bool running: t.state === "running"
    readonly property bool paused: t.state === "paused"
    property bool typing: false

    function commitTyped(text) {
        const s = TimerState.parse(text);
        if (s > 0)
            TimerState.setDuration(s);
        typing = false;
    }

    cfg: Config.data.timer ?? ({})
    ns: "timer"
    holdOpen: !idle || typing
    // flashColour: "#rrggbb" or a scheme colour name ("primary", "error", ...), so it follows the scheme.
    flashColour: String(cfg.flashColour ?? "primary").startsWith("#") ? cfg.flashColour : Theme.c(cfg.flashColour ?? "primary", Theme.m3primary)
    flashStrength: Math.max(0, Math.min(1, cfg.flashStrength ?? 0.45))
    keyboard: typing

    // Finished: pulse the panel towards the primary colour.
    SequentialAnimation {
        running: win.finished && (win.cfg.flash ?? true)
        loops: Animation.Infinite
        onRunningChanged: if (!running)
            win.flash = 0

        NumberAnimation {
            target: win
            property: "flash"
            to: 1
            duration: Math.max(100, win.cfg.flashSpeed ?? 900) / 2
            easing.type: Easing.InOutSine
        }

        NumberAnimation {
            target: win
            property: "flash"
            to: 0
            duration: Math.max(100, win.cfg.flashSpeed ?? 900) / 2
            easing.type: Easing.InOutSine
        }
    }

    // Idle: title, −/time/+ and play, presets. Running: just the countdown and pause.
    // Paused: countdown, resume and cancel. Finished: "Done" and dismiss.
    Card {
        spacing: 8

        RowLayout {
            width: parent.width
            visible: win.idle

            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: 2
                text: win.cfg.title ?? "Timer"
                font.weight: 600
            }

            PinButton {
                pinned: win.pinned
                visible: (win.cfg.mode ?? "hover") !== "always"
                onClicked: win.togglePin()
            }
        }

        RowLayout {
            width: parent.width
            spacing: 6

            IconButton {
                icon: "minus"
                visible: win.idle
                onClicked: TimerState.adjust(-60)
            }

            // Time: wheel adjusts by a minute (Shift: 10 s); click to type when not running.
            Item {
                Layout.fillWidth: true
                implicitHeight: display.implicitHeight

                StyledText {
                    id: display

                    anchors.left: win.idle ? undefined : parent.left
                    anchors.horizontalCenter: win.idle ? parent.horizontalCenter : undefined
                    anchors.leftMargin: 4
                    visible: !win.typing
                    text: win.finished ? "Done" : TimerState.format(TimerState.remaining)
                    color: win.finished ? Theme.m3primary : win.paused ? Theme.m3onSurfaceVariant : Theme.m3onSurface
                    font.family: Theme.monoFont
                    font.pixelSize: Math.round(Theme.fontSize * (win.cfg.timeScale ?? 2.2))
                    font.weight: 600
                }

                TextInput {
                    id: input

                    width: parent.width
                    visible: win.typing
                    horizontalAlignment: TextInput.AlignHCenter
                    color: Theme.m3primary
                    font.family: Theme.monoFont
                    font.pixelSize: Math.round(Theme.fontSize * (win.cfg.timeScale ?? 2.2))
                    font.weight: 600
                    selectByMouse: true
                    onAccepted: win.commitTyped(text)
                    onActiveFocusChanged: if (!activeFocus && win.typing)
                        win.commitTyped(text)
                    Keys.onEscapePressed: win.typing = false
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !win.typing && (win.idle || win.paused)
                    cursorShape: enabled ? Qt.IBeamCursor : Qt.ArrowCursor
                    onClicked: {
                        win.typing = true;
                        input.text = TimerState.format(TimerState.remaining);
                        input.selectAll();
                        input.forceActiveFocus();
                    }
                }

                WheelHandler {
                    enabled: !win.finished
                    onWheel: e => TimerState.adjust((e.angleDelta.y > 0 ? 1 : -1) * (e.modifiers & Qt.ShiftModifier ? 10 : 60))
                }
            }

            IconButton {
                icon: "plus"
                visible: win.idle
                onClicked: TimerState.adjust(60)
            }

            // Cancel (paused only), secondary style.
            Rectangle {
                visible: win.paused
                implicitWidth: 30
                implicitHeight: 30
                radius: width / 2
                color: cancelMouse.containsMouse ? Theme.m3outlineVariant : Theme.m3surfaceContainerHigh

                Image {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    sourceSize: Qt.size(28, 28)
                    source: Icons.url("x", Theme.m3onSurface)
                }

                MouseArea {
                    id: cancelMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: TimerState.reset()
                }
            }

            // Primary: play (idle/paused), pause (running), dismiss (finished).
            Rectangle {
                implicitWidth: 36
                implicitHeight: 36
                radius: width / 2
                color: playMouse.containsMouse ? Qt.lighter(Theme.m3primary, 1.08) : Theme.m3primary

                Image {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    sourceSize: Qt.size(32, 32)
                    source: Icons.url(win.finished ? "x" : win.running ? "pause" : "play", Theme.m3onPrimary)
                }

                MouseArea {
                    id: playMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: win.finished ? TimerState.reset() : TimerState.toggle()
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 4
            radius: 2
            visible: win.running || win.paused
            color: Theme.m3surfaceContainerHigh

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, TimerState.progress))
                height: parent.height
                radius: 2
                color: Theme.m3primary

                Behavior on width {
                    NumberAnimation {
                        duration: 250
                    }
                }
            }
        }

        // Up to three presets (minutes).
        RowLayout {
            width: parent.width
            spacing: 8
            visible: win.idle && (win.cfg.presets ?? [3, 5, 15]).length > 0

            Repeater {
                model: (win.cfg.presets ?? [3, 5, 15]).slice(0, 3)

                Rectangle {
                    id: chip

                    required property var modelData
                    readonly property bool active: TimerState.duration === modelData * 60

                    Layout.fillWidth: true
                    implicitHeight: chipText.implicitHeight + 8
                    radius: height / 2
                    color: active ? Theme.m3primary : chipMouse.containsMouse ? Theme.m3surfaceContainerHigh : "transparent"
                    border.width: active ? 0 : 1
                    border.color: Theme.m3outlineVariant

                    StyledText {
                        id: chipText

                        anchors.centerIn: parent
                        text: chip.modelData >= 60 && chip.modelData % 60 === 0 ? chip.modelData / 60 + " h" : chip.modelData + " min"
                        color: chip.active ? Theme.m3onPrimary : Theme.m3onSurface
                        font.pixelSize: Theme.fontSmall
                        font.weight: 600
                    }

                    MouseArea {
                        id: chipMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: TimerState.setDuration(chip.modelData * 60)
                    }
                }
            }
        }
    }
}
