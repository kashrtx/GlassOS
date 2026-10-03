import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../ui"
import "../components"

FocusScope {
    id: pad
    property var hostWindow: null
    property string filePath: ""
    property bool wrap: Prefs.value("pad.wrap", true)
    property bool mono: Prefs.value("pad.mono", false)
    // code files: syntax highlighting, monospace, line numbers, smart indentation
    readonly property string language: Syntax.languageFor(filePath)
    readonly property bool isCode: language !== "" && language !== "markdown"
    readonly property bool useMono: mono || isCode
    property bool codeWrap: Prefs.value("pad.wrap.code", false) === true   // code files wrap separately (off by default)
    readonly property bool wrapOn: isCode ? codeWrap : wrap
    readonly property bool showGutter: isCode && !wrapOn
    onLanguageChanged: Syntax.attach(editor.textDocument, language)
    function formatJson() {
        var r = Syntax.formatJson(editor.text)
        if (!r.ok) { flash(r.error); return }
        var pos = editor.cursorPosition
        editor.text = r.text
        editor.cursorPosition = Math.min(pos, editor.length)
        flash("Formatted")
    }
    function smartKey(event) {
        if (!isCode || editor.readOnly) return
        if (event.key === Qt.Key_Tab && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier))) {
            editor.remove(editor.selectionStart, editor.selectionEnd)
            editor.insert(editor.cursorPosition, "    ")
            event.accepted = true
        } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
            var pos = editor.cursorPosition
            var start = pos
            while (start > 0 && editor.getText(start - 1, start) !== "\n") start--
            var indent = Syntax.newlineIndent(editor.getText(start, pos), language)
            editor.remove(editor.selectionStart, editor.selectionEnd)
            editor.insert(editor.cursorPosition, "\n" + indent)
            event.accepted = true
        }
    }
    property int zoom: Prefs.value("pad.zoom", 14)
    property int line: 1
    property int column: 1
    property int words: 0
    // O(1) dirty tracking: comparing editor.text with the saved copy would marshal
    // the whole document from C++ to JS on every keystroke.
    property bool dirty: false
    property bool loadingText: false
    readonly property bool hasUnsavedChanges: dirty
    readonly property string fileName: filePath ? filePath.split("/").pop() : "Untitled"
    readonly property bool isActive: hostWindow ? hostWindow.active : true
    readonly property var wm: UI.wm
    property var afterSave: null

    Component.onCompleted: {
        if (filePath) load(filePath)
        updateTitle()
        editor.forceActiveFocus()
        Qt.callLater(function () { Syntax.attach(editor.textDocument, pad.language) })   // code highlighting
    }
    onHasUnsavedChangesChanged: updateTitle()
    onFileNameChanged: updateTitle()

    function updateTitle() {
        if (hostWindow) hostWindow.title = (hasUnsavedChanges ? "● " : "") + fileName + " — GlassPad"
    }

    function load(path) {
        var r = Storage.readText(path)
        if (!r.ok) {
            wm.notify("Can't open " + path.split("/").pop(), r.error, "warning-color")
            filePath = ""
            return false
        }
        filePath = path
        setText(r.text)
        wm.rememberRecent(path)
        return true
    }

    function setText(t) {
        loadingText = true
        editor.text = t
        editor.cursorPosition = 0
        loadingText = false
        dirty = false
    }

    function save(then) {
        if (!filePath) { saveAs(then); return }
        if (Storage.writeText(filePath, editor.text)) {
            dirty = false
            flash("Saved")
            wm.rememberRecent(filePath)
            if (then) then()
        } else {
            wm.notify("Couldn't save", filePath, "warning-color")
        }
    }

    function saveAs(then) {
        picker.saveFile({ title: "Save as", folder: filePath ? Storage.parentOf(filePath) : "/Documents",
                          name: filePath ? fileName : "Untitled.txt" },
                        function (path) { filePath = path; save(then) })
    }

    function guard(action) {   // run action, asking to save first when there are changes
        if (!hasUnsavedChanges) { action(); return }
        dialog.ask({ title: "Save changes to “" + fileName + "”?", icon: "save",
                     message: "Your changes will be lost if you don't save them.",
                     buttons: [{ text: "Cancel", value: "cancel" }, { text: "Don't save", value: "discard" },
                               { text: "Save", value: "save", kind: "primary" }] },
                   function (v) {
                       if (v === "save") save(action)
                       else if (v === "discard") action()
                   })
    }

    function newFile() { guard(function () { filePath = ""; setText("") }) }
    function openFile() {
        guard(function () {
            picker.openFile({ title: "Open", folder: filePath ? Storage.parentOf(filePath) : "/Documents",
                              kinds: ["text", "code", "file"] }, function (p) { load(p) })
        })
    }

    // window close protocol
    function canClose() {
        if (!hasUnsavedChanges) return true
        guard(function () { dirty = false; hostWindow.forceClose() })
        return false
    }
    function sessionState() { return filePath ? { filePath: filePath } : {} }
    function handleArgs(props) { if (props.filePath && props.filePath !== filePath) guard(function () { load(props.filePath) }) }

    // drop a file from Files / the desktop (or your computer) onto the window to open it
    function acceptDrop(paths, urls) {
        var file = paths.filter(function (p) { return !Storage.isDir(p) })[0]
        if (file) { guard(function () { load(file) }); return }
        if (urls.length) wm.importInto(urls, "/Documents")
    }

    function setZoom(z) { zoom = Math.max(8, Math.min(40, z)); Prefs.setValue("pad.zoom", zoom) }
    function flash(msg) { status.flashText = msg; flashTimer.restart() }

    // ---------------------------------------------------------------- find
    function find(forward) {
        var needle = findField.text
        if (!needle) return false
        var hay = caseBox.checked ? editor.text : editor.text.toLowerCase()
        var n = caseBox.checked ? needle : needle.toLowerCase()
        var from = forward ? editor.selectionEnd : editor.selectionStart - 1
        var idx = forward ? hay.indexOf(n, from) : hay.lastIndexOf(n, Math.max(0, from))
        if (idx < 0) idx = forward ? hay.indexOf(n) : hay.lastIndexOf(n)   // wrap around
        if (idx < 0) { flash("No matches"); return false }
        editor.select(idx, idx + needle.length)
        return true
    }
    function replaceOne() {
        var sel = editor.selectedText
        var match = caseBox.checked ? sel === findField.text : sel.toLowerCase() === findField.text.toLowerCase()
        if (sel && match) {
            var start = editor.selectionStart
            editor.remove(start, editor.selectionEnd)
            editor.insert(start, replaceField.text)
            editor.cursorPosition = start + replaceField.text.length
        }
        find(true)
    }
    function replaceAll() {
        var needle = findField.text
        if (!needle) return
        var esc = needle.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
        var re = new RegExp(esc, caseBox.checked ? "g" : "gi")
        var count = (editor.text.match(re) || []).length
        if (count === 0) { flash("No matches"); return }
        var pos = editor.cursorPosition
        editor.text = editor.text.replace(re, function () { return replaceField.text })
        editor.cursorPosition = Math.min(pos, editor.length)
        flash("Replaced " + count)
    }

    Timer {   // cursor position and word count, debounced for big files
        id: statsTimer
        interval: 120
        onTriggered: {
            var before = editor.text.substring(0, editor.cursorPosition)
            var nl = before.lastIndexOf("\n")
            pad.line = (before.match(/\n/g) || []).length + 1
            pad.column = editor.cursorPosition - nl
            pad.words = editor.length > 200000 ? -1 : (editor.text.match(/\S+/g) || []).length
        }
    }
    Timer { id: flashTimer; interval: 1600; onTriggered: status.flashText = "" }

    Shortcut { enabled: pad.isActive; sequence: "Ctrl+S"; onActivated: pad.save() }
    Shortcut { enabled: pad.isActive; sequence: "Ctrl+Shift+S"; onActivated: pad.saveAs() }
    Shortcut { enabled: pad.isActive; sequence: "Ctrl+O"; onActivated: pad.openFile() }
    Shortcut { enabled: pad.isActive; sequence: "Ctrl+N"; onActivated: pad.newFile() }
    Shortcut { enabled: pad.isActive; sequence: "Ctrl+F"; onActivated: { findBar.visible = true; findField.forceActiveFocus(); findField.selectAll() } }
    Shortcut { enabled: pad.isActive; sequence: "Ctrl+H"; onActivated: { findBar.visible = true; replaceField.forceActiveFocus() } }
    Shortcut { enabled: pad.isActive; sequence: "F3"; onActivated: pad.find(true) }
    Shortcut { enabled: pad.isActive; sequence: "Shift+F3"; onActivated: pad.find(false) }
    Shortcut { enabled: pad.isActive; sequences: ["Ctrl++", "Ctrl+="]; onActivated: pad.setZoom(pad.zoom + 1) }
    Shortcut { enabled: pad.isActive; sequence: "Ctrl+-"; onActivated: pad.setZoom(pad.zoom - 1) }
    Shortcut { enabled: pad.isActive; sequence: "Ctrl+0"; onActivated: pad.setZoom(14) }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ---------------------------------------------------------- toolbar
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: UI.px(42)
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            spacing: 2
            IconButton { iconName: "file"; tip: "New (Ctrl+N)"; onClicked: pad.newFile() }
            IconButton { iconName: "folder-open"; tip: "Open (Ctrl+O)"; onClicked: pad.openFile() }
            IconButton { iconName: "save"; tip: "Save (Ctrl+S)"; onClicked: pad.save() }
            GButton { text: "Save as…"; kind: "flat"; onClicked: pad.saveAs() }
            Rectangle { width: 1; height: 20; color: UI.border; Layout.leftMargin: 4; Layout.rightMargin: 4 }
            IconButton { iconName: "undo"; tip: "Undo (Ctrl+Z)"; enabled: editor.canUndo; onClicked: editor.undo() }
            IconButton { iconName: "redo"; tip: "Redo (Ctrl+Y)"; enabled: editor.canRedo; onClicked: editor.redo() }
            IconButton { iconName: "search"; tip: "Find & replace (Ctrl+F)"; active: findBar.visible; onClicked: { findBar.visible = !findBar.visible; if (findBar.visible) findField.forceActiveFocus() } }
            Item { Layout.fillWidth: true }
            IconButton { iconName: "wrap"; tip: "Word wrap"; active: pad.wrapOn; onClicked: { if (pad.isCode) { pad.codeWrap = !pad.codeWrap; Prefs.setValue("pad.wrap.code", pad.codeWrap) } else { pad.wrap = !pad.wrap; Prefs.setValue("pad.wrap", pad.wrap) } } }
            IconButton { glyph: "</>"; glyphSize: 11; tip: "Monospace font"; active: pad.mono; onClicked: { pad.mono = !pad.mono; Prefs.setValue("pad.mono", pad.mono) } }
            IconButton { iconName: "minus"; tip: "Smaller (Ctrl+-)"; onClicked: pad.setZoom(pad.zoom - 1) }
            Text { elide: Text.ElideRight; font.weight: UI.textWeight; text: pad.zoom + "px"; color: UI.textDim; font.pixelSize: UI.px(11); Layout.preferredWidth: UI.px(34); horizontalAlignment: Text.AlignHCenter }
            IconButton { iconName: "plus"; tip: "Larger (Ctrl++)"; onClicked: pad.setZoom(pad.zoom + 1) }
        }

        // ---------------------------------------------------------- find bar
        Rectangle {
            id: findBar
            visible: false
            Layout.fillWidth: true
            Layout.preferredHeight: UI.px(46)
            color: Qt.rgba(0, 0, 0, 0.15)
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 6
                GTextField {
                    id: findField
                    Layout.preferredWidth: UI.px(200)
                    placeholderText: "Find"
                    onAccepted: pad.find(true)
                    Keys.onEscapePressed: { findBar.visible = false; editor.forceActiveFocus() }
                }
                IconButton { iconName: "down"; tip: "Next (F3)"; onClicked: pad.find(true) }
                IconButton { iconName: "up"; tip: "Previous (Shift+F3)"; onClicked: pad.find(false) }
                GTextField {
                    id: replaceField
                    Layout.preferredWidth: UI.px(180)
                    placeholderText: "Replace with"
                    onAccepted: pad.replaceOne()
                    Keys.onEscapePressed: { findBar.visible = false; editor.forceActiveFocus() }
                }
                GButton { text: "Replace"; onClicked: pad.replaceOne() }
                GButton { text: "All"; onClicked: pad.replaceAll() }
                CheckBox {
                    id: caseBox
                    text: "Aa"
                    contentItem: Text { font.weight: UI.textWeight; text: caseBox.text; color: UI.text; leftPadding: caseBox.indicator.width + 4; verticalAlignment: Text.AlignVCenter; font.pixelSize: UI.px(12) }
                }
                Item { Layout.fillWidth: true }
                IconButton { iconName: "close"; onClicked: { findBar.visible = false; editor.forceActiveFocus() } }
            }
        }

        // ---------------------------------------------------------- editor
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Qt.rgba(0.02, 0.03, 0.05, 0.45)

            ScrollView {
                id: scroller
                anchors.fill: parent
                ScrollBar.vertical: GScrollBar { parent: scroller; x: scroller.width - width; height: scroller.height }
                ScrollBar.horizontal: GScrollBar { parent: scroller; y: scroller.height - height; width: scroller.width }

                TextArea {
                    id: editor
                    focus: true
                    textFormat: TextEdit.PlainText
                    wrapMode: pad.wrapOn ? TextEdit.Wrap : TextEdit.NoWrap
                    selectByMouse: true
                    persistentSelection: true
                    color: UI.text
                    selectionColor: UI.alpha(UI.accent, 0.45)
                    selectedTextColor: "white"
                    font.pixelSize: pad.zoom
                    font.family: pad.useMono ? UI.monoFont : Qt.application.font.family
                    font.weight: pad.useMono ? Font.Normal : UI.textWeight
                    tabStopDistance: 4 * fm.averageCharacterWidth
                    leftPadding: pad.showGutter ? gutter.width + 14 : 18
                    rightPadding: 18
                    topPadding: 14
                    bottomPadding: 14
                    placeholderText: "Start typing…"
                    placeholderTextColor: UI.textFaint
                    background: null
                    onCursorPositionChanged: statsTimer.restart()
                    Keys.onPressed: function (event) { pad.smartKey(event) }

                    Rectangle {   // current line (drawn under the text)
                        visible: pad.isCode && editor.activeFocus && editor.selectionStart === editor.selectionEnd
                        z: -1
                        x: 0
                        y: editor.cursorRectangle.y
                        width: Math.max(editor.width, editor.contentWidth + editor.leftPadding + editor.rightPadding)
                        height: editor.cursorRectangle.height
                        color: Qt.rgba(1, 1, 1, 0.045)
                    }
                    Item {   // line numbers (scroll with the text; only when lines don't wrap)
                        id: gutter
                        visible: pad.showGutter
                        // pinned while the text scrolls sideways (long lines don't wrap in code mode)
                        x: scroller.contentItem && scroller.contentItem.contentX !== undefined ? scroller.contentItem.contentX : 0
                        z: 2
                        y: 0
                        width: fm.averageCharacterWidth * Math.max(3, String(editor.lineCount).length) + 18
                        height: editor.height
                        Rectangle { anchors.fill: parent; color: Qt.rgba(0.03, 0.04, 0.06, 0.94) }
                        Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: UI.border }
                        Text {
                            x: 6
                            y: editor.topPadding
                            width: parent.width - 14
                            horizontalAlignment: Text.AlignRight
                            font: editor.font
                            color: UI.textFaint
                            lineHeightMode: Text.FixedHeight
                            lineHeight: editor.lineCount > 0 ? (editor.contentHeight / editor.lineCount) : fm.lineSpacing
                            text: {
                                if (!pad.showGutter) return ""
                                var n = editor.lineCount, out = new Array(n)
                                for (var i = 0; i < n; i++) out[i] = i + 1
                                return out.join("\n")
                            }
                        }
                    }
                    onTextChanged: { if (!pad.loadingText) pad.dirty = true; statsTimer.restart() }
                    FontMetrics { id: fm; font: editor.font }
                }
            }
        }

        // ---------------------------------------------------------- status bar
        Rectangle {
            id: status
            property string flashText: ""
            Layout.fillWidth: true
            Layout.preferredHeight: UI.px(26)
            color: Qt.rgba(0, 0, 0, 0.18)
            Row {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 18
                Text { font.weight: UI.textWeight; text: "Ln " + pad.line + ", Col " + pad.column; color: UI.textFaint; font.pixelSize: UI.px(11.5) }
                Text { font.weight: UI.textWeight; text: pad.words >= 0 ? pad.words + " words · " + editor.length + " chars" : editor.length + " chars"; color: UI.textFaint; font.pixelSize: UI.px(11.5) }
                Text { font.weight: UI.textWeight; text: pad.filePath || "Not saved yet"; color: UI.textFaint; font.pixelSize: UI.px(11.5) }
                Text { font.weight: UI.textWeight; text: Syntax.languageName(pad.language); color: pad.isCode ? UI.accent : UI.textFaint; font.pixelSize: UI.px(11.5) }
                Text {
                    visible: pad.language === "json"
                    font.weight: UI.textWeight
                    text: "Format JSON"
                    color: UI.accent; font.pixelSize: UI.px(11.5); font.underline: fmtMouse.containsMouse
                    MouseArea { id: fmtMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pad.formatJson() }
                }
            }
            Text {
                elide: Text.ElideRight
                font.weight: UI.textWeight
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: status.flashText !== "" ? status.flashText : (pad.hasUnsavedChanges ? "Edited" : "Saved")
                color: status.flashText !== "" ? UI.accent : (pad.hasUnsavedChanges ? UI.warning : UI.success)
                font.pixelSize: UI.px(11.5)
            }
        }
    }

    FilePicker { id: picker }
    GDialog { id: dialog }
}
