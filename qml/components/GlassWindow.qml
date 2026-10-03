// A GlassOS application window, managed by Main.qml (the window manager).
//
// The app is loaded from `appSource` with `appProps` as initial properties.
// Every app declares `property var hostWindow` and may:
//   * set hostWindow.title / hostWindow.icon
//   * implement canClose(): returning false vetoes closing; the app then asks
//     the user and calls hostWindow.forceClose() itself
//   * expose `property bool hasUnsavedChanges` (used by the shutdown dialog)
import QtQuick
import QtQuick.Controls
import "../ui"

Item {
    id: win

    // ---- identity ----
    property string appId: ""
    property string title: "Window"
    property string icon: "app-files"
    property url appSource
    property var appProps: ({})
    property int minW: 320
    property int minH: 220
    readonly property var app: loader.item

    // ---- state ----
    readonly property bool active: UI.wm !== null && UI.wm.activeWindow === win
    property bool minimized: false
    property bool shown: true               // false once the minimize animation has finished
    property int workspace: 0
    property bool chromeless: false         // true fullscreen: no title bar, no border, covers the taskbar
    property string fsPrevSnap: ""
    visible: shown && (UI.wm === null || workspace === UI.wm.workspace)
    property string snap: ""            // "", "max", "left", "right", "tl", "tr", "bl", "br"
    readonly property bool maximized: snap === "max"
    property var normalRect: null       // geometry to return to when un-snapping
    property bool dragging: false
    property bool resizing: false
    property bool closing: false
    readonly property real areaW: parent ? parent.width : 800
    readonly property real areaH: parent ? parent.height : 600

    signal focusRequested()
    signal closed()
    signal snapHint(string zone)        // "" hides the preview

    // ---------------------------------------------------------------- geometry
    function zoneRect(zone) {
        var f = UI.zoneFrac(zone)
        if (!f) return Qt.rect(x, y, width, height)
        // round edges (not sizes) so neighbouring zones tile without gaps or overlaps
        var x0 = Math.round(f[0] * areaW), y0 = Math.round(f[1] * areaH)
        var x1 = Math.round((f[0] + f[2]) * areaW), y1 = Math.round((f[1] + f[3]) * areaH)
        return Qt.rect(x0, y0, x1 - x0, y1 - y0)
    }

    function animateTo(r) {
        geoAnim.stop()
        if (!UI.animations) { x = r.x; y = r.y; width = r.width; height = r.height; return }
        ax.to = r.x; ay.to = r.y; aw.to = r.width; ah.to = r.height
        geoAnim.start()
    }

    function setSnap(zone) {
        if (minimized) restore()
        if (zone === snap) return
        if (snap === "") normalRect = Qt.rect(x, y, width, height)
        snap = zone
        if (zone === "") {
            var r = normalRect || Qt.rect(x, y, width, height)
            animateTo(Qt.rect(Math.max(0, Math.min(r.x, areaW - 120)), Math.max(0, Math.min(r.y, areaH - 60)),
                              r.width, r.height))
        } else {
            animateTo(zoneRect(zone))
        }
    }

    function toggleMaximize() { setSnap(snap === "max" ? "" : "max") }

    // Called by the window manager (UI.wm.enterFullscreen / exitFullscreen)
    function enterFullscreen() {
        if (chromeless) return
        geoAnim.stop()
        fsPrevSnap = snap
        if (snap === "") normalRect = Qt.rect(x, y, width, height)
        snap = "max"
        chromeless = true
        x = 0; y = 0; width = areaW; height = areaH
    }
    function exitFullscreen() {
        if (!chromeless) return
        chromeless = false
        setSnap(fsPrevSnap)
        if (fsPrevSnap === "max") relayout()
    }

    function clampIntoView() {
        if (width > areaW) width = Math.max(minW, areaW)
        if (height > areaH) height = Math.max(minH, areaH)
        x = Math.max(-width + 120, Math.min(x, areaW - 120))
        y = Math.max(0, Math.min(y, areaH - 44))
    }

    function relayout() {
        if (!parent || dragging || resizing) return
        if (snap !== "") {
            geoAnim.stop()
            var r = zoneRect(snap)
            x = r.x; y = r.y; width = r.width; height = r.height
        } else {
            clampIntoView()
        }
    }
    onAreaWChanged: relayout()
    onAreaHChanged: relayout()

    ParallelAnimation {
        id: geoAnim
        NumberAnimation { id: ax; target: win; property: "x"; duration: 190; easing.type: Easing.OutCubic }
        NumberAnimation { id: ay; target: win; property: "y"; duration: 190; easing.type: Easing.OutCubic }
        NumberAnimation { id: aw; target: win; property: "width"; duration: 190; easing.type: Easing.OutCubic }
        NumberAnimation { id: ah; target: win; property: "height"; duration: 190; easing.type: Easing.OutCubic }
    }

    // ------------------------------------------------------- minimize / restore
    transform: [
        Scale { id: genie; origin.x: win.width / 2; origin.y: win.height },
        Translate { id: slide }
    ]

    function minimize() {
        if (minimized || closing) return
        restoreAnim.stop()
        minimized = true
        if (UI.animations) {
            mTx.to = win.areaW / 2 - (win.x + win.width / 2)
            mTy.to = win.areaH - win.y - win.height + 60
            minimizeAnim.start()
        } else {
            win.shown = false
        }
    }

    function restore() {
        if (!minimized) return
        minimizeAnim.stop()
        minimized = false
        win.shown = true
        if (UI.animations) {
            restoreAnim.start()
        } else {
            genie.xScale = 1; genie.yScale = 1; slide.x = 0; slide.y = 0; win.opacity = 1
        }
    }

    ParallelAnimation {
        id: minimizeAnim
        NumberAnimation { target: genie; property: "xScale"; to: 0.22; duration: 230; easing.type: Easing.InCubic }
        NumberAnimation { target: genie; property: "yScale"; to: 0.12; duration: 230; easing.type: Easing.InCubic }
        NumberAnimation { id: mTx; target: slide; property: "x"; duration: 230; easing.type: Easing.InCubic }
        NumberAnimation { id: mTy; target: slide; property: "y"; duration: 230; easing.type: Easing.InCubic }
        NumberAnimation { target: win; property: "opacity"; to: 0; duration: 230; easing.type: Easing.InQuad }
        onFinished: if (win.minimized) win.shown = false
    }

    ParallelAnimation {
        id: restoreAnim
        NumberAnimation { target: genie; property: "xScale"; to: 1; duration: 230; easing.type: Easing.OutCubic }
        NumberAnimation { target: genie; property: "yScale"; to: 1; duration: 230; easing.type: Easing.OutCubic }
        NumberAnimation { target: slide; property: "x"; to: 0; duration: 230; easing.type: Easing.OutCubic }
        NumberAnimation { target: slide; property: "y"; to: 0; duration: 230; easing.type: Easing.OutCubic }
        NumberAnimation { target: win; property: "opacity"; to: 1; duration: 200 }
    }

    // ----------------------------------------------------------- open / close
    function requestClose() {
        if (closing) return
        if (app && typeof app.canClose === "function" && !app.canClose()) {
            focusRequested()           // the app is showing its own "save changes?" prompt
            return
        }
        forceClose()
    }

    function forceClose() {
        if (closing) return
        closing = true
        if (UI.animations && visible) closeAnim.start()
        else closed()
    }

    function takeFocus() {
        if (loader.item) loader.item.forceActiveFocus()
        else body.forceActiveFocus()
    }

    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: win; property: "opacity"; from: 0; to: 1; duration: 170; easing.type: Easing.OutCubic }
        NumberAnimation { target: win; property: "scale"; from: 0.94; to: 1; duration: 210; easing.type: Easing.OutBack }
    }
    ParallelAnimation {
        id: closeAnim
        NumberAnimation { target: win; property: "opacity"; to: 0; duration: 130 }
        NumberAnimation { target: win; property: "scale"; to: 0.95; duration: 130; easing.type: Easing.InCubic }
        onFinished: win.closed()
    }

    Component.onCompleted: {
        var props = Object.assign({ hostWindow: win }, appProps || {})
        loader.setSource(appSource, props)
        if (UI.animations) openAnim.start()
    }

    // ------------------------------------------------------------------ visuals
    // Soft shadow from a few concentric *rings* (border only, transparent fill):
    // no overdraw of the window interior and no offscreen blur pass.
    Repeater {
        model: win.maximized || win.minimized ? 0 : 4
        Rectangle {
            readonly property real spread: (index + 1) * 3
            anchors.fill: parent
            anchors.margins: -spread
            anchors.topMargin: -spread * 0.6
            anchors.bottomMargin: -spread * 1.5
            radius: UI.radius + spread
            color: "transparent"
            border.width: 3
            border.color: Qt.rgba(0, 0, 0, (win.active ? 0.13 : 0.08) / (index + 1))
        }
    }

    // Catches drops on any part of the window the app itself doesn't handle
    // (apps with their own DropAreas, like Files, get the event first because
    // their content sits above this item). Hovering a drag raises the window.
    DropArea {
        id: windowDrop
        anchors.fill: parent
        readonly property string dir: win.app && win.app.dropTargetDir !== undefined ? win.app.dropTargetDir : ""
        readonly property bool appAccepts: win.app !== null && typeof win.app.acceptDrop === "function"
        onEntered: function (drag) {
            drag.accepted = true
            raiseTimer.restart()
            if (dir !== "" && UI.wm.canDropOn(drag, dir)) UI.wm.setDropTarget(UI.wm.folderName(dir))
            else if (appAccepts) UI.wm.setDropTarget(win.title)
            else UI.wm.setDropTarget("")
        }
        onExited: { raiseTimer.stop(); UI.wm.setDropTarget("") }
        onDropped: function (drop) {
            raiseTimer.stop()
            if (dir !== "" && UI.wm.dropInto(dir, drop)) { drop.acceptProposedAction(); return }
            if (appAccepts) {
                var paths = UI.wm.isFileDrag(drop) ? UI.wm.fileDrag.paths.slice() : []
                var urls = []
                if (!UI.wm.isFileDrag(drop) && drop.hasUrls)
                    for (var i = 0; i < drop.urls.length; i++) urls.push(drop.urls[i].toString())
                var app = win.app
                Qt.callLater(function () { app.acceptDrop(paths, urls) })
                drop.accept(Qt.CopyAction)
                return
            }
            drop.accept(Qt.IgnoreAction)   // swallow: don't let it fall through to the desktop
        }
        Timer { id: raiseTimer; interval: 650; onTriggered: if (!win.active) win.focusRequested() }
    }

    GlassSurface {
        id: frame
        anchors.fill: parent
        sceneX: win.x + slide.x
        sceneY: win.y + slide.y
        radius: win.maximized ? 0 : UI.radius
        showBorder: !win.chromeless
        borderColor: win.active ? UI.alpha(UI.accent, 0.42) : UI.border
    }

    // ------------------------------------------------------------------ title bar
    Item {
        id: titleBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: win.chromeless ? 0 : UI.px(38)
        visible: !win.chromeless

        MouseArea {
            id: titleDrag
            anchors.fill: parent
            anchors.rightMargin: controls.width + 6
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            property real offX: 0
            property real offY: 0
            property real pressX: 0
            property real pressY: 0
            property string hint: ""

            onPressed: function (mouse) {
                win.focusRequested()
                if (mouse.button === Qt.RightButton) {
                    windowMenu.show(titleDrag, mouse.x, mouse.y, win.menuItems())
                    return
                }
                var p = mapToItem(win.parent, mouse.x, mouse.y)
                pressX = p.x; pressY = p.y
                offX = p.x - win.x; offY = p.y - win.y
                hint = ""
            }
            onPositionChanged: function (mouse) {
                if (!(mouse.buttons & Qt.LeftButton)) return
                var p = mapToItem(win.parent, mouse.x, mouse.y)
                if (!win.dragging) {
                    if (Math.abs(p.x - pressX) + Math.abs(p.y - pressY) < 6) return
                    win.dragging = true
                    geoAnim.stop()
                    if (win.snap !== "") {   // tear the window out of its snapped slot
                        var r = win.normalRect || Qt.rect(win.x, win.y, win.width * 0.65, win.height * 0.65)
                        var ratio = offX / Math.max(1, win.width)
                        win.snap = ""
                        win.width = r.width
                        win.height = r.height
                        offX = Math.round(r.width * ratio)
                        offY = Math.min(offY, UI.px(19))
                    }
                }
                win.x = Math.max(-win.width + 120, Math.min(p.x - offX, win.areaW - 120))
                win.y = Math.max(0, Math.min(p.y - offY, win.areaH - 44))

                var e = 4, c = 80, z = ""
                var atL = p.x <= e, atR = p.x >= win.areaW - e, atT = p.y <= e
                if (atL) z = p.y < c ? "tl" : (p.y > win.areaH - c ? "bl" : "left")
                else if (atR) z = p.y < c ? "tr" : (p.y > win.areaH - c ? "br" : "right")
                else if (atT) z = p.x < c ? "tl" : (p.x > win.areaW - c ? "tr" : "max")
                if (z !== hint) { hint = z; win.snapHint(z) }
            }
            onReleased: finishDrag(true)
            onCanceled: finishDrag(false)
            onDoubleClicked: function (mouse) { if (mouse.button === Qt.LeftButton) win.toggleMaximize() }

            function finishDrag(apply) {
                if (win.dragging) {
                    win.dragging = false
                    var zone = hint
                    hint = ""
                    win.snapHint("")
                    if (apply && zone !== "") { win.setSnap(zone); UI.wm.offerSnapAssist(win, zone) }
                }
            }
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.right: controls.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 9
            Icon {
                id: iconText
                name: win.icon
                size: UI.px(18)
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                width: parent.width - iconText.width - 9
                text: win.title
                color: win.active ? UI.text : UI.textDim
                font.pixelSize: UI.px(12.5)
                font.weight: Font.Medium
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Row {
            id: controls
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: 6
            anchors.topMargin: 4
            spacing: 2
            IconButton {
                iconName: "minimize"; size: 30; glyphSize: 11; tip: "Minimize"
                onClicked: win.minimize()
            }
            IconButton {
                id: maxButton
                iconName: win.snap !== "" ? "restore" : "maximize"; size: 30; glyphSize: 13
                tip: win.snap !== "" ? "Restore" : "Maximize  ·  hover for snap layouts"
                onClicked: { layoutTimer.stop(); layouts.close(); win.toggleMaximize() }
                onHoveredChanged: { if (hovered) layoutTimer.restart(); else layoutTimer.stop() }
                Timer { id: layoutTimer; interval: 450; onTriggered: layouts.show(maxButton) }
            }
            IconButton {
                iconName: "close"; size: 30; glyphSize: 12; tip: "Close"
                hoverColor: UI.danger
                onClicked: win.requestClose()
            }
        }
    }

    function menuItems() {
        return [
            { text: snap !== "" ? "Restore" : "Maximize", icon: snap !== "" ? "restore" : "maximize", action: toggleMaximize },
            { text: "Minimize", icon: "minimize", action: minimize },
            { separator: true },
            { text: "Snap left", icon: "back", shortcut: "Ctrl+Alt+←", action: function () { setSnap("left"); UI.wm.offerSnapAssist(win, "left") } },
            { text: "Snap right", icon: "forward", shortcut: "Ctrl+Alt+→", action: function () { setSnap("right"); UI.wm.offerSnapAssist(win, "right") } },
            { text: "Snap to a quarter", icon: "grid", action: function () { setSnap("tl"); UI.wm.offerSnapAssist(win, "tl") } },
            { separator: true },
            { text: "Move to workspace " + ((workspace + 1) % 4 + 1), icon: "tab", shortcut: "Ctrl+Alt+Shift+1…4",
              action: function () { UI.wm.moveToWorkspace(win, (workspace + 1) % 4) } },
            { separator: true },
            { text: "Close", icon: "close", shortcut: "Ctrl+Alt+W", danger: true, action: requestClose }
        ]
    }

    GMenu { id: windowMenu; menuWidth: 240 }
    SnapLayouts {
        id: layouts
        onPicked: function (zone) { win.setSnap(zone); UI.wm.offerSnapAssist(win, zone) }
    }

    // ------------------------------------------------------------------ app body
    FocusScope {
        id: body
        anchors.top: titleBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 1
        anchors.topMargin: 0
        clip: true

        Loader {
            id: loader
            anchors.fill: parent
            focus: true
            onLoaded: item.focus = true
        }

        Column {
            visible: loader.status === Loader.Error
            anchors.centerIn: parent
            width: parent.width - 60
            spacing: 10
            Icon { name: "warning"; size: 44; anchors.horizontalCenter: parent.horizontalCenter }
            Text {
                elide: Text.ElideRight
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: win.title + " couldn't start"
                color: UI.text
                font.pixelSize: UI.px(16)
                font.weight: Font.DemiBold
            }
            Text {
                font.weight: UI.textWeight
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: "The app failed to load. Details were printed in the GlassOS console."
                color: UI.textDim
                font.pixelSize: UI.px(12)
            }
        }

        // First click on an inactive window focuses it and still reaches the app.
        MouseArea {
            anchors.fill: parent
            z: 100
            enabled: !win.active
            onPressed: function (mouse) { win.focusRequested(); mouse.accepted = false }
            onWheel: function (wheel) { wheel.accepted = false }
        }
    }

    // ------------------------------------------------------------- resize edges
    Repeater {
        model: win.snap === "" ? ["l", "r", "t", "b", "tl", "tr", "bl", "br"] : []
        MouseArea {
            id: edge
            readonly property string e: modelData
            readonly property bool hasL: e === "l" || e === "tl" || e === "bl"
            readonly property bool hasR: e === "r" || e === "tr" || e === "br"
            readonly property bool hasT: e === "t" || e === "tl" || e === "tr"
            readonly property bool hasB: e === "b" || e === "bl" || e === "br"
            property real sx: 0
            property real sy: 0
            property var startRect: null

            z: 60
            x: hasL ? -5 : (hasR ? win.width - 6 : 12)
            y: hasT ? -5 : (hasB ? win.height - 6 : 12)
            width: (hasL || hasR) ? 11 : win.width - 24
            height: (hasT || hasB) ? 11 : win.height - 24
            cursorShape: (e === "l" || e === "r") ? Qt.SizeHorCursor
                       : (e === "t" || e === "b") ? Qt.SizeVerCursor
                       : (e === "tl" || e === "br") ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor

            onPressed: function (mouse) {
                win.focusRequested()
                var p = mapToItem(win.parent, mouse.x, mouse.y)
                sx = p.x; sy = p.y
                startRect = Qt.rect(win.x, win.y, win.width, win.height)
                win.resizing = true
            }
            onPositionChanged: function (mouse) {
                if (!pressed || !startRect) return
                var p = mapToItem(win.parent, mouse.x, mouse.y)
                var dx = p.x - sx, dy = p.y - sy, r = startRect
                if (hasR) win.width = Math.max(win.minW, Math.min(r.width + dx, win.areaW - r.x))
                if (hasB) win.height = Math.max(win.minH, Math.min(r.height + dy, win.areaH - r.y))
                if (hasL) {
                    var nw = Math.max(win.minW, r.width - dx)
                    win.x = r.x + r.width - nw
                    win.width = nw
                }
                if (hasT) {
                    var nh = Math.max(win.minH, Math.min(r.height - dy, r.y + r.height))
                    win.y = r.y + r.height - nh
                    win.height = nh
                }
            }
            onReleased: win.resizing = false
            onCanceled: win.resizing = false
        }
    }
}
