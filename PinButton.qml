import QtQuick

IconButton {
    id: root

    property bool pinned

    icon: "pin"
    size: 15
    colour: pinned ? Theme.m3onPrimary : Theme.m3onSurfaceVariant

    Rectangle {
        z: -1
        anchors.fill: parent
        radius: width / 2
        color: Theme.m3primary
        visible: root.pinned
    }
}
