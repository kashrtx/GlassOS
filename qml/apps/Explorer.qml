// GlassOS File Explorer - Windows 11 Style with Details Pane
// Complete overhaul with navigation tree, toolbar, search, views, and details pane
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Rectangle {
    id: explorer
    color: "transparent"
    
    // ===== STATE =====
    property string currentPath: "/"
    property string initialPath: "/"
    property var files: []
    property var selectedFile: null
    property var selectedFiles: []  // Multiple selection support
    property string viewMode: "grid"  // "grid" or "details"
    property bool showDetailsPane: true
    property bool showCheckboxes: false  // Checkbox selection mode
    property string searchQuery: ""
    property var navigationHistory: []
    property int historyIndex: -1
    property int lastSelectedIndex: -1  // For shift+click range selection
    
    // ===== SELECTION HELPERS =====
    function isFileSelected(file) {
        for (var i = 0; i < selectedFiles.length; i++) {
            if (selectedFiles[i].path === file.path) return true
        }
        return false
    }
    
    function toggleFileSelection(file) {
        var newSelection = selectedFiles.slice()
        var idx = -1
        for (var i = 0; i < newSelection.length; i++) {
            if (newSelection[i].path === file.path) { idx = i; break }
        }
        if (idx >= 0) {
            newSelection.splice(idx, 1)
        } else {
            newSelection.push(file)
        }
        selectedFiles = newSelection
        selectedFile = newSelection.length > 0 ? newSelection[newSelection.length - 1] : null
    }
    
    function selectFile(file, addToSelection) {
        if (addToSelection) {
            toggleFileSelection(file)
        } else {
            selectedFiles = [file]
            selectedFile = file
        }
    }
    
    function selectAll() {
        var filtered = getFilteredFiles()
        selectedFiles = filtered.slice()
        selectedFile = filtered.length > 0 ? filtered[filtered.length - 1] : null
    }
    
    function clearSelection() {
        selectedFiles = []
        selectedFile = null
    }
    
    function getSelectedCount() {
        return selectedFiles.length
    }
    
    onInitialPathChanged: loadFolder(initialPath)
    
    signal openFileRequest(string path, string name, bool isImage, bool isText)
    signal setAsWallpaper(string path)
    signal openWithApp(string path, string appName)
    
    // Navigation tree structure
    property var navTree: [
        { name: "Desktop", path: "/", icon: "🖥", expanded: false, children: [] },
        { name: "Documents", path: "/Documents", icon: "📄", expanded: false, children: [] },
        { name: "Downloads", path: "/Downloads", icon: "⬇", expanded: false, children: [] },
        { name: "Pictures", path: "/Pictures", icon: "🖼", expanded: false, children: [] },
        { name: "Videos", path: "/Videos", icon: "🎬", expanded: false, children: [] },
        { name: "Apps", path: "/Apps", icon: "📦", expanded: false, children: [] },
        { name: "Recycle Bin", path: "/Recycle Bin", icon: "🗑", expanded: false, children: [] }
    ]
    
    Component.onCompleted: loadFolder(currentPath)
    
    // ===== FILE OPERATIONS =====
    function loadFolder(path, addToHistory) {
        // Hide any open context menus
        fileContextMenu.visible = false
        bgContextMenu.visible = false
        
        if (addToHistory !== false && path !== currentPath) {
            // Add to history
            if (historyIndex < navigationHistory.length - 1) {
                navigationHistory = navigationHistory.slice(0, historyIndex + 1)
            }
            navigationHistory.push(currentPath)
            historyIndex = navigationHistory.length - 1
        }
        
        currentPath = path
        files = Storage.listDirectory(path)
        selectedFile = null
        selectedFiles = []
        searchQuery = ""
    }
    
    function goBack() {
        if (historyIndex > 0) {
            historyIndex--
            loadFolder(navigationHistory[historyIndex], false)
        }
    }
    
    function goForward() {
        if (historyIndex < navigationHistory.length - 1) {
            historyIndex++
            loadFolder(navigationHistory[historyIndex], false)
        }
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
    
    function getFileType(file) {
        if (file.isDirectory) return "Folder"
        var ext = getFileExtension(file.name)
        var types = {
            ".txt": "Text Document", ".md": "Markdown", ".json": "JSON File",
            ".js": "JavaScript", ".py": "Python Script", ".qml": "QML File",
            ".html": "HTML Document", ".css": "CSS Stylesheet",
            ".jpg": "JPEG Image", ".jpeg": "JPEG Image", ".png": "PNG Image",
            ".gif": "GIF Image", ".bmp": "Bitmap", ".webp": "WebP Image",
            ".mp4": "Video", ".mp3": "Audio", ".pdf": "PDF Document"
        }
        return types[ext] || "File"
    }
    
    function formatFileSize(bytes) {
        if (bytes === 0) return "—"
        if (bytes < 1024) return bytes + " B"
        if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + " KB"
        if (bytes < 1024 * 1024 * 1024) return (bytes / (1024 * 1024)).toFixed(1) + " MB"
        return (bytes / (1024 * 1024 * 1024)).toFixed(2) + " GB"
    }
    
    function openFile(file) {
        if (file.isDirectory) {
            loadFolder(file.path)
            return
        }
        
        if (file.isImage || isImageFile(file.name)) {
            explorer.openFileRequest(file.path, file.name, true, false)
        } else {
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
    
    function getPathBreadcrumbs() {
        if (currentPath === "/") return [{ name: "Storage", path: "/" }]
        var parts = currentPath.split("/").filter(function(p) { return p !== "" })
        var crumbs = [{ name: "Storage", path: "/" }]
        var buildPath = ""
        for (var i = 0; i < parts.length; i++) {
            buildPath += "/" + parts[i]
            crumbs.push({ name: parts[i], path: buildPath })
        }
        return crumbs
    }
    
    // Filter files by search
    function getFilteredFiles() {
        if (!searchQuery || searchQuery.trim() === "") return files
        var q = searchQuery.toLowerCase()
        return files.filter(function(f) {
            return f.name.toLowerCase().indexOf(q) !== -1
        })
    }
    
    // Track clipboard for reactive paste button
    property bool hasClipboard: Storage.clipboardPath !== ""
    
    Connections {
        target: Storage
        function onClipboardChanged() {
            hasClipboard = Storage.clipboardPath !== ""
        }
    }
    
    // ===== CLICK OUTSIDE TO CLOSE MENUS =====
    MouseArea {
        anchors.fill: parent
        z: 50
        visible: fileContextMenu.visible || bgContextMenu.visible
        onClicked: {
            fileContextMenu.visible = false
            bgContextMenu.visible = false
        }
    }
    
    // ===== KEYBOARD SHORTCUTS =====
    focus: true
    Keys.onPressed: function(event) {
        if (event.modifiers & Qt.ControlModifier) {
            if (event.key === Qt.Key_A) {
                // Select all
                selectAll()
                event.accepted = true
            } else if (event.key === Qt.Key_C && selectedFiles.length > 0) {
                Storage.setClipboard(selectedFile.path, "copy")
                event.accepted = true
            } else if (event.key === Qt.Key_X && selectedFiles.length > 0) {
                Storage.setClipboard(selectedFile.path, "cut")
                event.accepted = true
            } else if (event.key === Qt.Key_V && currentPath !== "/Recycle Bin" && hasClipboard) {
                if (Storage.paste(currentPath)) loadFolder(currentPath)
                event.accepted = true
            } else if (event.key === Qt.Key_R) {
                loadFolder(currentPath)
                event.accepted = true
            }
        } else if (event.key === Qt.Key_Delete && selectedFiles.length > 0) {
            // Delete all selected files
            for (var i = 0; i < selectedFiles.length; i++) {
                if (currentPath === "/Recycle Bin") {
                    Storage.deleteItem(selectedFiles[i].path)
                } else {
                    Storage.moveToTrash(selectedFiles[i].path)
                }
            }
            loadFolder(currentPath)
            event.accepted = true
        } else if (event.key === Qt.Key_F5) {
            loadFolder(currentPath)
            event.accepted = true
        } else if (event.key === Qt.Key_Backspace && currentPath !== "/") {
            goUp()
            event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
            clearSelection()
            event.accepted = true
        }
    }
    
    // ===== MAIN LAYOUT =====
    RowLayout {
        anchors.fill: parent
        spacing: 0
        
        // ===== NAVIGATION PANE (Left Sidebar) =====
        Rectangle {
            Layout.preferredWidth: 180
            Layout.fillHeight: true
            color: Qt.rgba(0.06, 0.07, 0.09, 0.95)
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4
                
                // Quick Access Header
                Text {
                    text: "Quick Access"
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: "#888888"
                    leftPadding: 8
                    topPadding: 4
                    bottomPadding: 4
                }
                
                // Navigation Items
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: navTree
                    spacing: 2
                    clip: true
                    
                    delegate: Rectangle {
                        width: ListView.view.width
                        height: 32
                        radius: 6
                        
                        property bool isActive: currentPath === modelData.path
                        property bool isHovered: navItemMouse.containsMouse
                        
                        color: isActive ? Theme.accentColor : (isHovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                        
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            spacing: 10
                            
                            // Expand chevron (placeholder for future tree)
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "›"
                                font.pixelSize: 10
                                color: "#666"
                                visible: false // Hide for now
                            }
                            
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.icon
                                font.pixelSize: 14
                            }
                            
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name
                                font.pixelSize: 12
                                color: isActive ? "#ffffff" : "#cccccc"
                            }
                        }
                        
                        MouseArea {
                            id: navItemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: loadFolder(modelData.path)
                        }
                    }
                }
                
                // Separator
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.1)
                }
                
                // New Button
                Rectangle {
                    Layout.fillWidth: true
                    height: 36
                    radius: 6
                    color: newBtnMouse.containsMouse ? Qt.rgba(0.3, 0.5, 0.8, 0.5) : Qt.rgba(0.3, 0.5, 0.8, 0.3)
                    border.width: 1
                    border.color: Qt.rgba(0.4, 0.6, 0.9, 0.3)
                    
                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        Text { text: "➕"; font.pixelSize: 12 }
                        Text { text: "New"; font.pixelSize: 12; color: "#fff"; font.weight: Font.Medium }
                    }
                    
                    MouseArea {
                        id: newBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: newMenu.open()
                        
                        Popup {
                            id: newMenu
                            y: -height - 4
                            width: 160
                            padding: 6
                            
                            background: Rectangle {
                                color: Qt.rgba(0.12, 0.14, 0.18, 0.98)
                                radius: 6
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.15)
                            }
                            
                            Column {
                                width: parent.width
                                spacing: 2
                                
                                PopupMenuItem {
                                    text: "New Folder"
                                    icon: "📁"
                                    onClicked: { newMenu.close(); createNewFolder() }
                                }
                                PopupMenuItem {
                                    text: "New Text File"
                                    icon: "📄"
                                    onClicked: { newMenu.close(); createNewFile() }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // ===== MAIN CONTENT AREA =====
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0
            
            // ===== TOOLBAR =====
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                color: Qt.rgba(0.08, 0.09, 0.11, 0.98)
                
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 4
                    
                    // Navigation buttons
                    Row {
                        spacing: 2
                        
                        ToolbarButton {
                            icon: "←"
                            tooltip: "Back (Alt+Left)"
                            enabled: historyIndex > 0
                            onClicked: goBack()
                        }
                        ToolbarButton {
                            icon: "→"
                            tooltip: "Forward (Alt+Right)"
                            enabled: historyIndex < navigationHistory.length - 1
                            onClicked: goForward()
                        }
                        ToolbarButton {
                            icon: "↑"
                            tooltip: "Up (Backspace)"
                            enabled: currentPath !== "/"
                            onClicked: goUp()
                        }
                        ToolbarButton {
                            icon: "⟳"
                            tooltip: "Refresh (F5)"
                            onClicked: loadFolder(currentPath)
                        }
                    }
                    
                    // Breadcrumb Path Bar
                    Rectangle {
                        Layout.fillWidth: true
                        height: 32
                        radius: 6
                        color: Qt.rgba(0, 0, 0, 0.3)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.1)
                        
                        Row {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 4
                            
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: currentPath === "/Recycle Bin" ? "🗑" : "📁"
                                font.pixelSize: 14
                            }
                            
                            Repeater {
                                model: getPathBreadcrumbs()
                                
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4
                                    
                                    Text {
                                        visible: index > 0
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "›"
                                        font.pixelSize: 14
                                        color: "#666"
                                    }
                                    
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.name
                                        font.pixelSize: 13
                                        color: crumbMouse.containsMouse ? "#4a9eff" : "#ffffff"
                                        
                                        MouseArea {
                                            id: crumbMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: loadFolder(modelData.path)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // Search Box
                    Rectangle {
                        width: 180
                        height: 32
                        radius: 6
                        color: Qt.rgba(0, 0, 0, 0.3)
                        border.width: searchInput.activeFocus ? 1 : 0
                        border.color: Theme.accentColor
                        
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8
                            
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "🔍"
                                font.pixelSize: 12
                                opacity: 0.6
                            }
                            
                            TextInput {
                                id: searchInput
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 40
                                color: "#ffffff"
                                font.pixelSize: 12
                                clip: true
                                
                                onTextChanged: searchQuery = text
                                
                                Text {
                                    visible: !parent.text
                                    text: "Search..."
                                    color: "#666"
                                    font: parent.font
                                }
                            }
                        }
                    }
                }
            }
            
            // ===== ACTION BAR =====
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                color: Qt.rgba(0.06, 0.07, 0.09, 0.95)
                
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 4
                    
                    // Action Buttons
                    ActionButton { 
                        icon: "✂"; text: "Cut"; shortcut: "Ctrl+X"
                        enabled: selectedFile !== null && currentPath !== "/Recycle Bin"
                        onClicked: Storage.setClipboard(selectedFile.path, "cut")
                    }
                    ActionButton { 
                        icon: "📋"; text: "Copy"; shortcut: "Ctrl+C"
                        enabled: selectedFile !== null && currentPath !== "/Recycle Bin"
                        onClicked: Storage.setClipboard(selectedFile.path, "copy")
                    }
                    ActionButton { 
                        icon: "📥"; text: "Paste"; shortcut: "Ctrl+V"
                        enabled: hasClipboard && currentPath !== "/Recycle Bin"
                        onClicked: { if (Storage.paste(currentPath)) loadFolder(currentPath) }
                    }
                    ActionButton { 
                        icon: "✏"; text: "Rename"; shortcut: "F2"
                        enabled: selectedFile !== null
                        onClicked: {
                            renameDialog.visible = true
                            renameInput.text = selectedFile.name
                            renameInput.selectAll()
                            renameInput.forceActiveFocus()
                        }
                    }
                    ActionButton { 
                        icon: "🗑"; text: currentPath === "/Recycle Bin" ? "Delete" : "Delete"
                        enabled: selectedFile !== null
                        onClicked: deleteDialog.visible = true
                    }
                    
                    ToolbarSeparator {}
                    
                    // Sort dropdown
                    ActionButton {
                        icon: "↕"; text: "Sort"
                        hasDropdown: true
                    }
                    
                    // View dropdown
                    ActionButton {
                        icon: viewMode === "grid" ? "⊞" : "☰"
                        text: "View"
                        hasDropdown: true
                        onClicked: viewMode = (viewMode === "grid" ? "details" : "grid")
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    // Details pane toggle
                    Rectangle {
                        width: 80
                        height: 28
                        radius: 4
                        color: detailsPaneMouse.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
                        
                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Text { text: "☰"; font.pixelSize: 12; color: showDetailsPane ? Theme.accentColor : "#888" }
                            Text { text: "Details"; font.pixelSize: 11; color: showDetailsPane ? "#fff" : "#888" }
                        }
                        
                        MouseArea {
                            id: detailsPaneMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: showDetailsPane = !showDetailsPane
                        }
                    }
                }
            }
            
            // ===== CONTENT + DETAILS PANE =====
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0
                
                // File Area
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.margins: 8
                    radius: 8
                    color: Qt.rgba(0.04, 0.045, 0.06, 0.9)
                    
                    // Right-click on empty area
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.RightButton | Qt.LeftButton
                        onClicked: function(mouse) {
                            if (mouse.button === Qt.RightButton) {
                                clearSelection()
                                fileContextMenu.visible = false
                                bgContextMenu.x = mouse.x
                                bgContextMenu.y = mouse.y
                                bgContextMenu.visible = true
                            } else {
                                // Click on empty space deselects all
                                clearSelection()
                                fileContextMenu.visible = false
                                bgContextMenu.visible = false
                            }
                        }
                    }
                    
                    // Drop Area for folder
                    DropArea {
                        anchors.fill: parent
                        onDropped: function(drop) {
                            if (drop.hasFormat("path")) {
                                var sourcePath = drop.getDataAsString("path")
                                if (currentPath === "/Recycle Bin") {
                                    if (Storage.moveToTrash(sourcePath)) loadFolder(currentPath)
                                } else {
                                    if (Storage.moveItem(sourcePath, currentPath)) loadFolder(currentPath)
                                }
                            }
                        }
                    }
                    
                    // Grid View
                    GridView {
                        id: fileGrid
                        anchors.fill: parent
                        anchors.margins: 12
                        visible: viewMode === "grid"
                        cellWidth: 100
                        cellHeight: 100
                        clip: true
                        model: getFilteredFiles()
                        
                        delegate: FileGridItem {
                            file: modelData
                            isSelected: isFileSelected(modelData)
                            showCheckbox: showCheckboxes
                            
                            onClicked: function(mouse) {
                                bgContextMenu.visible = false
                                fileContextMenu.visible = false
                                
                                if (mouse.button === Qt.RightButton) {
                                    // Right-click: select if not selected, show menu
                                    if (!isFileSelected(modelData)) {
                                        selectFile(modelData, false)
                                    }
                                    fileContextMenu.x = mouse.x + x
                                    fileContextMenu.y = mouse.y + y
                                    fileContextMenu.visible = true
                                } else {
                                    // Left click with Ctrl = toggle selection
                                    var ctrlHeld = (mouse.modifiers & Qt.ControlModifier)
                                    selectFile(modelData, ctrlHeld)
                                }
                            }
                            
                            onCheckboxToggled: {
                                toggleFileSelection(modelData)
                            }
                            
                            onDoubleClicked: openFile(modelData)
                        }
                    }
                    
                    // Details View (List with columns)
                    Column {
                        anchors.fill: parent
                        visible: viewMode === "details"
                        
                        // Column Headers
                        Rectangle {
                            width: parent.width
                            height: 32
                            color: Qt.rgba(0, 0, 0, 0.3)
                            
                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                
                                Text { width: 250; text: "Name"; font.pixelSize: 11; color: "#888"; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                                Text { width: 140; text: "Date modified"; font.pixelSize: 11; color: "#888"; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                                Text { width: 100; text: "Type"; font.pixelSize: 11; color: "#888"; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                                Text { width: 80; text: "Size"; font.pixelSize: 11; color: "#888"; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                            }
                        }
                        
                        ListView {
                            width: parent.width
                            height: parent.height - 32
                            clip: true
                            model: getFilteredFiles()
                            
                            delegate: Rectangle {
                                id: detailDelegate
                                width: ListView.view.width
                                height: 34
                                
                                property bool itemSelected: isFileSelected(modelData)
                                
                                color: itemSelected ? Qt.rgba(0.25, 0.45, 0.75, 0.5) : 
                                       (detailMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                                border.width: itemSelected ? 1 : 0
                                border.color: Theme.accentColor
                                
                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    spacing: 0
                                    
                                    // Checkbox
                                    Rectangle {
                                        width: 28
                                        height: 28
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: "transparent"
                                        visible: showCheckboxes || itemSelected || detailMouse.containsMouse
                                        
                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 18
                                            height: 18
                                            radius: 9
                                            color: itemSelected ? Theme.accentColor : Qt.rgba(0.2, 0.22, 0.26, 0.9)
                                            border.width: itemSelected ? 0 : 2
                                            border.color: Qt.rgba(1, 1, 1, 0.3)
                                            
                                            Text {
                                                anchors.centerIn: parent
                                                text: "✓"
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: "#ffffff"
                                                visible: itemSelected
                                            }
                                            
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: toggleFileSelection(modelData)
                                            }
                                        }
                                    }
                                    
                                    // Icon and Name
                                    Row {
                                        width: 230
                                        spacing: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        
                                        Text { text: getFileIcon(modelData); font.pixelSize: 14 }
                                        Text { 
                                            text: modelData.name
                                            font.pixelSize: 12
                                            color: "#ffffff"
                                            elide: Text.ElideMiddle
                                            width: 200
                                        }
                                    }
                                    
                                    Text { 
                                        width: 140
                                        text: "—"
                                        font.pixelSize: 11
                                        color: "#777"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text { 
                                        width: 100
                                        text: getFileType(modelData)
                                        font.pixelSize: 11
                                        color: "#777"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text { 
                                        width: 80
                                        text: modelData.isDirectory ? "—" : formatFileSize(modelData.size || 0)
                                        font.pixelSize: 11
                                        color: "#777"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                
                                MouseArea {
                                    id: detailMouse
                                    anchors.fill: parent
                                    anchors.leftMargin: 28 // Leave room for checkbox
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    
                                    onClicked: function(mouse) {
                                        bgContextMenu.visible = false
                                        fileContextMenu.visible = false
                                        
                                        if (mouse.button === Qt.RightButton) {
                                            if (!isFileSelected(modelData)) {
                                                selectFile(modelData, false)
                                            }
                                            fileContextMenu.x = mouse.x
                                            fileContextMenu.y = mouse.y + parent.y + 120
                                            fileContextMenu.visible = true
                                        } else {
                                            var ctrlHeld = (mouse.modifiers & Qt.ControlModifier)
                                            selectFile(modelData, ctrlHeld)
                                        }
                                    }
                                    onDoubleClicked: openFile(modelData)
                                }
                            }
                        }
                    }
                    
                    // Empty State
                    Column {
                        anchors.centerIn: parent
                        spacing: 8
                        visible: getFilteredFiles().length === 0
                        
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "📂"; font.pixelSize: 56; opacity: 0.25 }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: searchQuery ? "No matching files" : "Empty folder"; font.pixelSize: 13; color: "#666" }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Right-click to create"; font.pixelSize: 11; color: "#555"; visible: !searchQuery }
                    }
                }
                
                // ===== DETAILS PANE (Right Sidebar) =====
                Rectangle {
                    Layout.preferredWidth: showDetailsPane ? 220 : 0
                    Layout.fillHeight: true
                    color: Qt.rgba(0.06, 0.07, 0.09, 0.95)
                    visible: showDetailsPane
                    clip: true
                    
                    Behavior on Layout.preferredWidth { NumberAnimation { duration: 150 } }
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 16
                        
                        // Header
                        Text {
                            text: {
                                if (selectedFiles.length > 1) {
                                    return selectedFiles.length + " items selected"
                                } else if (selectedFile) {
                                    return selectedFile.name
                                } else {
                                    return (currentPath.split("/").pop() || "Storage") + " (" + files.length + " items)"
                                }
                            }
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: selectedFiles.length > 1 ? Theme.accentColor : "#ffffff"
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }
                        
                        // File Preview / Icon
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 120
                            color: Qt.rgba(0, 0, 0, 0.2)
                            radius: 8
                            
                            Item {
                                anchors.centerIn: parent
                                
                                // Multi-select icon stack
                                Row {
                                    anchors.centerIn: parent
                                    spacing: -20
                                    visible: selectedFiles.length > 1
                                    
                                    Repeater {
                                        model: Math.min(selectedFiles.length, 3)
                                        
                                        Rectangle {
                                            width: 50
                                            height: 50
                                            radius: 8
                                            color: Qt.rgba(0.15, 0.18, 0.22, 1)
                                            border.width: 2
                                            border.color: Theme.accentColor
                                            
                                            Text {
                                                anchors.centerIn: parent
                                                text: selectedFiles[index] ? getFileIcon(selectedFiles[index]) : "📄"
                                                font.pixelSize: 24
                                            }
                                        }
                                    }
                                }
                                
                                // Single selection icon
                                Text {
                                    anchors.centerIn: parent
                                    text: selectedFile ? getFileIcon(selectedFile) : "📁"
                                    font.pixelSize: 56
                                    visible: selectedFiles.length <= 1 && (!selectedFile || !selectedFile.isImage)
                                }
                                
                                // Image preview (single selection only)
                                Image {
                                    anchors.centerIn: parent
                                    width: 100
                                    height: 100
                                    source: (selectedFiles.length === 1 && selectedFile && selectedFile.isImage) ? Storage.getFileUrl(selectedFile.path) : ""
                                    fillMode: Image.PreserveAspectFit
                                    visible: selectedFiles.length === 1 && selectedFile && selectedFile.isImage && status === Image.Ready
                                    asynchronous: true
                                }
                            }
                        }
                        
                        // File Info
                        Column {
                            Layout.fillWidth: true
                            spacing: 12
                            visible: selectedFile !== null
                            
                            DetailRow { label: "Type"; value: selectedFile ? getFileType(selectedFile) : "" }
                            DetailRow { label: "Size"; value: selectedFile && !selectedFile.isDirectory ? formatFileSize(selectedFile.size || 0) : "—" }
                            DetailRow { label: "Location"; value: currentPath }
                        }
                        
                        // Hint when nothing selected
                        Text {
                            visible: selectedFile === null
                            text: "Select a file to see more information and share your content."
                            font.pixelSize: 11
                            color: "#888"
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }
                        
                        Item { Layout.fillHeight: true }
                    }
                }
            }
            
            // ===== STATUS BAR =====
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                color: Qt.rgba(0.06, 0.07, 0.09, 0.98)
                
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    
                    Text { 
                        text: getFilteredFiles().length + " items"
                        font.pixelSize: 11
                        color: "#888"
                    }
                    
                    Rectangle { width: 1; height: 14; color: "#333" }
                    
                    // Show selection info
                    Text { 
                        visible: selectedFiles.length > 0
                        text: {
                            if (selectedFiles.length === 1) {
                                return "Selected: " + (selectedFile ? selectedFile.name : "")
                            } else {
                                return selectedFiles.length + " items selected"
                            }
                        }
                        font.pixelSize: 11
                        color: selectedFiles.length > 1 ? Theme.accentColor : "#aaa"
                        font.bold: selectedFiles.length > 1
                        elide: Text.ElideMiddle
                        Layout.fillWidth: true
                    }
                    
                    Item { Layout.fillWidth: true; visible: selectedFiles.length === 0 }
                    
                    // Checkbox mode toggle
                    Rectangle {
                        width: 24
                        height: 24
                        radius: 4
                        color: cbModeMouse.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
                        
                        Text {
                            anchors.centerIn: parent
                            text: "☑"
                            font.pixelSize: 14
                            color: showCheckboxes ? Theme.accentColor : "#666"
                        }
                        
                        MouseArea {
                            id: cbModeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: showCheckboxes = !showCheckboxes
                            
                            ToolTip.visible: containsMouse
                            ToolTip.text: "Toggle checkbox selection"
                            ToolTip.delay: 500
                        }
                    }
                    
                    Rectangle { width: 1; height: 14; color: "#333" }
                    
                    // View mode indicator
                    Text {
                        text: viewMode === "grid" ? "⊞ Grid" : "☰ Details"
                        font.pixelSize: 10
                        color: "#666"
                    }
                }
            }
        }
    }
    
    // ===== CONTEXT MENUS =====
    Rectangle {
        id: fileContextMenu
        visible: false
        width: 200
        height: menuColumn.height + 12
        radius: 8
        z: 1000
        
        color: Qt.rgba(0.12, 0.14, 0.18, 0.98)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.15)
        
        // Shadow
        Rectangle {
            anchors.fill: parent
            anchors.margins: -6
            radius: 12
            color: Qt.rgba(0, 0, 0, 0.5)
            z: -1
        }
        
        Column {
            id: menuColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 6
            spacing: 2
            
            PopupMenuItem {
                text: currentPath === "/Recycle Bin" ? "Restore" : "Open"
                icon: currentPath === "/Recycle Bin" ? "♻" : "📂"
                onClicked: { 
                    fileContextMenu.visible = false
                    if (currentPath === "/Recycle Bin") {
                        Storage.restoreFromTrash(selectedFile.trashName)
                        loadFolder(currentPath)
                    } else {
                        openFile(selectedFile)
                    }
                }
            }
            
            PopupMenuItem {
                text: "Open with GlassPad"
                icon: "📝"
                visible: selectedFile && !selectedFile.isDirectory && !isImageFile(selectedFile.name)
                onClicked: { 
                    fileContextMenu.visible = false
                    explorer.openFileRequest(selectedFile.path, selectedFile.name, false, true)
                }
            }
            
            Rectangle { width: parent.width - 12; height: 1; color: Qt.rgba(1,1,1,0.1); anchors.horizontalCenter: parent.horizontalCenter }
            
            PopupMenuItem {
                text: "Set as Wallpaper"
                icon: "🖼"
                visible: selectedFile && isImageFile(selectedFile.name)
                onClicked: { 
                    fileContextMenu.visible = false
                    Storage.setWallpaper(selectedFile.path)
                    explorer.setAsWallpaper(selectedFile.path)
                }
            }
            
            Rectangle { width: parent.width - 12; height: 1; color: Qt.rgba(1,1,1,0.1); anchors.horizontalCenter: parent.horizontalCenter; visible: selectedFile && isImageFile(selectedFile.name) }
            
            PopupMenuItem {
                text: "Cut"
                icon: "✂"
                shortcut: "Ctrl+X"
                enabled: currentPath !== "/Recycle Bin"
                onClicked: { fileContextMenu.visible = false; Storage.setClipboard(selectedFile.path, "cut") }
            }
            PopupMenuItem {
                text: "Copy"
                icon: "📋"
                shortcut: "Ctrl+C"
                enabled: currentPath !== "/Recycle Bin"
                onClicked: { fileContextMenu.visible = false; Storage.setClipboard(selectedFile.path, "copy") }
            }
            PopupMenuItem {
                text: "Rename"
                icon: "✏"
                shortcut: "F2"
                onClicked: { 
                    fileContextMenu.visible = false
                    renameDialog.visible = true
                    renameInput.text = selectedFile.name
                    renameInput.selectAll()
                    renameInput.forceActiveFocus()
                }
            }
            
            Rectangle { width: parent.width - 12; height: 1; color: Qt.rgba(1,1,1,0.1); anchors.horizontalCenter: parent.horizontalCenter }
            
            PopupMenuItem {
                text: currentPath === "/Recycle Bin" ? "Delete Permanently" : "Delete"
                icon: "🗑"
                shortcut: "Del"
                onClicked: { fileContextMenu.visible = false; deleteDialog.visible = true }
            }
        }
    }
    
    // Background context menu
    Rectangle {
        id: bgContextMenu
        visible: false
        width: 180
        height: bgMenuColumn.height + 12
        radius: 8
        z: 1000
        
        color: Qt.rgba(0.12, 0.14, 0.18, 0.98)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.15)
        
        Rectangle {
            anchors.fill: parent
            anchors.margins: -6
            radius: 12
            color: Qt.rgba(0, 0, 0, 0.5)
            z: -1
        }
        
        Column {
            id: bgMenuColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 6
            spacing: 2
            
            PopupMenuItem { text: "New Folder"; icon: "📁"; onClicked: { bgContextMenu.visible = false; createNewFolder() } }
            PopupMenuItem { text: "New Text File"; icon: "📄"; onClicked: { bgContextMenu.visible = false; createNewFile() } }
            Rectangle { width: parent.width - 12; height: 1; color: Qt.rgba(1,1,1,0.1); anchors.horizontalCenter: parent.horizontalCenter }
            PopupMenuItem { text: "Refresh"; icon: "⟳"; shortcut: "F5"; onClicked: { bgContextMenu.visible = false; loadFolder(currentPath) } }
            PopupMenuItem { 
                text: "Paste"
                icon: "📥"
                shortcut: "Ctrl+V"
                enabled: hasClipboard && currentPath !== "/Recycle Bin"
                onClicked: { bgContextMenu.visible = false; if (Storage.paste(currentPath)) loadFolder(currentPath) }
            }
        }
    }
    
    // ===== COMPONENTS =====
    component ToolbarButton: Rectangle {
        property string icon
        property string tooltip
        property bool enabled: true
        signal clicked()
        
        width: 32
        height: 32
        radius: 6
        color: enabled && tbMouse.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
        opacity: enabled ? 1 : 0.4
        
        Text { anchors.centerIn: parent; text: icon; font.pixelSize: 14; color: "#fff" }
        
        MouseArea {
            id: tbMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (enabled) parent.clicked()
        }
        
        ToolTip.visible: tbMouse.containsMouse && tooltip
        ToolTip.text: tooltip
        ToolTip.delay: 500
    }
    
    component ToolbarSeparator: Rectangle {
        width: 1
        height: 24
        color: Qt.rgba(1, 1, 1, 0.15)
    }
    
    component ActionButton: Rectangle {
        property string icon
        property string text
        property string shortcut: ""
        property bool enabled: true
        property bool hasDropdown: false
        signal clicked()
        
        width: actionRow.width + 16
        height: 28
        radius: 4
        color: enabled && abMouse.containsMouse ? Qt.rgba(1,1,1,0.08) : "transparent"
        opacity: enabled ? 1 : 0.4
        
        Row {
            id: actionRow
            anchors.centerIn: parent
            spacing: 6
            
            Text { text: icon; font.pixelSize: 12 }
            Text { text: parent.parent.text; font.pixelSize: 11; color: "#ccc" }
            Text { text: "▾"; font.pixelSize: 8; color: "#888"; visible: hasDropdown }
        }
        
        MouseArea {
            id: abMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (enabled) parent.clicked()
        }
    }
    
    component PopupMenuItem: Rectangle {
        property string text
        property string icon
        property string shortcut: ""
        property bool enabled: true
        signal clicked()
        
        width: parent.width - 12
        height: 30
        radius: 4
        color: enabled && pmMouse.containsMouse ? Qt.rgba(0.3, 0.5, 0.8, 0.4) : "transparent"
        opacity: enabled ? 1 : 0.4
        
        Row {
            anchors.fill: parent
            anchors.leftMargin: 10
            spacing: 10
            
            Text { anchors.verticalCenter: parent.verticalCenter; text: icon; font.pixelSize: 12; width: 16 }
            Text { anchors.verticalCenter: parent.verticalCenter; text: parent.parent.text; font.pixelSize: 12; color: "#fff" }
        }
        
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: shortcut
            font.pixelSize: 10
            color: "#666"
            visible: shortcut !== ""
        }
        
        MouseArea {
            id: pmMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (enabled) parent.clicked()
        }
    }
    
    component FileGridItem: Rectangle {
        id: fileGridItem
        property var file
        property bool isSelected: false
        property bool showCheckbox: false
        signal clicked(var mouse)
        signal checkboxToggled()
        signal doubleClicked()
        
        width: 95
        height: 95
        radius: 8
        color: isSelected ? Qt.rgba(0.25, 0.45, 0.75, 0.5) : (fgMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent")
        border.width: isSelected ? 2 : (fgMouse.containsMouse ? 1 : 0)
        border.color: isSelected ? Theme.accentColor : Qt.rgba(1, 1, 1, 0.2)
        
        Drag.active: fgMouse.drag.active
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2
        Drag.mimeData: { "path": file.path, "name": file.name, "isDir": file.isDirectory }
        
        // Checkbox (Windows 11 style - circular)
        Rectangle {
            id: checkbox
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 6
            width: 20
            height: 20
            radius: 10
            visible: showCheckbox || isSelected || fgMouse.containsMouse
            color: isSelected ? Theme.accentColor : Qt.rgba(0.2, 0.22, 0.26, 0.9)
            border.width: isSelected ? 0 : 2
            border.color: Qt.rgba(1, 1, 1, 0.4)
            z: 10
            
            Text {
                anchors.centerIn: parent
                text: "✓"
                font.pixelSize: 12
                font.bold: true
                color: "#ffffff"
                visible: isSelected
            }
            
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: function(mouse) {
                    mouse.accepted = true
                    fileGridItem.checkboxToggled()
                }
            }
            
            Behavior on opacity { NumberAnimation { duration: 100 } }
        }
        
        Column {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 2
            spacing: 6
            opacity: Storage.clipboardPath === file.path && Storage.clipboardOp === "cut" ? 0.4 : 1.0
            
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 48
                height: 48
                
                Text {
                    anchors.centerIn: parent
                    text: getFileIcon(file)
                    font.pixelSize: 36
                    visible: !file.isImage
                }
                
                Image {
                    anchors.fill: parent
                    source: file.isImage ? Storage.getFileUrl(file.path) : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: file.isImage && status === Image.Ready
                    asynchronous: true
                }
            }
            
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 85
                text: file.name
                font.pixelSize: 11
                color: "#ffffff"
                elide: Text.ElideMiddle
                horizontalAlignment: Text.AlignHCenter
            }
        }
        
        MouseArea {
            id: fgMouse
            anchors.fill: parent
            anchors.topMargin: 26 // Leave room for checkbox
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            drag.target: parent
            drag.threshold: 10
            
            onClicked: function(mouse) { fileGridItem.clicked(mouse) }
            onDoubleClicked: fileGridItem.doubleClicked()
        }
        
        // Also handle hover on whole item for checkbox visibility
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            propagateComposedEvents: true
            acceptedButtons: Qt.NoButton
        }
        
        scale: fgMouse.pressed ? 0.96 : 1.0
        Behavior on scale { NumberAnimation { duration: 60 } }
        Behavior on color { ColorAnimation { duration: 100 } }
    }
    
    component DetailRow: Row {
        property string label
        property string value
        
        spacing: 8
        
        Text { text: label + ":"; font.pixelSize: 11; color: "#888"; width: 60 }
        Text { text: value; font.pixelSize: 11; color: "#ccc"; width: 130; elide: Text.ElideMiddle }
    }
    
    // ===== DIALOGS =====
    Rectangle {
        id: newItemDialog
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.6)
        visible: false
        z: 2000
        
        property bool isFolder: true
        
        MouseArea { anchors.fill: parent; onClicked: newItemDialog.visible = false }
        
        Rectangle {
            anchors.centerIn: parent
            width: 360
            height: 160
            radius: 12
            color: Qt.rgba(0.12, 0.14, 0.18, 0.98)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.15)
            
            MouseArea { anchors.fill: parent }
            
            Column {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 16
                
                Text {
                    text: newItemDialog.isFolder ? "📁 New Folder" : "📄 New File"
                    font.pixelSize: 16
                    font.bold: true
                    color: "#ffffff"
                }
                
                TextField {
                    id: newItemInput
                    width: parent.width
                    height: 40
                    font.pixelSize: 13
                    color: "#ffffff"
                    placeholderText: newItemDialog.isFolder ? "Folder name" : "File name"
                    placeholderTextColor: "#666"
                    background: Rectangle {
                        color: Qt.rgba(0, 0, 0, 0.3)
                        radius: 6
                        border.width: newItemInput.activeFocus ? 2 : 1
                        border.color: newItemInput.activeFocus ? Theme.accentColor : Qt.rgba(1, 1, 1, 0.15)
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
                    spacing: 10
                    
                    Rectangle {
                        width: 80; height: 36; radius: 6
                        color: cancelMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.08)
                        Text { anchors.centerIn: parent; text: "Cancel"; font.pixelSize: 12; color: "#aaa" }
                        MouseArea { id: cancelMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: newItemDialog.visible = false }
                    }
                    
                    Rectangle {
                        width: 80; height: 36; radius: 6
                        color: createMouse.containsMouse ? Qt.rgba(0.2, 0.6, 0.4, 1) : Qt.rgba(0.2, 0.5, 0.4, 0.9)
                        Text { anchors.centerIn: parent; text: "Create"; font.pixelSize: 12; color: "#fff"; font.bold: true }
                        MouseArea { id: createMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: newItemInput.doCreate() }
                    }
                }
            }
        }
    }
    
    Rectangle {
        id: deleteDialog
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.6)
        visible: false
        z: 2000
        
        MouseArea { anchors.fill: parent; onClicked: deleteDialog.visible = false }
        
        Rectangle {
            anchors.centerIn: parent
            width: 360
            height: 140
            radius: 12
            color: Qt.rgba(0.12, 0.14, 0.18, 0.98)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.15)
            
            MouseArea { anchors.fill: parent }
            
            Column {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 14
                
                Text {
                    text: "🗑 Delete \"" + (selectedFile ? selectedFile.name : "") + "\"?"
                    font.pixelSize: 14
                    color: "#fff"
                    width: parent.width
                    elide: Text.ElideMiddle
                }
                
                Text { 
                    text: currentPath === "/Recycle Bin" ? "This will permanently delete the item." : "Item will be moved to Recycle Bin."
                    font.pixelSize: 12
                    color: "#888"
                }
                
                Row {
                    anchors.right: parent.right
                    spacing: 10
                    
                    Rectangle {
                        width: 80; height: 36; radius: 6
                        color: cancelDelMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.08)
                        Text { anchors.centerIn: parent; text: "Cancel"; font.pixelSize: 12; color: "#aaa" }
                        MouseArea { id: cancelDelMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: deleteDialog.visible = false }
                    }
                    
                    Rectangle {
                        width: 80; height: 36; radius: 6
                        color: confirmDelMouse.containsMouse ? "#c03030" : "#e04040"
                        Text { anchors.centerIn: parent; text: "Delete"; font.pixelSize: 12; color: "#fff"; font.bold: true }
                        MouseArea { 
                            id: confirmDelMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (selectedFile) {
                                    if (currentPath === "/Recycle Bin") {
                                        Storage.deleteItem(selectedFile.path)
                                    } else {
                                        Storage.moveToTrash(selectedFile.path)
                                    }
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
    
    Rectangle {
        id: renameDialog
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.6)
        visible: false
        z: 2000
        
        MouseArea { anchors.fill: parent; onClicked: renameDialog.visible = false }
        
        Rectangle {
            anchors.centerIn: parent
            width: 360
            height: 160
            radius: 12
            color: Qt.rgba(0.12, 0.14, 0.18, 0.98)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.15)
            
            MouseArea { anchors.fill: parent }
            
            Column {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 16
                
                Text { text: "✏ Rename"; font.pixelSize: 16; font.bold: true; color: "#fff" }
                
                TextField {
                    id: renameInput
                    width: parent.width
                    height: 40
                    font.pixelSize: 13
                    color: "#fff"
                    background: Rectangle {
                        color: Qt.rgba(0, 0, 0, 0.3)
                        radius: 6
                        border.width: renameInput.activeFocus ? 2 : 1
                        border.color: renameInput.activeFocus ? Theme.accentColor : Qt.rgba(1, 1, 1, 0.15)
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
                    spacing: 10
                    
                    Rectangle {
                        width: 80; height: 36; radius: 6
                        color: cancelRenameMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.08)
                        Text { anchors.centerIn: parent; text: "Cancel"; font.pixelSize: 12; color: "#aaa" }
                        MouseArea { id: cancelRenameMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: renameDialog.visible = false }
                    }
                    
                    Rectangle {
                        width: 80; height: 36; radius: 6
                        color: confirmRenameMouse.containsMouse ? Qt.rgba(0.3, 0.6, 0.9, 1) : Qt.rgba(0.3, 0.5, 0.8, 0.9)
                        Text { anchors.centerIn: parent; text: "Rename"; font.pixelSize: 12; color: "#fff"; font.bold: true }
                        MouseArea { id: confirmRenameMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: renameInput.doRename() }
                    }
                }
            }
        }
    }
}
