// GlassOS Settings App - Fixed and Stable
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: settingsApp
    color: "transparent"
    
    // Bind to Storage updates
    Connections {
        target: Storage
        function onWallpaperChanged() { refreshWallpapers() }
    }
    
    signal wallpaperSelected(string path)
    
    property int currentSection: 0
    property var wallpapers: []
    property string currentWallpaperUrl: Storage.getWallpaperUrl()
    property string currentWallpaperPath: Storage.currentWallpaper // Bind directly
    property var systemInfo: ({})
    
    // Safe font sizes
    property var fontSizes: [10, 12, 14, 16] // Small, Normal, Large, XLarge
    property int currentFontSize: (typeof Accessibility !== "undefined" && Accessibility) ? Accessibility.baseFontSize : 12
    property bool isBold: (typeof Accessibility !== "undefined" && Accessibility) ? Accessibility.boldText : false
    
    property var sections: [
        { name: "Personalization", icon: "🎨" },
        { name: "Display", icon: "🖥" },
        { name: "System", icon: "💻" },
        { name: "About", icon: "ℹ" }
    ]
    
    Component.onCompleted: {
        refreshAll()
    }
    
    function refreshAll() {
        refreshWallpapers()
        loadSystemInfo()
    }
    
    function refreshWallpapers() {
        var wpList = Storage.getWallpapers()
        wallpapers = wpList
        currentWallpaperUrl = Storage.getWallpaperUrl()
        // currentWallpaperPath updates automatically via binding
        console.log("Settings: Loaded", wpList.length, "wallpapers")
    }
    
    function loadSystemInfo() {
        try {
            var infoStr = Storage.getSystemInfo()
            systemInfo = JSON.parse(infoStr)
        } catch (e) {
            systemInfo = {}
        }
    }
    
    function getCurrentWallpaperName() {
        if (currentWallpaperPath) {
            var parts = currentWallpaperPath.replace(/\\/g, "/").split("/")
            return parts[parts.length - 1]
        }
        return "None selected"
    }
    
    function isCurrentWallpaper(wpPath) {
        if (!currentWallpaperPath || !wpPath) return false
        var current = currentWallpaperPath.replace(/\\/g, "/").toLowerCase()
        var compare = wpPath.replace(/\\/g, "/").toLowerCase()
        return current.indexOf(compare) !== -1 || compare.indexOf(current) !== -1
    }
    
    RowLayout {
        anchors.fill: parent
        spacing: 0
        
        // Sidebar
        Rectangle {
            Layout.preferredWidth: 180
            Layout.fillHeight: true
            color: Qt.rgba(0, 0, 0, 0.3)
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 4
                
                Row {
                    spacing: 6
                    Layout.bottomMargin: 10
                    Text { text: "⚙"; font.pixelSize: 20 }
                    Text { 
                        text: "Settings"
                        font.pixelSize: 16
                        font.bold: true
                        color: "#ffffff"
                    }
                }
                
                Repeater {
                    model: sections
                    Rectangle {
                        Layout.fillWidth: true
                        height: Math.max(32, currentFontSize * 2.2)
                        radius: 4
                        color: currentSection === index ? Qt.rgba(0.3, 0.5, 0.8, 0.5) : 
                               (sectionMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent")
                        
                        Row {
                            anchors.fill: parent; anchors.leftMargin: 8; spacing: 8
                            Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.icon; font.pixelSize: 14 }
                            Text { 
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name
                                font.pixelSize: currentFontSize
                                font.bold: isBold
                                color: "#ffffff"
                            }
                        }
                        MouseArea {
                            id: sectionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: currentSection = index
                        }
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }
        
        // Content
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"
            
            StackLayout {
                anchors.fill: parent
                anchors.margins: 14
                currentIndex: currentSection
                
                // ===== PERSONALIZATION =====
                ScrollView {
                    contentWidth: -1 // Disabled horizontal
                    clip: true
                    
                    Column {
                        width: parent.width
                        spacing: 14
                        
                        Text { text: "🎨 Personalization"; font.pixelSize: 18; font.bold: true; color: "#ffffff" }
                        
                        // Current Wallpaper Preview
                        Rectangle {
                            width: parent.width
                            height: 90
                            radius: 6
                            color: Qt.rgba(0,0,0,0.25)
                            
                            Row {
                                anchors.fill: parent; anchors.margins: 10; spacing: 12
                                Rectangle {
                                    width: 120; height: 70; radius: 4; color: Qt.rgba(0,0,0,0.4)
                                    Image {
                                        anchors.fill: parent; anchors.margins: 2
                                        source: currentWallpaperUrl
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        Text { anchors.centerIn: parent; text: "🖼"; visible: parent.status !== Image.Ready; opacity: 0.4; font.pixelSize: 24 }
                                    }
                                }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter; spacing: 6
                                    Text { text: "Current Wallpaper"; font.pixelSize: currentFontSize+1; font.bold: true; color: "#fff" }
                                    Text { 
                                        text: getCurrentWallpaperName()
                                        font.pixelSize: currentFontSize-1
                                        font.bold: isBold
                                        color: "#aaa"; width: 220; elide: Text.ElideMiddle
                                    }
                                    // Manual Refresh button
                                    Button {
                                        text: "Refresh"
                                        onClicked: refreshWallpapers()
                                        height: 24
                                        font.pixelSize: 10
                                    }
                                }
                            }
                        }
                        
                        Text { 
                            text: "Choose wallpaper (" + wallpapers.length + " found)"
                            font.pixelSize: currentFontSize; font.bold: isBold; color: "#aaa"
                        }
                        
                        // Wallpaper Grid
                        Rectangle {
                            width: parent.width
                            height: Math.max(180, Math.ceil(wallpapers.length / 4) * 85)
                            radius: 6
                            color: Qt.rgba(0,0,0,0.2)
                            
                            GridView {
                                id: wpGrid
                                anchors.fill: parent; anchors.margins: 8
                                cellWidth: 110; cellHeight: 80
                                clip: true
                                model: wallpapers
                                delegate: Rectangle {
                                    width: wpGrid.cellWidth-6; height: wpGrid.cellHeight-6; radius: 4
                                    color: mMouse.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
                                    border.width: isCurrentWallpaper(modelData.path) ? 2 : 0
                                    border.color: "#4a9eff"
                                    
                                    Image {
                                        anchors.fill: parent; anchors.margins: 2
                                        source: modelData.url
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                    }
                                    
                                    MouseArea {
                                        id: mMouse
                                        anchors.fill: parent; hoverEnabled: true
                                        onClicked: {
                                            Storage.setWallpaper(modelData.path)
                                            // UI updates via Connection
                                        }
                                    }
                                }
                            }
                            
                            // Better empty state
                            Column {
                                anchors.centerIn: parent
                                spacing: 6
                                visible: wallpapers.length === 0
                                width: parent.width - 40
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "🖼"; font.pixelSize: 28; opacity: 0.4 }
                                Text {
                                    width: parent.width
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "No wallpapers found"
                                    font.pixelSize: currentFontSize
                                    font.bold: isBold
                                    color: "#888"
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.Wrap
                                }
                                Text {
                                    width: parent.width
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "Place images in Storage/User/Pictures/Wallpapers"
                                    font.bold: isBold
                                    color: "#666"
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.Wrap
                                }
                                Text {
                                    width: parent.width
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "Looking in: " + Storage.storageRoot + "/Pictures/Wallpapers"
                                    font.pixelSize: 9
                                    color: "#555"
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.Wrap
                                }
                            }
                        }
                    }
                }
                
                // ===== DISPLAY =====
                Column {
                    spacing: 14
                    Text { text: "🖥 Display"; font.pixelSize: 18; font.bold: true; color: "#ffffff" }
                    
                    Rectangle {
                        width: parent.width; height: 160
                        radius: 6; color: Qt.rgba(0,0,0,0.25)
                        Column {
                            anchors.fill: parent; anchors.margins: 12; spacing: 14
                            
                            // Size
                            Column {
                                spacing: 8
                                Text { text: "Text Size"; font.pixelSize: currentFontSize; font.bold: true; color: "#fff" }
                                Row {
                                    spacing: 10
                                    Repeater {
                                        model: ["Small", "Normal", "Large", "XLarge"]
                                        Rectangle {
                                            width: 70; height: 36; radius: 4
                                            color: (typeof Accessibility !== "undefined" && Accessibility && Accessibility.fontSizePreset === index) ? "#4a9eff" : Qt.rgba(1,1,1,0.1)
                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData
                                                font.pixelSize: fontSizes[index]
                                                font.bold: isBold
                                                color: "#fff"
                                            }
                                            MouseArea { anchors.fill: parent; onClicked: if(typeof Accessibility !== "undefined") Accessibility.setFontSizePreset(index) }
                                        }
                                    }
                                }
                            }
                            
                            // Bold
                            Row {
                                spacing: 14
                                Rectangle {
                                    width: 24; height: 24; radius: 4
                                    color: (typeof Accessibility !== "undefined" && Accessibility && Accessibility.boldText) ? "#4a9eff" : Qt.rgba(1,1,1,0.1)
                                    Text { anchors.centerIn: parent; text: "B"; font.bold: true; color: "#fff" }
                                    MouseArea { anchors.fill: parent; onClicked: if(typeof Accessibility !== "undefined") Accessibility.setBoldText(!Accessibility.boldText) }
                                }
                                Text { 
                                    text: "Bold Text"
                                    font.pixelSize: currentFontSize
                                    font.bold: isBold
                                    color: "#fff"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }
                
                // ===== SYSTEM =====
                Column {
                    spacing: 14
                    Text { text: "💻 System Info"; font.pixelSize: 18; font.bold: true; color: "#ffffff" }
                    
                    // Resources
                    Rectangle {
                        width: parent.width; height: 70
                        radius: 6; color: Qt.rgba(0,0,0,0.25)
                        Row {
                            anchors.fill: parent; anchors.margins: 12; spacing: 30
                            Column {
                                spacing: 4
                                Text { text: "CPU"; color: "#888"; font.pixelSize: 10; font.bold: isBold }
                                Rectangle { width: 100; height: 6; radius: 3; color: "#333"; Rectangle { width: parent.width * ((typeof ResourceMonitor !== "undefined" && ResourceMonitor) ? ResourceMonitor.cpuPercent/100 : 0); height: 6; radius: 3; color: "#4a9eff" } }
                                Text { text: Math.round((typeof ResourceMonitor !== "undefined" && ResourceMonitor) ? ResourceMonitor.cpuPercent : 0)+"%"; color:"#fff"; font.bold: true }
                            }
                            Column {
                                spacing: 4
                                Text { text: "RAM"; color: "#888"; font.pixelSize: 10; font.bold: isBold }
                                Rectangle { width: 100; height: 6; radius: 3; color: "#333"; Rectangle { width: parent.width * ((typeof ResourceMonitor !== "undefined" && ResourceMonitor) ? ResourceMonitor.memoryPercent/100 : 0); height: 6; radius: 3; color: "#41cd52" } }
                                Text { text: ((typeof ResourceMonitor !== "undefined" && ResourceMonitor) ? ResourceMonitor.memoryUsedGB : "0") + " GB"; color:"#fff"; font.bold: true }
                            }
                        }
                    }
                    
                    // Specs
                    Rectangle {
                        width: parent.width; height: 100
                        radius: 6; color: Qt.rgba(0,0,0,0.25)
                        Column {
                            anchors.fill: parent; anchors.margins: 10; spacing: 8
                            Row {
                                spacing: 8
                                Text { text: "CPU"; color: "#aaa"; width: 40; font.bold: isBold }
                                Text { text: systemInfo.cpu ? systemInfo.cpu.name : "Loading..."; color: "#fff"; width: 250; elide: Text.ElideRight; font.bold: isBold }
                            }
                            Row {
                                spacing: 8
                                Text { text: "OS"; color: "#aaa"; width: 40; font.bold: isBold }
                                Text { text: systemInfo.os || "Loading..."; color: "#fff"; width: 250; elide: Text.ElideRight; font.bold: isBold }
                            }
                        }
                    }
                }
                
                // ===== ABOUT =====
                Column {
                    spacing: 14
                    Text { text: "ℹ About"; font.pixelSize: 18; font.bold: true; color: "#ffffff" }
                    Rectangle {
                        width: parent.width; height: 100; radius: 6; color: Qt.rgba(0,0,0,0.25)
                        Row {
                            anchors.fill: parent; anchors.margins: 14; spacing: 14
                            Text { text: "🌟"; font.pixelSize: 40 }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                Text { text: "GlassOS 1.0"; font.pixelSize: 22; font.bold: true; color: "#fff" }
                                Text { text: "A glassy Python desktop experience. By KashRTX (ಥ﹏ಥ)"; color: "#aaa"; font.pixelSize: currentFontSize; font.bold: isBold }
                            }
                        }
                    }
                }
            }
        }
    }
}
