import QtQuick

Item {
    id: root

    property string icon
    property color colour: Theme.m3onSurfaceVariant
    property real size: 18

    signal clicked

    implicitWidth: size + 10
    implicitHeight: size + 10

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Theme.m3onSurface
        opacity: mouse.containsMouse ? 0.1 : 0
    }

    Image {
        anchors.centerIn: parent
        width: root.size
        height: root.size
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        source: Icons.url(root.icon, root.colour)
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
