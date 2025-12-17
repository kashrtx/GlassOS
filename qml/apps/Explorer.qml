// GlassOS File Explorer - With File Preview and Context Menu
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Rectangle {
    id: explorer
    color: "transparent"
    
    property string currentPath: "/"
    property var files: []
    property var selectedFile: null
    
    signal openFile(string path, string name, bool isImage, bool isText)
    signal setAsWallpaper(string path)
    
    property var quickAccess: [
        { name: "Desktop", path: "/", icon: "🖥" },
        { name: "Documents", path: "/Documents", icon: "📄" },
        { name: "Downloads", path: "/Downloads", icon: "⬇" },
        { name: "Pictures", path: "/Pictures", icon: "🖼" },
        { name: "Videos", path: "/Videos", icon: "🎬" }
    ]
    
    Component.onCompleted: {
        loadFolder(currentPath)
    }
    
    function loadFolder(path) {
        currentPath = path
        files = Storage.listDirectory(path)
        selectedFile = null
    }
    
    function goUp() {
        if (currentPath !== "/") {
            var parts = currentPath.split("/").filter(function(p) { return p !== "" })
            parts.pop()
            var newPath = "/" + parts.join("/")
            if (newPath === "") newPath = "/"
            loadFolder(newPath)
        }
    }
    
    function isTextFile(name) {
        var ext = name.toLowerCase().split('.').pop()
        return ["txt", "md", "json", "xml", "html", "css", "js", "py", "qml", "log", "ini", "cfg"].indexOf(ext) !== -1
    }
    
    // Context menu
    Menu {
        id: contextMenu
        
        MenuItem {
            text: "Open"
            enabled: selectedFile !== null
            onTriggered: {
                if (selectedFile.isDirectory) {
                    loadFolder(selectedFile.path)
                } else {
                    openFilePreview(selectedFile)
                }
            }
        }
        
        MenuSeparator {}
        
        MenuItem {
            text: "Set as Wallpaper"
            enabled: selectedFile !== null && selectedFile.isImage
            onTriggered: {
                Storage.setWallpaper(selectedFile.path)
                explorer.setAsWallpaper(selectedFile.path)
            }
        }
        
        MenuSeparator {}
        
        MenuItem {
            text: "Refresh"
            onTriggered: loadFolder(currentPath)
        }
    }
    
    function openFilePreview(file) {
        if (file.isImage) {
            previewImage.source = Storage.getFileUrl(file.path)
            previewTitle.text = file.name
            previewType = "image"
            previewOverlay.visible = true
        } else if (isTextFile(file.name)) {
            previewText.text = Storage.readFile(file.path)
            previewTitle.text = file.name
            previewType = "text"
            previewOverlay.visible = true
        }
    }
    
    property string previewType: "none"
    
    RowLayout {
        anchors.fill: parent
        spacing: 0
        
        // Sidebar
        Rectangle {
            Layout.preferredWidth: 150
            Layout.fillHeight: true
            color: Qt.rgba(0, 0, 0, 0.2)
            
            Column {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 2
                
                Text {
                    text: "Quick Access"
                    font.pixelSize: 11
                    font.bold: true
                    color: "#888888"
                    leftPadding: 6
                    bottomPadding: 6
                }
                
                Repeater {
                    model: quickAccess
                    
                    Rectangle {
                        width: parent.width
                        height: 28
                        radius: 4
                        color: {
                            if (currentPath === modelData.path) return Qt.rgba(0.3, 0.6, 0.9, 0.3)
                            if (sidebarMouse.containsMouse) return Qt.rgba(1, 1, 1, 0.1)
                            return "transparent"
                        }
                        
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            spacing: 8
                            
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.icon
                                font.pixelSize: 14
                            }
                            
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name
                                font.pixelSize: 11
                                color: "#ffffff"
                            }
                        }
                        
                        MouseArea {
                            id: sidebarMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: loadFolder(modelData.path)
                        }
                    }
                }
            }
        }
        
        // Separator
        Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            color: Qt.rgba(1, 1, 1, 0.1)
        }
        
        // Main content
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
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
                    
                    // Back button
                    Rectangle {
                        width: 28
                        height: 26
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 3
                        color: backMouse.containsMouse && currentPath !== "/" ? Qt.rgba(1,1,1,0.15) : "transparent"
                        opacity: currentPath !== "/" ? 1 : 0.4
                        
                        Text {
                            anchors.centerIn: parent
                            text: "←"
                            font.pixelSize: 14
                            color: "#ffffff"
                        }
                        
                        MouseArea {
                            id: backMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: if (currentPath !== "/") goUp()
                        }
                    }
                    
                    // Up button
                    Rectangle {
                        width: 28
                        height: 26
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 3
                        color: upMouse.containsMouse && currentPath !== "/" ? Qt.rgba(1,1,1,0.15) : "transparent"
                        opacity: currentPath !== "/" ? 1 : 0.4
                        
                        Text {
                            anchors.centerIn: parent
                            text: "↑"
                            font.pixelSize: 14
                            color: "#ffffff"
                        }
                        
                        MouseArea {
                            id: upMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: if (currentPath !== "/") goUp()
                        }
                    }
                    
                    // Refresh button
                    Rectangle {
                        width: 28
                        height: 26
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 3
                        color: refreshMouse.containsMouse ? Qt.rgba(1,1,1,0.15) : "transparent"
                        
                        Text {
                            anchors.centerIn: parent
                            text: "🔄"
                            font.pixelSize: 12
                        }
                        
                        MouseArea {
                            id: refreshMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: loadFolder(currentPath)
                        }
                    }
                    
                    Item { width: 8; height: 1 }
                    
                    // Path bar
                    Rectangle {
                        width: explorer.width - 280
                        height: 26
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 3
                        color: Qt.rgba(0, 0, 0, 0.2)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.1)
                        
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            spacing: 6
                            
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "📁"
                                font.pixelSize: 12
                            }
                            
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: currentPath === "/" ? "Storage" : "Storage" + currentPath
                                font.pixelSize: 11
                                color: "#ffffff"
                            }
                        }
                    }
                }
            }
            
            // File grid area
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 8
                radius: 4
                color: Qt.rgba(0, 0, 0, 0.15)
                
                GridView {
                    id: fileGrid
                    anchors.fill: parent
                    anchors.margins: 8
                    cellWidth: 100
                    cellHeight: 90
                    clip: true
                    model: files
                    
                    delegate: Rectangle {
                        id: fileItem
                        width: fileGrid.cellWidth - 4
                        height: fileGrid.cellHeight - 4
                        radius: 4
                        color: fileMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                        border.width: selectedFile === modelData ? 1 : 0
                        border.color: "#4a9eff"
                        
                        Column {
                            anchors.centerIn: parent
                            spacing: 4
                            
                            // Icon or thumbnail
                            Item {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 48
                                height: 48
                                
                                // Folder/file icon
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.isDirectory ? "📁" : 
                                          (modelData.isImage ? "🖼" : "📄")
                                    font.pixelSize: 32
                                    visible: !modelData.isImage || !thumbImage.visible
                                }
                                
                                // Image thumbnail
                                Image {
                                    id: thumbImage
                                    anchors.fill: parent
                                    source: modelData.isImage ? Storage.getFileUrl(modelData.path) : ""
                                    fillMode: Image.PreserveAspectCrop
                                    visible: modelData.isImage && status === Image.Ready
                                    asynchronous: true
                                    
                                    Rectangle {
                                        anchors.fill: parent
                                        color: "transparent"
                                        border.width: 1
                                        border.color: Qt.rgba(1, 1, 1, 0.2)
                                        radius: 4
                                    }
                                }
                            }
                            
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 90
                                text: modelData.name
                                font.pixelSize: 10
                                color: "#ffffff"
                                elide: Text.ElideMiddle
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                        
                        MouseArea {
                            id: fileMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            
                            onClicked: function(mouse) {
                                selectedFile = modelData
                                if (mouse.button === Qt.RightButton) {
                                    contextMenu.popup()
                                }
                            }
                            
                            onDoubleClicked: {
                                if (modelData.isDirectory) {
                                    loadFolder(modelData.path)
                                } else {
                                    openFilePreview(modelData)
                                }
                            }
                        }
                        
                        scale: fileMouse.pressed ? 0.95 : 1.0
                        Behavior on scale { NumberAnimation { duration: 50 } }
                    }
                }
                
                // Empty folder message
                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    visible: files.length === 0
                    
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "📂"
                        font.pixelSize: 48
                        opacity: 0.4
                    }
                    
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "This folder is empty"
                        font.pixelSize: 12
                        color: "#666666"
                    }
                }
            }
            
            // Status bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                color: Qt.rgba(0, 0, 0, 0.2)
                
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: files.length + " items" + (selectedFile ? " | Selected: " + selectedFile.name : "")
                    font.pixelSize: 10
                    color: "#888888"
                }
            }
        }
    }
    
    // ===== FILE PREVIEW OVERLAY =====
    Rectangle {
        id: previewOverlay
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.8)
        visible: false
        
        MouseArea {
            anchors.fill: parent
            onClicked: previewOverlay.visible = false
        }
        
        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 60, 700)
            height: Math.min(parent.height - 60, 500)
            radius: 8
            color: Qt.rgba(0.12, 0.14, 0.18, 0.98)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.2)
            
            MouseArea {
                anchors.fill: parent
                // Prevent clicks from closing
            }
            
            Column {
                anchors.fill: parent
                spacing: 0
                
                // Header
                Rectangle {
                    width: parent.width
                    height: 36
                    radius: 8
                    color: Qt.rgba(0.2, 0.22, 0.28, 1)
                    
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 10
                        color: parent.color
                    }
                    
                    Text {
                        id: previewTitle
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Preview"
                        font.pixelSize: 13
                        font.bold: true
                        color: "#ffffff"
                    }
                    
                    // Close button
                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 4
                        width: 28
                        height: 26
                        radius: 4
                        color: previewCloseMouse.containsMouse ? "#e04343" : "transparent"
                        
                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            font.pixelSize: 12
                            color: "#ffffff"
                        }
                        
                        MouseArea {
                            id: previewCloseMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: previewOverlay.visible = false
                        }
                    }
                    
                    // Set as wallpaper button (for images)
                    Rectangle {
                        visible: previewType === "image"
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 4
                        anchors.rightMargin: 40
                        width: 120
                        height: 26
                        radius: 4
                        color: setWpMouse.containsMouse ? Qt.rgba(0.3, 0.5, 0.8, 0.6) : Qt.rgba(0.3, 0.5, 0.8, 0.3)
                        
                        Text {
                            anchors.centerIn: parent
                            text: "Set as Wallpaper"
                            font.pixelSize: 10
                            color: "#ffffff"
                        }
                        
                        MouseArea {
                            id: setWpMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                Storage.setWallpaper(selectedFile.path)
                                explorer.setAsWallpaper(selectedFile.path)
                            }
                        }
                    }
                }
                
                // Content
                Item {
                    width: parent.width
                    height: parent.height - 36
                    
                    // Image preview
                    Image {
                        id: previewImage
                        anchors.fill: parent
                        anchors.margins: 16
                        fillMode: Image.PreserveAspectFit
                        visible: previewType === "image"
                        asynchronous: true
                    }
                    
                    // Text preview
                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: 16
                        visible: previewType === "text"
                        clip: true
                        
                        TextArea {
                            id: previewText
                            readOnly: true
                            font.family: "Consolas"
                            font.pixelSize: 12
                            color: "#e0e0e0"
                            background: Rectangle { color: "transparent" }
                            wrapMode: TextArea.WrapAnywhere
                        }
                    }
                }
            }
            
            scale: previewOverlay.visible ? 1.0 : 0.9
            opacity: previewOverlay.visible ? 1.0 : 0
            Behavior on scale { NumberAnimation { duration: 150 } }
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }
    }
}
