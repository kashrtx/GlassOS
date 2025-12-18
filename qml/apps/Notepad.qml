// GlassOS Notepad (GlassPad) - Full-Featured Text Editor
// Complete rewrite with proper file operations, Save As, and usability improvements
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: notepad
    color: "transparent"
    
    // ===== STATE =====
    property int baseFontSize: (typeof Accessibility !== "undefined" && Accessibility) ? Accessibility.baseFontSize : 14
    property bool useBold: (typeof Accessibility !== "undefined" && Accessibility) ? Accessibility.boldText : false
    property int fontSize: baseFontSize
    
    property bool modified: false
    property string fileName: "Untitled"
    property string filePath: ""
    property var recentFiles: []
    
    // Track original content for detecting changes
    property string originalContent: ""
    
    // ===== SIGNALS =====
    signal requestWindowTitle(string title)
    
    // Update title when modified state changes
    onModifiedChanged: updateWindowTitle()
    onFileNameChanged: updateWindowTitle()
    
    function updateWindowTitle() {
        var title = (modified ? "• " : "") + fileName + " - GlassPad"
        requestWindowTitle(title)
    }
    
    // ===== FILE OPERATIONS =====
    function loadFile(path, name) {
        if (modified && !confirmDiscard()) return false
        
        filePath = path
        fileName = name || path.split("/").pop()
        var content = Storage.readFile(path)
        textArea.text = content || ""
        originalContent = textArea.text
        modified = false
        addToRecentFiles(path, name)
        return true
    }
    
    function saveFile() {
        if (!filePath) {
            // No path - show Save As dialog
            showSaveAsDialog()
            return false
        }
        return doSave(filePath)
    }
    
    function doSave(path) {
        var success = Storage.writeFile(path, textArea.text)
        if (success) {
            filePath = path
            fileName = path.split("/").pop()
            originalContent = textArea.text
            modified = false
            console.log("📝 Saved:", path)
            showNotification("File saved successfully!")
            addToRecentFiles(path, fileName)
            return true
        } else {
            showNotification("Failed to save file!", true)
            return false
        }
    }
    
    function newFile() {
        if (modified && !confirmDiscard()) return
        
        textArea.text = ""
        fileName = "Untitled"
        filePath = ""
        originalContent = ""
        modified = false
    }
    
    function confirmDiscard() {
        // In a real app, show a dialog. For now, always confirm.
        return true
    }
    
    function addToRecentFiles(path, name) {
        // Remove if already exists
        for (var i = recentFiles.length - 1; i >= 0; i--) {
            if (recentFiles[i].path === path) {
                recentFiles.splice(i, 1)
            }
        }
        // Add to front
        recentFiles.unshift({ path: path, name: name || path.split("/").pop() })
        // Keep only last 10
        if (recentFiles.length > 10) recentFiles.pop()
        recentFiles = recentFiles.slice() // Force update
    }
    
    function showNotification(message, isError) {
        notification.text = message
        notification.isError = isError || false
        notification.visible = true
        notificationTimer.restart()
    }
    
    function showSaveAsDialog() {
        saveAsDialog.visible = true
        saveAsInput.text = fileName !== "Untitled" ? fileName : "document.txt"
        saveAsInput.selectAll()
        saveAsInput.forceActiveFocus()
    }
    
    function showOpenDialog() {
        openDialog.visible = true
        openDialogList.currentIndex = -1
        loadDirectoryContents("/Documents")
    }
    
    function loadDirectoryContents(path) {
        openDialog.currentPath = path
        var items = Storage.listDirectory(path)
        openDialogModel.clear()
        
        // Add parent directory option if not at root
        if (path !== "/" && path !== "") {
            openDialogModel.append({
                name: "..",
                path: path.substring(0, path.lastIndexOf("/")),
                isDirectory: true,
                isParent: true
            })
        }
        
        // Add directories first, then files
        for (var i = 0; i < items.length; i++) {
            var item = items[i]
            if (item.isDirectory) {
                openDialogModel.append({
                    name: item.name,
                    path: item.path,
                    isDirectory: true,
                    isParent: false
                })
            }
        }
        for (var j = 0; j < items.length; j++) {
            var file = items[j]
            if (!file.isDirectory) {
                openDialogModel.append({
                    name: file.name,
                    path: file.path,
                    isDirectory: false,
                    isParent: false
                })
            }
        }
    }
    
    function toggleFindBar() {
        findBar.visible = !findBar.visible
        if (findBar.visible) {
            findInput.forceActiveFocus()
            findInput.selectAll()
        }
    }
    
    function findNext() {
        var searchText = findInput.text
        if (!searchText) return
        
        var text = textArea.text
        var startPos = textArea.cursorPosition
        var foundIndex = text.indexOf(searchText, startPos)
        
        if (foundIndex === -1 && startPos > 0) {
            // Wrap around
            foundIndex = text.indexOf(searchText, 0)
        }
        
        if (foundIndex !== -1) {
            textArea.cursorPosition = foundIndex
            textArea.select(foundIndex, foundIndex + searchText.length)
            findStatus.text = ""
        } else {
            findStatus.text = "Not found"
        }
    }
    
    function replaceNext() {
        if (textArea.selectedText === findInput.text) {
            textArea.remove(textArea.selectionStart, textArea.selectionEnd)
            textArea.insert(textArea.cursorPosition, replaceInput.text)
        }
        findNext()
    }
    
    function replaceAll() {
        var searchText = findInput.text
        var replaceText = replaceInput.text
        if (!searchText) return
        
        var count = 0
        var text = textArea.text
        while (text.indexOf(searchText) !== -1) {
            text = text.replace(searchText, replaceText)
            count++
        }
        textArea.text = text
        findStatus.text = count + " replaced"
    }
    
    // ===== MAIN LAYOUT =====
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        
        // ===== MENU BAR =====
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            color: Qt.rgba(0.08, 0.09, 0.11, 0.98)
            
            Row {
                anchors.fill: parent
                anchors.leftMargin: 4
                spacing: 0
                
                // File Menu
                MenuButton {
                    text: "File"
                    onClicked: fileMenu.open()
                    
                    Popup {
                        id: fileMenu
                        y: parent.height
                        width: 200
                        padding: 4
                        
                        background: Rectangle {
                            color: Qt.rgba(0.12, 0.14, 0.18, 0.98)
                            radius: 6
                            border.width: 1
                            border.color: Qt.rgba(1,1,1,0.1)
                        }
                        
                        Column {
                            width: parent.width
                            spacing: 2
                            
                            MenuItem { 
                                text: "New"; shortcut: "Ctrl+N"; icon: "📄"
                                onClicked: { fileMenu.close(); newFile() }
                            }
                            MenuItem { 
                                text: "Open..."; shortcut: "Ctrl+O"; icon: "📂"
                                onClicked: { fileMenu.close(); showOpenDialog() }
                            }
                            MenuSeparator {}
                            MenuItem { 
                                text: "Save"; shortcut: "Ctrl+S"; icon: "💾"
                                enabled: modified || !filePath
                                onClicked: { fileMenu.close(); saveFile() }
                            }
                            MenuItem { 
                                text: "Save As..."; shortcut: "Ctrl+Shift+S"; icon: "📥"
                                onClicked: { fileMenu.close(); showSaveAsDialog() }
                            }
                            MenuSeparator {}
                            
                            // Recent files
                            Text {
                                text: "Recent Files"
                                color: "#888"
                                font.pixelSize: 10
                                leftPadding: 12
                                topPadding: 4
                                visible: recentFiles.length > 0
                            }
                            
                            Repeater {
                                model: recentFiles.slice(0, 5)
                                MenuItem {
                                    text: modelData.name
                                    icon: "📄"
                                    onClicked: { 
                                        fileMenu.close()
                                        loadFile(modelData.path, modelData.name)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Edit Menu
                MenuButton {
                    text: "Edit"
                    onClicked: editMenu.open()
                    
                    Popup {
                        id: editMenu
                        y: parent.height
                        width: 180
                        padding: 4
                        
                        background: Rectangle {
                            color: Qt.rgba(0.12, 0.14, 0.18, 0.98)
                            radius: 6
                            border.width: 1
                            border.color: Qt.rgba(1,1,1,0.1)
                        }
                        
                        Column {
                            width: parent.width
                            spacing: 2
                            
                            MenuItem { text: "Undo"; shortcut: "Ctrl+Z"; icon: "↩"; onClicked: { editMenu.close(); textArea.undo() } }
                            MenuItem { text: "Redo"; shortcut: "Ctrl+Y"; icon: "↪"; onClicked: { editMenu.close(); textArea.redo() } }
                            MenuSeparator {}
                            MenuItem { text: "Cut"; shortcut: "Ctrl+X"; icon: "✂"; onClicked: { editMenu.close(); textArea.cut() } }
                            MenuItem { text: "Copy"; shortcut: "Ctrl+C"; icon: "📋"; onClicked: { editMenu.close(); textArea.copy() } }
                            MenuItem { text: "Paste"; shortcut: "Ctrl+V"; icon: "📥"; onClicked: { editMenu.close(); textArea.paste() } }
                            MenuSeparator {}
                            MenuItem { text: "Find..."; shortcut: "Ctrl+F"; icon: "🔍"; onClicked: { editMenu.close(); toggleFindBar() } }
                            MenuItem { text: "Select All"; shortcut: "Ctrl+A"; icon: "☑"; onClicked: { editMenu.close(); textArea.selectAll() } }
                        }
                    }
                }
                
                // View Menu
                MenuButton {
                    text: "View"
                    onClicked: viewMenu.open()
                    
                    Popup {
                        id: viewMenu
                        y: parent.height
                        width: 180
                        padding: 4
                        
                        background: Rectangle {
                            color: Qt.rgba(0.12, 0.14, 0.18, 0.98)
                            radius: 6
                            border.width: 1
                            border.color: Qt.rgba(1,1,1,0.1)
                        }
                        
                        Column {
                            width: parent.width
                            spacing: 2
                            
                            MenuItem { 
                                text: textArea.wrapMode === TextEdit.Wrap ? "✓ Word Wrap" : "  Word Wrap"
                                onClicked: { viewMenu.close(); textArea.wrapMode = textArea.wrapMode === TextEdit.Wrap ? TextEdit.NoWrap : TextEdit.Wrap }
                            }
                            MenuItem { 
                                text: gutters.visible ? "✓ Line Numbers" : "  Line Numbers"
                                onClicked: { viewMenu.close(); gutters.visible = !gutters.visible }
                            }
                            MenuSeparator {}
                            MenuItem { text: "Zoom In"; shortcut: "Ctrl++"; onClicked: { viewMenu.close(); if(fontSize < 48) fontSize += 2 } }
                            MenuItem { text: "Zoom Out"; shortcut: "Ctrl+-"; onClicked: { viewMenu.close(); if(fontSize > 8) fontSize -= 2 } }
                            MenuItem { text: "Reset Zoom"; onClicked: { viewMenu.close(); fontSize = baseFontSize } }
                        }
                    }
                }
            }
        }
        
        // ===== TOOLBAR =====
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            color: Qt.rgba(0.1, 0.12, 0.15, 0.95)
            
            Row {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                
                ToolButton { icon: "📄"; tooltip: "New (Ctrl+N)"; onBtnClicked: newFile() }
                ToolButton { icon: "📂"; tooltip: "Open (Ctrl+O)"; onBtnClicked: showOpenDialog() }
                ToolButton { icon: "💾"; tooltip: "Save (Ctrl+S)"; highlight: modified; onBtnClicked: saveFile() }
                ToolButton { icon: "📥"; tooltip: "Save As..."; onBtnClicked: showSaveAsDialog() }
                ToolSeparator {}
                ToolButton { icon: "✂"; tooltip: "Cut (Ctrl+X)"; onBtnClicked: textArea.cut() }
                ToolButton { icon: "📋"; tooltip: "Copy (Ctrl+C)"; onBtnClicked: textArea.copy() }
                ToolButton { icon: "📥"; tooltip: "Paste (Ctrl+V)"; onBtnClicked: textArea.paste() }
                ToolSeparator {}
                ToolButton { icon: "↩"; tooltip: "Undo (Ctrl+Z)"; onBtnClicked: textArea.undo() }
                ToolButton { icon: "↪"; tooltip: "Redo (Ctrl+Y)"; onBtnClicked: textArea.redo() }
                ToolSeparator {}
                ToolButton { icon: "🔍"; tooltip: "Find (Ctrl+F)"; highlight: findBar.visible; onBtnClicked: toggleFindBar() }
                ToolSeparator {}
                ToolButton { 
                    icon: "⏎"; tooltip: "Word Wrap"
                    highlight: textArea.wrapMode === TextEdit.Wrap
                    onBtnClicked: textArea.wrapMode = (textArea.wrapMode === TextEdit.Wrap ? TextEdit.NoWrap : TextEdit.Wrap)
                }
                
                Item { width: 20 }
                
                // Font size controls
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    
                    Text { 
                        text: "Size:"
                        color: "#888"
                        font.pixelSize: 11
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    
                    Rectangle {
                        width: 28; height: 26; radius: 4
                        color: minusMouse.containsMouse ? Qt.rgba(1,1,1,0.15) : Qt.rgba(1,1,1,0.05)
                        Text { anchors.centerIn: parent; text: "−"; color: "#fff"; font.pixelSize: 16 }
                        MouseArea { 
                            id: minusMouse; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if(fontSize > 8) fontSize -= 2 
                        }
                    }
                    
                    Rectangle {
                        width: 45; height: 26; radius: 4
                        color: Qt.rgba(0,0,0,0.3)
                        Text { 
                            anchors.centerIn: parent
                            text: fontSize + "px"
                            color: "#fff"; font.pixelSize: 12
                        }
                    }
                    
                    Rectangle {
                        width: 28; height: 26; radius: 4
                        color: plusMouse.containsMouse ? Qt.rgba(1,1,1,0.15) : Qt.rgba(1,1,1,0.05)
                        Text { anchors.centerIn: parent; text: "+"; color: "#fff"; font.pixelSize: 16 }
                        MouseArea { 
                            id: plusMouse; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if(fontSize < 48) fontSize += 2 
                        }
                    }
                }
            }
        }
        
        // ===== FIND/REPLACE BAR =====
        Rectangle {
            id: findBar
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 44 : 0
            color: Qt.rgba(0.14, 0.16, 0.20, 0.98)
            visible: false
            clip: true
            
            Behavior on Layout.preferredHeight { NumberAnimation { duration: 150 } }
            
            Row {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                
                Text { text: "Find:"; color: "#aaa"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                
                Rectangle {
                    width: 180; height: 28; radius: 4
                    color: Qt.rgba(0,0,0,0.3)
                    border.width: findInput.activeFocus ? 1 : 0
                    border.color: Theme.accentColor
                    
                    TextInput {
                        id: findInput
                        anchors.fill: parent
                        anchors.margins: 6
                        color: "#fff"
                        font.pixelSize: 12
                        clip: true
                        
                        onAccepted: findNext()
                    }
                }
                
                Rectangle {
                    width: 60; height: 28; radius: 4
                    color: findNextMouse.containsMouse ? Qt.rgba(0.3, 0.5, 0.8, 0.6) : Qt.rgba(0.3, 0.5, 0.8, 0.4)
                    Text { anchors.centerIn: parent; text: "Next"; color: "#fff"; font.pixelSize: 11 }
                    MouseArea { id: findNextMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: findNext() }
                }
                
                ToolSeparator {}
                
                Text { text: "Replace:"; color: "#aaa"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                
                Rectangle {
                    width: 160; height: 28; radius: 4
                    color: Qt.rgba(0,0,0,0.3)
                    border.width: replaceInput.activeFocus ? 1 : 0
                    border.color: Theme.accentColor
                    
                    TextInput {
                        id: replaceInput
                        anchors.fill: parent
                        anchors.margins: 6
                        color: "#fff"
                        font.pixelSize: 12
                        clip: true
                    }
                }
                
                Rectangle {
                    width: 70; height: 28; radius: 4
                    color: replaceMouse.containsMouse ? Qt.rgba(0.4, 0.6, 0.3, 0.8) : Qt.rgba(0.4, 0.6, 0.3, 0.5)
                    Text { anchors.centerIn: parent; text: "Replace"; color: "#fff"; font.pixelSize: 11 }
                    MouseArea { id: replaceMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: replaceNext() }
                }
                
                Rectangle {
                    width: 70; height: 28; radius: 4
                    color: replaceAllMouse.containsMouse ? Qt.rgba(0.5, 0.4, 0.7, 0.8) : Qt.rgba(0.5, 0.4, 0.7, 0.5)
                    Text { anchors.centerIn: parent; text: "All"; color: "#fff"; font.pixelSize: 11 }
                    MouseArea { id: replaceAllMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: replaceAll() }
                }
                
                Text {
                    id: findStatus
                    color: "#f88"
                    font.pixelSize: 11
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                Item { Layout.fillWidth: true }
                
                // Close button
                Rectangle {
                    width: 24; height: 24; radius: 12
                    color: closeFindMouse.containsMouse ? Qt.rgba(1,0.3,0.3,0.6) : "transparent"
                    anchors.verticalCenter: parent.verticalCenter
                    Text { anchors.centerIn: parent; text: "×"; color: "#888"; font.pixelSize: 16 }
                    MouseArea { id: closeFindMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: findBar.visible = false }
                }
            }
        }
        
        // ===== EDITOR AREA =====
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Qt.rgba(0.04, 0.045, 0.06, 0.95)
            
            // Line Numbers
            Rectangle {
                id: gutters
                width: 50
                height: parent.height
                color: Qt.rgba(0.06, 0.07, 0.09, 1)
                visible: true
                
                Column {
                    y: -textAreaFlick.contentY + textArea.topPadding
                    width: parent.width
                    
                    Repeater {
                        model: Math.max(1, textArea.lineCount)
                        
                        Text {
                            width: 44
                            height: fontSize * 1.4
                            x: 3
                            text: index + 1
                            font.family: "Consolas"
                            font.pixelSize: fontSize - 1
                            color: (index + 1) === currentLine ? "#fff" : "#555"
                            horizontalAlignment: Text.AlignRight
                            verticalAlignment: Text.AlignVCenter
                            
                            property int currentLine: {
                                var pos = textArea.cursorPosition
                                var text = textArea.text.substring(0, pos)
                                return text.split("\n").length
                            }
                        }
                    }
                }
            }
            
            Flickable {
                id: textAreaFlick
                anchors.left: gutters.visible ? gutters.right : parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                contentWidth: textArea.width
                contentHeight: textArea.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                
                TextArea {
                    id: textArea
                    width: Math.max(textAreaFlick.width, implicitWidth)
                    height: Math.max(textAreaFlick.height, implicitHeight)
                    padding: 8
                    leftPadding: 12
                    
                    color: "#e8e8e8"
                    selectionColor: "#4a90d9"
                    selectedTextColor: "#ffffff"
                    
                    font.family: "Consolas"
                    font.pixelSize: fontSize
                    font.bold: useBold
                    
                    wrapMode: TextEdit.NoWrap
                    
                    placeholderText: "Start typing..."
                    placeholderTextColor: "#555"
                    
                    onTextChanged: {
                        modified = (text !== originalContent)
                    }
                    
                    // Keyboard shortcuts
                    Keys.onPressed: (event) => {
                        if (event.modifiers & Qt.ControlModifier) {
                            if (event.key === Qt.Key_S) {
                                if (event.modifiers & Qt.ShiftModifier) {
                                    showSaveAsDialog()
                                } else {
                                    saveFile()
                                }
                                event.accepted = true
                            } else if (event.key === Qt.Key_N) {
                                newFile()
                                event.accepted = true
                            } else if (event.key === Qt.Key_O) {
                                showOpenDialog()
                                event.accepted = true
                            } else if (event.key === Qt.Key_F) {
                                toggleFindBar()
                                event.accepted = true
                            } else if (event.key === Qt.Key_G) {
                                // Go to line (future feature)
                                event.accepted = true
                            }
                        }
                        if (event.key === Qt.Key_Escape && findBar.visible) {
                            findBar.visible = false
                            event.accepted = true
                        }
                        if (event.key === Qt.Key_F3) {
                            findNext()
                            event.accepted = true
                        }
                    }
                }
                
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }
            }
        }
        
        // ===== STATUS BAR =====
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 26
            color: Qt.rgba(0.08, 0.09, 0.11, 0.98)
            
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 0
                
                // File status
                Row {
                    spacing: 6
                    
                    Rectangle {
                        width: 8; height: 8; radius: 4
                        color: modified ? "#f59e0b" : "#22c55e"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    
                    Text { 
                        text: fileName
                        color: "#fff"
                        font.pixelSize: 11
                        font.bold: useBold
                    }
                    
                    Text {
                        text: modified ? "(unsaved)" : ""
                        color: "#f59e0b"
                        font.pixelSize: 11
                    }
                }
                
                Item { Layout.fillWidth: true }
                
                // Stats
                Row {
                    spacing: 16
                    
                    Text { 
                        text: "Ln " + getCurrentLine() + ", Col " + getCurrentColumn()
                        color: "#888"
                        font.pixelSize: 11
                        
                        function getCurrentLine() {
                            var pos = textArea.cursorPosition
                            var text = textArea.text.substring(0, pos)
                            return text.split("\n").length
                        }
                        
                        function getCurrentColumn() {
                            var pos = textArea.cursorPosition
                            var text = textArea.text.substring(0, pos)
                            var lastNewline = text.lastIndexOf("\n")
                            return pos - lastNewline
                        }
                    }
                    
                    Rectangle { width: 1; height: 14; color: "#333"; anchors.verticalCenter: parent.verticalCenter }
                    
                    Text { 
                        text: textArea.text.length + " chars"
                        color: "#888"
                        font.pixelSize: 11
                    }
                    
                    Text { 
                        text: textArea.lineCount + " lines"
                        color: "#888"
                        font.pixelSize: 11
                    }
                    
                    Rectangle { width: 1; height: 14; color: "#333"; anchors.verticalCenter: parent.verticalCenter }
                    
                    Text { 
                        text: textArea.wrapMode === TextEdit.Wrap ? "Wrap: On" : "Wrap: Off"
                        color: "#666"
                        font.pixelSize: 11
                    }
                }
            }
        }
    }
    
    // ===== SAVE AS DIALOG =====
    Rectangle {
        id: saveAsDialog
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.7)
        visible: false
        z: 1000
        
        MouseArea { anchors.fill: parent; onClicked: {} } // Block clicks
        
        Rectangle {
            anchors.centerIn: parent
            width: 420
            height: 180
            radius: 12
            color: Qt.rgba(0.12, 0.14, 0.18, 0.98)
            border.width: 1
            border.color: Qt.rgba(1,1,1,0.1)
            
            Column {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 16
                
                Text {
                    text: "Save As"
                    color: "#fff"
                    font.pixelSize: 18
                    font.bold: true
                }
                
                Row {
                    spacing: 8
                    width: parent.width
                    
                    Text {
                        text: "File name:"
                        color: "#aaa"
                        font.pixelSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 70
                    }
                    
                    Rectangle {
                        width: parent.width - 78
                        height: 36
                        radius: 6
                        color: Qt.rgba(0,0,0,0.3)
                        border.width: saveAsInput.activeFocus ? 2 : 1
                        border.color: saveAsInput.activeFocus ? Theme.accentColor : Qt.rgba(1,1,1,0.1)
                        
                        TextInput {
                            id: saveAsInput
                            anchors.fill: parent
                            anchors.margins: 10
                            color: "#fff"
                            font.pixelSize: 14
                            clip: true
                            
                            onAccepted: {
                                var path = "/Documents/" + text
                                if (doSave(path)) {
                                    saveAsDialog.visible = false
                                }
                            }
                        }
                    }
                }
                
                Text {
                    text: "File will be saved to: /Documents/"
                    color: "#666"
                    font.pixelSize: 11
                }
                
                Row {
                    anchors.right: parent.right
                    spacing: 12
                    
                    Rectangle {
                        width: 80; height: 36; radius: 6
                        color: cancelSaveMouse.containsMouse ? Qt.rgba(1,1,1,0.15) : Qt.rgba(1,1,1,0.08)
                        Text { anchors.centerIn: parent; text: "Cancel"; color: "#aaa"; font.pixelSize: 13 }
                        MouseArea { 
                            id: cancelSaveMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: saveAsDialog.visible = false
                        }
                    }
                    
                    Rectangle {
                        width: 80; height: 36; radius: 6
                        color: confirmSaveMouse.containsMouse ? Qt.rgba(0.2, 0.7, 0.4, 1) : Qt.rgba(0.2, 0.6, 0.4, 0.9)
                        Text { anchors.centerIn: parent; text: "Save"; color: "#fff"; font.pixelSize: 13; font.bold: true }
                        MouseArea { 
                            id: confirmSaveMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var path = "/Documents/" + saveAsInput.text
                                if (doSave(path)) {
                                    saveAsDialog.visible = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // ===== OPEN FILE DIALOG =====
    Rectangle {
        id: openDialog
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.7)
        visible: false
        z: 1000
        
        property string currentPath: "/Documents"
        
        MouseArea { anchors.fill: parent; onClicked: {} }
        
        Rectangle {
            anchors.centerIn: parent
            width: 500
            height: 400
            radius: 12
            color: Qt.rgba(0.12, 0.14, 0.18, 0.98)
            border.width: 1
            border.color: Qt.rgba(1,1,1,0.1)
            
            Column {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 12
                
                Row {
                    width: parent.width
                    
                    Text {
                        text: "Open File"
                        color: "#fff"
                        font.pixelSize: 18
                        font.bold: true
                    }
                    
                    Item { width: 20 }
                    
                    Text {
                        text: openDialog.currentPath
                        color: "#888"
                        font.pixelSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                
                Rectangle {
                    width: parent.width
                    height: parent.height - 100
                    radius: 6
                    color: Qt.rgba(0,0,0,0.3)
                    
                    ListView {
                        id: openDialogList
                        anchors.fill: parent
                        anchors.margins: 4
                        clip: true
                        model: ListModel { id: openDialogModel }
                        
                        delegate: Rectangle {
                            width: ListView.view.width
                            height: 32
                            radius: 4
                            color: ListView.isCurrentItem ? Qt.rgba(0.3, 0.5, 0.8, 0.4) : (openItemMouse.containsMouse ? Qt.rgba(1,1,1,0.08) : "transparent")
                            
                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                spacing: 10
                                
                                Text {
                                    text: model.isParent ? "📁" : (model.isDirectory ? "📁" : "📄")
                                    font.pixelSize: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                
                                Text {
                                    text: model.name
                                    color: "#fff"
                                    font.pixelSize: 13
                                    font.italic: model.isParent
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            
                            MouseArea {
                                id: openItemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                
                                onClicked: openDialogList.currentIndex = index
                                
                                onDoubleClicked: {
                                    if (model.isDirectory) {
                                        loadDirectoryContents(model.path)
                                    } else {
                                        loadFile(model.path, model.name)
                                        openDialog.visible = false
                                    }
                                }
                            }
                        }
                    }
                }
                
                Row {
                    anchors.right: parent.right
                    spacing: 12
                    
                    Rectangle {
                        width: 80; height: 36; radius: 6
                        color: cancelOpenMouse.containsMouse ? Qt.rgba(1,1,1,0.15) : Qt.rgba(1,1,1,0.08)
                        Text { anchors.centerIn: parent; text: "Cancel"; color: "#aaa"; font.pixelSize: 13 }
                        MouseArea { 
                            id: cancelOpenMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: openDialog.visible = false
                        }
                    }
                    
                    Rectangle {
                        width: 80; height: 36; radius: 6
                        color: confirmOpenMouse.containsMouse ? Qt.rgba(0.3, 0.5, 0.8, 1) : Qt.rgba(0.3, 0.5, 0.8, 0.8)
                        opacity: openDialogList.currentIndex >= 0 ? 1 : 0.5
                        Text { anchors.centerIn: parent; text: "Open"; color: "#fff"; font.pixelSize: 13; font.bold: true }
                        MouseArea { 
                            id: confirmOpenMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: openDialogList.currentIndex >= 0
                            onClicked: {
                                var item = openDialogModel.get(openDialogList.currentIndex)
                                if (item.isDirectory) {
                                    loadDirectoryContents(item.path)
                                } else {
                                    loadFile(item.path, item.name)
                                    openDialog.visible = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // ===== NOTIFICATION =====
    Rectangle {
        id: notification
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 60
        width: notificationText.width + 40
        height: 40
        radius: 20
        color: isError ? Qt.rgba(0.8, 0.2, 0.2, 0.95) : Qt.rgba(0.2, 0.6, 0.3, 0.95)
        visible: false
        z: 2000
        
        property alias text: notificationText.text
        property bool isError: false
        
        Text {
            id: notificationText
            anchors.centerIn: parent
            color: "#fff"
            font.pixelSize: 13
        }
        
        Timer {
            id: notificationTimer
            interval: 2500
            onTriggered: notification.visible = false
        }
        
        Behavior on visible {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
        }
    }
    
    // ===== INLINE COMPONENTS =====
    
    component ToolButton: Rectangle {
        property string icon
        property string tooltip
        property bool highlight: false
        signal btnClicked()
        
        width: 34
        height: 32
        radius: 5
        anchors.verticalCenter: parent.verticalCenter
        color: highlight ? Qt.rgba(0.3, 0.5, 0.8, 0.5) : (tbMouse.containsMouse ? Qt.rgba(1,1,1,0.12) : "transparent")
        
        Text { 
            anchors.centerIn: parent
            text: icon
            font.pixelSize: 16
        }
        
        MouseArea {
            id: tbMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btnClicked()
        }
        
        ToolTip.visible: tbMouse.containsMouse
        ToolTip.text: tooltip
        ToolTip.delay: 500
    }
    
    component ToolSeparator: Rectangle {
        width: 1
        height: 22
        color: Qt.rgba(1,1,1,0.15)
        anchors.verticalCenter: parent.verticalCenter
    }
    
    component MenuButton: Rectangle {
        property alias text: menuText.text
        signal clicked()
        
        width: menuText.width + 16
        height: 24
        radius: 3
        anchors.verticalCenter: parent.verticalCenter
        color: menuBtnMouse.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
        
        Text {
            id: menuText
            anchors.centerIn: parent
            color: "#ccc"
            font.pixelSize: 12
        }
        
        MouseArea {
            id: menuBtnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }
    
    component MenuItem: Rectangle {
        property string text
        property string shortcut: ""
        property string icon: ""
        property bool enabled: true
        signal clicked()
        
        width: parent.width
        height: 30
        radius: 4
        color: enabled && menuItemMouse.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
        opacity: enabled ? 1 : 0.5
        
        Row {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10
            
            Text {
                text: icon
                font.pixelSize: 12
                width: 16
                anchors.verticalCenter: parent.verticalCenter
            }
            
            Text {
                text: parent.parent.text
                color: "#ddd"
                font.pixelSize: 12
                anchors.verticalCenter: parent.verticalCenter
            }
            
            Item { width: 1; Layout.fillWidth: true }
            
            Text {
                text: shortcut
                color: "#666"
                font.pixelSize: 11
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        
        MouseArea {
            id: menuItemMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (enabled) parent.clicked()
        }
    }
    
    component MenuSeparator: Rectangle {
        width: parent.width
        height: 9
        color: "transparent"
        
        Rectangle {
            anchors.centerIn: parent
            width: parent.width - 20
            height: 1
            color: Qt.rgba(1,1,1,0.1)
        }
    }
}
