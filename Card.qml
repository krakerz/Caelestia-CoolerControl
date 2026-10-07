import QtQuick

// Inner card, like Caelestia's utilities cards.
Rectangle {
    id: root

    default property alias content: column.data
    property alias spacing: column.spacing

    width: parent?.width ?? 0
    implicitHeight: column.implicitHeight + Theme.cardPadding * 2
    color: Theme.m3surfaceContainer
    radius: Theme.cardRounding

    Column {
        id: column

        x: Theme.cardPadding
        y: Theme.cardPadding
        width: root.width - Theme.cardPadding * 2
        spacing: 8
    }
}
