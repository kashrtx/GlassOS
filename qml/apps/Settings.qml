import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../ui"
import "../components"

FocusScope {
    id: settings
    property var hostWindow: null
    property string initialPage: "personalize"
    property string page: initialPage
    property var wallpapers: Storage.wallpapers()
    readonly property var wm: UI.wm

    readonly property var pages: [
        { id: "personalize", name: "Personalization", icon: "palette" },
        { id: "accessibility", name: "Accessibility", icon: "accessibility" },
        { id: "sound", name: "Sound", icon: "volume" },
        { id: "time", name: "Date & time", icon: "clock" },
        { id: "region", name: "Weather & location", icon: "location" },
        { id: "browser", name: "Browser", icon: "globe" },
        { id: "storage", name: "Storage", icon: "save" },
        { id: "about", name: "About", icon: "diamond" }
    ]

    function sessionState() { return { initialPage: page } }
    function handleArgs(props) { if (props.initialPage) page = props.initialPage }
    Connections {
        target: Storage
        function onChanged(dir) { if (dir === "/Pictures/Wallpapers") settings.wallpapers = Storage.wallpapers() }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ---------------------------------------------------------- nav
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: UI.px(210)
            color: Qt.rgba(0, 0, 0, 0.14)
            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 2
                Row {
                    spacing: 12
                    leftPadding: 6
                    bottomPadding: 14
                    topPadding: 6
                    Rectangle {
                        width: UI.px(40); height: width; radius: width / 2
                        gradient: Gradient {
                            GradientStop { position: 0; color: Qt.lighter(UI.accent, 1.3) }
                            GradientStop { position: 1; color: Qt.darker(UI.accent, 1.4) }
                        }
                        Text { anchors.centerIn: parent; text: Prefs.userName.charAt(0).toUpperCase(); color: "white"; font.pixelSize: UI.px(17); font.bold: true }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text { text: Prefs.userName; color: UI.text; font.pixelSize: UI.px(13); font.weight: Font.DemiBold }
                        Text { font.weight: UI.textWeight; text: "Local account"; color: UI.textFaint; font.pixelSize: UI.px(11) }
                    }
                }
                Repeater {
                    model: settings.pages
                    delegate: AbstractButton {
                        id: nav
                        width: parent.width
                        height: UI.px(36)
                        hoverEnabled: true
                        readonly property bool current: settings.page === modelData.id
                        onClicked: settings.page = modelData.id
                        background: Rectangle {
                            radius: UI.radiusSmall
                            color: nav.current ? UI.accentFaint : (nav.hovered ? UI.hover : "transparent")
                            Rectangle { visible: nav.current; width: 3; height: 18; radius: 1.5; color: UI.accent; anchors.verticalCenter: parent.verticalCenter }
                        }
                        contentItem: Row {
                            leftPadding: 12
                            spacing: 12
                            Icon { name: modelData.icon; size: UI.px(14); anchors.verticalCenter: parent.verticalCenter }
                            Text { font.weight: UI.textWeight; text: modelData.name; color: UI.text; font.pixelSize: UI.px(13); anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
            }
        }

        // ---------------------------------------------------------- pages
        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: pageCol.implicitHeight + 40
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: GScrollBar {}

            Column {
                id: pageCol
                x: 26
                y: 22
                width: flick.width - 52
                spacing: 12

                Text {
                    text: settings.pages.filter(function (p) { return p.id === settings.page })[0].name
                    color: UI.text
                    font.pixelSize: UI.px(24)
                    font.weight: Font.DemiBold
                    bottomPadding: 6
                }

                // ================================================= personalize
                Column {
                    visible: settings.page === "personalize"
                    width: parent.width
                    spacing: 12

                    Rectangle {   // preview
                        width: Math.min(parent.width, UI.px(420))
                        height: width * 9 / 16
                        radius: UI.radius
                        color: "black"
                        clip: true
                        Image {
                            anchors.fill: parent
                            source: Prefs.wallpaperUrl
                            sourceSize.width: 640
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                        Rectangle {   // mini window
                            x: parent.width * 0.18; y: parent.height * 0.16
                            width: parent.width * 0.5; height: parent.height * 0.5
                            radius: 6
                            color: UI.alpha("#121722", 0.75)
                            border.color: UI.alpha(UI.accent, 0.6)
                            Rectangle { width: parent.width; height: 12; radius: 6; color: Qt.rgba(1, 1, 1, 0.08) }
                            Rectangle { x: 10; y: 24; width: parent.width * 0.4; height: 8; radius: 4; color: UI.accent }
                        }
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width; height: parent.height * 0.08
                            color: UI.alpha("#0b0f17", 0.8)
                            Row {
                                anchors.centerIn: parent
                                spacing: 4
                                Repeater { model: 5; Rectangle { width: 8; height: 8; radius: 2; color: index === 0 ? UI.accent : Qt.rgba(1, 1, 1, 0.4) } }
                            }
                        }
                    }

                    SectionTitle { text: "Wallpaper" }
                    Flow {
                        width: parent.width
                        spacing: 10
                        Repeater {
                            model: settings.wallpapers
                            delegate: MouseArea {
                                id: wpTile
                                width: UI.px(150); height: UI.px(94)
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                readonly property bool current: Prefs.wallpaper === modelData.path
                                onClicked: Prefs.setWallpaper(modelData.path)
                                Rectangle {
                                    anchors.fill: parent
                                    radius: UI.radius
                                    color: UI.card
                                    border.width: wpTile.current ? 3 : (wpTile.containsMouse ? 1 : 0)
                                    border.color: wpTile.current ? UI.accent : UI.borderStrong
                                    clip: true
                                    Image {
                                        anchors.fill: parent
                                        anchors.margins: wpTile.current ? 3 : 0
                                        source: modelData.url
                                        sourceSize.width: 300
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                    }
                                }
                                Rectangle {
                                    visible: wpTile.current
                                    anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 8
                                    width: 22; height: 22; radius: 11; color: UI.accent
                                    Icon { name: "check"; size: UI.px(16); anchors.centerIn: parent }
                                }
                                GTip { visible: wpTile.containsMouse; text: modelData.name }
                            }
                        }
                    }
                    Text {
                        font.weight: UI.textWeight
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: "Tip: put any image into Pictures ▸ Wallpapers (or right-click a picture ▸ Set as wallpaper)."
                        color: UI.textFaint
                        font.pixelSize: UI.px(11.5)
                    }

                    SectionTitle { text: "Accent color" }
                    Row {
                        spacing: 10
                        Repeater {
                            model: Prefs.accentPresets
                            delegate: Rectangle {
                                width: UI.px(34); height: width; radius: width / 2
                                color: modelData
                                border.width: Prefs.accent.toString() === Qt.lighter(modelData, 1.0).toString() ? 3 : 0
                                border.color: "white"
                                scale: dot.containsMouse ? 1.12 : 1
                                Behavior on scale { NumberAnimation { duration: UI.dur(90) } }
                                MouseArea { id: dot; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Prefs.setAccent(modelData) }
                            }
                        }
                        GTextField {
                            width: UI.px(120)
                            placeholderText: "#hex"
                            text: Prefs.accent.toString()
                            onAccepted: Prefs.setAccent(text)
                        }
                    }

                    SectionTitle { text: "Effects" }
                    SettingRow { title: "Glass (frosted transparency)"; subtitle: "Windows, taskbar and menus blur the wallpaper behind them"; GToggle { checked: Prefs.glass; onToggled: Prefs.setGlass(checked) } }
                    SettingRow { title: "Desktop clock"; subtitle: "Show the big clock and greeting on the desktop"; GToggle { checked: Prefs.showDesktopClock; onToggled: Prefs.setShowDesktopClock(checked) } }
                    SettingRow { title: "Night light"; subtitle: "Warmer colors that are easier on your eyes at night"; GToggle { checked: Prefs.nightLight; onToggled: Prefs.setNightLight(checked) } }

                    SectionTitle { text: "Startup & multitasking" }
                    SettingRow {
                        title: "Restore windows at startup"
                        subtitle: "Reopen the apps, folders and files you had open, on the same workspaces"
                        GToggle { checked: Prefs.value("session.restore", true) !== false; onToggled: Prefs.setValue("session.restore", checked) }
                    }
                    SettingRow {
                        title: "Snap layouts"
                        subtitle: "Hover a window's maximize button, drag a window to an edge or corner, or press Ctrl+Alt+arrows"
                        GButton { text: "Shortcuts"; iconName: "keyboard"; onClicked: settings.wm.notify("Tip", "Press F1 any time to see every keyboard shortcut.", "keyboard") }
                    }
                }

                // ================================================= accessibility
                Column {
                    visible: settings.page === "accessibility"
                    width: parent.width
                    spacing: 12
                    SectionTitle { text: "Text size" }
                    Row {
                        spacing: 8
                        Repeater {
                            model: ["Small", "Default", "Large", "Extra large"]
                            GButton {
                                text: modelData
                                kind: Prefs.textSize === index ? "primary" : "normal"
                                onClicked: Prefs.setTextSize(index)
                            }
                        }
                    }
                    Text { font.weight: UI.textWeight; text: "The quick brown fox jumps over the lazy dog."; color: UI.textDim; font.pixelSize: UI.px(14) }
                    SettingRow { title: "Bold text"; subtitle: "Heavier text everywhere, easier to read on glass"; GToggle { checked: Prefs.boldText; onToggled: Prefs.setBoldText(checked) } }
                    SettingRow { title: "Animations"; subtitle: "Turn off to make everything snap instantly (also saves battery)"; GToggle { checked: Prefs.animations; onToggled: Prefs.setAnimations(checked) } }
                    SettingRow { title: "Glass effect"; subtitle: "Turn off for maximum contrast"; GToggle { checked: Prefs.glass; onToggled: Prefs.setGlass(checked) } }
                }

                // ================================================= sound
                Column {
                    visible: settings.page === "sound"
                    width: parent.width
                    spacing: 12
                    SettingRow {
                        title: "Volume"
                        subtitle: Prefs.muted ? "Muted" : Prefs.volume + "%"
                        GSlider { width: UI.px(220); from: 0; to: 100; stepSize: 1; value: Prefs.volume; onMoved: Prefs.setVolume(value) }
                    }
                    SettingRow { title: "Mute"; subtitle: "Also mutes every AeroBrowser tab"; GToggle { checked: Prefs.muted; onToggled: Prefs.setMuted(checked) } }
                }

                // ================================================= time
                Column {
                    visible: settings.page === "time"
                    width: parent.width
                    spacing: 12
                    Text { text: UI.timeText(UI.now); color: UI.text; font.pixelSize: UI.px(42); font.weight: Font.Light }
                    Text { font.weight: UI.textWeight; text: Qt.formatDate(UI.now, "dddd, MMMM d, yyyy"); color: UI.textDim; font.pixelSize: UI.px(14) }
                    SettingRow { title: "24-hour clock"; subtitle: "Show 18:30 instead of 6:30 PM"; GToggle { checked: Prefs.use24h; onToggled: Prefs.setUse24h(checked) } }
                }

                // ================================================= weather & location
                Column {
                    id: regionPage
                    visible: settings.page === "region"
                    width: parent.width
                    spacing: 12

                    // Choosing a city clears the result list, destroying the clicked delegate,
                    // so the pick runs here at page level (same pattern as the Weather app).
                    function pickCity(i) {
                        citySearch.text = ""
                        citySearch.focus = false
                        WeatherService.choose(i)
                    }

                    Text { font.weight: UI.textWeight; text: "Your location is used for the weather on the desktop, the taskbar and in the Weather app."; color: UI.textDim; font.pixelSize: UI.px(12.5); width: parent.width; wrapMode: Text.Wrap }

                    Rectangle {   // current location card
                        width: parent.width
                        height: UI.px(92)
                        radius: UI.radiusLarge
                        color: UI.card
                        border.color: UI.border
                        Row {
                            anchors.left: parent.left; anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 14
                            Icon { name: WeatherService.hasData ? (WeatherService.current.icon || "wx-cloudy") : "location"; size: UI.px(52); anchors.verticalCenter: parent.verticalCenter }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                Text { font.weight: Font.DemiBold; text: WeatherService.city || "No location set"; color: UI.text; font.pixelSize: UI.px(16); width: regionPage.width - UI.px(220); elide: Text.ElideRight }
                                Text { font.weight: UI.textWeight; text: WeatherService.region; visible: text !== ""; color: UI.textDim; font.pixelSize: UI.px(12); width: regionPage.width - UI.px(220); elide: Text.ElideRight }
                                Text {
                                    font.weight: UI.textWeight
                                    text: WeatherService.loading ? "Updating…" : (WeatherService.error !== "" ? WeatherService.error
                                          : (WeatherService.hasData ? UI.temp(WeatherService.current.temp) + "  ·  " + (WeatherService.current.condition || "") : ""))
                                    color: WeatherService.error !== "" ? UI.warning : UI.textFaint
                                    font.pixelSize: UI.px(11.5)
                                    width: regionPage.width - UI.px(220); elide: Text.ElideRight
                                }
                            }
                        }
                        GButton {
                            anchors.right: parent.right; anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Refresh"; iconName: "refresh"
                            enabled: !WeatherService.loading
                            onClicked: WeatherService.refresh()
                        }
                    }

                    SectionTitle { text: "Change location" }
                    GTextField {
                        id: citySearch
                        width: parent.width
                        leading: "search"
                        placeholderText: "Search for a city (e.g. Mississauga, Tokyo, London)"
                        onTextEdited: cityDebounce.restart()
                        onAccepted: { cityDebounce.stop(); if (text.trim()) WeatherService.search(text) }
                        Timer { id: cityDebounce; interval: 350; onTriggered: if (citySearch.text.trim().length >= 2) WeatherService.search(citySearch.text) }
                    }
                    Column {
                        width: parent.width
                        spacing: 4
                        visible: citySearch.text.trim().length >= 2
                        Text {
                            font.weight: UI.textWeight
                            visible: WeatherService.searching || WeatherService.searchResults.length === 0
                            text: WeatherService.searching ? "Searching…" : "No places found"
                            color: UI.textFaint; font.pixelSize: UI.px(12)
                        }
                        Repeater {
                            model: WeatherService.searching ? [] : WeatherService.searchResults
                            delegate: MouseArea {
                                id: cityRow
                                width: regionPage.width
                                height: UI.px(48)
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { var i = index; Qt.callLater(function () { regionPage.pickCity(i) }) }
                                Rectangle { anchors.fill: parent; radius: UI.radius; color: cityRow.containsMouse ? UI.hover : UI.card; border.color: UI.border }
                                Row {
                                    anchors.left: parent.left; anchors.leftMargin: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 12
                                    Icon { name: "location"; size: UI.px(18); anchors.verticalCenter: parent.verticalCenter }
                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        Text { font.weight: Font.DemiBold; text: modelData.name; color: UI.text; font.pixelSize: UI.px(13) }
                                        Text { font.weight: UI.textWeight; text: [modelData.admin, modelData.country].filter(function (x) { return x }).join(", "); color: UI.textFaint; font.pixelSize: UI.px(11); width: regionPage.width - UI.px(80); elide: Text.ElideRight }
                                    }
                                }
                            }
                        }
                    }

                    SectionTitle { text: "Units" }
                    SettingRow {
                        title: "Temperature unit"; subtitle: "Used everywhere: desktop, taskbar and Weather"
                        Row {
                            spacing: 6
                            GButton { text: "°C"; kind: Prefs.weatherUnit === "C" ? "primary" : "normal"; onClicked: Prefs.setWeatherUnit("C") }
                            GButton { text: "°F"; kind: Prefs.weatherUnit === "F" ? "primary" : "normal"; onClicked: Prefs.setWeatherUnit("F") }
                        }
                    }
                }

                // ================================================= browser
                Column {
                    visible: settings.page === "browser"
                    width: parent.width
                    spacing: 12
                    Text { font.weight: UI.textWeight; visible: !HasWebEngine; width: parent.width; wrapMode: Text.Wrap; text: "QtWebEngine isn't installed, so AeroBrowser is disabled. Run: pip install PySide6-Addons"; color: UI.warning; font.pixelSize: UI.px(13) }
                    SettingRow {
                        title: "Ad & tracker blocker"
                        subtitle: AdBlocker ? AdBlocker.blockedCount + " requests blocked this session" : "Not available"
                        GToggle { enabled: AdBlocker !== null; checked: AdBlocker ? AdBlocker.enabled : false; onToggled: AdBlocker.setEnabled(checked) }
                    }
                    SettingRow {
                        title: "Bookmarks"; subtitle: "Restore the default bookmarks bar"
                        GButton { text: "Reset"; onClicked: { Prefs.setValue("browser.bookmarks", null); settings.wm.notify("Bookmarks reset", "Open a new AeroBrowser window to see them.", "bookmark") } }
                    }
                }

                // ================================================= storage
                Column {
                    visible: settings.page === "storage"
                    width: parent.width
                    spacing: 12
                    SettingRow {
                        title: "Recycle Bin"; subtitle: Storage.trashCount + " item(s)"
                        GButton { text: "Empty"; kind: "danger"; enabled: Storage.trashCount > 0; onClicked: { var n = Storage.emptyTrash(); settings.wm.notify("Recycle Bin emptied", n + " item(s) deleted", "broom") } }
                    }
                    SettingRow {
                        title: "Host disk"; subtitle: System.hasStats ? Math.round(System.diskPercent) + "% used" : "Install psutil for disk stats"
                        UsageBar { value: System.diskPercent }
                    }
                    SettingRow {
                        title: "Clear recent files & terminal history"; subtitle: "Start menu ‘Recent’ and GlassShell history"
                        GButton { text: "Clear"; onClicked: { Prefs.setValue("recent.files", []); Prefs.setValue("term.history", []); settings.wm.notify("History cleared", "", "broom") } }
                    }
                    SettingRow {
                        title: "Reset desktop icon layout"; subtitle: "Put all desktop icons back in a tidy column"
                        GButton { text: "Reset"; onClicked: Prefs.setValue("desktop.layout", {}) }
                    }
                }

                // ================================================= about
                Column {
                    visible: settings.page === "about"
                    width: parent.width
                    spacing: 12
                    Row {
                        spacing: 16
                        Grid {
                            columns: 2; spacing: 4
                            anchors.verticalCenter: parent.verticalCenter
                            Repeater { model: 4; Rectangle { width: 22; height: 22; radius: 6; color: index === 3 ? UI.alpha(UI.accent, 0.6) : UI.accent } }
                        }
                        Column {
                            Text { text: "GlassOS " + System.version; color: UI.text; font.pixelSize: UI.px(20); font.weight: Font.DemiBold }
                            Text { font.weight: UI.textWeight; text: "A glassy desktop environment made with Python + Qt Quick"; color: UI.textDim; font.pixelSize: UI.px(12.5) }
                        }
                    }
                    SettingRow {
                        title: "Your name"; subtitle: "Shown on the start menu, lock screen and greetings"
                        GTextField { width: UI.px(200); text: Prefs.userName; onEditingFinished: Prefs.setUserName(text) }
                    }
                    SettingRow { title: "Host"; subtitle: System.hostOS + " · " + System.cpuName + " · " + System.cpuCores + " cores" }
                    SettingRow { title: "Runtime"; subtitle: "Python " + System.pythonVersion + " · Qt " + System.qtVersion }
                    SettingRow { title: "Features"; subtitle: "Web engine: " + (HasWebEngine ? "on" : "off") + "   ·   Live stats: " + (System.hasStats ? "on" : "off") + "   ·   Media: " + (HasMultimedia ? "on" : "off") + "   ·   Frosted glass: " + (UI.blurUrl !== "" ? "on" : "off") }
                    SettingRow { title: "CPU"; subtitle: System.hasStats ? Math.round(System.cpuPercent) + "%" : "–"; UsageBar { value: System.cpuPercent } }
                    SettingRow { title: "Memory"; subtitle: System.hasStats ? System.memUsedGB + " / " + System.memTotalGB + " GB" : "–"; UsageBar { value: System.memPercent } }
                    SettingRow { title: "Session uptime"; subtitle: System.uptime + "  ·  GlassOS uses " + System.appMemMB + " MB" }
                    SettingRow {
                        title: "Reset all settings"; subtitle: "Accent, toggles and sizes go back to defaults (your files are untouched)"
                        GButton { text: "Reset"; kind: "danger"; onClicked: Prefs.resetAll() }
                    }
                }
            }
        }
    }
}
