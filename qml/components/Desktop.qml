// The desktop: icons on a snapping grid (positions persisted), rubber-band
// selection, keyboard shortcuts, context menus, and drag & drop using the
// window manager's shared drag engine (see Main.qml "file drag & drop"):
//   * drag icons to rearrange them, onto folders / the Recycle Bin, or into any window
//   * drop files here from Files windows or straight from your computer's file manager
import QtQuick
import QtQuick.Controls
import "../ui"
import "../js/Apps.js" as Apps

FocusScope {
    id: desk

    readonly property var wm: UI.wm
    readonly property real cellW: UI.px(92)
    readonly property real cellH: UI.px(100)
    readonly property real margin: 10
    readonly property int rows: Math.max(1, Math.floor((height - margin * 2) / cellH))
    readonly property int cols: Math.max(1, Math.floor((width - margin * 2) / cellW))

    property var icons: []
    property var selected: ({})          // key -> true
    property var layout: UI.obj(Prefs.value("desktop.layout", {}))
    readonly property var cutSet: {
        var m = {}
        if (Storage.clipboardMode === "cut") Storage.clipboardPaths.forEach(function (p) { m[p] = true })
        return m
    }

    Component.onCompleted: refresh()
    onRowsChanged: refresh()
    onColsChanged: refresh()

    Connections {
        target: Storage
        function onChanged(dir) { if (dir === "/Desktop") desk.refresh() }
    }
    Connections {
        target: Prefs
        function onValueChanged(key) {
            if (key === "desktop.apps") desk.refresh()
            else if (key === "desktop.layout") {
                var l = UI.obj(Prefs.value("desktop.layout", {}))
                if (JSON.stringify(l) !== JSON.stringify(desk.layout)) { desk.layout = l; desk.refresh() }
            }
        }
    }

    // ------------------------------------------------------------ model
    function refresh() {
        var list = [
            { key: "sys:pc", name: "This PC", icon: "place-pc", kind: "system", app: "AeroExplorer", props: { initialPath: "/" } },
            { key: "sys:trash", name: "Recycle Bin", icon: "place-trash", kind: "trash", app: "AeroExplorer", props: { initialPath: "/Recycle Bin" } }
        ]
        var apps = wm ? wm.desktopApps() : []
        for (var a = 0; a < apps.length; a++) {
            var info = Apps.get(apps[a])
            list.push({ key: "app:" + info.id, name: info.name, icon: info.icon, kind: "app", app: info.id, props: {} })
        }
        var files = Storage.list("/Desktop")
        for (var i = 0; i < files.length; i++) {
            var f = files[i]
            list.push({ key: "file:" + f.name, name: f.name, icon: f.icon, kind: f.kind, path: f.path, isDir: f.isDir })
        }
        // saved cell if it's on screen and free, otherwise the next free cell (column-major)
        var used = {}
        var pending = []
        for (var j = 0; j < list.length; j++) {
            var saved = layout[list[j].key]
            saved = UI.arr(saved)
            if (saved.length === 2 && saved[0] >= 0 && saved[1] >= 0
                    && saved[0] < cols && saved[1] < rows && !used[saved[0] + "," + saved[1]]) {
                list[j].col = saved[0]; list[j].row = saved[1]
                used[saved[0] + "," + saved[1]] = true
            } else pending.push(list[j])
        }
        var c = 0, r = 0
        for (var k = 0; k < pending.length; k++) {
            while (used[c + "," + r] && c < cols) { r++; if (r >= rows) { r = 0; c++ } }
            pending[k].col = Math.min(c, cols - 1); pending[k].row = r
            used[c + "," + r] = true
        }
        var keep = {}
        for (var m = 0; m < list.length; m++) if (selected[list[m].key]) keep[list[m].key] = true
        selected = keep
        icons = list
    }

    function saveCell(key, col, row) {
        var l = Object.assign({}, layout)
        l[key] = [col, row]
        layout = l
        Prefs.setValue("desktop.layout", l)
    }
    function cellAt(x, y) {
        return [Math.max(0, Math.min(cols - 1, Math.floor((x - margin) / cellW))),
                Math.max(0, Math.min(rows - 1, Math.floor((y - margin) / cellH)))]
    }
    function iconAtCell(col, row, exceptKey) {
        for (var i = 0; i < icons.length; i++)
            if (icons[i].col === col && icons[i].row === row && icons[i].key !== exceptKey) return icons[i]
        return null
    }
    function freeCellNear(col, row, exceptKey) {
        for (var d = 0; d < Math.max(cols, rows); d++)
            for (var dc = -d; dc <= d; dc++)
                for (var dr = -d; dr <= d; dr++) {
                    var c = col + dc, r = row + dr
                    if (c < 0 || r < 0 || c >= cols || r >= rows) continue
                    if (!iconAtCell(c, r, exceptKey)) return [c, r]
                }
        return [col, row]
    }

    // ------------------------------------------------------------ selection
    function selectedIcons() { return icons.filter(function (i) { return selected[i.key] }) }
    function selectedPaths() { return selectedIcons().filter(function (i) { return !!i.path }).map(function (i) { return i.path }) }
    function select(key, additive) {
        var s = additive ? Object.assign({}, selected) : {}
        if (additive && s[key]) delete s[key]; else s[key] = true
        selected = s
    }
    function clearSelection() { selected = {} }
    function selectAll() { var s = {}; icons.forEach(function (i) { s[i.key] = true }); selected = s }

    // ------------------------------------------------------------ actions
    function open(ic) {
        if (ic.app) wm.openApp(ic.app, ic.props || {})
        else if (ic.path) wm.openPath(ic.path)
    }
    function trashSelection() {
        var paths = selectedPaths()
        if (paths.length) wm.transferFiles(paths, "/Recycle Bin", false)
        selectedIcons().forEach(function (i) { if (i.kind === "app") wm.toggleDesktopApp(i.app) })
    }
    function rename(ic) {
        if (!ic.path) return
        dialog.ask({ title: "Rename", input: true, text: ic.name, selectStem: !ic.isDir,
                     buttons: [{ text: "Cancel", value: "cancel" }, { text: "Rename", value: "ok", kind: "primary" }] },
                   function (v, text) {
                       if (v !== "ok" || text === ic.name) return
                       if (!Storage.isValidName(text)) { wm.notify("Can't rename", "That name isn't allowed.", "warning-color"); return }
                       var pos = layout[ic.key]
                       if (Storage.rename(ic.path, text)) { if (UI.isList(pos)) saveCell("file:" + text, pos[0], pos[1]) }
                       else wm.notify("Can't rename", "An item called “" + text + "” already exists.", "warning-color")
                   })
    }
    function newItem(folder, col, row) {
        var p = folder ? Storage.createFolder("/Desktop", "New folder") : Storage.createFile("/Desktop", "New text document.txt")
        if (!p) { wm.notify("Couldn't create the item", "", "warning-color"); return }
        var name = p.split("/").pop()
        var cell = freeCellNear(col, row, "")
        saveCell("file:" + name, cell[0], cell[1])
        refresh()
        var ic = icons.filter(function (i) { return i.key === "file:" + name })[0]
        if (ic) { selected = {}; select(ic.key, false); rename(ic) }
    }

    function iconMenu(ic, item, mx, my) {
        if (!selected[ic.key]) select(ic.key, false)
        var items = [{ text: "Open", icon: "folder-open", shortcut: "Enter", action: function () { desk.open(ic) } }]
        if (ic.kind === "trash") {
            items.push({ separator: true })
            items.push({ text: "Empty Recycle Bin", icon: "broom", danger: true, enabled: Storage.trashCount > 0,
                         action: function () { var n = Storage.emptyTrash(); wm.notify("Recycle Bin emptied", n + " item(s) deleted", "broom") } })
        } else if (ic.kind === "app") {
            items.push({ text: wm.isPinned(ic.app) ? "Unpin from taskbar" : "Pin to taskbar", icon: "pin", action: function () { wm.togglePin(ic.app) } })
            items.push({ separator: true })
            items.push({ text: "Remove from desktop", icon: "close", danger: true, action: function () { wm.toggleDesktopApp(ic.app) } })
        } else if (ic.path) {
            if (!ic.isDir && ic.kind === "image")
                items.push({ text: "Set as wallpaper", icon: "image", action: function () { Prefs.setWallpaper(ic.path) } })
            if (!ic.isDir) items.push({ text: "Edit in GlassPad", icon: "edit", action: function () { wm.openApp("GlassPad", { filePath: ic.path }) } })
            items.push({ separator: true })
            items.push({ text: "Cut", icon: "cut", shortcut: "Ctrl+X", action: function () { Storage.cut(desk.selectedPaths()) } })
            items.push({ text: "Copy", icon: "paste", shortcut: "Ctrl+C", action: function () { Storage.copy(desk.selectedPaths()) } })
            items.push({ text: "Rename", icon: "edit", shortcut: "F2", action: function () { desk.rename(ic) } })
            if (!ic.isDir && Storage.canExtract(ic.path))
                items.push({ text: "Extract here", icon: "file-archive", action: function () { Storage.startTransfer("extract", [ic.path], "/Desktop") } })
            items.push({ text: "Compress to ZIP", icon: "file-archive", action: function () { Storage.startTransfer("compress", desk.selectedPaths(), "/Desktop") } })
            items.push({ text: "Export to computer…", icon: "export", action: function () { wm.openExportDialog(desk.selectedPaths()) } })
            items.push({ separator: true })
            items.push({ text: "Delete", icon: "trash", shortcut: "Del", danger: true, action: desk.trashSelection })
        }
        menu.show(item, mx, my, items)
    }

    function appShortcutMenu(mx, my) {
        var items = Apps.list.map(function (a) {
            var on = wm.isOnDesktop(a.id)
            return { text: a.name + (on ? "  (on desktop)" : ""), icon: on ? "check" : a.icon, action: function () { wm.toggleDesktopApp(a.id) } }
        })
        menu.show(desk, mx, my, items)
    }

    function backgroundMenu(mx, my) {
        var cell = cellAt(mx, my)
        menu.show(desk, mx, my, [
            { text: "New folder", icon: "folder", action: function () { desk.newItem(true, cell[0], cell[1]) } },
            { text: "New text document", icon: "edit", action: function () { desk.newItem(false, cell[0], cell[1]) } },
            { text: "Add app shortcut…", icon: "plus", action: function () { desk.appShortcutMenu(mx, my) } },
            { text: "Import files from computer…", icon: "import", action: function () { wm.openImportDialog("/Desktop") } },
            { text: "Paste", icon: "paste", shortcut: "Ctrl+V", enabled: wm.canPaste(), action: function () { wm.pasteInto("/Desktop") } },
            { separator: true },
            { text: "Open Terminal here", icon: "terminal", action: function () { wm.openApp("Terminal", { initialCwd: "/Desktop" }) } },
            { text: "Open in Files", icon: "folder", action: function () { wm.openApp("AeroExplorer", { initialPath: "/Desktop" }) } },
            { text: "Refresh", icon: "refresh", shortcut: "F5", action: function () { desk.refresh() } },
            { text: "Next wallpaper", icon: "palette", action: function () { wm.cycleWallpaper() } },
            { text: "Tidy up icons", icon: "sparkles", action: function () { desk.layout = ({}); Prefs.setValue("desktop.layout", {}); desk.refresh() } },
            { separator: true },
            { text: "Personalize", icon: "settings", action: function () { wm.openApp("Settings", { initialPage: "personalize" }) } }
        ])
    }

    // Start dragging the pressed icon (plus the rest of the selection when it's selected).
    function startDrag(ic, x, y) {
        if (!selected[ic.key]) select(ic.key, false)
        var paths = ic.path ? selectedPaths() : []
        wm.beginFileDrag({ paths: paths, sourceDir: "/Desktop", sourceKey: ic.key, icon: ic.icon, x: x, y: y,
                           label: paths.length > 1 ? paths.length + " items" : ic.name })
    }

    Keys.onPressed: function (event) {
        var sel = selectedIcons()
        if (event.key === Qt.Key_Delete) { trashSelection(); event.accepted = true }
        else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && sel.length) { sel.forEach(open); event.accepted = true }
        else if (event.key === Qt.Key_F2 && sel.length === 1) { rename(sel[0]); event.accepted = true }
        else if (event.key === Qt.Key_F5) { refresh(); event.accepted = true }
        else if (event.modifiers & Qt.ControlModifier) {
            if (event.key === Qt.Key_A) { selectAll(); event.accepted = true }
            else if (event.key === Qt.Key_C) { Storage.copy(selectedPaths()); event.accepted = true }
            else if (event.key === Qt.Key_X) { Storage.cut(selectedPaths()); event.accepted = true }
            else if (event.key === Qt.Key_V) { wm.pasteInto("/Desktop"); event.accepted = true }
        }
    }

    // ------------------------------------------------------------ drop target (empty desktop)
    DropArea {
        id: deskDrop
        anchors.fill: parent
        property var hoverCell: null
        onEntered: function (drag) {
            var fromDesktop = desk.wm.isFileDrag(drag) && desk.wm.fileDrag.sourceKey !== ""
            drag.accepted = fromDesktop || desk.wm.canDropOn(drag, "/Desktop")
            desk.wm.setDropTarget(fromDesktop && !desk.wm.fileDrag.copy ? "" : "Desktop")
        }
        onPositionChanged: function (drag) { hoverCell = desk.cellAt(drag.x, drag.y) }
        onExited: { hoverCell = null; desk.wm.setDropTarget("") }
        onDropped: function (drop) {
            hoverCell = null
            var cell = desk.cellAt(drop.x, drop.y)
            var fd = desk.wm.fileDrag
            if (desk.wm.isFileDrag(drop) && fd.sourceKey !== "" && !(fd.copy && fd.paths.length)) {
                // rearranging icons on the desktop
                var key = fd.sourceKey
                var spot = desk.iconAtCell(cell[0], cell[1], key) ? desk.freeCellNear(cell[0], cell[1], key) : cell
                desk.saveCell(key, spot[0], spot[1])
                Qt.callLater(desk.refresh)
                drop.accept(Qt.MoveAction)
                return
            }
            // files arriving from a window or the host computer: land where they were dropped
            var names = desk.wm.isFileDrag(drop) ? fd.paths.map(function (p) { return p.split("/").pop() }) : []
            if (!desk.wm.isFileDrag(drop) && drop.hasUrls)
                for (var i = 0; i < drop.urls.length; i++) names.push(decodeURIComponent(drop.urls[i].toString().split("/").pop()))
            if (desk.wm.dropInto("/Desktop", drop)) {
                var free = desk.freeCellNear(cell[0], cell[1], "")
                if (names.length) desk.saveCell("file:" + names[0], free[0], free[1])
                drop.acceptProposedAction()
            }
        }
    }
    Rectangle {   // landing-spot preview
        visible: deskDrop.containsDrag && deskDrop.hoverCell !== null
        x: deskDrop.hoverCell ? desk.margin + deskDrop.hoverCell[0] * desk.cellW + 3 : 0
        y: deskDrop.hoverCell ? desk.margin + deskDrop.hoverCell[1] * desk.cellH + 3 : 0
        width: desk.cellW - 6
        height: desk.cellH - 6
        radius: UI.radius
        color: UI.alpha(UI.accent, 0.12)
        border.color: UI.alpha(UI.accent, 0.6)
        border.width: 1
    }

    // ------------------------------------------------------------ background (rubber band)
    MouseArea {
        id: bg
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        property point origin: Qt.point(0, 0)
        property bool banding: false
        onPressed: function (mouse) {
            desk.forceActiveFocus()
            if (mouse.button === Qt.RightButton) { desk.backgroundMenu(mouse.x, mouse.y); return }
            origin = Qt.point(mouse.x, mouse.y)
            banding = false
            if (!(mouse.modifiers & Qt.ControlModifier)) desk.clearSelection()
        }
        onPositionChanged: function (mouse) {
            if (!(mouse.buttons & Qt.LeftButton)) return
            if (!banding && Math.abs(mouse.x - origin.x) + Math.abs(mouse.y - origin.y) > 4) banding = true
            if (!banding) return
            band.x = Math.min(origin.x, mouse.x); band.y = Math.min(origin.y, mouse.y)
            band.width = Math.abs(mouse.x - origin.x); band.height = Math.abs(mouse.y - origin.y)
            var s = {}
            for (var i = 0; i < desk.icons.length; i++) {
                var ic = desk.icons[i]
                var ix = desk.margin + ic.col * desk.cellW, iy = desk.margin + ic.row * desk.cellH
                if (ix < band.x + band.width && ix + desk.cellW > band.x && iy < band.y + band.height && iy + desk.cellH > band.y) s[ic.key] = true
            }
            desk.selected = s
        }
        onReleased: banding = false
    }

    Rectangle {
        id: band
        visible: bg.banding
        color: UI.alpha(UI.accent, 0.16)
        border.color: UI.alpha(UI.accent, 0.7)
        radius: 2
    }

    // ------------------------------------------------------------ clock widget
    Column {
        visible: Prefs.showDesktopClock
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 44
        anchors.topMargin: 36
        spacing: 2
        Text {
            elide: Text.ElideRight
            anchors.right: parent.right
            text: UI.timeText(UI.now)
            color: "white"
            font.pixelSize: UI.px(64)
            font.weight: Font.Light
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.25)
        }
        Text {
            elide: Text.ElideRight
            font.weight: UI.textWeight
            anchors.right: parent.right
            text: Qt.formatDate(UI.now, "dddd, MMMM d")
            color: Qt.rgba(1, 1, 1, 0.9)
            font.pixelSize: UI.px(18)
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.25)
        }
        Text {
            elide: Text.ElideRight
            font.weight: UI.textWeight
            anchors.right: parent.right
            text: UI.greeting() + ", " + Prefs.userName + (WeatherService.hasData ? "  ·  " + WeatherService.city + " " + UI.temp(WeatherService.current.temp) : "")
            color: Qt.rgba(1, 1, 1, 0.75)
            font.pixelSize: UI.px(13)
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.25)
        }
    }

    // ------------------------------------------------------------ icons
    Repeater {
        model: desk.icons
        delegate: Item {
            id: tile
            readonly property var ic: modelData
            readonly property bool isSelected: desk.selected[ic.key] === true
            readonly property bool dropTarget: ic.isDir === true || ic.kind === "trash"
            readonly property string dropDir: ic.kind === "trash" ? "/Recycle Bin" : (ic.path || "")
            property string thumb: ""
            Component.onCompleted: if (ic.kind === "image" || ic.kind === "video") tile.thumb = Thumbs.request(ic.path)
            Connections { target: Thumbs; function onReady(p, url) { if (p === tile.ic.path && url) tile.thumb = url } }

            x: desk.margin + ic.col * desk.cellW
            y: desk.margin + ic.row * desk.cellH
            width: desk.cellW
            height: desk.cellH
            opacity: tileMouse.dragging ? 0.4 : (ic.path && desk.cutSet[ic.path] === true ? 0.5 : 1)
            Behavior on x { NumberAnimation { duration: UI.dur(180); easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: UI.dur(180); easing.type: Easing.OutCubic } }

            DropArea {
                id: tileDrop
                anchors.fill: parent
                enabled: tile.dropTarget
                onEntered: function (drag) {
                    var self = desk.wm.isFileDrag(drag) && desk.wm.fileDrag.sourceKey === tile.ic.key
                    var ok = !self && desk.wm.canDropOn(drag, tile.dropDir)
                    drag.accepted = ok
                    if (ok) desk.wm.setDropTarget(tile.ic.name)
                }
                onExited: desk.wm.setDropTarget("")
                onDropped: function (drop) { if (desk.wm.dropInto(tile.dropDir, drop)) drop.acceptProposedAction() }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 3
                radius: UI.radius
                color: tileDrop.containsDrag ? UI.alpha(UI.accent, 0.35)
                     : tile.isSelected ? UI.alpha(UI.accent, 0.28) : (tileMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent")
                border.width: tileDrop.containsDrag ? 2 : (tile.isSelected ? 1 : 0)
                border.color: tileDrop.containsDrag ? "white" : UI.alpha(UI.accent, 0.6)
            }
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 10
                spacing: 6
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: UI.px(46); height: UI.px(44)
                    Image {
                        id: tileThumb
                        anchors.centerIn: parent
                        width: UI.px(52); height: UI.px(44)
                        visible: tile.thumb !== "" && status === Image.Ready
                        source: tile.thumb
                        sourceSize.width: 104
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }
                    Icon {
                        anchors.centerIn: parent
                        visible: !tileThumb.visible
                        name: tile.ic.kind === "trash" && Storage.trashCount > 0 ? "place-trash-full" : tile.ic.icon
                        size: UI.px(46)
                        scale: tileDrop.containsDrag ? 1.15 : 1
                        Behavior on scale { NumberAnimation { duration: UI.dur(120) } }
                    }
                    Rectangle {
                        visible: tile.ic.kind === "trash" && Storage.trashCount > 0
                        anchors.right: parent.right; anchors.top: parent.top
                        width: UI.px(18); height: width; radius: width / 2
                        color: UI.accent
                        Text { anchors.centerIn: parent; text: Math.min(99, Storage.trashCount); font.pixelSize: UI.px(9); font.bold: true; color: UI.accentText }
                    }
                    Rectangle {   // shortcut badge on app icons
                        visible: tile.ic.kind === "app"
                        anchors.left: parent.left; anchors.bottom: parent.bottom
                        width: UI.px(15); height: width; radius: 4
                        color: Qt.rgba(1, 1, 1, 0.92)
                        Text { anchors.centerIn: parent; text: "↗"; color: "#1e293b"; font.pixelSize: UI.px(10); font.bold: true }
                    }
                }
                Text {
                    font.weight: UI.textWeight
                    width: desk.cellW - 10
                    text: tile.ic.name
                    color: "white"
                    font.pixelSize: UI.px(12)
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    maximumLineCount: tile.isSelected ? 3 : 2
                    elide: Text.ElideRight
                    style: Text.Outline
                    styleColor: Qt.rgba(0, 0, 0, 0.45)
                }
            }

            MouseArea {
                id: tileMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                property point pressPos: Qt.point(0, 0)
                property bool dragging: false
                property bool deferSelect: false
                onPressed: function (mouse) {
                    desk.forceActiveFocus()
                    if (mouse.button === Qt.RightButton) { desk.iconMenu(tile.ic, tileMouse, mouse.x, mouse.y); return }
                    pressPos = Qt.point(mouse.x, mouse.y)
                    dragging = false
                    deferSelect = tile.isSelected && mouse.modifiers === Qt.NoModifier
                    if (mouse.modifiers & Qt.ControlModifier) desk.select(tile.ic.key, true)
                    else if (!tile.isSelected) desk.select(tile.ic.key, false)
                }
                onPositionChanged: function (mouse) {
                    if (!(mouse.buttons & Qt.LeftButton)) return
                    var p = mapToItem(null, mouse.x, mouse.y)
                    if (!dragging) {
                        if (Math.abs(mouse.x - pressPos.x) + Math.abs(mouse.y - pressPos.y) < 8) return
                        dragging = true
                        desk.startDrag(tile.ic, p.x, p.y)
                    }
                    desk.wm.moveFileDrag(p.x, p.y, mouse.modifiers)
                }
                onReleased: function (mouse) {
                    if (mouse.button !== Qt.LeftButton) return
                    if (dragging) {
                        dragging = false
                        var p = mapToItem(null, mouse.x, mouse.y)
                        desk.wm.endFileDrag(p.x, p.y, mouse.modifiers)   // last statement: may refresh the icons
                    } else if (deferSelect) {
                        desk.select(tile.ic.key, false)
                    }
                }
                onCanceled: { if (dragging) { dragging = false; desk.wm.cancelFileDrag() } }
                onDoubleClicked: function (mouse) { if (mouse.button === Qt.LeftButton) desk.open(tile.ic) }
            }
        }
    }

    GMenu { id: menu }
    GDialog { id: dialog }
}
