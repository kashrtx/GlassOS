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
    
    Component.onCompleted: {
        refreshIcons()
    }
    
    // Listen for file system changes (e.g. valid delete from Recycle Bin)
    Connections {
        target: Storage
        function onDesktopUpdated() {
            console.log("Desktop updated signal received, refreshing icons...")
            refreshIcons()
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
    
    // Unified Desktop MouseArea for Clicks & Drops
    MouseArea {
        id: desktopMouseArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        focus: true
        
        // Key handling
        Keys.onPressed: function(event) {
            if (event.modifiers & Qt.ControlModifier) {
                if (event.key === Qt.Key_C && selectedIndex !== -1) {
                    Storage.setClipboard("/Desktop/" + icons[selectedIndex].name, "copy")
                } else if (event.key === Qt.Key_X && selectedIndex !== -1) {
                    Storage.setClipboard("/Desktop/" + icons[selectedIndex].name, "cut")
                } else if (event.key === Qt.Key_V) {
                    if (Storage.paste("/Desktop")) { refreshIcons() }
                } else if (event.key === Qt.Key_R) {
                    refreshIcons()
                }
            } else if (event.key === Qt.Key_Delete && selectedIndex !== -1) {
                if (Storage.moveToTrash("/Desktop/" + icons[selectedIndex].name)) {
                    refreshIcons()
                    selectedIndex = -1
                }
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
            
            // Drag and Drop Meta
            Drag.active: iconMouse.drag.active
            Drag.hotSpot.x: width / 2
            Drag.hotSpot.y: height / 2
            Drag.mimeData: { "path": (modelData.app === "RecycleBin") ? "/Recycle Bin" : "/Desktop/" + modelData.name, "index": index, "name": modelData.name, "isApp": !!modelData.app }
            
            // DropArea for folders/trash
            DropArea {
                id: iconDropArea
                anchors.fill: parent
                enabled: modelData.app === "RecycleBin" || modelData.icon === "📁"
                
                onEntered: function(drag) {
                    if (drag.source !== iconItem) {
                        iconItem.border.width = 2
                        iconItem.border.color = "#4a9eff"
                    }
                }
                onExited: {
                    iconItem.border.width = (selectedIndex === index) ? 1 : 0
                    iconItem.border.color = Qt.rgba(0.4, 0.7, 1, 0.6)
                }
                onDropped: function(drop) {
                    var sourcePath = drop.getDataAsString("path")
                    var sourceIndex = parseInt(drop.getDataAsString("index"))
                    
                    if (modelData.app === "RecycleBin") {
                        if (Storage.moveToTrash(sourcePath)) {
                            refreshIcons()
                        }
                    } else if (modelData.icon === "📁") {
                        if (Storage.moveItem(sourcePath, "/Desktop/" + modelData.name)) {
                            refreshIcons()
                        }
                    }
                }
            }
            
            color: selectedIndex === index ? Qt.rgba(1, 1, 1, 0.2) : "transparent"
            
            border.width: selectedIndex === index ? 1 : 0
            border.color: Qt.rgba(0.4, 0.7, 1, 0.6)
            
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
                drag.threshold: 10
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                
                onPressed: function(mouse) {
                    // Close menu if clicking elsewhere
                    if (showContextMenu) {
                       showContextMenu = false
                       // Don't return, let selection happen
                    }
                    
                    selectedIndex = index
                    root.forceActiveFocus()
                    if (mouse.button === Qt.RightButton) {
                        menuX = mouse.x + iconItem.x // Fixed menu pos
                        menuY = mouse.y + iconItem.y
                        showContextMenu = true
                    }
                }
                
                onReleased: {
                    // Logic handled by DropAreas (Background or other icons)
                    // We do NOT update the model here to avoid race conditions 
                    // with the DropArea.onDropped (e.g., recycle bin delete)
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
                enabled: Storage.clipboardPath !== ""
                onItemClicked: { 
                    var clipboardPath = Storage.clipboardPath
                    if (Storage.paste("/Desktop")) {
                        // We refresh everything to see the new item
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
