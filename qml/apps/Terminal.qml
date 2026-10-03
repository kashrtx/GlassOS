import QtQuick
import QtQuick.Controls
import "../ui"
import "../components"

FocusScope {
    id: term
    property var hostWindow: null
    property string initialCwd: "/"
    property string cwd: "/"
    property var cmdHistory: UI.arr(Prefs.value("term.history", []))
    property int histPos: -1
    property string draft: ""
    readonly property string user: Prefs.userName.toLowerCase().replace(/\s+/g, "")
    readonly property var wm: UI.wm

    ListModel { id: lines }

    Component.onCompleted: {
        cwd = Storage.isDir(initialCwd) ? initialCwd : "/"
        println("GlassShell 2.0 — type 'help' to get started, 'neofetch' to show off.", "accent")
        println("")
        Qt.callLater(function () { view.positionViewAtEnd() })
        updateTitle()
        input.forceActiveFocus()
    }

    // dropping files types their (quoted) paths at the prompt, like real terminals
    function acceptDrop(paths, urls) {
        var parts = paths.map(function (p) { return /\s/.test(p) ? "\"" + p + "\"" : p })
        if (!parts.length) return
        input.insert(input.cursorPosition, (input.text && !/\s$/.test(input.text) ? " " : "") + parts.join(" ") + " ")
        input.forceActiveFocus()
    }

    function sessionState() { return { initialCwd: cwd } }
    function updateTitle() { if (hostWindow) hostWindow.title = user + "@glassos: " + cwd }

    function println(text, color) {
        lines.append({ text: String(text), color: color || "" })
        if (lines.count > 3000) lines.remove(0, lines.count - 3000)
    }

    function colorFor(c) {
        return c === "accent" ? UI.accent : c === "ok" ? UI.success : c === "err" ? UI.danger
             : c === "dim" ? UI.textFaint : c === "warn" ? UI.warning : c === "prompt" ? UI.accent : "#e6edf6"
    }

    function run(line) {
        println(prompt.text + " " + line, "prompt")
        if (line.trim() !== "") {
            var h = cmdHistory.filter(function (x) { return x !== line })
            h.push(line)
            if (h.length > 200) h = h.slice(h.length - 200)
            cmdHistory = h
            Prefs.setValue("term.history", h)
        }
        histPos = -1
        var res = Shell.run(cwd, line)
        if (res.clear) lines.clear()
        for (var i = 0; i < res.lines.length; i++) println(res.lines[i].text, res.lines[i].color)
        cwd = res.cwd
        updateTitle()
        for (var j = 0; j < res.actions.length; j++) {
            var a = res.actions[j]
            if (a.type === "launch") wm.openApp(a.app, a.app === "Terminal" ? { initialCwd: cwd } : {})
            else if (a.type === "open") wm.openPath(a.path)
            else if (a.type === "matrix") matrix.start()
            else if (a.type === "lock") wm.lock()
            else if (a.type === "exit") { if (hostWindow) hostWindow.forceClose() }
            else if (a.type === "history") {
                var start = Math.max(0, cmdHistory.length - 25)
                for (var k = start; k < cmdHistory.length; k++) println(("    " + (k + 1)).slice(-5) + "  " + cmdHistory[k], "dim")
            }
        }
        Qt.callLater(function () { view.positionViewAtEnd() })
    }

    function complete() {
        var text = input.text
        var options = Shell.complete(cwd, text)
        if (options.length === 0) return
        var words = text.split(" ")
        if (options.length === 1) {
            words[words.length - 1] = options[0] + (options[0].endsWith("/") || words.length === 1 ? (words.length === 1 ? " " : "") : " ")
            input.text = words.join(" ")
        } else {
            // extend to the longest common prefix, then list the choices
            var prefix = options[0]
            for (var i = 1; i < options.length; i++) while (options[i].indexOf(prefix) !== 0) prefix = prefix.slice(0, -1)
            if (prefix.length > words[words.length - 1].length) { words[words.length - 1] = prefix; input.text = words.join(" ") }
            else { println(prompt.text + " " + text, "prompt"); println(options.join("    "), "dim"); Qt.callLater(function () { view.positionViewAtEnd() }) }
        }
        input.cursorPosition = input.length
    }

    Rectangle { anchors.fill: parent; color: Qt.rgba(0.01, 0.015, 0.03, 0.72) }

    MouseArea { anchors.fill: parent; onClicked: input.forceActiveFocus(); cursorShape: Qt.IBeamCursor }

    ListView {
        id: view
        x: 12
        y: 12
        width: parent.width - 24
        height: Math.min(contentHeight, parent.height - 24 - promptRow.height)
        clip: true
        model: lines
        boundsBehavior: Flickable.StopAtBounds
        reuseItems: true
        ScrollBar.vertical: GScrollBar {}

        delegate: TextEdit {
            width: view.width - 10
            text: model.text
            color: term.colorFor(model.color)
            font.family: UI.monoFont
            font.pixelSize: UI.px(13)
            wrapMode: Text.WrapAnywhere
            readOnly: true
            selectByMouse: true
            selectionColor: UI.alpha(UI.accent, 0.45)
            textFormat: TextEdit.PlainText
        }
    }

    Row {
        id: promptRow
        x: 12
        y: view.y + view.height
        width: term.width - 24
        spacing: 8
        Text {
            id: prompt
            text: term.user + "@glassos " + (term.cwd === "/" ? "~" : "~" + term.cwd) + " $"
            color: UI.accent
            font.family: UI.monoFont
            font.pixelSize: UI.px(13)
            font.bold: true
        }
        TextInput {
            id: input
            width: parent.width - prompt.width - 10
            focus: true
            color: "#ffffff"
            font.family: UI.monoFont
            font.pixelSize: UI.px(13)
            selectByMouse: true
            selectionColor: UI.alpha(UI.accent, 0.45)
            cursorDelegate: Rectangle {
                width: 8
                color: UI.accent
                opacity: blink.on ? 0.85 : 0.15
                Timer { id: blink; property bool on: true; interval: 530; running: input.activeFocus; repeat: true; onTriggered: on = !on }
            }
            Keys.onReturnPressed: { var t = text; text = ""; term.run(t) }
            Keys.onEnterPressed: { var t = text; text = ""; term.run(t) }
            Keys.onTabPressed: term.complete()
            Keys.onUpPressed: {
                if (term.cmdHistory.length === 0) return
                if (term.histPos === -1) { term.draft = text; term.histPos = term.cmdHistory.length }
                term.histPos = Math.max(0, term.histPos - 1)
                text = term.cmdHistory[term.histPos]
            }
            Keys.onDownPressed: {
                if (term.histPos === -1) return
                term.histPos++
                if (term.histPos >= term.cmdHistory.length) { term.histPos = -1; text = term.draft }
                else text = term.cmdHistory[term.histPos]
            }
            Keys.onPressed: function (event) {
                if (event.modifiers & Qt.ControlModifier) {
                    if (event.key === Qt.Key_L) { lines.clear(); event.accepted = true }
                    else if (event.key === Qt.Key_C && selectedText === "") { term.println(prompt.text + " " + text + "^C", "dim"); text = ""; event.accepted = true }
                }
            }
        }
    }

    // ------------------------------------------------------------ matrix rain
    Canvas {
        id: matrix
        anchors.fill: parent
        visible: running
        property bool running: false
        property var drops: []
        readonly property int size: 15
        readonly property string glyphs: "アイウエオカキクケコサシスセソタチツテトナニヌネノ0123456789GLASSOS"

        function start() {
            var cols = Math.ceil(width / size)
            var d = []
            for (var i = 0; i < cols; i++) d.push(Math.floor(Math.random() * -40))
            drops = d
            running = true
            focusCatcher.forceActiveFocus()
            var ctx = getContext("2d")
            if (ctx) { ctx.fillStyle = "black"; ctx.fillRect(0, 0, width, height) }
        }
        function stop() { running = false; input.forceActiveFocus() }

        Timer { interval: 45; repeat: true; running: matrix.running; onTriggered: matrix.requestPaint() }
        onPaint: {
            var ctx = getContext("2d")
            ctx.fillStyle = "rgba(0, 0, 0, 0.09)"
            ctx.fillRect(0, 0, width, height)
            ctx.font = size + "px monospace"
            for (var i = 0; i < drops.length; i++) {
                var ch = glyphs.charAt(Math.floor(Math.random() * glyphs.length))
                var y = drops[i] * size
                ctx.fillStyle = Math.random() > 0.97 ? "#d8ffe0" : "#22e06b"
                ctx.fillText(ch, i * size, y)
                if (y > height && Math.random() > 0.975) drops[i] = 0
                drops[i]++
            }
        }
        FocusScope {
            id: focusCatcher
            anchors.fill: parent
            Keys.onPressed: function (event) { event.accepted = true; matrix.stop() }
        }
        MouseArea { anchors.fill: parent; onClicked: matrix.stop() }
    }
}
