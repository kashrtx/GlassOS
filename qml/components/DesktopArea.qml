// GlassOS Desktop Area - Interactive & Customizable
import QtQuick

Item {
    id: root
    // desktopRoot renamed to root for standard convention and scope clarity
    
    signal openApp(string appName, var params)
    
    property int selectedIndex: -1
    property bool showContextMenu: false
    property real menuX: 0
    property real menuY: 0
    
    property var icons: []
    property int dragHoverTarget: -1  // Index of icon being hovered during drag
    
    // Track clipboard state for Paste button reactivity
    property bool hasClipboard: Storage.clipboardPath !== ""
    
    Component.onCompleted: {
        refreshIcons()
        // Initialize clipboard state
        hasClipboard = Storage.clipboardPath !== ""
    }
    
    // Listen for file system changes (e.g. valid delete from Recycle Bin)
    Connections {
        target: Storage
        function onDesktopUpdated() {
            console.log("Desktop updated signal received, refreshing icons...")
            refreshIcons()
        }
        function onClipboardChanged() {
            console.log("Clipboard changed:", Storage.clipboardPath, Storage.clipboardOp)
            hasClipboard = Storage.clipboardPath !== ""
        }
    }
    
    function refreshIcons() {
        var savedIcons = Storage.getDesktopIcons()
        // Ensure all icons have x and y and don't overlap
        for (var i = 0; i < savedIcons.length; i++) {
            if (savedIcons[i].x === undefined) savedIcons[i].x = 16
            if (savedIcons[i].y === undefined) savedIcons[i].y = 16 + i * 88
        }
        icons = savedIcons
    }
    
    function getNextFreeSpot(targetX, targetY) {
        var grid = 88
        var x = Math.max(16, Math.round(targetX / grid) * grid)
        if (x === 0) x = 16
        var y = Math.max(16, Math.round(targetY / grid) * grid)
        if (y === 0) y = 16
        
        var attempts = 0
        var foundCollision = true
        while (foundCollision && attempts < 50) {
            foundCollision = false
            for (var i = 0; i < icons.length; i++) {
                if (Math.abs(icons[i].x - x) < 40 && Math.abs(icons[i].y - y) < 40) {
                    y += grid
                    if (y + 80 > root.height - 48) {
                        y = 16
                        x += grid
                    }
                    foundCollision = true
                    attempts++
                    break
                }
            }
        }
        return { "x": x, "y": y }
    }
    
    function saveIcons() {
        Storage.saveDesktopIcons(icons)
    }
    
    function sortIcons(by) {
        var sorted = icons.slice()
        if (by === "name") {
            sorted.sort((a, b) => a.name.localeCompare(b.name))
        }
        
        // Re-arrange in a grid
        var startX = 16
        var startY = 16
        var spacing = 88
        var rows = Math.floor(root.height / spacing)
        
        for (var i = 0; i < sorted.length; i++) {
            var col = Math.floor(i / rows)
            var row = i % rows
            sorted[i].x = startX + col * 88
            sorted[i].y = startY + row * 88
        }
        icons = sorted
        saveIcons()
    }
    
    // Manual drop target detection - checks if x,y is over a folder or recycle bin
    function getDropTargetAt(x, y, sourceIndex) {
        for (var i = 0; i < icons.length; i++) {
            if (i === sourceIndex) continue // Skip self
            
            var icon = icons[i]
            var iconX = icon.x
            var iconY = icon.y
            var iconW = 72
            var iconH = 80
            
            // Check if the point is within this icon's bounds
            if (x >= iconX && x <= iconX + iconW && y >= iconY && y <= iconY + iconH) {
                // Is it a valid drop target?
                if (icon.app === "RecycleBin" || icon.icon === "📁") {
                    return { 
                        index: i, 
                        name: icon.name, 
                        isTrash: icon.app === "RecycleBin",
                        isFolder: icon.icon === "📁"
                    }
                }
            }
        }
        return null
    }
    
    // Perform the drop action
    function performDrop(sourceIndex, target) {
        if (!target) return false
        
        var sourcePath = "/Desktop/" + icons[sourceIndex].name
        
        if (target.isTrash) {
            console.log("🗑️ Dropping", sourcePath, "to Recycle Bin")
            if (Storage.moveToTrash(sourcePath)) {
                refreshIcons()
                return true
            }
        } else if (target.isFolder) {
            var destPath = "/Desktop/" + target.name
            console.log("📁 Dropping", sourcePath, "to folder", destPath)
            if (Storage.moveItem(sourcePath, destPath)) {
                refreshIcons()
                return true
            }
        }
        return false
    }
    
    // Unified Desktop MouseArea for Clicks & Drops
    MouseArea {
        id: desktopMouseArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        focus: true
        
        // Key handling - Ctrl+C, Ctrl+X, Ctrl+V, Delete, F5
        Keys.onPressed: function(event) {
            console.log("Key pressed:", event.key, "Modifiers:", event.modifiers)
            
            if (event.modifiers & Qt.ControlModifier) {
                if (event.key === Qt.Key_C && selectedIndex !== -1) {
                    console.log("📋 Copy:", icons[selectedIndex].name)
                    Storage.setClipboard("/Desktop/" + icons[selectedIndex].name, "copy")
                    event.accepted = true
                } else if (event.key === Qt.Key_X && selectedIndex !== -1) {
                    console.log("✂ Cut:", icons[selectedIndex].name)
                    Storage.setClipboard("/Desktop/" + icons[selectedIndex].name, "cut")
                    event.accepted = true
                } else if (event.key === Qt.Key_V && root.hasClipboard) {
                    console.log("📋 Paste to Desktop")
                    if (Storage.paste("/Desktop")) { 
                        refreshIcons() 
                    }
                    event.accepted = true
                } else if (event.key === Qt.Key_A) {
                    // Select first icon
                    if (icons.length > 0) selectedIndex = 0
                    event.accepted = true
                }
            } else if (event.key === Qt.Key_Delete && selectedIndex !== -1) {
                console.log("🗑 Delete:", icons[selectedIndex].name)
                if (Storage.moveToTrash("/Desktop/" + icons[selectedIndex].name)) {
                    refreshIcons()
                    selectedIndex = -1
                }
                event.accepted = true
            } else if (event.key === Qt.Key_F5) {
                console.log("🔄 Refresh")
                refreshIcons()
                event.accepted = true
            }
        }
        
        // Background Click
        onClicked: function(mouse) {
            // Dismiss menu if open
            if (showContextMenu) {
                showContextMenu = false
                return
            }
            
            selectedIndex = -1
            forceActiveFocus()
            
            if (mouse.button === Qt.RightButton) {
                menuX = mouse.x
                menuY = mouse.y
                showContextMenu = true
            }
        }
        
        // DropArea for file drops from Explorer or same desktop
        DropArea {
            anchors.fill: parent
            
            onDropped: function(drop) {
                if (drop.hasFormat("path")) {
                    var sourcePath = drop.getDataAsString("path")
                    var sourceName = drop.getDataAsString("name")
                    var isDir = drop.getDataAsString("isDir") === "true" // Basic check
                    
                    // Prevent dropping on itself (if needed, but Storage.moveItem handles it)
                    if (sourcePath.indexOf("/Desktop/") === -1) {
                        if (Storage.moveItem(sourcePath, "/Desktop")) {
                            
                            // Find a spot for the new icon
                            var spot = getNextFreeSpot(drop.x, drop.y)
                            
                            var newIcons = icons.slice()
                            newIcons.push({
                                name: sourceName,
                                icon: isDir ? "📁" : "📄", // Simple fallback icon logic
                                app: isDir ? "AeroExplorer" : "GlassPad", // Simple app association
                                x: spot.x,
                                y: spot.y
                            })
                            icons = newIcons
                            root.saveIcons()
                            refreshIcons()
                        }
                    } else {
                         // Dragging within desktop - just move icon
                         // This is handled by the icon's own onReleased logic usually,
                         // but if we want free placement drop:
                         var sourceIndex = parseInt(drop.getDataAsString("index"))
                         if (!isNaN(sourceIndex) && sourceIndex >= 0 && sourceIndex < icons.length) {
                             var newIcons = icons.slice()
                             // Snap to grid
                             var grid = 20
                             newIcons[sourceIndex].x = Math.round(drop.x / grid) * grid
                             newIcons[sourceIndex].y = Math.round(drop.y / grid) * grid
                             icons = newIcons
                             root.saveIcons()
                         }
                    }
                }
            }
        }
    }
    
    // Desktop icons
    Repeater {
        model: icons
        
        Rectangle {
            id: iconItem
            x: modelData.x
            y: modelData.y
            width: 72
            height: 80
            radius: 4
            // Z-index boost when dragging to ensuring it appears over windows
            z: iconMouse.drag.active ? 100000 : (selectedIndex === index ? 10 : 1)
            
            // Drag and Drop Configuration
            Drag.active: iconMouse.drag.active
            Drag.hotSpot.x: width / 2
            Drag.hotSpot.y: height / 2
            Drag.supportedActions: Qt.MoveAction
            Drag.dragType: Drag.Internal  // Internal for in-app DnD
            Drag.keys: ["desktop-icon", "file"]
            Drag.mimeData: { 
                "path": (modelData.app === "RecycleBin") ? "/Recycle Bin" : "/Desktop/" + modelData.name, 
                "index": String(index), 
                "name": modelData.name, 
                "isApp": modelData.app ? "true" : "false",
                "isDir": modelData.icon === "📁" ? "true" : "false"
            }
            Drag.source: iconItem
            
            // DropArea for folders/trash - accepts drops from other icons
            DropArea {
                id: iconDropArea
                anchors.fill: parent
                enabled: modelData.app === "RecycleBin" || modelData.icon === "📁"
                keys: ["desktop-icon", "file"]
                
                onContainsDragChanged: {
                    if (containsDrag) {
                        console.log("🎯 Drag entered:", modelData.name, "- containsDrag:", containsDrag)
                    }
                }
                
                onEntered: function(drag) {
                    console.log("📥 onEntered:", modelData.name, "source:", drag.source)
                    if (drag.source !== iconItem) {
                        iconItem.border.width = 2
                        iconItem.border.color = modelData.app === "RecycleBin" ? "#ff6666" : "#4a9eff"
                        iconItem.color = Qt.rgba(0.3, 0.5, 0.8, 0.3)
                        drag.accept(Qt.MoveAction)
                    }
                }
                onExited: {
                    console.log("📤 onExited:", modelData.name)
                    iconItem.border.width = (selectedIndex === index) ? 1 : 0
                    iconItem.border.color = Qt.rgba(0.4, 0.7, 1, 0.6)
                    iconItem.color = selectedIndex === index ? Qt.rgba(1, 1, 1, 0.2) : "transparent"
                }
                onDropped: function(drop) {
                    // Reset visual state
                    iconItem.border.width = (selectedIndex === index) ? 1 : 0
                    iconItem.border.color = Qt.rgba(0.4, 0.7, 1, 0.6)
                    iconItem.color = selectedIndex === index ? Qt.rgba(1, 1, 1, 0.2) : "transparent"
                    
                    var sourcePath = drop.getDataAsString("path")
                    var sourceIndex = parseInt(drop.getDataAsString("index"))
                    
                    // Don't drop on self
                    if (drop.source === iconItem) return
                    
                    if (modelData.app === "RecycleBin") {
                        console.log("🗑 Dropping to Recycle Bin:", sourcePath)
                        if (Storage.moveToTrash(sourcePath)) {
                            refreshIcons()
                        }
                        drop.accepted = true
                    } else if (modelData.icon === "📁") {
                        console.log("📁 Dropping to folder:", modelData.name)
                        if (Storage.moveItem(sourcePath, "/Desktop/" + modelData.name)) {
                            refreshIcons()
                        }
                        drop.accepted = true
                    }
                }
            }
            
            // Highlight when this is a drag hover target
            property bool isDragTarget: (dragHoverTarget === index) && (modelData.app === "RecycleBin" || modelData.icon === "📁")
            
            color: isDragTarget ? Qt.rgba(0.3, 0.5, 0.8, 0.4) : 
                   (selectedIndex === index ? Qt.rgba(1, 1, 1, 0.2) : "transparent")
            
            border.width: isDragTarget ? 2 : (selectedIndex === index ? 1 : 0)
            border.color: isDragTarget ? (modelData.app === "RecycleBin" ? "#ff6666" : "#4a9eff") : 
                          Qt.rgba(0.4, 0.7, 1, 0.6)
            
            Column {
                anchors.centerIn: parent
                spacing: 2
                
                // Ghost image when cutting
                opacity: Storage.clipboardPath === "/Desktop/" + modelData.name && Storage.clipboardOp === "cut" ? 0.5 : 1.0
                
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData.icon
                    font.pixelSize: 32
                }
                
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData.name
                    width: 70
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                    color: "white"
                    font.pixelSize: 12
                    style: Text.Outline
                    styleColor: "black"
                    elide: Text.ElideMiddle
                    maximumLineCount: 2
                }
            }
            
            MouseArea {
                id: iconMouse
                anchors.fill: parent
                hoverEnabled: true
                drag.target: iconItem
                drag.axis: Drag.XAndYAxis
                drag.threshold: 8
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: drag.active ? Qt.ClosedHandCursor : (containsMouse ? Qt.PointingHandCursor : Qt.ArrowCursor)
                
                property real startX: 0
                property real startY: 0
                property bool wasDragged: false
                
                onPressed: function(mouse) {
                    // Close menu if clicking elsewhere
                    if (showContextMenu) {
                       showContextMenu = false
                    }
                    
                    startX = iconItem.x
                    startY = iconItem.y
                    wasDragged = false
                    
                    selectedIndex = index
                    root.forceActiveFocus()
                    if (mouse.button === Qt.RightButton) {
                        menuX = mouse.x + iconItem.x
                        menuY = mouse.y + iconItem.y
                        showContextMenu = true
                    }
                }
                
                onPositionChanged: {
                    if (drag.active) {
                        wasDragged = true
                        
                        // Check for hover over drop targets for visual feedback
                        var centerX = iconItem.x + iconItem.width / 2
                        var centerY = iconItem.y + iconItem.height / 2
                        var target = root.getDropTargetAt(centerX, centerY, index)
                        
                        // Update visual state of potential target
                        if (target && target.index !== root.dragHoverTarget) {
                            root.dragHoverTarget = target.index
                        } else if (!target && root.dragHoverTarget !== -1) {
                            root.dragHoverTarget = -1
                        }
                    }
                }
                
                onReleased: function(mouse) {
                    if (wasDragged) {
                        // Calculate the center of the icon's new position
                        var centerX = iconItem.x + iconItem.width / 2
                        var centerY = iconItem.y + iconItem.height / 2
                        
                        // Check if we're over a drop target (folder or recycle bin)
                        var target = root.getDropTargetAt(centerX, centerY, index)
                        
                        if (target) {
                            // Perform the drop action
                            if (root.performDrop(index, target)) {
                                // Drop was successful, icons will be refreshed
                                wasDragged = false
                                return
                            }
                        }
                        
                        // No valid target - just move the icon to its new position
                        // Snap to grid
                        var grid = 20
                        var newX = Math.max(16, Math.round(iconItem.x / grid) * grid)
                        var newY = Math.max(16, Math.round(iconItem.y / grid) * grid)
                        
                        // Clamp to screen bounds
                        newX = Math.min(newX, root.width - iconItem.width - 16)
                        newY = Math.min(newY, root.height - iconItem.height - 60) // Above taskbar
                        
                        // Update model and save
                        var newIcons = icons.slice()
                        if (index >= 0 && index < newIcons.length) {
                            newIcons[index].x = newX
                            newIcons[index].y = newY
                            icons = newIcons
                            root.saveIcons()
                        }
                        
                        // Snap the visual position
                        iconItem.x = newX
                        iconItem.y = newY
                    }
                    wasDragged = false
                    root.dragHoverTarget = -1  // Reset hover state
                }
                
                onDoubleClicked: {
                    if (modelData.app === "RecycleBin") {
                         root.openApp("RecycleBin", {})
                    } else if (modelData.icon === "📁") {
                         root.openApp("AeroExplorer", { "path": "/Desktop/" + modelData.name })
                    } else if (modelData.app) {
                        root.openApp(modelData.app, {})
                    }
                }
            }
        }
    }
    
    // Context menu (No overlay MouseArea needed, clicks handled by desktop/icon areas)
    Rectangle {
        id: contextMenu
        x: Math.min(menuX, root.width - width - 10)
        y: Math.min(menuY, root.height - height - 10)
        width: 180
        height: menuColumn.height + 12
        visible: showContextMenu
        z: 9999
        radius: 6
        
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.18, 0.20, 0.25, 0.98) }
            GradientStop { position: 1.0; color: Qt.rgba(0.12, 0.14, 0.18, 0.98) }
        }
        
        border.width: 1
        border.color: Qt.rgba(0.4, 0.6, 0.9, 0.4)
        
        Column {
            id: menuColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 6
            spacing: 2
            
            // Icon Specific Items
            ContextMenuItem { 
                visible: selectedIndex !== -1
                text: "Open"; icon: "📂"
                onItemClicked: { 
                    var app = icons[selectedIndex].app
                    var icon = icons[selectedIndex].icon
                    var name = icons[selectedIndex].name
                    if (app === "RecycleBin") root.openApp("RecycleBin", {})
                    else if (icon === "📁") root.openApp("AeroExplorer", { "path": "/Desktop/" + name })
                    else if (app) root.openApp(app, {})
                    showContextMenu = false 
                } 
            }
            
            ContextMenuItem { 
                visible: selectedIndex !== -1
                text: "Cut"; icon: "✂"
                onItemClicked: { 
                    var name = icons[selectedIndex].name
                    Storage.setClipboard("/Desktop/" + name, "cut")
                    showContextMenu = false 
                } 
            }

            ContextMenuItem { 
                visible: selectedIndex !== -1
                text: "Copy"; icon: "📋"
                onItemClicked: { 
                    var name = icons[selectedIndex].name
                    Storage.setClipboard("/Desktop/" + name, "copy")
                    showContextMenu = false 
                } 
            }
            
            ContextMenuItem { 
                visible: selectedIndex !== -1
                text: "Delete"; icon: "🗑"
                onItemClicked: { 
                    var name = icons[selectedIndex].name
                    if (Storage.moveToTrash("/Desktop/" + name)) {
                        refreshIcons()
                    }
                    showContextMenu = false 
                } 
            }

            Rectangle { visible: selectedIndex !== -1; width: parent.width - 12; height: 1; color: Qt.rgba(1,1,1,0.15); anchors.horizontalCenter: parent.horizontalCenter }
            
            // General Items
            ContextMenuItem { 
                text: "Refresh"; icon: "🔄"
                onItemClicked: { refreshIcons(); showContextMenu = false } 
            }
            
            ContextMenuItem { 
                text: "Paste"; icon: "📋"
                enabled: root.hasClipboard
                onItemClicked: { 
                    if (Storage.paste("/Desktop")) {
                        // Refresh to see the new item
                        refreshIcons()
                    }
                    showContextMenu = false 
                } 
            }
            
            Rectangle { width: parent.width - 12; height: 1; color: Qt.rgba(1,1,1,0.15); anchors.horizontalCenter: parent.horizontalCenter }
            
            ContextMenuItem { 
                text: "Sort by Name"; icon: "🔤"
                onItemClicked: { sortIcons("name"); showContextMenu = false } 
            }
            
            ContextMenuItem { 
                text: "Auto-arrange Icons"; icon: "📐"
                onItemClicked: { sortIcons("name"); showContextMenu = false } 
            }
            
            Rectangle { width: parent.width - 12; height: 1; color: Qt.rgba(1,1,1,0.15); anchors.horizontalCenter: parent.horizontalCenter }
            
            ContextMenuItem { 
                text: "New Folder"; icon: "📁"
                onItemClicked: { 
                    var name = "New Folder"
                    var baseName = name
                    var counter = 1
                    while (icons.some(i => i.name === name)) {
                        name = baseName + " (" + counter + ")"
                        counter++
                    }
                    Storage.createDirectory("/Desktop/" + name)
                    var spot = getNextFreeSpot(menuX, menuY)
                    var newIcons = icons.slice()
                    newIcons.push({ name: name, icon: "📁", app: "AeroExplorer", x: spot.x, y: spot.y })
                    icons = newIcons
                    root.saveIcons()
                    showContextMenu = false 
                } 
            }
            ContextMenuItem { 
                text: "New Text File"; icon: "📄"
                onItemClicked: { 
                    var name = "New File.txt"
                    var baseName = "New File"
                    var ext = ".txt"
                    var counter = 1
                    while (icons.some(i => i.name === name)) {
                        name = baseName + " (" + counter + ")" + ext
                        counter++
                    }
                    Storage.writeFile("/Desktop/" + name, "")
                    var spot = getNextFreeSpot(menuX, menuY)
                    var newIcons = icons.slice()
                    newIcons.push({ name: name, icon: "📄", app: "GlassPad", x: spot.x, y: spot.y })
                    icons = newIcons
                    root.saveIcons()
                    showContextMenu = false 
                } 
            }
            
            Rectangle { width: parent.width - 12; height: 1; color: Qt.rgba(1,1,1,0.15); anchors.horizontalCenter: parent.horizontalCenter }
            
            ContextMenuItem { 
                text: "Display Settings"; icon: "🖥"
                onItemClicked: { root.openApp("Settings", {}); showContextMenu = false }
            }
            
            ContextMenuItem { 
                text: "Personalize"; icon: "🎨"
                onItemClicked: { root.openApp("Settings", {}); showContextMenu = false }
            }
        }
    }
    
    // Context menu item component
    component ContextMenuItem: Rectangle {
        property string text: ""
        property string icon: ""
        property bool hasArrow: false
        property bool enabled: true
        signal itemClicked()
        
        width: parent.width
        height: 28
        radius: 4
        color: ciMouse.containsMouse ? Qt.rgba(0.3, 0.5, 0.8, 0.4) : "transparent"
        opacity: enabled ? 1.0 : 0.4
        
        Row {
            anchors.fill: parent
            anchors.leftMargin: 10
            spacing: 8
            
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: icon
                font.pixelSize: 14
            }
            
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: parent.parent.text
                font.pixelSize: 11
                color: "#ffffff"
            }
        }
        
        MouseArea {
            id: ciMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: if (enabled) parent.itemClicked()
        }
    }
}
