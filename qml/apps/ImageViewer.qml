import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../ui"
import "../components"

FocusScope {
    id: viewer
    property var hostWindow: null
    property string filePath: ""
    property var siblings: []
    property int index: -1
    property real zoom: 1
    property bool fit: true
    property int rotationAngle: 0
    property var gallery: []
    property bool immersive: false
    function setImmersive(on) {
        if (on === immersive || galleryMode) return
        immersive = on
        if (on) UI.wm.enterFullscreen(hostWindow, function () { viewer.setImmersive(false) })
        else UI.wm.exitFullscreen(hostWindow)
    }
    Connections {
        target: UI.wm
        function onFullscreenWindowChanged() { if (viewer.immersive && UI.wm.fullscreenWindow !== viewer.hostWindow) viewer.immersive = false }
    }
    readonly property var wm: UI.wm
    readonly property bool galleryMode: filePath === ""
    readonly property real fitZoom: img.implicitWidth > 0
        ? Math.min(stage.width / rotatedW(), stage.height / rotatedH(), 1) : 1
    readonly property real effectiveZoom: fit ? fitZoom : zoom

    function rotatedW() { return (rotationAngle % 180 === 0 ? img.implicitWidth : img.implicitHeight) || 1 }
    function rotatedH() { return (rotationAngle % 180 === 0 ? img.implicitHeight : img.implicitWidth) || 1 }

    Component.onCompleted: { if (filePath) show(filePath); else loadGallery(); viewer.forceActiveFocus() }
    function sessionState() { return filePath ? { filePath: filePath } : {} }
    function handleArgs(props) { if (props.filePath) show(props.filePath) }

    function loadGallery() {
        var out = []
        var dirs = ["/Pictures", "/Pictures/Wallpapers", "/Desktop", "/Downloads", "/Documents"]
        dirs.forEach(function (dir) {
            Storage.list(dir).forEach(function (e) { if (e.kind === "image") out.push(e) })
        })
        gallery = out
        if (hostWindow) hostWindow.title = "Photos"
    }

    function show(path) {
        filePath = path
        var dir = Storage.parentOf(path)
        siblings = Storage.list(dir).filter(function (e) { return e.kind === "image" }).map(function (e) { return e.path })
        index = siblings.indexOf(path)
        fit = true
        rotationAngle = 0
        if (hostWindow) hostWindow.title = path.split("/").pop() + " — Photos"
        UI.wm.rememberRecent(path)
    }
    function acceptDrop(paths, urls) {
        var img = paths.filter(function (p) { return Storage.kindOf(p) === "image" })[0]
        if (img) show(img)
        else if (urls.length) wm.importInto(urls, "/Pictures")
    }

    function step(d) { if (siblings.length > 1) show(siblings[(index + d + siblings.length) % siblings.length]) }

    function zoomBy(f, cx, cy) {
        var old = effectiveZoom
        var nz = Math.max(0.05, Math.min(16, old * f))
        if (cx === undefined) { cx = flick.width / 2; cy = flick.height / 2 }
        // keep the point under the cursor fixed
        var px = (flick.contentX + cx) / Math.max(1, flick.contentWidth)
        var py = (flick.contentY + cy) / Math.max(1, flick.contentHeight)
        fit = false
        zoom = nz
        Qt.callLater(function () {
            flick.contentX = Math.max(0, px * flick.contentWidth - cx)
            flick.contentY = Math.max(0, py * flick.contentHeight - cy)
        })
    }

    function trashCurrent() {
        if (!filePath) return
        var path = filePath, next = siblings.length > 1 ? siblings[(index + 1) % siblings.length] : ""
        if (Storage.trash([path])) {
            wm.notify("Moved to Recycle Bin", path.split("/").pop(), "trash")
            if (next && next !== path) show(next); else { filePath = ""; loadGallery() }
        }
    }

    Keys.onPressed: function (event) {
        var k = event.key
        if (galleryMode) return
        if (k === Qt.Key_Right || k === Qt.Key_Space) step(1)
        else if (k === Qt.Key_Left || k === Qt.Key_Backspace) step(-1)
        else if (k === Qt.Key_Plus || k === Qt.Key_Equal) zoomBy(1.25)
        else if (k === Qt.Key_Minus) zoomBy(0.8)
        else if (k === Qt.Key_0) fit = true
        else if (k === Qt.Key_1) { fit = false; zoom = 1 }
        else if (k === Qt.Key_R) rotationAngle = (rotationAngle + 90) % 360
        else if (k === Qt.Key_Delete) trashCurrent()
        else if (k === Qt.Key_F || k === Qt.Key_F11) setImmersive(!immersive)
        else if (k === Qt.Key_Escape) { filePath = ""; loadGallery() }
        else return
        event.accepted = true
    }

    Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.55) }

    // ------------------------------------------------------------ gallery
    GridView {
        id: galleryView
        visible: viewer.galleryMode
        anchors.fill: parent
        anchors.margins: 12
        cellWidth: Math.max(UI.px(150), width / Math.max(1, Math.floor(width / UI.px(170))))
        cellHeight: cellWidth * 0.72
        clip: true
        model: viewer.gallery
        ScrollBar.vertical: GScrollBar {}
        header: Text { text: "Your pictures"; color: UI.text; font.pixelSize: UI.px(20); font.weight: Font.DemiBold; bottomPadding: 12 }
        delegate: MouseArea {
            id: tile
            width: galleryView.cellWidth
            height: galleryView.cellHeight
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: viewer.show(modelData.path)
            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                radius: UI.radius
                color: UI.card
                clip: true
                Image {
                    id: galImg
                    anchors.fill: parent
                    property string thumb: Thumbs.request(modelData.path)
                    Connections { target: Thumbs; function onReady(p, url) { if (p === modelData.path && url) galImg.thumb = url } }
                    source: thumb
                    sourceSize.width: 360
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    scale: tile.containsMouse ? 1.05 : 1
                    Behavior on scale { NumberAnimation { duration: UI.dur(200) } }
                }
            }
        }
        Text {
            font.weight: UI.textWeight
            visible: viewer.gallery.length === 0
            anchors.centerIn: parent
            text: "No pictures yet. Drop some into Pictures."
            color: UI.textDim; font.pixelSize: UI.px(13)
        }
    }

    // ------------------------------------------------------------ viewer
    Item {
        id: stage
        visible: !viewer.galleryMode
        anchors.fill: parent
        anchors.bottomMargin: toolbar.visible ? toolbar.height : 0

        Flickable {
            id: flick
            anchors.fill: parent
            clip: true
            contentWidth: Math.max(width, viewer.rotatedW() * viewer.effectiveZoom)
            contentHeight: Math.max(height, viewer.rotatedH() * viewer.effectiveZoom)
            boundsBehavior: Flickable.StopAtBounds
            interactive: !viewer.fit
            ScrollBar.vertical: GScrollBar {}
            ScrollBar.horizontal: GScrollBar {}

            Image {
                id: img
                anchors.centerIn: parent
                width: implicitWidth * viewer.effectiveZoom
                height: implicitHeight * viewer.effectiveZoom
                source: viewer.filePath ? Storage.fileUrl(viewer.filePath) : ""
                sourceSize.width: 4096
                sourceSize.height: 4096
                asynchronous: true
                smooth: viewer.effectiveZoom < 2
                mipmap: viewer.effectiveZoom < 0.5
                rotation: viewer.rotationAngle
                Behavior on rotation { NumberAnimation { duration: UI.dur(220); easing.type: Easing.OutCubic } }
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: function (wheel) {
                    viewer.zoomBy(wheel.angleDelta.y > 0 ? 1.15 : 1 / 1.15, wheel.x - flick.contentX, wheel.y - flick.contentY)
                }
            }
            TapHandler { onDoubleTapped: { if (viewer.fit) { viewer.fit = false; viewer.zoom = 1 } else viewer.fit = true } }
        }

        BusyIndicator { anchors.centerIn: parent; running: img.status === Image.Loading }
        Text { font.weight: UI.textWeight; visible: img.status === Image.Error; anchors.centerIn: parent; text: "This image can't be displayed"; color: UI.textDim; font.pixelSize: UI.px(14) }

        // side arrows
        Repeater {
            model: viewer.siblings.length > 1 ? [-1, 1] : []
            delegate: IconButton {
                anchors.verticalCenter: parent.verticalCenter
                x: modelData < 0 ? 12 : stage.width - width - 12
                iconName: modelData < 0 ? "chevron-left" : "chevron-right"
                size: 44; glyphSize: 26
                opacity: hovered ? 1 : 0.6
                onClicked: viewer.step(modelData)
            }
        }
    }

    Rectangle {
        id: toolbar
        visible: !viewer.galleryMode && !viewer.immersive
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: UI.px(46)
        color: Qt.rgba(0, 0, 0, 0.35)
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 4
            IconButton { iconName: "grid"; tip: "All photos (Esc)"; onClicked: { viewer.filePath = ""; viewer.loadGallery() } }
            Text {
                font.weight: UI.textWeight
                Layout.fillWidth: true
                text: viewer.filePath.split("/").pop() + (img.implicitWidth ? "   ·   " + img.implicitWidth + " × " + img.implicitHeight : "")
                      + (viewer.siblings.length > 1 ? "   ·   " + (viewer.index + 1) + " / " + viewer.siblings.length : "")
                color: UI.textDim; font.pixelSize: UI.px(12); elide: Text.ElideMiddle
            }
            IconButton { iconName: "minus"; tip: "Zoom out (-)"; onClicked: viewer.zoomBy(0.8) }
            Text { elide: Text.ElideRight; font.weight: UI.textWeight; text: Math.round(viewer.effectiveZoom * 100) + "%"; color: UI.text; font.pixelSize: UI.px(12); Layout.preferredWidth: UI.px(44); horizontalAlignment: Text.AlignHCenter }
            IconButton { iconName: "plus"; tip: "Zoom in (+)"; onClicked: viewer.zoomBy(1.25) }
            IconButton { iconName: "fit"; tip: "Fit (0)"; active: viewer.fit; onClicked: viewer.fit = true }
            IconButton { glyph: "1:1"; glyphSize: 11; tip: "Actual size (1)"; onClicked: { viewer.fit = false; viewer.zoom = 1 } }
            IconButton { iconName: "refresh"; tip: "Rotate (R)"; onClicked: viewer.rotationAngle = (viewer.rotationAngle + 90) % 360 }
            IconButton { iconName: "fullscreen"; tip: "Full screen (F)"; onClicked: viewer.setImmersive(true) }
            IconButton { iconName: "image"; tip: "Set as wallpaper"; onClicked: { if (Prefs.setWallpaper(viewer.filePath)) viewer.wm.notify("Wallpaper changed", viewer.filePath.split("/").pop(), "image") } }
            IconButton { iconName: "folder"; tip: "Show in Files"; onClicked: viewer.wm.openApp("AeroExplorer", { initialPath: Storage.parentOf(viewer.filePath) }) }
            IconButton { iconName: "trash"; tip: "Delete (Del)"; onClicked: viewer.trashCurrent() }
        }
    }
}
