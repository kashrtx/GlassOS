// In-window file picker for the GlassOS storage.
//   picker.openFile({ title: "Open", folder: "/Documents", kinds: ["text", "code"] }, function (path) { ... })
//   picker.saveFile({ title: "Save as", folder: "/Documents", name: "Untitled.txt" }, function (path) { ... })
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../ui"

FocusScope {
    id: picker
    anchors.fill: parent
    visible: false
    z: 900

    property string mode: "open"
    property string title: "Open"
    property string folder: "/Documents"
    property var kinds: []
    property var entries: []
    property string chosen: ""
    property var callback: null

    function openFile(opts, cb) { start("open", opts, cb) }
    function saveFile(opts, cb) { start("save", opts, cb) }

    function start(m, opts, cb) {
        mode = m
        title = opts.title || (m === "save" ? "Save as" : "Open")
        kinds = opts.kinds || []
        callback = cb
        nameField.text = opts.name || ""
        chosen = ""
        go(opts.folder && Storage.isDir(opts.folder) ? opts.folder : "/Documents")
        visible = true
        if (m === "save") { nameField.forceActiveFocus(); var dot = nameField.text.lastIndexOf("."); nameField.select(0, dot > 0 ? dot : nameField.text.length) }
        else picker.forceActiveFocus()
    }

    function go(p) {
        folder = p
        var all = Storage.list(p)
        entries = all.filter(function (e) { return e.isDir || kinds.length === 0 || kinds.indexOf(e.kind) >= 0 })
        chosen = ""
    }

    function cancel() { visible = false; callback = null }

    function accept() {
        var path = ""
        if (mode === "save") {
            var name = nameField.text.trim()
            if (!name) return
            if (!Storage.isValidName(name)) { errorText.text = "That name isn't allowed."; return }
            path = Storage.join(folder, name)
            if (Storage.isDir(path)) { go(path); return }
            if (Storage.exists(path) && confirmOverwrite.pending !== path) {
                confirmOverwrite.pending = path
                errorText.text = "“" + name + "” exists — press Save again to replace it."
                return
            }
        } else {
            if (!chosen) return
            if (Storage.isDir(chosen)) { go(chosen); return }
            path = chosen
        }
        visible = false
        var cb = callback
        callback = null
        if (cb) cb(path)
    }

    QtObject { id: confirmOverwrite; property string pending: "" }

    Keys.onEscapePressed: cancel()

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onWheel: function (wheel) { wheel.accepted = true } }
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - 30, UI.px(560))
        height: Math.min(parent.height - 30, UI.px(440))
        radius: UI.radiusLarge
        color: "#171c28"
        border.color: UI.borderStrong

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Text { elide: Text.ElideRight; text: picker.title; color: UI.text; font.pixelSize: UI.px(16); font.weight: Font.DemiBold; Layout.fillWidth: true }
                IconButton { iconName: "close"; onClicked: picker.cancel() }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                IconButton { iconName: "up"; tip: "Up"; enabled: picker.folder !== "/"; onClicked: picker.go(Storage.parentOf(picker.folder)) }
                Text { font.weight: UI.textWeight; text: picker.folder; color: UI.textDim; font.pixelSize: UI.px(12.5); Layout.fillWidth: true; elide: Text.ElideMiddle }
                Repeater {
                    model: Storage.specialFolders()
                    IconButton { iconName: modelData.icon; glyphSize: 15; tip: modelData.name; active: picker.folder === modelData.path; onClicked: picker.go(modelData.path) }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: UI.radiusSmall
                color: UI.field
                border.color: UI.border
                ListView {
                    id: listView
                    anchors.fill: parent
                    anchors.margins: 4
                    clip: true
                    model: picker.entries
                    ScrollBar.vertical: GScrollBar {}
                    delegate: Rectangle {
                        width: listView.width
                        height: UI.px(30)
                        radius: 4
                        color: picker.chosen === modelData.path ? UI.accentSoft : (rowMouse.containsMouse ? UI.hover : "transparent")
                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8
                            Icon { name: modelData.icon; size: UI.px(14) }
                            Text { font.weight: UI.textWeight; text: modelData.name; color: UI.text; font.pixelSize: UI.px(12.5) }
                        }
                        Text {
                            elide: Text.ElideRight
                            font.weight: UI.textWeight
                            anchors.right: parent.right; anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.isDir ? "" : UI.fmtSize(modelData.size)
                            color: UI.textFaint; font.pixelSize: UI.px(11)
                        }
                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                picker.chosen = modelData.path
                                if (picker.mode === "save" && !modelData.isDir) nameField.text = modelData.name
                            }
                            onDoubleClicked: { picker.chosen = modelData.path; if (modelData.isDir) picker.go(modelData.path); else picker.accept() }
                        }
                    }
                    Text {
                        font.weight: UI.textWeight
                        visible: picker.entries.length === 0
                        anchors.centerIn: parent
                        text: Storage.list(picker.folder).length === 0 ? "This folder is empty"
                              : (picker.kinds.length ? "No " + (picker.kinds.indexOf("audio") >= 0 || picker.kinds.indexOf("video") >= 0 ? "music or video" : picker.kinds.join(" or ")) + " files here" : "Nothing here")
                        color: UI.textFaint; font.pixelSize: UI.px(12)
                    }
                }
            }
            Text { font.weight: UI.textWeight; id: errorText; visible: text !== ""; color: UI.warning; font.pixelSize: UI.px(12); Layout.fillWidth: true; elide: Text.ElideRight }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                GTextField {
                    id: nameField
                    visible: picker.mode === "save"
                    Layout.fillWidth: true
                    placeholderText: "File name"
                    onTextChanged: { errorText.text = ""; confirmOverwrite.pending = "" }
                    onAccepted: picker.accept()
                    Keys.onEscapePressed: picker.cancel()
                }
                Item { visible: picker.mode !== "save"; Layout.fillWidth: true }
                GButton { text: "Cancel"; onClicked: picker.cancel() }
                GButton {
                    text: picker.mode === "save" ? "Save" : "Open"
                    kind: "primary"
                    enabled: picker.mode === "save" ? nameField.text.trim() !== "" : picker.chosen !== ""
                    onClicked: picker.accept()
                }
            }
        }
    }
}
