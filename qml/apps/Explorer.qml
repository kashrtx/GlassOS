// GlassOS File Explorer - Consistent Menus & Open With Support
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Rectangle {
    id: explorer
    color: "transparent"
    
    property string currentPath: "/"
    property var files: []
    property var selectedFile: null
    
    signal openFileRequest(string path, string name, bool isImage, bool isText)
    signal setAsWallpaper(string path)
    signal openWithApp(string path, string appName)
    
    property var quickAccess: [
        { name: "Desktop", path: "/", icon: "🖥" },
        { name: "Documents", path: "/Documents", icon: "📄" },
        { name: "Downloads", path: "/Downloads", icon: "⬇" },
        { name: "Pictures", path: "/Pictures", icon: "🖼" },
        { name: "Videos", path: "/Videos", icon: "🎬" },
        { name: "Apps", path: "/Apps", icon: "📦" }
    ]
    
    Component.onCompleted: loadFolder(currentPath)
    
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
    
    function getFileExtension(name) {
        var parts = name.split('.')
        return parts.length > 1 ? '.' + parts[parts.length - 1].toLowerCase() : ''
    }
    
    // ALL text-like files should be editable in Notepad
    function isTextFile(name) {
        var ext = getFileExtension(name)
        var textExts = [".txt", ".md", ".json", ".xml", ".html", ".css", ".js", ".py", 
                        ".qml", ".log", ".ini", ".cfg", ".yaml", ".yml", ".csv", ".sh", 
                        ".bat", ".ps1", ".conf", ".gitignore", ".env"]
        return textExts.indexOf(ext) !== -1
    }
    
    function isImageFile(name) {
        var ext = getFileExtension(name)
        return [".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp", ".ico"].indexOf(ext) !== -1
    }
    
    function getFileIcon(file) {
        if (file.isDirectory) return "📁"
        if (file.isImage || isImageFile(file.name)) return "🖼"
        
        var ext = getFileExtension(file.name)
        var icons = {
            ".py": "🐍", ".js": "📜", ".qml": "📜",
            ".json": "📋", ".xml": "📋", ".html": "🌐",
            ".mp4": "🎬", ".mp3": "🎵", ".wav": "🎵",
            ".zip": "📦", ".pdf": "📕", ".md": "📝"
        }
        return icons[ext] || "📄"
    }
    
    function openFile(file) {
        if (file.isDirectory) {
            loadFolder(file.path)
            return
        }
        
        // All non-image files open in Notepad (editable text editor)
        if (file.isImage || isImageFile(file.name)) {
            explorer.openFileRequest(file.path, file.name, true, false)
        } else {
            // Open in Notepad for editing
            explorer.openFileRequest(file.path, file.name, false, true)
        }
    }
    
    function createNewFolder() {
        newItemDialog.isFolder = true
        newItemDialog.visible = true
        newItemInput.text = "New Folder"
        newItemInput.selectAll()
        newItemInput.forceActiveFocus()
    }
    
    function createNewFile() {
        newItemDialog.isFolder = false
        newItemDialog.visible = true
        newItemInput.text = "New File.txt"
        newItemInput.selectAll()
        newItemInput.forceActiveFocus()
    }
    
    // ===== CONSISTENT CONTEXT MENU STYLE =====
    component StyledMenu: Rectangle {
        id: menuRoot
        visible: false
        width: 180
        radius: 6
        z: 1000
        
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.18, 0.20, 0.25, 0.98) }
            GradientStop { position: 1.0; color: Qt.rgba(0.12, 0.14, 0.18, 0.98) }
        }
        
        border.width: 1
        border.color: Qt.rgba(0.4, 0.6, 0.9, 0.4)
        
        // Shadow
        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            radius: 10
            color: Qt.rgba(0, 0, 0, 0.5)
            z: -1
        }
        
        default property alias content: menuColumn.children
        property int itemCount: menuColumn.children.length
        
        height: menuColumn.height + 12
        
        Column {
            id: menuColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 6
            spacing: 2
        }
        
        function show(x, y) {
            menuRoot.x = x
            menuRoot.y = y
            menuRoot.visible = true
        }
        
        function hide() {
            menuRoot.visible = false
        }
    }
    
    component StyledMenuItem: Rectangle {
        id: menuItem
        height: 28
        radius: 4
        color: itemMouse.containsMouse ? Qt.rgba(0.3, 0.5, 0.8, 0.4) : "transparent"
        
        property string text: ""
        property string icon: ""
        property bool enabled: true
        signal clicked()
        
        opacity: enabled ? 1.0 : 0.4
        
        Row {
            anchors.fill: parent
            anchors.leftMargin: 10
            spacing: 8
            
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: menuItem.icon
                font.pixelSize: 12
                visible: menuItem.icon !== ""
            }
            
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: menuItem.text
                font.pixelSize: 11
                color: "#ffffff"
            }
        }
        
        MouseArea {
            id: itemMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: menuItem.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                if (menuItem.enabled) {
                    menuItem.clicked()
                }
            }
        }
    }
    
    component MenuSeparator: Rectangle {
        height: 1
        color: Qt.rgba(1, 1, 1, 0.15)
    }
    
    // File context menu
    StyledMenu {
        id: fileContextMenu
        
        StyledMenuItem {
            width: parent.width - 12
            text: "Open"
            icon: "📂"
            onClicked: { openFile(selectedFile); fileContextMenu.hide() }
        }
        
        StyledMenuItem {
            width: parent.width - 12
            text: "Open with GlassPad"
            icon: "📝"
            visible: !selectedFile?.isDirectory && !isImageFile(selectedFile?.name || "")
            onClicked: { 
                explorer.openFileRequest(selectedFile.path, selectedFile.name, false, true)
                fileContextMenu.hide()
            }
        }
        
        StyledMenuItem {
            width: parent.width - 12
            text: "Open with ImageViewer"
            icon: "🖼"
            visible: selectedFile && isImageFile(selectedFile.name)
            onClicked: { 
                explorer.openFileRequest(selectedFile.path, selectedFile.name, true, false)
                fileContextMenu.hide()
            }
        }
        
        MenuSeparator { width: parent.width - 12 }
        
        StyledMenuItem {
            width: parent.width - 12
            text: "Set as Wallpaper"
            icon: "🖼"
            visible: selectedFile && (selectedFile.isImage || isImageFile(selectedFile.name))
            onClicked: { 
                Storage.setWallpaper(selectedFile.path)
                explorer.setAsWallpaper(selectedFile.path)
                fileContextMenu.hide()
            }
        }
        
        MenuSeparator { width: parent.width - 12 }
        
        StyledMenuItem {
            width: parent.width - 12
            text: "Cut"
            icon: "✂"
            onClicked: { fileContextMenu.hide() }
        }
        
        StyledMenuItem {
            width: parent.width - 12
            text: "Copy"
            icon: "📋"
            onClicked: { fileContextMenu.hide() }
        }
        
        StyledMenuItem {
            width: parent.width - 12
            text: "Rename"
            icon: "✏"
            onClicked: { 
                fileContextMenu.hide()
                renameDialog.visible = true
                renameInput.text = selectedFile.name
                renameInput.selectAll()
                renameInput.forceActiveFocus()
            }
        }
        
        MenuSeparator { width: parent.width - 12 }
        
        StyledMenuItem {
            width: parent.width - 12
            text: "Delete"
            icon: "🗑"
            onClicked: { 
                fileContextMenu.hide()
                deleteDialog.visible = true
            }
        }
    }
    
    // Background context menu
    StyledMenu {
        id: bgContextMenu
        
        StyledMenuItem {
            width: parent.width - 12
            text: "New Folder"
            icon: "📁"
            onClicked: { bgContextMenu.hide(); createNewFolder() }
        }
        
        StyledMenuItem {
            width: parent.width - 12
            text: "New Text File"
            icon: "📄"
            onClicked: { bgContextMenu.hide(); createNewFile() }
        }
        
        MenuSeparator { width: parent.width - 12 }
        
        StyledMenuItem {
            width: parent.width - 12
            text: "Refresh"
            icon: "🔄"
            onClicked: { bgContextMenu.hide(); loadFolder(currentPath) }
        }
        
        StyledMenuItem {
            width: parent.width - 12
            text: "Paste"
            icon: "📋"
            enabled: false
            onClicked: { bgContextMenu.hide() }
        }
    }
    
    RowLayout {
        anchors.fill: parent
        spacing: 0
        
        // Sidebar
        Rectangle {
            Layout.preferredWidth: 130
            Layout.fillHeight: true
            color: Qt.rgba(0, 0, 0, 0.25)
            
            Column {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 2
                
                Text {
                    text: "Quick Access"
                    font.pixelSize: 10
                    font.bold: true
                    color: "#888888"
                    leftPadding: 4
                    bottomPadding: 6
                }
                
                Repeater {
                    model: quickAccess
                    
                    Rectangle {
                        width: parent.width
                        height: 28
                        radius: 4
                        color: currentPath === modelData.path ? Qt.rgba(0.3, 0.6, 0.9, 0.4) :
                               (sidebarMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent")
                        
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
                            cursorShape: Qt.PointingHandCursor
                            onClicked: loadFolder(modelData.path)
                        }
                    }
                }
                
                Item { height: 10; width: 1 }
                
                // New button
                Rectangle {
                    width: parent.width
                    height: 30
                    radius: 4
                    color: newBtnMouse.containsMouse ? Qt.rgba(0.3, 0.5, 0.8, 0.4) : Qt.rgba(0.3, 0.5, 0.8, 0.2)
                    border.width: 1
                    border.color: Qt.rgba(0.4, 0.6, 0.9, 0.3)
                    
                    Row {
                        anchors.centerIn: parent
                        spacing: 5
                        Text { text: "➕"; font.pixelSize: 11 }
                        Text { text: "New"; font.pixelSize: 10; color: "#fff" }
                    }
                    
                    MouseArea {
                        id: newBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            bgContextMenu.show(parent.x + 130, parent.y)
                        }
                    }
                }
            }
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
                color: Qt.rgba(0, 0, 0, 0.2)
                
                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    spacing: 4
                    
                    // Back
                    Rectangle {
                        width: 28
                        height: 26
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 4
                        color: backMouse.containsMouse && currentPath !== "/" ? Qt.rgba(1,1,1,0.15) : "transparent"
                        opacity: currentPath !== "/" ? 1 : 0.4
                        
                        Text { anchors.centerIn: parent; text: "←"; font.pixelSize: 14; color: "#fff" }
                        
                        MouseArea {
                            id: backMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: currentPath !== "/" ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: if (currentPath !== "/") goUp()
                        }
                    }
                    
                    // Refresh
                    Rectangle {
                        width: 28
                        height: 26
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 4
                        color: refreshMouse.containsMouse ? Qt.rgba(1,1,1,0.15) : "transparent"
                        
                        Text { anchors.centerIn: parent; text: "🔄"; font.pixelSize: 12 }
                        
                        MouseArea {
                            id: refreshMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: loadFolder(currentPath)
                        }
                    }
                    
                    // Path bar
                    Rectangle {
                        width: explorer.width - 350
                        height: 26
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 4
                        color: Qt.rgba(0, 0, 0, 0.25)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.1)
                        
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            spacing: 6
                            
                            Text { anchors.verticalCenter: parent.verticalCenter; text: "📁"; font.pixelSize: 12 }
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
            
            // File grid
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 8
                radius: 6
                color: Qt.rgba(0, 0, 0, 0.15)
                
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    onClicked: function(mouse) {
                        selectedFile = null
                        fileContextMenu.hide()
                        bgContextMenu.show(mouse.x, mouse.y)
                    }
                }
                
                GridView {
                    id: fileGrid
                    anchors.fill: parent
                    anchors.margins: 8
                    cellWidth: 85
                    cellHeight: 85
                    clip: true
                    model: files
                    
                    delegate: Rectangle {
                        width: 80
                        height: 80
                        radius: 4
                        color: selectedFile === modelData ? Qt.rgba(0.3, 0.5, 0.8, 0.4) : 
                               (fileMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent")
                        border.width: selectedFile === modelData ? 1 : 0
                        border.color: "#4a9eff"
                        
                        Column {
                            anchors.centerIn: parent
                            spacing: 4
                            
                            Item {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 44
                                height: 44
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: getFileIcon(modelData)
                                    font.pixelSize: 32
                                    visible: !modelData.isImage || thumbImg.status !== Image.Ready
                                }
                                
                                Image {
                                    id: thumbImg
                                    anchors.fill: parent
                                    source: modelData.isImage ? Storage.getFileUrl(modelData.path) : ""
                                    fillMode: Image.PreserveAspectCrop
                                    visible: modelData.isImage && status === Image.Ready
                                    asynchronous: true
                                }
                            }
                            
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 75
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
                                bgContextMenu.hide()
                                if (mouse.button === Qt.RightButton) {
                                    fileContextMenu.show(mouse.x + parent.x + 130, mouse.y + parent.y + 36)
                                }
                            }
                            
                            onDoubleClicked: openFile(modelData)
                        }
                        
                        scale: fileMouse.pressed ? 0.95 : 1.0
                        Behavior on scale { NumberAnimation { duration: 50 } }
                    }
                }
                
                // Empty state
                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    visible: files.length === 0
                    
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "📂"; font.pixelSize: 48; opacity: 0.35 }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Empty folder"; font.pixelSize: 12; color: "#666" }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Right-click to create"; font.pixelSize: 10; color: "#555" }
                }
            }
            
            // Status bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                color: Qt.rgba(0, 0, 0, 0.25)
                
                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 16
                    
                    Text { text: files.length + " items"; font.pixelSize: 10; color: "#888" }
                    Text { 
                        visible: selectedFile !== null
                        text: "Selected: " + (selectedFile ? selectedFile.name : "")
                        font.pixelSize: 10
                        color: "#aaa"
                    }
                }
            }
        }
    }
    
    // ===== NEW ITEM DIALOG =====
    Rectangle {
        id: newItemDialog
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.6)
        visible: false
        z: 100
        
        property bool isFolder: true
        
        MouseArea { anchors.fill: parent; onClicked: newItemDialog.visible = false }
        
        Rectangle {
            anchors.centerIn: parent
            width: 320
            height: 140
            radius: 8
            color: Qt.rgba(0.12, 0.14, 0.18, 0.98)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.2)
            
            MouseArea { anchors.fill: parent }
            
            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12
                
                Text {
                    text: newItemDialog.isFolder ? "📁 New Folder" : "📄 New File"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#ffffff"
                }
                
                TextField {
                    id: newItemInput
                    width: parent.width
                    height: 32
                    font.pixelSize: 12
                    color: "#ffffff"
                    placeholderText: newItemDialog.isFolder ? "Folder name" : "File name"
                    placeholderTextColor: "#666"
                    background: Rectangle {
                        color: Qt.rgba(0, 0, 0, 0.3)
                        radius: 4
                        border.width: 1
                        border.color: newItemInput.activeFocus ? "#4a9eff" : Qt.rgba(1, 1, 1, 0.15)
                    }
                    
                    Keys.onReturnPressed: doCreate()
                    Keys.onEscapePressed: newItemDialog.visible = false
                    
                    function doCreate() {
                        var name = newItemInput.text.trim()
                        if (name) {
                            var fullPath = currentPath === "/" ? "/" + name : currentPath + "/" + name
                            if (newItemDialog.isFolder) {
                                Storage.createDirectory(fullPath)
                            } else {
                                Storage.writeFile(fullPath, "")
                            }
                            newItemDialog.visible = false
                            loadFolder(currentPath)
                        }
                    }
                }
                
                Row {
                    anchors.right: parent.right
                    spacing: 8
                    
                    Rectangle {
                        width: 70; height: 28; radius: 4
                        color: cancelMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.08)
                        Text { anchors.centerIn: parent; text: "Cancel"; font.pixelSize: 11; color: "#fff" }
                        MouseArea { id: cancelMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: newItemDialog.visible = false }
                    }
                    
                    Rectangle {
                        width: 70; height: 28; radius: 4
                        color: createMouse.containsMouse ? Qt.rgba(0.3, 0.5, 0.8, 0.7) : Qt.rgba(0.3, 0.5, 0.8, 0.5)
                        Text { anchors.centerIn: parent; text: "Create"; font.pixelSize: 11; color: "#fff" }
                        MouseArea { id: createMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: newItemInput.doCreate() }
                    }
                }
            }
        }
    }
    
    // ===== DELETE DIALOG =====
    Rectangle {
        id: deleteDialog
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.6)
        visible: false
        z: 100
        
        MouseArea { anchors.fill: parent; onClicked: deleteDialog.visible = false }
        
        Rectangle {
            anchors.centerIn: parent
            width: 320
            height: 110
            radius: 8
            color: Qt.rgba(0.12, 0.14, 0.18, 0.98)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.2)
            
            MouseArea { anchors.fill: parent }
            
            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12
                
                Text {
                    text: "🗑 Delete \"" + (selectedFile ? selectedFile.name : "") + "\"?"
                    font.pixelSize: 12
                    color: "#fff"
                    width: parent.width
                    elide: Text.ElideMiddle
                }
                
                Text { text: "This cannot be undone."; font.pixelSize: 11; color: "#888" }
                
                Row {
                    anchors.right: parent.right
                    spacing: 8
                    
                    Rectangle {
                        width: 70; height: 28; radius: 4
                        color: cancelDelMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.08)
                        Text { anchors.centerIn: parent; text: "Cancel"; font.pixelSize: 11; color: "#fff" }
                        MouseArea { id: cancelDelMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: deleteDialog.visible = false }
                    }
                    
                    Rectangle {
                        width: 70; height: 28; radius: 4
                        color: confirmDelMouse.containsMouse ? "#c04040" : "#e04343"
                        Text { anchors.centerIn: parent; text: "Delete"; font.pixelSize: 11; color: "#fff" }
                        MouseArea { 
                            id: confirmDelMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (selectedFile) {
                                    Storage.deleteItem(selectedFile.path)
                                    deleteDialog.visible = false
                                    loadFolder(currentPath)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // ===== RENAME DIALOG =====
    Rectangle {
        id: renameDialog
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.6)
        visible: false
        z: 100
        
        MouseArea { anchors.fill: parent; onClicked: renameDialog.visible = false }
        
        Rectangle {
            anchors.centerIn: parent
            width: 320
            height: 130
            radius: 8
            color: Qt.rgba(0.12, 0.14, 0.18, 0.98)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.2)
            
            MouseArea { anchors.fill: parent }
            
            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12
                
                Text { text: "✏ Rename"; font.pixelSize: 14; font.bold: true; color: "#fff" }
                
                TextField {
                    id: renameInput
                    width: parent.width
                    height: 32
                    font.pixelSize: 12
                    color: "#fff"
                    background: Rectangle {
                        color: Qt.rgba(0, 0, 0, 0.3)
                        radius: 4
                        border.width: 1
                        border.color: renameInput.activeFocus ? "#4a9eff" : Qt.rgba(1, 1, 1, 0.15)
                    }
                    
                    Keys.onReturnPressed: doRename()
                    Keys.onEscapePressed: renameDialog.visible = false
                    
                    function doRename() {
                        var newName = renameInput.text.trim()
                        if (newName && selectedFile) {
                            if (Storage.renameItem(selectedFile.path, newName)) {
                                renameDialog.visible = false
                                loadFolder(currentPath)
                            }
                        }
                    }
                }
                
                Row {
                    anchors.right: parent.right
                    spacing: 8
                    
                    Rectangle {
                        width: 70; height: 28; radius: 4
                        color: cancelRenameMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.08)
                        Text { anchors.centerIn: parent; text: "Cancel"; font.pixelSize: 11; color: "#fff" }
                        MouseArea { id: cancelRenameMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: renameDialog.visible = false }
                    }
                    
                    Rectangle {
                        width: 70; height: 28; radius: 4
                        color: confirmRenameMouse.containsMouse ? Qt.rgba(0.3, 0.5, 0.8, 0.7) : Qt.rgba(0.3, 0.5, 0.8, 0.5)
                        Text { anchors.centerIn: parent; text: "Rename"; font.pixelSize: 11; color: "#fff" }
                        MouseArea { id: confirmRenameMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: renameInput.doRename() }
                    }
                }
            }
        }
    }
}
