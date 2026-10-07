import QtQuick

// Plain text normally; an inline text field while `editing`. Emits `edited` on Enter or focus loss.
Item {
    id: root

    property string text
    property bool editing
    property color colour: Theme.m3onSurface
    property int pixelSize: Theme.fontSize
    property int weight: 400

    signal edited(string text)

    onTextChanged: if (!input.activeFocus) input.text = text

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight + (editing ? 4 : 0)

    StyledText {
        id: label

        width: parent.width
        visible: !root.editing
        text: root.text
        color: root.colour
        font.pixelSize: root.pixelSize
        font.weight: root.weight
        elide: Text.ElideRight
    }

    TextInput {
        id: input

        width: parent.width
        visible: root.editing
        color: root.colour
        selectionColor: Theme.m3primary
        selectedTextColor: Theme.m3onPrimary
        font.family: Theme.font
        font.pixelSize: root.pixelSize
        font.weight: root.weight
        clip: true
        selectByMouse: true
        Component.onCompleted: text = root.text
        onEditingFinished: if (text !== root.text) root.edited(text)
        Keys.onEscapePressed: {
            text = root.text;
            focus = false;
        }
    }

    Rectangle {
        visible: root.editing
        anchors.top: input.bottom
        anchors.topMargin: 1
        width: parent.width
        height: 1
        color: input.activeFocus ? Theme.m3primary : Theme.m3outlineVariant
    }
}
