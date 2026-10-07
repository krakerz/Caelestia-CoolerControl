import QtQuick
import QtQuick.Layouts

Image {
    id: root

    property bool checked

    signal clicked

    Layout.preferredWidth: 16
    Layout.preferredHeight: 16
    width: 16
    height: 16
    sourceSize: Qt.size(32, 32)
    source: Icons.url(checked ? "square-check" : "square", Theme.m3primary)

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
