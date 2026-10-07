import QtQuick

// Up/down arrows for reordering in edit mode.
Row {
    id: root

    property bool canUp: true
    property bool canDown: true

    signal moved(int dir)

    spacing: -4

    IconButton {
        icon: "chevron-up"
        size: 14
        opacity: root.canUp ? 1 : 0.3
        enabled: root.canUp
        onClicked: root.moved(-1)
    }

    IconButton {
        icon: "chevron-down"
        size: 14
        opacity: root.canDown ? 1 : 0.3
        enabled: root.canDown
        onClicked: root.moved(1)
    }
}
