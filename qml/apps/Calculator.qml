// GlassOS Calculator - Fully Working
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: calc
    color: "transparent"
    
    property string display: "0"
    property real memory: 0
    property string operation: ""
    property bool newNumber: true
    
    function inputDigit(digit) {
        if (newNumber) {
            display = digit
            newNumber = false
        } else {
            if (display === "0" && digit !== ".") {
                display = digit
            } else if (digit === "." && display.indexOf(".") !== -1) {
                return
            } else {
                display = display + digit
            }
        }
    }
    
    function setOperation(op) {
        if (operation && !newNumber) {
            calculate()
        } else {
            memory = parseFloat(display)
        }
        operation = op
        newNumber = true
    }
    
    function calculate() {
        var current = parseFloat(display)
        var result = 0
        
        switch(operation) {
            case "+": result = memory + current; break
            case "-": result = memory - current; break
            case "*": result = memory * current; break
            case "/": result = current !== 0 ? memory / current : NaN; break
            default: return
        }
        
        if (isNaN(result) || !isFinite(result)) {
            display = "Error"
        } else {
            display = result.toString()
            if (display.length > 12) {
                display = result.toPrecision(10)
            }
        }
        
        memory = result
        operation = ""
        newNumber = true
    }
    
    function clear() {
        display = "0"
        memory = 0
        operation = ""
        newNumber = true
    }
    
    function backspace() {
        if (display.length > 1) {
            display = display.slice(0, -1)
        } else {
            display = "0"
            newNumber = true
        }
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8
        
        // Display
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            radius: 4
            color: Qt.rgba(0, 0, 0, 0.3)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.1)
            
            Text {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 10
                text: display
                font.pixelSize: display.length > 10 ? 24 : 36
                font.family: "Segoe UI"
                color: "#ffffff"
            }
            
            Text {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 6
                text: operation
                font.pixelSize: 14
                color: "#4aa3df"
                visible: operation !== ""
            }
        }
        
        // Buttons grid
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 4
            rowSpacing: 4
            columnSpacing: 4
            
            // Row 1
            CalcButton { text: "%"; onClicked: { display = (parseFloat(display) / 100).toString() } }
            CalcButton { text: "CE"; onClicked: { display = "0"; newNumber = true } }
            CalcButton { text: "C"; isAccent: true; onClicked: clear() }
            CalcButton { text: "⌫"; onClicked: backspace() }
            
            // Row 2
            CalcButton { text: "7"; isNumber: true; onClicked: inputDigit("7") }
            CalcButton { text: "8"; isNumber: true; onClicked: inputDigit("8") }
            CalcButton { text: "9"; isNumber: true; onClicked: inputDigit("9") }
            CalcButton { text: "÷"; isOp: true; onClicked: setOperation("/") }
            
            // Row 3
            CalcButton { text: "4"; isNumber: true; onClicked: inputDigit("4") }
            CalcButton { text: "5"; isNumber: true; onClicked: inputDigit("5") }
            CalcButton { text: "6"; isNumber: true; onClicked: inputDigit("6") }
            CalcButton { text: "×"; isOp: true; onClicked: setOperation("*") }
            
            // Row 4
            CalcButton { text: "1"; isNumber: true; onClicked: inputDigit("1") }
            CalcButton { text: "2"; isNumber: true; onClicked: inputDigit("2") }
            CalcButton { text: "3"; isNumber: true; onClicked: inputDigit("3") }
            CalcButton { text: "-"; isOp: true; onClicked: setOperation("-") }
            
            // Row 5
            CalcButton { 
                text: "±"
                onClicked: { 
                    var val = parseFloat(display)
                    display = (-val).toString()
                }
            }
            CalcButton { text: "0"; isNumber: true; onClicked: inputDigit("0") }
            CalcButton { text: "."; isNumber: true; onClicked: inputDigit(".") }
            CalcButton { text: "+"; isOp: true; onClicked: setOperation("+") }
            
            // Row 6
            CalcButton { text: "√"; onClicked: { display = Math.sqrt(parseFloat(display)).toString() } }
            CalcButton { text: "x²"; onClicked: { display = Math.pow(parseFloat(display), 2).toString() } }
            CalcButton { text: "1/x"; onClicked: { display = (1 / parseFloat(display)).toString() } }
            CalcButton { text: "="; isEquals: true; onClicked: calculate() }
        }
    }
    
    component CalcButton: Rectangle {
        property string text: ""
        property bool isNumber: false
        property bool isOp: false
        property bool isEquals: false
        property bool isAccent: false
        signal clicked()
        
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: 4
        
        color: {
            if (isEquals) return "#2a7fff"
            if (isAccent) return "#c43c3c"
            if (isOp) return Qt.rgba(0.2, 0.5, 0.8, 0.5)
            if (isNumber) return Qt.rgba(1, 1, 1, 0.12)
            return Qt.rgba(1, 1, 1, 0.08)
        }
        
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: btnMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
        }
        
        Text {
            anchors.centerIn: parent
            text: parent.text
            font.pixelSize: isNumber ? 20 : 16
            font.family: "Segoe UI"
            font.bold: isEquals
            color: "#ffffff"
        }
        
        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: parent.clicked()
        }
        
        scale: btnMouse.pressed ? 0.96 : 1.0
        Behavior on scale { NumberAnimation { duration: 50 } }
    }
}
