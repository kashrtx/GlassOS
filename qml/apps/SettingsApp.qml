// GlassOS Settings App - Improved with Full Functionality
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: settingsApp
    color: "transparent"
    
    signal wallpaperSelected(string path)
    
    property int currentSection: 0
    property var wallpapers: []
    
    property var sections: [
        { name: "Personalization", icon: "🎨" },
        { name: "Display", icon: "🖥" },
        { name: "System", icon: "⚙" },
        { name: "Storage", icon: "💾" },
        { name: "About", icon: "ℹ" }
    ]
    
    Component.onCompleted: {
        refreshWallpapers()
    }
    
    function refreshWallpapers() {
        wallpapers = Storage.getWallpapers()
    }
    
    function getCurrentWallpaperName() {
        var url = Storage.getWallpaperUrl()
        if (url) {
            var parts = url.split("/")
            return parts[parts.length - 1]
        }
        return "None"
    }
    
    RowLayout {
        anchors.fill: parent
        spacing: 0
        
        // Sidebar
        Rectangle {
            Layout.preferredWidth: 180
            Layout.fillHeight: true
            color: Qt.rgba(0, 0, 0, 0.25)
            
            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 4
                
                // Header
                Row {
                    spacing: 8
                    bottomPadding: 16
                    
                    Text {
                        text: "⚙"
                        font.pixelSize: 24
                    }
                    
                    Text {
                        text: "Settings"
                        font.pixelSize: 18
                        font.bold: true
                        color: "#ffffff"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                
                Repeater {
                    model: sections
                    
                    Rectangle {
                        width: parent.width
                        height: 40
                        radius: 6
                        color: currentSection === index ? Qt.rgba(0.3, 0.5, 0.8, 0.5) : 
                               (sectionMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent")
                        
                        border.width: currentSection === index ? 1 : 0
                        border.color: Qt.rgba(0.4, 0.6, 0.9, 0.5)
                        
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            spacing: 12
                            
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.icon
                                font.pixelSize: 18
                            }
                            
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name
                                font.pixelSize: 13
                                color: "#ffffff"
                            }
                        }
                        
                        MouseArea {
                            id: sectionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: currentSection = index
                        }
                        
                        Behavior on color { ColorAnimation { duration: 100 } }
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
        
        // Content
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"
            
            StackLayout {
                anchors.fill: parent
                anchors.margins: 20
                currentIndex: currentSection
                
                // ===== PERSONALIZATION =====
                ScrollView {
                    clip: true
                    
                    ColumnLayout {
                        width: parent.width
                        spacing: 20
                        
                        // Section header
                        Column {
                            spacing: 4
                            
                            Text {
                                text: "🎨 Personalization"
                                font.pixelSize: 22
                                font.bold: true
                                color: "#ffffff"
                            }
                            
                            Text {
                                text: "Customize your desktop appearance"
                                font.pixelSize: 12
                                color: "#888888"
                            }
                        }
                        
                        // Current wallpaper
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 120
                            radius: 8
                            color: Qt.rgba(0, 0, 0, 0.2)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.1)
                            
                            Row {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 16
                                
                                // Preview
                                Rectangle {
                                    width: 160
                                    height: 96
                                    radius: 6
                                    color: Qt.rgba(0, 0, 0, 0.3)
                                    
                                    Image {
                                        anchors.fill: parent
                                        anchors.margins: 2
                                        source: Storage.getWallpaperUrl()
                                        fillMode: Image.PreserveAspectCrop
                                        
                                        Rectangle {
                                            anchors.fill: parent
                                            color: "transparent"
                                            radius: 4
                                        }
                                    }
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "No wallpaper"
                                        font.pixelSize: 10
                                        color: "#666666"
                                        visible: Storage.getWallpaperUrl() === ""
                                    }
                                }
                                
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 8
                                    
                                    Text {
                                        text: "Current Wallpaper"
                                        font.pixelSize: 14
                                        font.bold: true
                                        color: "#ffffff"
                                    }
                                    
                                    Text {
                                        text: getCurrentWallpaperName()
                                        font.pixelSize: 12
                                        color: "#aaaaaa"
                                    }
                                    
                                    Rectangle {
                                        width: 100
                                        height: 28
                                        radius: 4
                                        color: refreshBtnMouse.containsMouse ? Qt.rgba(1,1,1,0.15) : Qt.rgba(1,1,1,0.08)
                                        
                                        Text {
                                            anchors.centerIn: parent
                                            text: "🔄 Refresh"
                                            font.pixelSize: 11
                                            color: "#ffffff"
                                        }
                                        
                                        MouseArea {
                                            id: refreshBtnMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: refreshWallpapers()
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Wallpaper selection label
                        Row {
                            spacing: 12
                            
                            Text {
                                text: "Choose a wallpaper"
                                font.pixelSize: 14
                                font.bold: true
                                color: "#aaaaaa"
                            }
                            
                            Text {
                                text: "(" + wallpapers.length + " available)"
                                font.pixelSize: 12
                                color: "#666666"
                            }
                        }
                        
                        // Wallpaper grid
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.max(180, Math.ceil(wallpapers.length / 4) * 90 + 20)
                            radius: 8
                            color: Qt.rgba(0, 0, 0, 0.2)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.1)
                            
                            GridView {
                                id: wallpaperGrid
                                anchors.fill: parent
                                anchors.margins: 10
                                cellWidth: 130
                                cellHeight: 85
                                clip: true
                                model: wallpapers
                                
                                delegate: Rectangle {
                                    width: 122
                                    height: 77
                                    radius: 6
                                    color: wpMouse.containsMouse ? Qt.rgba(0.3, 0.5, 0.8, 0.4) : Qt.rgba(1, 1, 1, 0.05)
                                    border.width: Storage.getWallpaperUrl().indexOf(modelData.name) !== -1 ? 2 : 0
                                    border.color: "#4a9eff"
                                    
                                    Image {
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        source: modelData.url
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                    }
                                    
                                    // Overlay with name
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        height: 22
                                        radius: 4
                                        color: Qt.rgba(0, 0, 0, 0.7)
                                        
                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            height: 6
                                            color: parent.color
                                        }
                                        
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.name
                                            font.pixelSize: 9
                                            color: "#ffffff"
                                            elide: Text.ElideMiddle
                                            width: parent.width - 8
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }
                                    
                                    // Selected checkmark
                                    Rectangle {
                                        visible: Storage.getWallpaperUrl().indexOf(modelData.name) !== -1
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 6
                                        width: 20
                                        height: 20
                                        radius: 10
                                        color: "#4a9eff"
                                        
                                        Text {
                                            anchors.centerIn: parent
                                            text: "✓"
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: "#ffffff"
                                        }
                                    }
                                    
                                    MouseArea {
                                        id: wpMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            settingsApp.wallpaperSelected(modelData.path)
                                        }
                                    }
                                    
                                    scale: wpMouse.pressed ? 0.97 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 50 } }
                                }
                            }
                            
                            // Empty state
                            Column {
                                anchors.centerIn: parent
                                spacing: 12
                                visible: wallpapers.length === 0
                                
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "🖼"
                                    font.pixelSize: 40
                                    opacity: 0.4
                                }
                                
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "No wallpapers found"
                                    font.pixelSize: 14
                                    color: "#888888"
                                }
                                
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "Add images to:"
                                    font.pixelSize: 11
                                    color: "#666666"
                                }
                                
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 280
                                    height: 28
                                    radius: 4
                                    color: Qt.rgba(0, 0, 0, 0.3)
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "Storage/User/Pictures/Wallpapers"
                                        font.family: "Consolas"
                                        font.pixelSize: 10
                                        color: "#aaaaaa"
                                    }
                                }
                            }
                        }
                        
                        Item { height: 20 }
                    }
                }
                
                // ===== DISPLAY =====
                ColumnLayout {
                    spacing: 20
                    
                    Column {
                        spacing: 4
                        
                        Text {
                            text: "🖥 Display"
                            font.pixelSize: 22
                            font.bold: true
                            color: "#ffffff"
                        }
                        
                        Text {
                            text: "Configure display settings"
                            font.pixelSize: 12
                            color: "#888888"
                        }
                    }
                    
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 100
                        radius: 8
                        color: Qt.rgba(0, 0, 0, 0.2)
                        
                        Column {
                            anchors.centerIn: parent
                            spacing: 8
                            
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "🚧"
                                font.pixelSize: 32
                            }
                            
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Display settings coming in a future update"
                                font.pixelSize: 12
                                color: "#888888"
                            }
                        }
                    }
                    
                    Item { Layout.fillHeight: true }
                }
                
                // ===== SYSTEM =====
                ColumnLayout {
                    spacing: 20
                    
                    Column {
                        spacing: 4
                        
                        Text {
                            text: "⚙ System"
                            font.pixelSize: 22
                            font.bold: true
                            color: "#ffffff"
                        }
                        
                        Text {
                            text: "System preferences and options"
                            font.pixelSize: 12
                            color: "#888888"
                        }
                    }
                    
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 100
                        radius: 8
                        color: Qt.rgba(0, 0, 0, 0.2)
                        
                        Column {
                            anchors.centerIn: parent
                            spacing: 8
                            
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "🚧"
                                font.pixelSize: 32
                            }
                            
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "System settings coming in a future update"
                                font.pixelSize: 12
                                color: "#888888"
                            }
                        }
                    }
                    
                    Item { Layout.fillHeight: true }
                }
                
                // ===== STORAGE =====
                ColumnLayout {
                    spacing: 20
                    
                    Column {
                        spacing: 4
                        
                        Text {
                            text: "💾 Storage"
                            font.pixelSize: 22
                            font.bold: true
                            color: "#ffffff"
                        }
                        
                        Text {
                            text: "View storage information"
                            font.pixelSize: 12
                            color: "#888888"
                        }
                    }
                    
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 140
                        radius: 8
                        color: Qt.rgba(0, 0, 0, 0.2)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.1)
                        
                        Column {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12
                            
                            Text {
                                text: "Storage Location"
                                font.pixelSize: 14
                                font.bold: true
                                color: "#ffffff"
                            }
                            
                            Rectangle {
                                width: parent.width
                                height: 32
                                radius: 4
                                color: Qt.rgba(0, 0, 0, 0.3)
                                
                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Storage.storageRoot
                                    font.family: "Consolas"
                                    font.pixelSize: 11
                                    color: "#aaaaaa"
                                }
                            }
                            
                            Text {
                                text: "All your files are stored in this directory. GlassOS only accesses files within this folder."
                                font.pixelSize: 11
                                color: "#888888"
                                wrapMode: Text.Wrap
                                width: parent.width
                            }
                        }
                    }
                    
                    Item { Layout.fillHeight: true }
                }
                
                // ===== ABOUT =====
                ColumnLayout {
                    spacing: 20
                    
                    Column {
                        spacing: 4
                        
                        Text {
                            text: "ℹ About GlassOS"
                            font.pixelSize: 22
                            font.bold: true
                            color: "#ffffff"
                        }
                        
                        Text {
                            text: "System information"
                            font.pixelSize: 12
                            color: "#888888"
                        }
                    }
                    
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 150
                        radius: 8
                        color: Qt.rgba(0, 0, 0, 0.2)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.1)
                        
                        Row {
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 24
                            
                            Rectangle {
                                width: 100
                                height: 100
                                radius: 20
                                
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "#4a9eff" }
                                    GradientStop { position: 1.0; color: "#2a5298" }
                                }
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "🌟"
                                    font.pixelSize: 48
                                }
                            }
                            
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6
                                
                                Text {
                                    text: "GlassOS"
                                    font.pixelSize: 28
                                    font.bold: true
                                    color: "#ffffff"
                                }
                                
                                Text {
                                    text: "Version 1.0.0"
                                    font.pixelSize: 14
                                    color: "#aaaaaa"
                                }
                                
                                Text {
                                    text: "Aero-Mojo Desktop Environment"
                                    font.pixelSize: 12
                                    color: "#888888"
                                }
                                
                                Row {
                                    spacing: 8
                                    topPadding: 4
                                    
                                    Rectangle {
                                        width: 70
                                        height: 20
                                        radius: 3
                                        color: "#306998"
                                        
                                        Text {
                                            anchors.centerIn: parent
                                            text: "Python"
                                            font.pixelSize: 9
                                            color: "#ffd43b"
                                        }
                                    }
                                    
                                    Rectangle {
                                        width: 50
                                        height: 20
                                        radius: 3
                                        color: "#41cd52"
                                        
                                        Text {
                                            anchors.centerIn: parent
                                            text: "Qt"
                                            font.pixelSize: 9
                                            color: "#ffffff"
                                        }
                                    }
                                    
                                    Rectangle {
                                        width: 50
                                        height: 20
                                        radius: 3
                                        color: "#f0db4f"
                                        
                                        Text {
                                            anchors.centerIn: parent
                                            text: "QML"
                                            font.pixelSize: 9
                                            color: "#323330"
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    Item { Layout.fillHeight: true }
                }
            }
        }
    }
}
