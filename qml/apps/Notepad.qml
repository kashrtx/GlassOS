// GlassOS Notepad (GlassPad) - Full Text Editor
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: notepad
    color: "transparent"
    
    // Bind to System Accessibility
    property int baseFontSize: (typeof Accessibility !== "undefined" && Accessibility) ? Accessibility.baseFontSize : 14
    property bool useBold: (typeof Accessibility !== "undefined" && Accessibility) ? Accessibility.boldText : false
    property int fontSize: baseFontSize // Validated default
    
    // Watch for system changes to reset/update
    onBaseFontSizeChanged: fontSize = baseFontSize
    
    property bool modified: false
    property string fileName: "Untitled"
    property string filePath: ""
    
    function loadFile(path, name) {
        filePath = path
        fileName = name
        var content = Storage.readFile(path)
        textArea.text = content
        modified = false
    }
    
    function saveFile() {
        if (filePath) {
            Storage.writeFile(filePath, textArea.text)
            modified = false
        } else {
            console.log("Save As not implemented in inline editor")
        }
    }
    
    function newFile() {
        textArea.text = ""
        fileName = "Untitled"
        filePath = ""
        modified = false
    }
    
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        
        // Toolbar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            color: Qt.rgba(0.1, 0.12, 0.15, 0.95)
            
            Row {
                anchors.fill: parent; anchors.leftMargin: 8; spacing: 4
                
                ToolButton { icon: "📄"; tooltip: "New"; onBtnClicked: newFile() }
                ToolButton { icon: "💾"; tooltip: "Save"; highlight: modified; onBtnClicked: saveFile() }
                ToolSeparator {}
                ToolButton { icon: "✂"; tooltip: "Cut"; onBtnClicked: textArea.cut() }
                ToolButton { icon: "📋"; tooltip: "Copy"; onBtnClicked: textArea.copy() }
                ToolButton { icon: "📥"; tooltip: "Paste"; onBtnClicked: textArea.paste() }
                ToolSeparator {}
                ToolButton { icon: "↩"; tooltip: "Undo"; onBtnClicked: textArea.undo() }
                ToolButton { icon: "↪"; tooltip: "Redo"; onBtnClicked: textArea.redo() }
                ToolSeparator {}
                ToolButton { 
                    icon: "⏎"; tooltip: "Word Wrap"; 
                    highlight: textArea.wrapMode === TextEdit.Wrap
                    onBtnClicked: textArea.wrapMode = (textArea.wrapMode === TextEdit.Wrap ? TextEdit.NoWrap : TextEdit.Wrap)
                }
                
                Item { width: 10 }
                
                // Font Control
                Row {
                    anchors.verticalCenter: parent.verticalCenter; spacing: 4
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "A"; font.pixelSize: 12; color: "#aaa" }
                    
                    Rectangle {
                        width: 24; height: 22; radius: 4
                        color: minusMouse.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
                        Text { anchors.centerIn: parent; text: "−"; color: "#fff" }
                        MouseArea { id: minusMouse; anchors.fill: parent; onClicked: if(fontSize > 8) fontSize -= 2 }
                    }
                    
                    Text { 
                        anchors.verticalCenter: parent.verticalCenter
                        text: fontSize + "px"
                        color: "#fff"; font.pixelSize: 11; width: 30
                        horizontalAlignment: Text.AlignHCenter
                    }
                    
                    Rectangle {
                        width: 24; height: 22; radius: 4
                        color: plusMouse.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
                        Text { anchors.centerIn: parent; text: "+"; color: "#fff" }
                        MouseArea { id: plusMouse; anchors.fill: parent; onClicked: if(fontSize < 48) fontSize += 2 }
                    }
                }
            }
        }
        
        // Editor Area
        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true
            color: Qt.rgba(0.05, 0.05, 0.08, 0.9)
            
            // Line Numbers
            Rectangle {
                id: gutters
                width: 40; height: parent.height
                color: Qt.rgba(0,0,0,0.2)
                
                Column {
                    y: -textAreaFlick.contentY + textArea.topPadding
                    width: parent.width
                    Repeater {
                        model: textArea.lineCount
                        Text {
                            width: 34; height: textArea.cursorRectangle.height
                            x: 3
                            text: index + 1
                            font: textArea.font
                            color: "#666"
                            horizontalAlignment: Text.AlignRight
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
            
            Flickable {
                id: textAreaFlick
                anchors.left: gutters.right; anchors.right: parent.right
                anchors.top: parent.top; anchors.bottom: parent.bottom
                contentWidth: textArea.width; contentHeight: textArea.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                
                TextArea {
                    id: textArea
                    width: Math.max(textAreaFlick.width, implicitWidth)
                    height: Math.max(textAreaFlick.height, implicitHeight)
                    padding: 8
                    
                    color: "#ffffff"
                    selectionColor: "#4a90d9"
                    selectedTextColor: "#ffffff"
                    
                    font.family: "Consolas"
                    font.pixelSize: fontSize
                    font.bold: useBold
                    
                    wrapMode: TextEdit.NoWrap
                    
                    onTextChanged: modified = true
                    
                    Keys.onPressed: (event) => {
                        if ((event.key === Qt.Key_S) && (event.modifiers & Qt.ControlModifier)) {
                            saveFile(); event.accepted = true;
                        }
                        if ((event.key === Qt.Key_N) && (event.modifiers & Qt.ControlModifier)) {
                            newFile(); event.accepted = true;
                        }
                    }
                }
                
                ScrollBar.vertical: ScrollBar {}
                ScrollBar.horizontal: ScrollBar {}
            }
        }
        
        // Status Bar
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 24
            color: "#1e1e1e"
            Row {
                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 12
                Text { 
                    text: (modified ? "*" : "") + (fileName || "Untitled")
                    color: "#fff"; font.pixelSize: 11; font.bold: useBold
                    anchors.verticalCenter: parent.verticalCenter
                }
                Rectangle { width: 1; height: 14; color: "#444"; anchors.verticalCenter: parent.verticalCenter }
                Text { 
                    text: textArea.length + " chars"
                    color: "#aaa"; font.pixelSize: 11; font.bold: useBold
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text { 
                    text: textArea.lineCount + " lines"
                    color: "#aaa"; font.pixelSize: 11; font.bold: useBold
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
    
    // Components
    component ToolButton: Rectangle {
        property string icon
        property string tooltip
        property bool highlight: false
        signal btnClicked()
        
        width: 30; height: 30
        radius: 4
        anchors.verticalCenter: parent.verticalCenter
        color: highlight ? Qt.rgba(0.3, 0.5, 0.8, 0.4) : (tbMouse.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent")
        
        Text { anchors.centerIn: parent; text: icon; font.pixelSize: 16 }
        
        MouseArea {
            id: tbMouse; anchors.fill: parent; hoverEnabled: true
            onClicked: btnClicked()
        }
        ToolTip.visible: tbMouse.containsMouse
        ToolTip.text: tooltip
        ToolTip.delay: 500
    }
    
    component ToolSeparator: Rectangle {
        width: 1; height: 20
        color: "#444"
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: 2
    }
}
