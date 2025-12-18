// GlassOS Calculator - Advanced Scientific Calculator
// Modern equation-based input with history, scientific functions, and a beautiful UI
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: calc
    color: "transparent"
    
    // ===== STATE =====
    property string expression: ""
    property string result: "0"
    property var history: []
    property bool showHistory: false
    property bool showScientific: true
    property bool degreeMode: true  // true = degrees, false = radians
    property int precision: 10
    
    // ===== EXPRESSION EVALUATOR =====
    function evaluateExpression(expr) {
        if (!expr || expr.trim() === "") return "0"
        
        try {
            // Preprocess the expression
            var processed = expr
            
            // Replace display symbols with JS operators
            processed = processed.replace(/×/g, "*")
            processed = processed.replace(/÷/g, "/")
            processed = processed.replace(/−/g, "-")
            processed = processed.replace(/\^/g, "**")
            
            // Handle implicit multiplication: 2(3) -> 2*(3), (2)(3) -> (2)*(3), 2sin -> 2*sin
            processed = processed.replace(/(\d)(\()/g, "$1*(")
            processed = processed.replace(/(\))(\d)/g, ")*$2")
            processed = processed.replace(/(\))(\()/g, ")*(")
            processed = processed.replace(/(\d)(sin|cos|tan|log|ln|sqrt|abs|exp|asin|acos|atan)/g, "$1*$2")
            
            // Handle percentage
            processed = processed.replace(/(\d+\.?\d*)%/g, "($1/100)")
            
            // Handle factorial
            processed = processed.replace(/(\d+)!/g, "factorial($1)")
            
            // Math functions - convert to proper JS with degree/radian handling
            if (degreeMode) {
                processed = processed.replace(/sin\(([^)]+)\)/g, "Math.sin(($1)*Math.PI/180)")
                processed = processed.replace(/cos\(([^)]+)\)/g, "Math.cos(($1)*Math.PI/180)")
                processed = processed.replace(/tan\(([^)]+)\)/g, "Math.tan(($1)*Math.PI/180)")
                processed = processed.replace(/asin\(([^)]+)\)/g, "(Math.asin($1)*180/Math.PI)")
                processed = processed.replace(/acos\(([^)]+)\)/g, "(Math.acos($1)*180/Math.PI)")
                processed = processed.replace(/atan\(([^)]+)\)/g, "(Math.atan($1)*180/Math.PI)")
            } else {
                processed = processed.replace(/sin\(/g, "Math.sin(")
                processed = processed.replace(/cos\(/g, "Math.cos(")
                processed = processed.replace(/tan\(/g, "Math.tan(")
                processed = processed.replace(/asin\(/g, "Math.asin(")
                processed = processed.replace(/acos\(/g, "Math.acos(")
                processed = processed.replace(/atan\(/g, "Math.atan(")
            }
            
            processed = processed.replace(/sqrt\(/g, "Math.sqrt(")
            processed = processed.replace(/log\(/g, "Math.log10(")
            processed = processed.replace(/ln\(/g, "Math.log(")
            processed = processed.replace(/abs\(/g, "Math.abs(")
            processed = processed.replace(/exp\(/g, "Math.exp(")
            processed = processed.replace(/floor\(/g, "Math.floor(")
            processed = processed.replace(/ceil\(/g, "Math.ceil(")
            processed = processed.replace(/round\(/g, "Math.round(")
            
            // Constants
            processed = processed.replace(/\bpi\b/gi, "Math.PI")
            processed = processed.replace(/\be\b/g, "Math.E")
            processed = processed.replace(/π/g, "Math.PI")
            
            // Factorial function
            var factorialFunc = "var factorial = function(n) { if (n < 0) return NaN; if (n === 0 || n === 1) return 1; var r = 1; for (var i = 2; i <= n; i++) r *= i; return r; }; "
            
            // Evaluate
            var evalResult = eval(factorialFunc + processed)
            
            if (isNaN(evalResult)) return "Error"
            if (!isFinite(evalResult)) return evalResult > 0 ? "∞" : "-∞"
            
            // Format result
            if (Number.isInteger(evalResult)) {
                return evalResult.toString()
            } else {
                // Round to precision, remove trailing zeros
                var rounded = parseFloat(evalResult.toPrecision(precision))
                var str = rounded.toString()
                
                // Handle very small/large numbers with scientific notation
                if (Math.abs(evalResult) < 0.0000001 || Math.abs(evalResult) > 9999999999) {
                    str = evalResult.toExponential(6)
                }
                
                return str
            }
        } catch (e) {
            console.log("Calc error:", e)
            return "Error"
        }
    }
    
    function calculate() {
        if (expression.trim() === "") return
        
        var res = evaluateExpression(expression)
        result = res
        
        // Add to history
        if (res !== "Error") {
            history.unshift({
                expression: expression,
                result: res,
                timestamp: new Date().toLocaleTimeString()
            })
            // Keep last 50 entries
            if (history.length > 50) history.pop()
            history = history.slice()  // Force update
        }
    }
    
    function insertText(text) {
        expression = expression + text
    }
    
    function insertFunction(func) {
        expression = expression + func + "("
    }
    
    function clear() {
        expression = ""
        result = "0"
    }
    
    function clearEntry() {
        expression = ""
    }
    
    function backspace() {
        if (expression.length > 0) {
            expression = expression.slice(0, -1)
        }
    }
    
    function useResult() {
        if (result !== "0" && result !== "Error") {
            expression = result
        }
    }
    
    function useHistoryItem(item) {
        expression = item.expression
        result = item.result
    }
    
    // ===== KEYBOARD HANDLING =====
    Component.onCompleted: expressionInput.forceActiveFocus()
    
    // ===== MAIN LAYOUT =====
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        
        // ===== HEADER BAR =====
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            color: Qt.rgba(0.08, 0.09, 0.11, 0.98)
            
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8
                
                Text {
                    text: "GlassCalc"
                    color: "#888"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }
                
                Item { Layout.fillWidth: true }
                
                // Mode toggle
                Rectangle {
                    width: 60
                    height: 24
                    radius: 12
                    color: degreeMode ? Qt.rgba(0.3, 0.6, 0.9, 0.3) : Qt.rgba(0.5, 0.3, 0.8, 0.3)
                    
                    Text {
                        anchors.centerIn: parent
                        text: degreeMode ? "DEG" : "RAD"
                        color: "#fff"
                        font.pixelSize: 11
                        font.bold: true
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: degreeMode = !degreeMode
                        
                        ToolTip.visible: containsMouse
                        ToolTip.text: degreeMode ? "Degree mode - Click for Radians" : "Radian mode - Click for Degrees"
                        ToolTip.delay: 500
                        hoverEnabled: true
                    }
                }
                
                // Scientific toggle
                Rectangle {
                    width: 28
                    height: 24
                    radius: 4
                    color: showScientific ? Theme.accentColor : Qt.rgba(1,1,1,0.1)
                    
                    Text {
                        anchors.centerIn: parent
                        text: "f(x)"
                        color: "#fff"
                        font.pixelSize: 9
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: showScientific = !showScientific
                        
                        ToolTip.visible: containsMouse
                        ToolTip.text: "Toggle scientific functions"
                        ToolTip.delay: 500
                        hoverEnabled: true
                    }
                }
                
                // History toggle
                Rectangle {
                    width: 28
                    height: 24
                    radius: 4
                    color: showHistory ? Theme.accentColor : Qt.rgba(1,1,1,0.1)
                    
                    Text {
                        anchors.centerIn: parent
                        text: "📜"
                        font.pixelSize: 12
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: showHistory = !showHistory
                    }
                }
            }
        }
        
        // ===== DISPLAY AREA =====
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 120
            color: Qt.rgba(0.04, 0.045, 0.06, 0.95)
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8
                
                // Expression input (editable!)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    radius: 8
                    color: Qt.rgba(0, 0, 0, 0.4)
                    border.width: expressionInput.activeFocus ? 2 : 1
                    border.color: expressionInput.activeFocus ? Theme.accentColor : Qt.rgba(1, 1, 1, 0.15)
                    
                    TextInput {
                        id: expressionInput
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        verticalAlignment: Text.AlignVCenter
                        
                        text: expression
                        onTextChanged: expression = text
                        
                        color: "#ffffff"
                        font.pixelSize: 22
                        font.family: "Consolas"
                        
                        selectByMouse: true
                        
                        // Placeholder
                        Text {
                            visible: !parent.text
                            text: "Type an expression..."
                            color: "#555"
                            font: parent.font
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Keys.onReturnPressed: calculate()
                        Keys.onEnterPressed: calculate()
                        Keys.onEscapePressed: clear()
                    }
                }
                
                // Result display
                Text {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                    
                    text: "= " + result
                    color: result === "Error" ? "#ff6b6b" : "#4ade80"
                    font.pixelSize: result.length > 12 ? 28 : 36
                    font.family: "Segoe UI"
                    font.weight: Font.Light
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: useResult()
                        
                        ToolTip.visible: containsMouse && result !== "0"
                        ToolTip.text: "Click to use this result"
                        ToolTip.delay: 500
                        hoverEnabled: true
                    }
                }
            }
        }
        
        // ===== MAIN CONTENT AREA =====
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0
            
            // ===== CALCULATOR BUTTONS =====
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0
                
                // Scientific functions row (collapsible)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: showScientific ? 90 : 0
                    color: Qt.rgba(0.06, 0.07, 0.09, 0.95)
                    clip: true
                    visible: showScientific
                    
                    Behavior on Layout.preferredHeight { NumberAnimation { duration: 150 } }
                    
                    GridLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        columns: 6
                        rowSpacing: 4
                        columnSpacing: 4
                        
                        // Row 1: Trig functions
                        SciFnButton { text: "sin"; onClicked: insertFunction("sin") }
                        SciFnButton { text: "cos"; onClicked: insertFunction("cos") }
                        SciFnButton { text: "tan"; onClicked: insertFunction("tan") }
                        SciFnButton { text: "log"; onClicked: insertFunction("log") }
                        SciFnButton { text: "ln"; onClicked: insertFunction("ln") }
                        SciFnButton { text: "√"; onClicked: insertFunction("sqrt") }
                        
                        // Row 2: Advanced
                        SciFnButton { text: "sin⁻¹"; onClicked: insertFunction("asin") }
                        SciFnButton { text: "cos⁻¹"; onClicked: insertFunction("acos") }
                        SciFnButton { text: "tan⁻¹"; onClicked: insertFunction("atan") }
                        SciFnButton { text: "10ˣ"; onClicked: insertText("10**") }
                        SciFnButton { text: "eˣ"; onClicked: insertFunction("exp") }
                        SciFnButton { text: "x²"; onClicked: insertText("**2") }
                        
                        // Row 3: Constants and extras
                        SciFnButton { text: "π"; onClicked: insertText("π") }
                        SciFnButton { text: "e"; onClicked: insertText("e") }
                        SciFnButton { text: "n!"; onClicked: insertText("!") }
                        SciFnButton { text: "xʸ"; onClicked: insertText("^") }
                        SciFnButton { text: "|x|"; onClicked: insertFunction("abs") }
                        SciFnButton { text: "( )"; onClicked: insertText("()"); highlight: true }
                    }
                }
                
                // Main calculator buttons
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Qt.rgba(0.08, 0.09, 0.11, 0.95)
                    
                    GridLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        columns: 4
                        rowSpacing: 6
                        columnSpacing: 6
                        
                        // Row 1: Clear functions
                        CalcButton { text: "%"; onBtnClicked: insertText("%") }
                        CalcButton { text: "CE"; onBtnClicked: clearEntry(); isFunction: true }
                        CalcButton { text: "C"; isAccent: true; onBtnClicked: clear() }
                        CalcButton { text: "⌫"; onBtnClicked: backspace() }
                        
                        // Row 2
                        CalcButton { text: "7"; isNumber: true; onBtnClicked: insertText("7") }
                        CalcButton { text: "8"; isNumber: true; onBtnClicked: insertText("8") }
                        CalcButton { text: "9"; isNumber: true; onBtnClicked: insertText("9") }
                        CalcButton { text: "÷"; isOp: true; onBtnClicked: insertText("÷") }
                        
                        // Row 3
                        CalcButton { text: "4"; isNumber: true; onBtnClicked: insertText("4") }
                        CalcButton { text: "5"; isNumber: true; onBtnClicked: insertText("5") }
                        CalcButton { text: "6"; isNumber: true; onBtnClicked: insertText("6") }
                        CalcButton { text: "×"; isOp: true; onBtnClicked: insertText("×") }
                        
                        // Row 4
                        CalcButton { text: "1"; isNumber: true; onBtnClicked: insertText("1") }
                        CalcButton { text: "2"; isNumber: true; onBtnClicked: insertText("2") }
                        CalcButton { text: "3"; isNumber: true; onBtnClicked: insertText("3") }
                        CalcButton { text: "−"; isOp: true; onBtnClicked: insertText("-") }
                        
                        // Row 5
                        CalcButton { text: "("; onBtnClicked: insertText("(") }
                        CalcButton { text: "0"; isNumber: true; onBtnClicked: insertText("0") }
                        CalcButton { text: ")"; onBtnClicked: insertText(")") }
                        CalcButton { text: "+"; isOp: true; onBtnClicked: insertText("+") }
                        
                        // Row 6
                        CalcButton { text: "±"; onBtnClicked: insertText("(-") }
                        CalcButton { text: "."; isNumber: true; onBtnClicked: insertText(".") }
                        CalcButton { text: "^"; onBtnClicked: insertText("^") }
                        CalcButton { text: "="; isEquals: true; onBtnClicked: calculate() }
                    }
                }
            }
            
            // ===== HISTORY PANEL =====
            Rectangle {
                Layout.preferredWidth: showHistory ? 200 : 0
                Layout.fillHeight: true
                color: Qt.rgba(0.06, 0.07, 0.09, 0.98)
                clip: true
                visible: showHistory
                
                Behavior on Layout.preferredWidth { NumberAnimation { duration: 150 } }
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8
                    
                    RowLayout {
                        Layout.fillWidth: true
                        
                        Text {
                            text: "History"
                            color: "#888"
                            font.pixelSize: 12
                            font.bold: true
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        Rectangle {
                            width: 20
                            height: 20
                            radius: 4
                            color: clearHistMouse.containsMouse ? Qt.rgba(1,0.3,0.3,0.5) : "transparent"
                            
                            Text {
                                anchors.centerIn: parent
                                text: "🗑"
                                font.pixelSize: 10
                            }
                            
                            MouseArea {
                                id: clearHistMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: history = []
                            }
                        }
                    }
                    
                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: history
                        clip: true
                        spacing: 4
                        
                        delegate: Rectangle {
                            width: ListView.view.width
                            height: 50
                            radius: 6
                            color: histItemMouse.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.03)
                            
                            Column {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 2
                                
                                Text {
                                    width: parent.width
                                    text: modelData.expression
                                    color: "#aaa"
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                                
                                Text {
                                    text: "= " + modelData.result
                                    color: "#4ade80"
                                    font.pixelSize: 14
                                    font.bold: true
                                }
                            }
                            
                            MouseArea {
                                id: histItemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: useHistoryItem(modelData)
                            }
                        }
                        
                        // Empty state
                        Text {
                            anchors.centerIn: parent
                            text: "No history yet"
                            color: "#555"
                            font.pixelSize: 12
                            visible: history.length === 0
                        }
                    }
                }
            }
        }
        
        // ===== STATUS BAR =====
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
            color: Qt.rgba(0.06, 0.07, 0.09, 0.98)
            
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                
                Text {
                    text: degreeMode ? "Degrees" : "Radians"
                    color: "#666"
                    font.pixelSize: 10
                }
                
                Rectangle { width: 1; height: 12; color: "#333" }
                
                Text {
                    text: history.length + " calculations"
                    color: "#666"
                    font.pixelSize: 10
                }
                
                Item { Layout.fillWidth: true }
                
                Text {
                    text: "Press Enter to calculate"
                    color: "#555"
                    font.pixelSize: 10
                }
            }
        }
    }
    
    // ===== BUTTON COMPONENTS =====
    
    component CalcButton: Rectangle {
        property string text: ""
        property bool isNumber: false
        property bool isOp: false
        property bool isEquals: false
        property bool isAccent: false
        property bool isFunction: false
        signal btnClicked()
        
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumWidth: 50
        Layout.minimumHeight: 30
        radius: 8
        
        gradient: Gradient {
            GradientStop { 
                position: 0.0
                color: {
                    if (isEquals) return "#3b82f6"
                    if (isAccent) return "#dc2626"
                    if (isOp) return Qt.rgba(0.25, 0.45, 0.75, 0.7)
                    if (isNumber) return Qt.rgba(0.18, 0.20, 0.24, 1)
                    return Qt.rgba(0.14, 0.16, 0.20, 1)
                }
            }
            GradientStop { 
                position: 1.0
                color: {
                    if (isEquals) return "#2563eb"
                    if (isAccent) return "#b91c1c"
                    if (isOp) return Qt.rgba(0.2, 0.4, 0.7, 0.6)
                    if (isNumber) return Qt.rgba(0.14, 0.16, 0.20, 1)
                    return Qt.rgba(0.10, 0.12, 0.16, 1)
                }
            }
        }
        
        // Hover overlay
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: btnMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
        }
        
        // Subtle border
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.08)
        }
        
        Text {
            anchors.centerIn: parent
            text: parent.text
            font.pixelSize: isNumber ? 24 : 18
            font.family: "Segoe UI"
            font.weight: isEquals ? Font.Bold : Font.Normal
            color: "#ffffff"
        }
        
        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.btnClicked()
        }
        
        scale: btnMouse.pressed ? 0.95 : 1.0
        Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
    }
    
    component SciFnButton: Rectangle {
        property string text: ""
        property bool highlight: false
        signal clicked()
        
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: 6
        color: highlight ? Qt.rgba(0.4, 0.6, 0.9, 0.4) : Qt.rgba(0.12, 0.14, 0.18, 1)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.08)
        
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: sciBtnMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
        }
        
        Text {
            anchors.centerIn: parent
            text: parent.text
            font.pixelSize: 12
            font.family: "Segoe UI"
            color: "#cccccc"
        }
        
        MouseArea {
            id: sciBtnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
        
        scale: sciBtnMouse.pressed ? 0.95 : 1.0
        Behavior on scale { NumberAnimation { duration: 60 } }
    }
}
