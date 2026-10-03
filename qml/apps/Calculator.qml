import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../ui"
import "../components"

FocusScope {
    id: calc
    property var hostWindow: null
    property string initialExpression: ""
    property bool degrees: Prefs.value("calc.degrees", true)
    property bool scientific: Prefs.value("calc.scientific", false)
    property bool showHistory: false
    property var history: UI.arr(Prefs.value("calc.history", [])).filter(function (h) { return h && typeof h.expr === "string" })
    property string ans: "0"
    property bool justEvaluated: false
    readonly property var preview: input.text.trim() === "" ? ({ ok: false, value: "", error: "" })
                                                           : Calc.evaluate(input.text, degrees, ans)

    Component.onCompleted: {
        if (initialExpression) { input.text = initialExpression; equals() }
        input.forceActiveFocus()
    }
    function handleArgs(props) { if (props.initialExpression) { input.text = props.initialExpression; equals() } }

    function insert(s) {
        if (justEvaluated && /^[0-9.(πe√a-z]/.test(s)) input.text = ""   // typing a number starts fresh
        justEvaluated = false
        var pos = input.cursorPosition
        input.insert(pos, s)
        if (s.endsWith("()")) input.cursorPosition = pos + s.length - 1
        input.forceActiveFocus()
    }
    function backspace() {
        justEvaluated = false
        var p = input.cursorPosition
        if (input.selectedText.length) input.remove(input.selectionStart, input.selectionEnd)
        else if (p > 0) input.remove(p - 1, p)
        input.forceActiveFocus()
    }
    function clearAll() { input.text = ""; justEvaluated = false; input.forceActiveFocus() }
    function equals() {
        var expr = input.text.trim()
        if (!expr) return
        var r = Calc.evaluate(expr, degrees, ans)
        if (!r.ok) { errorShake.restart(); return }
        var h = history.slice(0, 49)
        h.unshift({ expr: expr, value: r.value })
        history = h
        Prefs.setValue("calc.history", h)
        ans = r.value
        input.text = r.value
        input.cursorPosition = input.length
        justEvaluated = true
    }

    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Escape) { clearAll(); event.accepted = true }
    }

    readonly property var keys: [
        { t: "C", k: "fn", act: "clear" }, { t: "⌫", k: "fn", act: "back" }, { t: "%", k: "op" }, { t: "÷", k: "op" },
        { t: "7", k: "num" }, { t: "8", k: "num" }, { t: "9", k: "num" }, { t: "×", k: "op" },
        { t: "4", k: "num" }, { t: "5", k: "num" }, { t: "6", k: "num" }, { t: "−", k: "op" },
        { t: "1", k: "num" }, { t: "2", k: "num" }, { t: "3", k: "num" }, { t: "+", k: "op" },
        { t: "ans", k: "fn" }, { t: "0", k: "num" }, { t: ".", k: "num" }, { t: "=", k: "eq" }
    ]
    readonly property var sciKeys: [
        { t: "sin", ins: "sin(" }, { t: "cos", ins: "cos(" }, { t: "tan", ins: "tan(" }, { t: "(", ins: "(" },
        { t: "asin", ins: "asin(" }, { t: "acos", ins: "acos(" }, { t: "atan", ins: "atan(" }, { t: ")", ins: ")" },
        { t: "ln", ins: "ln(" }, { t: "log", ins: "log(" }, { t: "√", ins: "√(" }, { t: "xʸ", ins: "^" },
        { t: "x²", ins: "^2" }, { t: "1/x", ins: "1/(" }, { t: "n!", ins: "!" }, { t: "mod", ins: " mod " },
        { t: "π", ins: "π" }, { t: "e", ins: "e" }, { t: "|x|", ins: "abs(" }, { t: "∛", ins: "cbrt(" }
    ]

    function press(key) {
        if (key.act === "clear") clearAll()
        else if (key.act === "back") backspace()
        else if (key.k === "eq") equals()
        else insert(key.t)
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 12
            spacing: 10

            // ---------------------------------------------------- mode row
            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                GButton { text: calc.degrees ? "DEG" : "RAD"; kind: "flat"; onClicked: { calc.degrees = !calc.degrees; Prefs.setValue("calc.degrees", calc.degrees) } }
                GButton { text: "Scientific"; kind: calc.scientific ? "primary" : "flat"; onClicked: { calc.scientific = !calc.scientific; Prefs.setValue("calc.scientific", calc.scientific) } }
                Item { Layout.fillWidth: true }
                IconButton { iconName: "history"; tip: "History"; active: calc.showHistory; onClicked: calc.showHistory = !calc.showHistory }
            }

            // ---------------------------------------------------- display
            Rectangle {
                id: display
                Layout.fillWidth: true
                Layout.preferredHeight: UI.px(140)
                radius: UI.radius
                color: Qt.rgba(0, 0, 0, 0.25)
                border.color: input.activeFocus ? UI.alpha(UI.accent, 0.5) : UI.border

                SequentialAnimation {
                    id: errorShake
                    NumberAnimation { target: shakeT; property: "x"; to: -8; duration: 40 }
                    NumberAnimation { target: shakeT; property: "x"; to: 8; duration: 60 }
                    NumberAnimation { target: shakeT; property: "x"; to: -5; duration: 50 }
                    NumberAnimation { target: shakeT; property: "x"; to: 0; duration: 40 }
                }
                transform: Translate { id: shakeT }

                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    horizontalAlignment: Text.AlignRight
                    text: calc.history.length && calc.justEvaluated ? calc.history[0].expr + " =" : " "
                    color: UI.textDim
                    font.pixelSize: UI.px(15)
                    font.weight: Font.Medium
                    elide: Text.ElideLeft
                }
                TextInput {
                    id: input
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 12
                    focus: true
                    horizontalAlignment: TextInput.AlignRight
                    color: UI.text
                    selectionColor: UI.alpha(UI.accent, 0.45)
                    selectByMouse: true
                    clip: true
                    font.pixelSize: UI.px(length > 22 ? 26 : (length > 14 ? 34 : 44))
                    font.weight: Font.DemiBold
                    validator: RegularExpressionValidator { regularExpression: /[0-9a-zA-Z.+\-*\/^()!%,\s×÷−πe√]*/ }
                    onAccepted: calc.equals()
                    Keys.onEnterPressed: calc.equals()
                    Keys.onEscapePressed: calc.clearAll()
                    onTextEdited: calc.justEvaluated = false
                    Text {
                        elide: Text.ElideRight
                        anchors.right: parent.right
                        visible: input.text === ""
                        text: "0"
                        color: UI.textFaint
                        font: input.font
                    }
                }
                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 12
                    horizontalAlignment: Text.AlignRight
                    text: calc.justEvaluated ? "" : (calc.preview.ok ? "= " + calc.preview.value : (input.text.trim() ? calc.preview.error : ""))
                    color: calc.preview.ok ? UI.accent : UI.textFaint
                    font.pixelSize: UI.px(17)
                    font.weight: Font.DemiBold
                    elide: Text.ElideLeft
                }
            }

            // ---------------------------------------------------- keypads
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                GridLayout {
                    visible: calc.scientific
                    Layout.fillHeight: true
                    Layout.fillWidth: false
                    Layout.preferredWidth: (parent.width - 8) * 0.44
                    Layout.maximumWidth: (parent.width - 8) * 0.44
                    columns: 4
                    rowSpacing: 6
                    columnSpacing: 6
                    Repeater {
                        model: calc.sciKeys
                        AbstractButton {
                            id: sciKey
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            hoverEnabled: true
                            focusPolicy: Qt.NoFocus
                            onClicked: calc.insert(modelData.ins)
                            background: Rectangle {
                                radius: UI.radiusSmall
                                color: sciKey.down ? UI.pressed : (sciKey.hovered ? UI.cardStrong : Qt.rgba(1, 1, 1, 0.03))
                            }
                            contentItem: Text {
                                text: modelData.t
                                color: UI.text
                                font.pixelSize: UI.px(15)
                                font.weight: Font.DemiBold
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 100
                    columns: 4
                    rowSpacing: 6
                    columnSpacing: 6
                    Repeater {
                        model: calc.keys
                        AbstractButton {
                            id: key
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            hoverEnabled: true
                            focusPolicy: Qt.NoFocus
                            onClicked: calc.press(modelData)
                            background: Rectangle {
                                radius: UI.radiusSmall
                                color: {
                                    if (modelData.k === "eq") return key.down ? Qt.darker(UI.accent, 1.2) : (key.hovered ? Qt.lighter(UI.accent, 1.1) : UI.accent)
                                    var base = modelData.k === "num" ? 0.09 : 0.05
                                    return key.down ? UI.pressed : Qt.rgba(1, 1, 1, key.hovered ? base + 0.06 : base)
                                }
                                Behavior on color { ColorAnimation { duration: UI.dur(70) } }
                            }
                            contentItem: Text {
                                text: modelData.t
                                color: modelData.k === "eq" ? UI.accentText : (modelData.k === "op" ? UI.accent : UI.text)
                                font.pixelSize: UI.px(modelData.k === "num" || modelData.k === "eq" ? 25 : 21)
                                font.weight: modelData.k === "num" ? Font.DemiBold : Font.Bold
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                scale: key.down ? 0.92 : 1
                                Behavior on scale { NumberAnimation { duration: UI.dur(70) } }
                            }
                        }
                    }
                }
            }
        }

        // -------------------------------------------------------- history
        Rectangle {
            visible: calc.showHistory
            Layout.fillHeight: true
            Layout.preferredWidth: UI.px(220)
            color: Qt.rgba(0, 0, 0, 0.18)
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                RowLayout {
                    Layout.fillWidth: true
                    Text { elide: Text.ElideRight; text: "History"; color: UI.text; font.pixelSize: UI.px(14); font.weight: Font.DemiBold; Layout.fillWidth: true }
                    IconButton { iconName: "trash"; tip: "Clear history"; enabled: calc.history.length > 0; onClicked: { calc.history = []; Prefs.setValue("calc.history", []) } }
                }
                ListView {
                    id: histList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: calc.history
                    spacing: 2
                    ScrollBar.vertical: GScrollBar {}
                    delegate: Rectangle {
                        width: histList.width
                        height: col.implicitHeight + 12
                        radius: UI.radiusSmall
                        color: histMouse.containsMouse ? UI.hover : "transparent"
                        Column {
                            id: col
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 16
                            Text { font.weight: UI.textWeight; width: parent.width; horizontalAlignment: Text.AlignRight; text: modelData.expr; color: UI.textFaint; font.pixelSize: UI.px(11.5); elide: Text.ElideLeft }
                            Text { elide: Text.ElideRight; font.weight: UI.textWeight; width: parent.width; horizontalAlignment: Text.AlignRight; text: "= " + modelData.value; color: UI.text; font.pixelSize: UI.px(15) }
                        }
                        MouseArea {
                            id: histMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { input.text = modelData.expr; calc.justEvaluated = false; input.forceActiveFocus() }
                        }
                    }
                    Text { font.weight: UI.textWeight; visible: calc.history.length === 0; anchors.centerIn: parent; text: "No calculations yet"; color: UI.textFaint; font.pixelSize: UI.px(12) }
                }
            }
        }
    }
}
