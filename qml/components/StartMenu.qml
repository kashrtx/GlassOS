import QtQuick
import QtQuick.Controls
import "../ui"
import "../js/Apps.js" as Apps

Popup {
    id: start
    parent: Overlay.overlay
    width: Math.min(UI.px(640), parent ? parent.width - 20 : 640)
    height: Math.min(UI.px(640), parent ? parent.height - UI.taskbarHeight - 30 : 640)
    x: parent ? Math.round((parent.width - width) / 2) : 0
    // slide-in offset: animating y directly would replace this binding with a fixed number,
    // so a popup that grows after opening (e.g. notifications) would hang off the screen
    property real slide: 0
    y: (parent ? parent.height - UI.taskbarHeight - height - 10 : 0) + slide
    padding: 0
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    property double closedAt: 0      // lets the taskbar button toggle without instantly reopening
    onClosed: closedAt = Date.now()

    readonly property var wm: UI.wm
    property string query: ""
    property var results: []
    property int selected: 0
    property var recent: []
    property bool allApps: false

    // "All apps": alphabetical rows with a letter header before each new initial
    function alphabetical() {
        var apps = Apps.list.slice().sort(function (x, y) { return x.name.localeCompare(y.name) })
        var out = [], last = ""
        apps.forEach(function (a) {
            var l = a.name.charAt(0).toUpperCase()
            if (l !== last) { out.push({ header: true, letter: l }); last = l }
            out.push({ app: a })
        })
        return out
    }
    function recentWhen(p) {
        var info = Storage.quickInfo(p)
        var folder = Storage.parentOf(p)
        return (info.modified ? UI.fmtDate(info.modified) + "  ·  " : "") + (folder === "/" ? "Home" : folder.split("/").pop())
    }

    onOpened: {
        search.text = ""
        query = ""
        allApps = false
        recent = UI.arr(Prefs.value("recent.files", [])).filter(function (p) { return typeof p === "string" && Storage.exists(p) }).slice(0, 6)
        search.forceActiveFocus()
    }

    // Search touches the disk, so wait for a short pause in typing.
    onQueryChanged: searchDebounce.restart()
    Timer { id: searchDebounce; interval: 120; onTriggered: { start.rebuild(); start.selected = 0 } }

    function rebuild() {
        var q = query.trim()
        if (q === "") { results = []; return }
        var out = []
        if (Calc.looksLikeMath(q)) {
            var r = Calc.evaluate(q, true, "0")
            if (r.ok) out.push({ kind: "calc", icon: "calculator", title: "= " + r.value, subtitle: "Press Enter to copy into Calculator", value: q })
        }
        Apps.search(q).forEach(function (a) {
            out.push({ kind: "app", icon: a.icon, title: a.name, subtitle: a.desc, id: a.id })
        })
        Storage.search(q, "/", 8).forEach(function (f) {
            out.push({ kind: "file", icon: f.icon, title: f.name, subtitle: Storage.parentOf(f.path), path: f.path })
        })
        if (HasWebEngine) out.push({ kind: "web", icon: "search", title: "Search the web for “" + q + "”", subtitle: "AeroBrowser", value: q })
        results = out
    }

    function launch(r) {
        close()
        if (r.kind === "app") wm.openApp(r.id, {})
        else if (r.kind === "file") wm.openPath(r.path)
        else if (r.kind === "calc") wm.openApp("Calculator", { initialExpression: r.value })
        else if (r.kind === "web") wm.openApp("AeroBrowser", { initialUrl: "https://duckduckgo.com/?q=" + encodeURIComponent(r.value) })
    }

    function launchApp(id) { close(); wm.openApp(id, {}) }

    function tileMenu(app, item, mx, my) {
        tileActions.show(item, mx, my, [
            { text: "Open", icon: app.icon, action: function () { start.launchApp(app.id) } },
            { separator: true },
            { text: wm.isPinned(app.id) ? "Unpin from taskbar" : "Pin to taskbar", icon: "pin", action: function () { wm.togglePin(app.id) } },
            { text: wm.isOnDesktop(app.id) ? "Remove from desktop" : "Add to desktop", icon: "monitor", action: function () { wm.toggleDesktopApp(app.id) } }
        ])
    }

    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: UI.dur(150) }
            NumberAnimation { property: "slide"; from: 30; to: 0; duration: UI.dur(220); easing.type: Easing.OutCubic }
        }
    }
    exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: UI.dur(100) } }

    background: GlassSurface {
        sceneX: start.x
        sceneY: start.y
        radius: UI.radiusLarge
        borderColor: UI.borderStrong
    }

    contentItem: Item {
        // -------------------------------------------------------- search
        GTextField {
            id: search
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 22
            height: UI.px(40)
            radiusOverride: 20
            leading: "search"
            placeholderText: "Search apps, files, or type a calculation…"
            onTextChanged: start.query = text
            Keys.onDownPressed: start.selected = Math.min(start.selected + 1, start.results.length - 1)
            Keys.onUpPressed: start.selected = Math.max(start.selected - 1, 0)
            onAccepted: {
                if (searchDebounce.running) { searchDebounce.stop(); start.rebuild() }   // Enter before the debounce fired
                if (start.results.length > 0) start.launch(start.results[Math.min(start.selected, start.results.length - 1)])
            }
        }

        // -------------------------------------------------------- results
        ListView {
            id: resultList
            visible: start.query.trim() !== ""
            anchors.top: search.bottom
            anchors.topMargin: 14
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: footer.top
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            clip: true
            model: start.results
            currentIndex: start.selected
            ScrollBar.vertical: GScrollBar {}
            delegate: Rectangle {
                width: resultList.width
                height: UI.px(52)
                radius: UI.radius
                color: index === start.selected ? UI.accentFaint : (rowMouse.containsMouse ? UI.hover : "transparent")
                border.width: index === start.selected ? 1 : 0
                border.color: UI.alpha(UI.accent, 0.35)
                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12
                    Icon { name: modelData.icon; size: UI.px(22); anchors.verticalCenter: parent.verticalCenter }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            text: modelData.title
                            color: UI.text
                            font.pixelSize: UI.px(modelData.kind === "calc" ? 17 : 13)
                            font.weight: modelData.kind === "calc" ? Font.DemiBold : Font.Normal
                            width: resultList.width - 90
                            elide: Text.ElideRight
                        }
                        Text {
                            font.weight: UI.textWeight
                            text: modelData.subtitle
                            color: UI.textFaint
                            font.pixelSize: UI.px(11)
                            width: resultList.width - 90
                            elide: Text.ElideMiddle
                        }
                    }
                }
                Text {
                    elide: Text.ElideRight
                    font.weight: UI.textWeight
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: ({ app: "App", file: "File", calc: "Answer", web: "Web" })[modelData.kind]
                    color: UI.textFaint
                    font.pixelSize: UI.px(11)
                }
                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: start.launch(modelData)
                }
            }
            Text {
                font.weight: UI.textWeight
                visible: start.results.length === 0
                anchors.centerIn: parent
                text: "No results for “" + start.query + "”"
                color: UI.textFaint
                font.pixelSize: UI.px(13)
            }
        }

        // -------------------------------------------------------- home (Pinned / All apps + Recommended)
        Flickable {
            id: home
            visible: start.query.trim() === ""
            anchors.top: search.bottom
            anchors.topMargin: 18
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: footer.top
            anchors.leftMargin: 26
            anchors.rightMargin: 26
            clip: true
            contentHeight: homeCol.implicitHeight + 12
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: GScrollBar {}

            Column {
                id: homeCol
                width: home.width
                spacing: 8

                // section header: "Pinned" + All apps  /  "All apps" + Back
                Item {
                    width: parent.width
                    height: UI.px(32)
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        text: start.allApps ? "All apps" : "Pinned"
                        color: UI.text; font.pixelSize: UI.px(14); font.weight: Font.DemiBold
                    }
                    GButton {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        kind: "flat"
                        text: start.allApps ? "Back" : "All apps  ›"
                        iconName: start.allApps ? "chevron-left" : ""
                        onClicked: { start.allApps = !start.allApps; home.contentY = 0 }
                    }
                }

                // ---- pinned grid: the app icons as designed (no tinted tile behind them)
                Grid {
                    id: grid
                    visible: !start.allApps
                    columns: 6
                    width: parent.width
                    readonly property real cell: width / columns
                    Repeater {
                        model: Apps.list
                        delegate: MouseArea {
                            id: tile
                            width: grid.cell
                            height: UI.px(90)
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: function (mouse) {
                                if (mouse.button === Qt.RightButton) start.tileMenu(modelData, tile, mouse.x, mouse.y)
                                else start.launchApp(modelData.id)
                            }
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 3
                                radius: UI.radius
                                color: tile.pressed ? UI.pressed : (tile.containsMouse ? UI.hover : "transparent")
                                Behavior on color { ColorAnimation { duration: UI.dur(90) } }
                            }
                            Column {
                                anchors.centerIn: parent
                                spacing: 8
                                Icon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    name: modelData.icon
                                    size: UI.px(42)
                                    scale: tile.pressed ? 0.92 : (tile.containsMouse ? 1.06 : 1)
                                    Behavior on scale { NumberAnimation { duration: UI.dur(120); easing.type: Easing.OutBack } }
                                }
                                Text {
                                    font.weight: UI.textWeight
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.name
                                    color: UI.text
                                    font.pixelSize: UI.px(11.5)
                                    width: grid.cell - 8
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                }
                            }
                            GTip { text: modelData.desc; visible: tile.containsMouse }
                        }
                    }
                }

                // ---- all apps: alphabetical, with letter headers
                Column {
                    visible: start.allApps
                    width: parent.width
                    spacing: 2
                    Repeater {
                        model: start.allApps ? start.alphabetical() : []
                        delegate: Item {
                            width: parent.width
                            height: modelData.header ? UI.px(30) : UI.px(46)
                            Text {
                                visible: modelData.header === true
                                anchors.left: parent.left; anchors.leftMargin: 10
                                anchors.bottom: parent.bottom; anchors.bottomMargin: 4
                                text: modelData.letter || ""
                                color: UI.accent; font.pixelSize: UI.px(12); font.weight: Font.DemiBold
                            }
                            MouseArea {
                                id: appRow
                                visible: modelData.header !== true
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: function (mouse) {
                                    if (mouse.button === Qt.RightButton) start.tileMenu(modelData.app, appRow, mouse.x, mouse.y)
                                    else start.launchApp(modelData.app.id)
                                }
                                Rectangle { anchors.fill: parent; radius: UI.radius; color: appRow.containsMouse ? UI.hover : "transparent" }
                                Row {
                                    anchors.left: parent.left; anchors.leftMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 12
                                    Icon { name: modelData.app ? modelData.app.icon : ""; size: UI.px(30); anchors.verticalCenter: parent.verticalCenter }
                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        Text { font.weight: UI.textWeight; text: modelData.app ? modelData.app.name : ""; color: UI.text; font.pixelSize: UI.px(12.5) }
                                        Text { font.weight: UI.textWeight; text: modelData.app ? modelData.app.desc : ""; color: UI.textFaint; font.pixelSize: UI.px(10.5); width: homeCol.width - UI.px(70); elide: Text.ElideRight }
                                    }
                                }
                            }
                        }
                    }
                }

                // ---- recommended: recent files (fills the space instead of leaving a void)
                Item { visible: !start.allApps; width: 1; height: UI.px(10) }
                Text {
                    visible: !start.allApps
                    leftPadding: 4
                    text: "Recommended"
                    color: UI.text; font.pixelSize: UI.px(14); font.weight: Font.DemiBold
                }
                Grid {
                    visible: !start.allApps && start.recent.length > 0
                    columns: 2
                    width: parent.width
                    Repeater {
                        model: start.recent
                        delegate: MouseArea {
                            id: rec
                            width: home.width / 2
                            height: UI.px(54)
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { start.close(); start.wm.openPath(modelData) }
                            Rectangle { anchors.fill: parent; anchors.margins: 2; radius: UI.radius; color: rec.containsMouse ? UI.hover : "transparent" }
                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 12
                                Icon { name: Storage.iconFor(modelData); size: UI.px(32); anchors.verticalCenter: parent.verticalCenter }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text {
                                        font.weight: UI.textWeight
                                        text: modelData.split("/").pop()
                                        color: UI.text; font.pixelSize: UI.px(12)
                                        width: home.width / 2 - UI.px(70); elide: Text.ElideMiddle
                                    }
                                    Text {
                                        font.weight: UI.textWeight
                                        text: start.recentWhen(modelData)
                                        color: UI.textFaint; font.pixelSize: UI.px(10.5)
                                        width: home.width / 2 - UI.px(70); elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }
                Rectangle {   // nothing recent yet: a friendly placeholder instead of empty space
                    visible: !start.allApps && start.recent.length === 0
                    width: parent.width
                    height: UI.px(86)
                    radius: UI.radiusLarge
                    color: Qt.rgba(1, 1, 1, 0.035)
                    border.color: UI.border
                    Row {
                        anchors.centerIn: parent
                        spacing: 14
                        Icon { name: "sparkles"; size: UI.px(26); opacity: 0.8; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Text { font.weight: UI.textWeight; text: "Your recent files will show up here"; color: UI.text; font.pixelSize: UI.px(12.5) }
                            Text { font.weight: UI.textWeight; text: "Open a document, photo or song to get started"; color: UI.textFaint; font.pixelSize: UI.px(11) }
                        }
                    }
                }
            }
        }

        // -------------------------------------------------------- footer (seamless: same glass, soft inset divider)
        Item {
            id: footer
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: UI.px(64)
            Rectangle {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 48
                height: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 0.15; color: UI.border }
                    GradientStop { position: 0.85; color: UI.border }
                    GradientStop { position: 1; color: "transparent" }
                }
            }

            MouseArea {
                id: userArea
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                width: userRow.implicitWidth + 20
                height: UI.px(46)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: start.launchApp("Settings")
                Rectangle { anchors.fill: parent; radius: height / 2; color: userArea.containsMouse ? UI.hover : "transparent" }
                Row {
                    id: userRow
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    Rectangle {
                        width: UI.px(32); height: width; radius: width / 2
                        gradient: Gradient {
                            GradientStop { position: 0; color: Qt.lighter(UI.accent, 1.3) }
                            GradientStop { position: 1; color: Qt.darker(UI.accent, 1.4) }
                        }
                        Text {
                            anchors.centerIn: parent
                            text: Prefs.userName.charAt(0).toUpperCase()
                            color: "white"; font.pixelSize: UI.px(14); font.bold: true
                        }
                    }
                    Text {
                        font.weight: UI.textWeight
                        text: Prefs.userName
                        color: UI.text; font.pixelSize: UI.px(13)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                GTip { text: "Account & settings"; visible: userArea.containsMouse }
            }

            IconButton {
                id: powerButton
                anchors.right: parent.right
                anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                iconName: "power"; size: 40; glyphSize: 17; tip: "Power"
                onClicked: powerMenu.show(powerButton, 0, -5 * UI.px(32) - 30, [
                    { text: "Keyboard shortcuts", icon: "keyboard", shortcut: "F1", action: function () { start.close(); start.wm.showShortcuts() } },
                    { text: "Lock", icon: "lock", shortcut: "Ctrl+Alt+L", action: function () { start.close(); start.wm.lock() } },
                    { text: "Restart GlassOS", icon: "refresh", action: function () { start.close(); start.wm.requestPower("restart") } },
                    { separator: true },
                    { text: "Shut down", icon: "power", shortcut: "Ctrl+Q", danger: true, action: function () { start.close(); start.wm.requestPower("shutdown") } }
                ])
            }
        }
    }

    GMenu { id: powerMenu; menuWidth: 220 }
    GMenu { id: tileActions; menuWidth: 230 }
}
