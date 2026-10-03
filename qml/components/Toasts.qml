// Top-right notification toasts. Main.qml calls show(title, body, icon).
import QtQuick
import "../ui"

Item {
    id: toasts
    width: UI.px(340)

    ListModel { id: toastModel }
    property var actions: ({})          // stamp -> function (ListModel can't hold functions)
    property double seq: 0

    function show(title, body, icon, action) {
        var stamp = Date.now() + (++seq) / 1000
        if (typeof action === "function") actions[stamp] = action
        toastModel.insert(0, { title: title || "", body: body || "", icon: icon || "bell", stamp: stamp,
                               hasAction: typeof action === "function" })
        while (toastModel.count > 4) toastModel.remove(toastModel.count - 1)
    }

    Column {
        width: parent.width
        spacing: 8
        move: Transition { NumberAnimation { properties: "y"; duration: UI.dur(180); easing.type: Easing.OutCubic } }
        Repeater {
            model: toastModel
            delegate: Item {
                id: toast
                width: toasts.width
                height: card.height
                property bool leaving: false
                Component.onCompleted: { if (UI.animations) inAnim.start() }
                NumberAnimation { id: inAnim; target: card; property: "x"; from: toasts.width + 20; to: 0; duration: 260; easing.type: Easing.OutCubic }
                NumberAnimation {
                    id: outAnim; target: card; property: "opacity"; to: 0; duration: UI.dur(180)
                    onFinished: {
                        delete toasts.actions[stamp]
                        for (var i = 0; i < toastModel.count; i++) if (toastModel.get(i).stamp === stamp) { toastModel.remove(i); break }
                    }
                }
                Timer { interval: 4800; running: !hover.containsMouse; onTriggered: outAnim.start() }

                Rectangle {
                    id: card
                    width: parent.width
                    height: content.implicitHeight + 24
                    radius: UI.radius
                    color: Qt.rgba(0.09, 0.11, 0.16, 0.95)
                    border.color: UI.borderStrong
                    Rectangle { width: 3; height: parent.height - 20; anchors.verticalCenter: parent.verticalCenter; x: 0; radius: 1.5; color: UI.accent }
                    Row {
                        id: content
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        anchors.leftMargin: 16
                        spacing: 12
                        Icon { name: icon; size: UI.px(24) }
                        Column {
                            width: parent.width - UI.px(40)
                            spacing: 2
                            Text { width: parent.width; text: title; color: UI.text; font.pixelSize: UI.px(13); font.weight: Font.DemiBold; elide: Text.ElideRight }
                            Text { font.weight: UI.textWeight; width: parent.width; text: body; visible: body !== ""; color: UI.textDim; font.pixelSize: UI.px(12); wrapMode: Text.Wrap; maximumLineCount: 4; elide: Text.ElideRight }
                        }
                    }
                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var act = toasts.actions[stamp]
                            outAnim.start()
                            if (act) act()
                        }
                    }
                    Text {
                        elide: Text.ElideRight
                        font.weight: UI.textWeight
                        visible: hasAction
                        anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 8
                        text: "Click to open"
                        color: UI.accent; font.pixelSize: UI.px(10.5)
                    }
                }
            }
        }
    }
}
