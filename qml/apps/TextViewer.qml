// GlassOS Text Viewer - Full Window Text File Viewer
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: textViewer
    color: "transparent"
    
    property string filePath: ""
    property string fileName: ""
    property string content: ""
    property bool wordWrap: true
    property int fontSize: 12
    
    function loadFile(path, name) {
        filePath = path
        fileName = name
        content = Storage.readFile(path)
    }
    
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        
        // Toolbar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            color: Qt.rgba(0, 0, 0, 0.3)
            
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8
                
                // Font size controls
                Text {
                    text: "Font Size:"
                    font.pixelSize: 11
                    color: "#888888"
                }
                
                Rectangle {
                    width: 28
                    height: 26
                    radius: 4
                    color: fontDownMouse.containsMouse ? Qt.rgba(1,1,1,0.15) : "transparent"
                    
                    Text {
                        anchors.centerIn: parent
                        text: "A-"
                        font.pixelSize: 12
                        color: "#ffffff"
                    }
                    
                    MouseArea {
                        id: fontDownMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: fontSize = Math.max(8, fontSize - 2)
                    }
                }
                
                Rectangle {
                    width: 40
                    height: 24
                    radius: 3
                    color: Qt.rgba(0, 0, 0, 0.3)
                    
                    Text {
                        anchors.centerIn: parent
                        text: fontSize + "px"
                        font.pixelSize: 10
                        color: "#ffffff"
                    }
                }
                
                Rectangle {
                    width: 28
                    height: 26
                    radius: 4
                    color: fontUpMouse.containsMouse ? Qt.rgba(1,1,1,0.15) : "transparent"
                    
                    Text {
                        anchors.centerIn: parent
                        text: "A+"
                        font.pixelSize: 12
                        color: "#ffffff"
                    }
                    
                    MouseArea {
                        id: fontUpMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: fontSize = Math.min(32, fontSize + 2)
                    }
                }
                
                Rectangle {
                    width: 1
                    height: 20
                    color: Qt.rgba(1, 1, 1, 0.2)
                }
                
                // Word wrap toggle
                Rectangle {
                    width: 90
                    height: 26
                    radius: 4
                    color: wordWrap ? Qt.rgba(0.3, 0.5, 0.8, 0.4) : (wrapMouse.containsMouse ? Qt.rgba(1,1,1,0.15) : "transparent")
                    border.width: wordWrap ? 1 : 0
                    border.color: Qt.rgba(0.4, 0.6, 0.9, 0.5)
                    
                    Text {
                        anchors.centerIn: parent
                        text: "Word Wrap"
                        font.pixelSize: 11
                        color: "#ffffff"
                    }
                    
                    MouseArea {
                        id: wrapMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: wordWrap = !wordWrap
                    }
                }
                
                Item { Layout.fillWidth: true }
                
                // Copy all button
                Rectangle {
                    width: 80
                    height: 26
                    radius: 4
                    color: copyMouse.containsMouse ? Qt.rgba(1,1,1,0.2) : Qt.rgba(1,1,1,0.1)
                    
                    Text {
                        anchors.centerIn: parent
                        text: "📋 Copy All"
                        font.pixelSize: 11
                        color: "#ffffff"
                    }
                    
                    MouseArea {
                        id: copyMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            textArea.selectAll()
                            textArea.copy()
                            textArea.deselect()
                        }
                    }
                }
            }
        }
        
        // Text content
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Qt.rgba(0.05, 0.05, 0.08, 1)
            
            ScrollView {
                anchors.fill: parent
                anchors.margins: 8
                clip: true
                
                TextArea {
                    id: textArea
                    text: content
                    readOnly: true
                    font.family: "Consolas, Courier New, monospace"
                    font.pixelSize: fontSize
                    color: "#e0e0e0"
                    selectionColor: "#4a9eff"
                    selectedTextColor: "#ffffff"
                    wrapMode: wordWrap ? TextArea.WrapAnywhere : TextArea.NoWrap
                    background: Rectangle { color: "transparent" }
                    padding: 8
                    
                    // Line numbers would go here in a more advanced version
                }
            }
            
            // Empty state
            Column {
                anchors.centerIn: parent
                spacing: 12
                visible: content === "" && filePath !== ""
                
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "📄"
                    font.pixelSize: 48
                    opacity: 0.4
                }
                
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "File is empty"
                    font.pixelSize: 14
                    color: "#666666"
                }
            }
            
            // No file state
            Column {
                anchors.centerIn: parent
                spacing: 12
                visible: filePath === ""
                
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "📝"
                    font.pixelSize: 64
                    opacity: 0.3
                }
                
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No file loaded"
                    font.pixelSize: 14
                    color: "#666666"
                }
            }
        }
        
        // Status bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
            color: Qt.rgba(0, 0, 0, 0.3)
            
            Row {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 16
                
                Text {
                    text: fileName
                    font.pixelSize: 10
                    color: "#aaaaaa"
                }
                
                Text {
                    text: content.length + " characters"
                    font.pixelSize: 10
                    color: "#888888"
                }
                
                Text {
                    text: content.split("\n").length + " lines"
                    font.pixelSize: 10
                    color: "#888888"
                }
            }
        }
    }
}
