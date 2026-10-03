import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../ui"
import "../components"

FocusScope {
    id: tm
    property var hostWindow: null
    property string tab: "apps"
    readonly property var wm: UI.wm

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        RowLayout {
            spacing: 6
            GButton { text: "Apps"; iconName: "tab"; kind: tm.tab === "apps" ? "primary" : "flat"; onClicked: tm.tab = "apps" }
            GButton { text: "Performance"; iconName: "activity"; kind: tm.tab === "perf" ? "primary" : "flat"; onClicked: tm.tab = "perf" }
            Item { Layout.fillWidth: true }
            Text { font.weight: UI.textWeight; text: tm.wm.windows.length + " window(s) · GlassOS " + System.appMemMB + " MB"; color: UI.textFaint; font.pixelSize: UI.px(11.5) }
        }

        // ---------------------------------------------------------- apps
        ListView {
            id: list
            visible: tm.tab === "apps"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: tm.wm.windows
            ScrollBar.vertical: GScrollBar {}
            delegate: Rectangle {
                width: list.width
                height: UI.px(52)
                radius: UI.radius
                color: rowMouse.containsMouse ? UI.cardStrong : UI.card
                border.color: modelData.active ? UI.alpha(UI.accent, 0.5) : UI.border
                MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true; onDoubleClicked: tm.wm.focusWindow(modelData) }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 10
                    spacing: 12
                    Icon { name: modelData.icon; size: UI.px(22) }
                    Column {
                        Layout.fillWidth: true
                        Text { font.weight: UI.textWeight; width: parent.width; text: modelData.title; color: UI.text; font.pixelSize: UI.px(13); elide: Text.ElideRight }
                        Text {
                            font.weight: UI.textWeight
                            text: (modelData.active ? "Active" : modelData.minimized ? "Minimized" : "Running")
                                  + (modelData.app && modelData.app.hasUnsavedChanges ? "  ·  unsaved changes" : "")
                            color: modelData.app && modelData.app.hasUnsavedChanges ? UI.warning : UI.textFaint
                            font.pixelSize: UI.px(11)
                        }
                    }
                    GButton { text: "Switch to"; kind: "flat"; onClicked: tm.wm.focusWindow(modelData) }
                    GButton { text: "End task"; kind: "danger"; enabled: modelData !== tm.hostWindow; onClicked: modelData.forceClose() }
                }
            }
            Text { font.weight: UI.textWeight; visible: list.count <= 1; anchors.centerIn: parent; text: "Only Task Manager is running. Open some apps."; color: UI.textFaint; font.pixelSize: UI.px(12.5) }
        }

        // ---------------------------------------------------------- performance
        ColumnLayout {
            visible: tm.tab === "perf"
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12
            Text {
                font.weight: UI.textWeight
                visible: !System.hasStats
                text: "Install psutil (pip install psutil) to see live CPU and memory graphs."
                color: UI.warning; font.pixelSize: UI.px(13)
            }
            Repeater {
                model: [
                    { name: "CPU", detail: System.cpuCores + " cores · " + System.cpuName, value: System.cpuPercent, history: System.cpuHistory, color: "#4cc2ff",
                      big: Math.round(System.cpuPercent) + "%" },
                    { name: "Memory", detail: System.memUsedGB + " of " + System.memTotalGB + " GB in use", value: System.memPercent, history: System.memHistory, color: "#a78bfa",
                      big: Math.round(System.memPercent) + "%" }
                ]
                delegate: Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: UI.radius
                    color: UI.card
                    border.color: UI.border
                    Column {
                        x: 16; y: 12
                        Text { text: modelData.name; color: UI.text; font.pixelSize: UI.px(15); font.weight: Font.DemiBold }
                        Text { font.weight: UI.textWeight; text: modelData.detail; color: UI.textFaint; font.pixelSize: UI.px(11.5) }
                    }
                    Text {
                        elide: Text.ElideRight
                        anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 12
                        text: modelData.big; color: modelData.color; font.pixelSize: UI.px(26); font.weight: Font.Light
                    }
                    Canvas {
                        id: graph
                        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                        anchors.margins: 12
                        anchors.top: parent.top; anchors.topMargin: UI.px(58)
                        property var points: modelData.history
                        property color lineColor: modelData.color
                        onPointsChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.07)
                            ctx.lineWidth = 1
                            for (var g = 1; g < 4; g++) { ctx.beginPath(); ctx.moveTo(0, height * g / 4); ctx.lineTo(width, height * g / 4); ctx.stroke() }
                            var pts = points || []
                            if (pts.length < 2) return
                            var stepX = width / (pts.length - 1)
                            ctx.beginPath()
                            ctx.moveTo(0, height)
                            for (var i = 0; i < pts.length; i++) ctx.lineTo(i * stepX, height - pts[i] / 100 * height)
                            ctx.lineTo(width, height)
                            ctx.closePath()
                            var grad = ctx.createLinearGradient(0, 0, 0, height)
                            grad.addColorStop(0, Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.45))
                            grad.addColorStop(1, Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.02))
                            ctx.fillStyle = grad
                            ctx.fill()
                            ctx.beginPath()
                            for (var j = 0; j < pts.length; j++) {
                                var y = height - pts[j] / 100 * height
                                if (j === 0) ctx.moveTo(0, y); else ctx.lineTo(j * stepX, y)
                            }
                            ctx.strokeStyle = lineColor
                            ctx.lineWidth = 2
                            ctx.stroke()
                        }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Repeater {
                    model: [
                        { k: "Disk", v: Math.round(System.diskPercent) + "% used" },
                        { k: "Uptime", v: System.uptime },
                        { k: "Windows", v: String(tm.wm.windows.length) },
                        { k: "GlassOS memory", v: System.appMemMB + " MB" }
                    ]
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        height: UI.px(56)
                        radius: UI.radius
                        color: UI.card
                        border.color: UI.border
                        Column {
                            anchors.centerIn: parent
                            Text { font.weight: UI.textWeight; anchors.horizontalCenter: parent.horizontalCenter; text: modelData.v; color: UI.text; font.pixelSize: UI.px(15) }
                            Text { font.weight: UI.textWeight; anchors.horizontalCenter: parent.horizontalCenter; text: modelData.k; color: UI.textFaint; font.pixelSize: UI.px(11) }
                        }
                    }
                }
            }
        }
    }
}
