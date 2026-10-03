// Centered dock: Start + pinned apps + running apps, weather on the left,
// system tray on the right.
import QtQuick
import QtQuick.Controls
import "../ui"
import "../js/Apps.js" as Apps

Item {
    id: bar
    height: UI.taskbarHeight

    property bool startOpen: false
    signal startRequested()
    signal quickSettingsRequested()
    signal calendarRequested()

    readonly property var wm: UI.wm
    // only the current workspace's windows appear in the dock
    readonly property var windows: wm ? wm.windows.filter(function (w) { return w.workspace === wm.workspace }) : []
    property var pinned: loadPinned()
    readonly property var entries: buildEntries(pinned, windows)

    function loadPinned() {
        var p = Prefs.value("taskbar.pinned", Apps.defaultPinned)
        return UI.isList(p) ? UI.arr(p).filter(function (id) { return typeof id === "string" && Apps.get(id) !== null }) : Apps.defaultPinned
    }
    Connections {
        target: Prefs
        function onValueChanged(key) { if (key === "taskbar.pinned") bar.pinned = bar.loadPinned() }
    }

    function buildEntries(pins, wins) {
        var out = [], index = {}
        function entry(id) {
            if (index[id] === undefined) {
                var info = Apps.get(id)
                if (!info) return null
                index[id] = out.length
                out.push({ id: id, info: info, windows: [], pinned: pins.indexOf(id) >= 0 })
            }
            return out[index[id]]
        }
        for (var i = 0; i < pins.length; i++) entry(pins[i])
        for (var j = 0; j < wins.length; j++) {
            var e = entry(wins[j].appId)
            if (e) e.windows.push(wins[j])
        }
        return out
    }

    function togglePin(id) { wm.togglePin(id) }

    function activateEntry(entry, button) {
        var ws = entry.windows
        if (ws.length === 0) { wm.openApp(entry.id, {}); return }
        if (ws.length === 1) {
            var w = ws[0]
            if (w === wm.activeWindow && !w.minimized) wm.minimizeWindow(w)
            else wm.focusWindow(w)
            return
        }
        var items = ws.map(function (w) {
            return { text: w.title, icon: w.icon, action: function () { wm.focusWindow(w) } }
        })
        items.push({ separator: true })
        items.push({ text: "Close all " + ws.length + " windows", icon: "close", danger: true,
                     action: function () { ws.slice().forEach(function (w) { wm.closeWindow(w) }) } })
        menu.menuWidth = 280
        var h = items.length * UI.px(32) + 10
        menu.show(button, 0, -h - 10, items)
    }

    function entryMenu(entry, button) {
        var items = [
            { text: entry.info.name, icon: entry.info.icon, enabled: false },
            { separator: true },
            { text: "New window", icon: "plus", action: function () { wm.openApp(entry.id, {}) } },
            { text: entry.pinned ? "Unpin from taskbar" : "Pin to taskbar", icon: "pin",
              action: function () { bar.togglePin(entry.id) } }
        ]
        if (entry.windows.length > 0) {
            items.push({ separator: true })
            items.push({ text: entry.windows.length > 1 ? "Close all windows" : "Close window", icon: "close", danger: true,
                         action: function () { entry.windows.slice().forEach(function (w) { wm.closeWindow(w) }) } })
        }
        menu.menuWidth = 236
        var h = (items.length - 2) * UI.px(32) + 2 * 9 + 10
        menu.show(button, 0, -h - 10, items)
    }

    GMenu { id: menu }

    MouseArea {   // right-click the empty taskbar
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: function (mouse) {
            menu.menuWidth = 236
            menu.show(bar, mouse.x, -6 * UI.px(32) - 30, [
                { text: "Task Manager", icon: "activity", action: function () { bar.wm.openApp("TaskManager", {}) } },
                { text: "Clipboard history", icon: "paste", shortcut: "Ctrl+Alt+V", action: function () { bar.wm.openClipboard() } },
                { text: "Show desktop", icon: "monitor", shortcut: "Ctrl+Alt+D", action: function () { bar.wm.showDesktop() } },
                { text: "Refresh", icon: "refresh", action: function () { Storage.notifyChanged("/Desktop") } },
                { separator: true },
                { text: "Taskbar & personalization", icon: "settings", action: function () { bar.wm.openApp("Settings", { initialPage: "personalize" }) } },
                { text: "Keyboard shortcuts", icon: "keyboard", shortcut: "F1", action: function () { bar.wm.showShortcuts() } }
            ])
        }
    }

    GlassSurface {
        anchors.fill: parent
        radius: 0
        sceneX: bar.x
        sceneY: bar.y
        tint: Qt.rgba(0.05, 0.065, 0.1, 0.58)
        showBorder: false
    }
    Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: UI.border }

    // ---------------------------------------------------------------- weather
    MouseArea {
        id: weatherChip
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: weatherRow.implicitWidth + 20
        height: parent.height - 12
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        visible: WeatherService.hasData && bar.width > 820
        onClicked: wm.openApp("Weather", {})
        Rectangle { anchors.fill: parent; radius: UI.radius; color: weatherChip.containsMouse ? UI.hover : "transparent" }
        Row {
            id: weatherRow
            anchors.centerIn: parent
            spacing: 8
            Icon { name: WeatherService.current.icon || ""; size: UI.px(26); anchors.verticalCenter: parent.verticalCenter }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    text: {
                        var t = WeatherService.current.temp
                        if (t === undefined) return ""
                        return UI.temp(t)
                    }
                    color: UI.text; font.pixelSize: UI.px(12); font.weight: Font.DemiBold
                }
                Text { font.weight: UI.textWeight; text: WeatherService.current.condition || ""; color: UI.textDim; font.pixelSize: UI.px(11) }
            }
        }
    }

    // ------------------------------------------------------------ dock (center)
    Row {
        id: dock
        anchors.centerIn: parent
        spacing: 4

        // Start
        AbstractButton {
            id: startButton
            width: UI.px(44); height: UI.px(44)
            hoverEnabled: true
            onClicked: bar.startRequested()
            background: Rectangle {
                radius: UI.radius
                color: startButton.down || bar.startOpen ? UI.pressed : (startButton.hovered ? UI.hover : "transparent")
            }
            contentItem: Item {
                Grid {
                    anchors.centerIn: parent
                    columns: 2; spacing: 2.5
                    scale: startButton.down ? 0.86 : 1
                    Behavior on scale { NumberAnimation { duration: UI.dur(90) } }
                    Repeater {
                        model: 4
                        Rectangle {
                            width: UI.px(9); height: UI.px(9); radius: 2.5
                            gradient: Gradient {
                                GradientStop { position: 0; color: Qt.lighter(UI.accent, 1.35) }
                                GradientStop { position: 1; color: UI.accent }
                            }
                            opacity: index === 3 ? 0.75 : 1
                        }
                    }
                }
            }
            GTip { text: "Start  (Ctrl+Space)"; visible: startButton.hovered }
        }

        Repeater {
            model: bar.entries
            delegate: AbstractButton {
                id: appButton
                width: UI.px(44); height: UI.px(44)
                hoverEnabled: true
                readonly property var entry: modelData
                readonly property bool running: entry.windows.length > 0
                readonly property bool focused: {
                    for (var i = 0; i < entry.windows.length; i++)
                        if (entry.windows[i].active && !entry.windows[i].minimized) return true
                    return false
                }

                background: Rectangle {
                    radius: UI.radius
                    // running apps get a visible tile; the focused one is highlighted in the accent color
                    color: appButton.down ? UI.pressed
                         : appButton.focused ? UI.accentSoft
                         : appButton.running ? (appButton.hovered ? UI.cardStrong : UI.card)
                         : (appButton.hovered ? UI.hover : "transparent")
                    border.width: appButton.running ? 1 : 0
                    border.color: appButton.focused ? UI.alpha(UI.accent, 0.55) : UI.border
                }
                contentItem: Item {
                    Icon {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -1
                        name: appButton.entry.info.icon
                        size: UI.px(28)
                        scale: appButton.down ? 0.84 : 1
                        Behavior on scale { NumberAnimation { duration: UI.dur(110); easing.type: Easing.OutBack } }
                    }
                }
                Rectangle {   // running indicator
                    z: 5
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 1
                    height: 3; radius: 1.5
                    width: appButton.focused ? UI.px(20) : UI.px(8)
                    visible: appButton.running
                    color: appButton.focused ? UI.accent : Qt.rgba(1, 1, 1, 0.75)
                    Behavior on width { NumberAnimation { duration: UI.dur(160); easing.type: Easing.OutCubic } }
                }
                Rectangle {   // window count badge
                    // z: a Control stacks its contentItem (the icon) above plain children,
                    // so without this the badge was hidden behind the icon
                    z: 5
                    visible: appButton.entry.windows.length > 1
                    anchors.right: parent.right; anchors.top: parent.top
                    anchors.rightMargin: 1; anchors.topMargin: 1
                    width: UI.px(16); height: width; radius: width / 2
                    color: UI.accent
                    border.width: 2
                    border.color: Qt.rgba(0.06, 0.08, 0.11, 0.95)   // dark ring separates it from the icon
                    Text {
                        anchors.centerIn: parent
                        text: appButton.entry.windows.length
                        color: UI.accentText; font.pixelSize: UI.px(9); font.bold: true
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton | Qt.MiddleButton
                    onClicked: function (mouse) {
                        if (mouse.button === Qt.MiddleButton) bar.wm.openApp(appButton.entry.id, {})
                        else bar.entryMenu(appButton.entry, appButton)
                    }
                }
                onClicked: bar.activateEntry(entry, appButton)
                GTip {
                    visible: appButton.hovered && !menu.opened
                    text: appButton.entry.windows.length === 1 ? appButton.entry.windows[0].title : appButton.entry.info.name
                }
            }
        }
    }

    // ------------------------------------------------------------- tray (right)
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        spacing: 2

        Row {   // workspace switcher
            id: workspaces
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            rightPadding: 6
            Repeater {
                model: bar.wm ? bar.wm.workspaceCount : 0
                delegate: MouseArea {
                    id: ws
                    width: UI.px(22); height: UI.px(28)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    readonly property bool current: bar.wm.workspace === index
                    readonly property int count: { var n = bar.wm.windows.length; return bar.wm.workspaceWindowCount(index) }
                    onClicked: bar.wm.switchWorkspace(index)
                    onWheel: function (wheel) { bar.wm.switchWorkspace(bar.wm.workspace + (wheel.angleDelta.y < 0 ? 1 : -1)) }
                    Rectangle {
                        anchors.centerIn: parent
                        width: UI.px(18); height: UI.px(18)
                        radius: 5
                        color: ws.current ? UI.accent : (ws.containsMouse ? UI.hover : "transparent")
                        border.color: ws.current ? "transparent" : (ws.count > 0 ? UI.borderStrong : UI.border)
                        Text {
                            anchors.centerIn: parent
                            text: index + 1
                            color: ws.current ? UI.accentText : (ws.count > 0 ? UI.text : UI.textFaint)
                            font.pixelSize: UI.px(10)
                            font.bold: ws.current
                        }
                    }
                    GTip { text: "Workspace " + (index + 1) + (ws.count ? "  ·  " + ws.count + " window" + (ws.count > 1 ? "s" : "") : "") + "  (Ctrl+Alt+" + (index + 1) + ")"; visible: ws.containsMouse }
                }
            }
        }

        MouseArea {
            id: trayIcons
            width: trayRow.implicitWidth + 18
            height: parent.height - 12
            anchors.verticalCenter: parent.verticalCenter
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: bar.quickSettingsRequested()
            onWheel: function (wheel) {
                Prefs.setVolume(Prefs.volume + (wheel.angleDelta.y > 0 ? 5 : -5))
                Prefs.setMuted(false)
            }
            Rectangle { anchors.fill: parent; radius: UI.radius; color: trayIcons.containsMouse ? UI.hover : "transparent" }
            Row {
                id: trayRow
                anchors.centerIn: parent
                spacing: 10
                Icon {   // background file transfer in progress
                    visible: Storage.busy
                    name: "refresh"
                    size: UI.px(15)
                    anchors.verticalCenter: parent.verticalCenter
                    RotationAnimation on rotation { running: Storage.busy; from: 0; to: 360; duration: 1000; loops: Animation.Infinite }
                }
                Row {
                    id: cpuReadout
                    spacing: 3
                    visible: System.hasStats
                    anchors.verticalCenter: parent.verticalCenter
                    Icon { name: "cpu"; size: UI.px(13); opacity: 0.75; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        font.weight: UI.textWeight
                        text: Math.round(System.cpuPercent) + "%"
                        color: System.cpuPercent > 80 ? UI.warning : UI.textDim
                        font.pixelSize: UI.px(11)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    HoverHandler { id: cpuHover }
                    GTip { text: "CPU usage: " + Math.round(System.cpuPercent) + "%  ·  click for Task Manager"; visible: cpuHover.hovered }
                    TapHandler { onTapped: UI.wm.openApp("TaskManager", {}) }
                }
                Icon { name: "wifi"; size: UI.px(13); anchors.verticalCenter: parent.verticalCenter }
                Icon {
                    name: Prefs.muted || Prefs.volume === 0 ? "mute" : (Prefs.volume < 50 ? "volume-low" : "volume")
                    size: UI.px(17)
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            GTip { text: "Quick settings  ·  scroll to change volume (" + Prefs.volume + "%)"; visible: trayIcons.containsMouse }
        }

        MouseArea {
            id: clock
            width: clockCol.implicitWidth + 20
            height: parent.height - 12
            anchors.verticalCenter: parent.verticalCenter
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: bar.calendarRequested()
            Rectangle { anchors.fill: parent; radius: UI.radius; color: clock.containsMouse ? UI.hover : "transparent" }
            Column {
                id: clockCol
                anchors.centerIn: parent
                Text {
                    elide: Text.ElideRight
                    anchors.right: parent.right
                    text: UI.timeText(UI.now)
                    color: UI.text; font.pixelSize: UI.px(12); font.weight: Font.Medium
                }
                Text {
                    elide: Text.ElideRight
                    font.weight: UI.textWeight
                    anchors.right: parent.right
                    text: Qt.formatDate(UI.now, "d MMM yyyy")
                    color: UI.textDim; font.pixelSize: UI.px(11)
                }
            }
            Rectangle {
                visible: bar.wm && bar.wm.unreadCount > 0
                anchors.right: parent.right; anchors.top: parent.top
                anchors.margins: 3
                width: 8; height: 8; radius: 4
                color: UI.accent
            }
        }

        MouseArea {   // show desktop sliver
            id: showDesk
            width: 10
            height: parent.height
            hoverEnabled: true
            onClicked: bar.wm.showDesktop()
            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 12; anchors.bottomMargin: 12
                radius: 2
                color: showDesk.containsMouse ? UI.hover : "transparent"
                Rectangle { anchors.left: parent.left; width: 1; height: parent.height; color: UI.border }
            }
            GTip { text: "Show desktop  (Ctrl+Alt+D)"; visible: showDesk.containsMouse }
        }
    }
}
