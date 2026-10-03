// In-window modal dialog. Place as the last child of an app and call:
//   dialog.ask({ title: "Rename", message: "", input: true, text: "old.txt",
//                buttons: [{ text: "Cancel", value: "cancel" }, { text: "Rename", value: "ok", kind: "primary" }] },
//              function (value, text) { ... })
// Enter triggers the primary button, Escape the first one.
import QtQuick
import QtQuick.Controls
import "../ui"

FocusScope {
    id: dlg
    anchors.fill: parent
    visible: false
    z: 1000

    property string title: ""
    property string message: ""
    property string icon: ""
    property bool hasInput: false
    property var buttons: []
    property var callback: null
    property string selectStem: ""   // when renaming "a.txt", only "a" gets selected

    property var pending: []          // requests that arrived while a dialog was showing

    function ask(opts, cb) {
        opts = opts || {}
        if (visible) { pending = pending.concat([{ opts: opts, cb: cb }]); return }
        title = opts.title || ""
        message = opts.message || ""
        icon = opts.icon || ""
        hasInput = !!opts.input
        field.text = opts.text || ""
        field.placeholderText = opts.placeholder || ""
        buttons = opts.buttons || [{ text: "OK", value: "ok", kind: "primary" }]
        callback = cb || null
        visible = true
        card.scale = 0.96
        popAnim.restart()
        if (hasInput) {
            field.forceActiveFocus()
            var t = field.text, dot = t.lastIndexOf(".")
            if (opts.selectStem && dot > 0) field.select(0, dot)
            else field.selectAll()
        } else {
            dlg.forceActiveFocus()
        }
    }

    function finish(value) {
        if (!visible) return
        visible = false
        var cb = callback, text = field.text
        callback = null
        try {
            if (cb) cb(value, text)
        } catch (e) {
            console.warn("GDialog callback failed:", e)
        }
        if (pending.length) {
            var next = pending[0]
            pending = pending.slice(1)
            ask(next.opts, next.cb)
        }
    }

    function primaryValue() {
        for (var i = 0; i < buttons.length; i++) if (buttons[i].kind === "primary") return buttons[i].value
        return buttons.length ? buttons[buttons.length - 1].value : "ok"
    }

    Keys.onEscapePressed: finish(buttons.length ? buttons[0].value : "cancel")
    Keys.onReturnPressed: finish(primaryValue())
    Keys.onEnterPressed: finish(primaryValue())

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.AllButtons
            onWheel: function (wheel) { wheel.accepted = true }
        }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, UI.px(400))
        height: col.implicitHeight + 40
        radius: UI.radiusLarge
        color: "#1a2030"
        border.color: UI.borderStrong

        NumberAnimation { id: popAnim; target: card; property: "scale"; to: 1; duration: UI.dur(140); easing.type: Easing.OutBack }

        Column {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 20
            spacing: 14

            Row {
                spacing: 10
                width: parent.width
                Icon { name: dlg.icon; size: UI.px(22); visible: dlg.icon !== "" }
                Text {
                    width: parent.width - 40
                    text: dlg.title
                    color: UI.text
                    font.pixelSize: UI.px(16)
                    font.weight: Font.DemiBold
                    wrapMode: Text.Wrap
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            Text {
                font.weight: UI.textWeight
                visible: dlg.message !== ""
                width: parent.width
                text: dlg.message
                color: UI.textDim
                font.pixelSize: UI.px(13)
                wrapMode: Text.Wrap
                lineHeight: 1.2
            }
            GTextField {
                id: field
                visible: dlg.hasInput
                width: parent.width
                Keys.onEscapePressed: dlg.finish(dlg.buttons.length ? dlg.buttons[0].value : "cancel")
                onAccepted: dlg.finish(dlg.primaryValue())
            }
            Row {
                anchors.right: parent.right
                spacing: 8
                Repeater {
                    model: dlg.buttons
                    GButton {
                        text: modelData.text
                        kind: modelData.kind || "normal"
                        onClicked: dlg.finish(modelData.value)
                    }
                }
            }
        }
    }
}
