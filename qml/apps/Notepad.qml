// GlassOS Notepad (GlassPad) - Working Text Editor
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: notepad
    color: "transparent"
    
    property bool modified: false
    property string fileName: "Untitled"
    
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        
        // Toolbar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            color: Qt.rgba(0, 0, 0, 0.15)
            
            Row {
                anchors.fill: parent
                anchors.leftMargin: 8
                spacing: 4
                
                ToolButton { icon: "📄"; tooltip: "New"; onClicked: { textArea.text = ""; modified = false; fileName = "Untitled" } }
                ToolButton { icon: "📂"; tooltip: "Open"; onClicked: { /* TODO */ } }
                ToolButton { icon: "💾"; tooltip: "Save"; onClicked: { modified = false } }
                
                ToolSeparator {}
                
                ToolButton { icon: "✂"; tooltip: "Cut" }
                ToolButton { icon: "📋"; tooltip: "Copy" }
                ToolButton { icon: "📥"; tooltip: "Paste" }
                
                ToolSeparator {}
                
                ToolButton { icon: "↩"; tooltip: "Undo" }
                ToolButton { icon: "↪"; tooltip: "Redo" }
                
                ToolSeparator {}
                
                ToolButton { 
                    icon: "B"
                    tooltip: "Bold"
                    fontBold: true
                }
                ToolButton { 
                    icon: "I"
                    tooltip: "Italic"
                    fontItalic: true
                }
                ToolButton { 
                    icon: "U"
                    tooltip: "Underline"
                    fontUnderline: true
                }
            }
        }
        
        // Text area
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Qt.rgba(0.05, 0.05, 0.08, 0.9)
            
            ScrollView {
                anchors.fill: parent
                anchors.margins: 4
                
                TextArea {
                    id: textArea
                    font.family: "Consolas"
                    font.pixelSize: 14
                    color: "#ffffff"
                    selectionColor: "#4a90d9"
                    selectedTextColor: "#ffffff"
                    wrapMode: TextEdit.Wrap
                    
                    background: Rectangle {
                        color: "transparent"
                    }
                    
                    placeholderText: "Start typing..."
                    placeholderTextColor: "#555555"
                    
                    onTextChanged: modified = true
                }
            }
        }
        
        // Status bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 22
            color: Qt.rgba(0, 0, 0, 0.25)
            
            Row {
                anchors.fill: parent
                anchors.leftMargin: 10
                spacing: 20
                
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: fileName + (modified ? " *" : "")
                    font.pixelSize: 10
                    color: "#888888"
                }
                
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: textArea.text.length + " characters"
                    font.pixelSize: 10
                    color: "#888888"
                }
                
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: textArea.text.split("\n").length + " lines"
                    font.pixelSize: 10
                    color: "#888888"
                }
            }
        }
    }
    
    component ToolButton: Rectangle {
        property string icon: ""
        property string tooltip: ""
        property bool fontBold: false
        property bool fontItalic: false
        property bool fontUnderline: false
        signal clicked()
        
        width: 28
        height: 26
        anchors.verticalCenter: parent.verticalCenter
        radius: 3
        color: tbMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
        
        Text {
            anchors.centerIn: parent
            text: icon
            font.pixelSize: 13
            font.bold: fontBold
            font.italic: fontItalic
            font.underline: fontUnderline
            color: "#ffffff"
        }
        
        MouseArea {
            id: tbMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: parent.clicked()
        }
        
        ToolTip.visible: tbMouse.containsMouse
        ToolTip.text: tooltip
        ToolTip.delay: 500
    }
    
    component ToolSeparator: Rectangle {
        width: 1
        height: 20
        anchors.verticalCenter: parent.verticalCenter
        color: Qt.rgba(1, 1, 1, 0.2)
    }
}
