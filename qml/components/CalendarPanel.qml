// Clock flyout: notification history + month calendar.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../ui"

Popup {
    id: cal
    parent: Overlay.overlay
    width: UI.px(340)
    // never taller than the space above the taskbar; the notification list gives way
    height: Math.min(implicitHeight, parent ? parent.height - UI.taskbarHeight - 20 : implicitHeight)
    x: parent ? parent.width - width - 10 : 0
    // slide-in offset: animating y directly would replace this binding with a fixed number,
    // so a popup that grows after opening (e.g. notifications) would hang off the screen
    property real slide: 0
    y: (parent ? parent.height - UI.taskbarHeight - height - 10 : 0) + slide
    padding: 16
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    property double closedAt: 0      // lets the taskbar button toggle without instantly reopening
    onClosed: closedAt = Date.now()

    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()
    readonly property var notes: UI.wm ? UI.wm.notificationHistory : []

    onOpened: {
        var d = new Date(); viewYear = d.getFullYear(); viewMonth = d.getMonth()
        if (UI.wm) UI.wm.unreadCount = 0
    }
    function shift(n) {
        var m = viewMonth + n, y = viewYear
        while (m < 0) { m += 12; y-- }
        while (m > 11) { m -= 12; y++ }
        viewMonth = m; viewYear = y
    }

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: UI.dur(140) }
        NumberAnimation { property: "slide"; from: 24; to: 0; duration: UI.dur(200); easing.type: Easing.OutCubic }
    }
    exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: UI.dur(90) } }
    background: GlassSurface { sceneX: cal.x; sceneY: cal.y; radius: UI.radiusLarge; borderColor: UI.borderStrong }

    contentItem: ColumnLayout {
        spacing: 12

        Row {
            Layout.fillWidth: true
            Text { elide: Text.ElideRight; width: parent.width - clearBtn.width; text: "Notifications"; color: UI.text; font.pixelSize: UI.px(14); font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
            GButton { id: clearBtn; text: "Clear"; kind: "flat"; visible: cal.notes.length > 0; onClicked: UI.wm.notificationHistory = [] }
        }
        Text { font.weight: UI.textWeight; visible: cal.notes.length === 0; text: "You're all caught up"; color: UI.textFaint; font.pixelSize: UI.px(12) }
        ListView {
            id: noteList
            visible: cal.notes.length > 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: Math.min(contentHeight, UI.px(230))
            Layout.minimumHeight: Math.min(contentHeight, UI.px(70))
            clip: true
            spacing: 6
            model: cal.notes
            ScrollBar.vertical: GScrollBar {}
            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                height: UI.px(26)
                visible: noteList.contentHeight > noteList.height + 2 && !noteList.atYEnd
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 1; color: Qt.rgba(0.07, 0.09, 0.12, 0.85) }
                }
            }
            delegate: Rectangle {
                width: ListView.view.width
                height: noteCol.implicitHeight + 16
                radius: UI.radiusSmall
                color: UI.card
                MouseArea {
                    anchors.fill: parent
                    enabled: typeof modelData.action === "function"
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { var a = modelData.action; cal.close(); a() }
                }
                Row {
                    id: noteCol
                    x: 10; y: 8
                    spacing: 10
                    Icon { name: modelData.icon; size: UI.px(18) }
                    Column {
                        width: cal.availableWidth - UI.px(50)
                        Text { width: parent.width; text: modelData.title; color: UI.text; font.pixelSize: UI.px(12); font.weight: Font.Medium; elide: Text.ElideRight }
                        Text { font.weight: UI.textWeight; width: parent.width; text: modelData.body; visible: modelData.body !== ""; color: UI.textDim; font.pixelSize: UI.px(11); wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight }
                        Text { font.weight: UI.textWeight; text: UI.timeText(new Date(modelData.time)); color: UI.textFaint; font.pixelSize: UI.px(10) }
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: UI.border }

        Column {
            Layout.fillWidth: true
            spacing: 0
            Text { text: UI.timeText(UI.now); color: UI.text; font.pixelSize: UI.px(30); font.weight: Font.Light }
            Text { font.weight: UI.textWeight; text: Qt.formatDate(UI.now, "dddd, MMMM d, yyyy"); color: UI.textDim; font.pixelSize: UI.px(12) }
        }

        Row {
            Layout.fillWidth: true
            Text {
                elide: Text.ElideRight
                width: parent.width - 2 * UI.px(32)
                text: Qt.formatDate(new Date(cal.viewYear, cal.viewMonth, 1), "MMMM yyyy")
                color: UI.text; font.pixelSize: UI.px(13); font.weight: Font.DemiBold
                anchors.verticalCenter: parent.verticalCenter
            }
            IconButton { iconName: "chevron-left"; glyphSize: 18; onClicked: cal.shift(-1) }
            IconButton { iconName: "chevron-right"; glyphSize: 18; onClicked: cal.shift(1) }
        }

        Grid {
            id: days
            columns: 7
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            readonly property real cell: width / 7
            readonly property int firstDay: new Date(cal.viewYear, cal.viewMonth, 1).getDay()
            readonly property int monthDays: new Date(cal.viewYear, cal.viewMonth + 1, 0).getDate()
            Repeater {
                model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
                Text { elide: Text.ElideRight; font.weight: UI.textWeight; width: days.cell; height: UI.px(24); text: modelData; color: UI.textFaint; font.pixelSize: UI.px(11); horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
            Repeater {
                // only as many week rows as this month needs (5 most months, sometimes 4 or 6)
                model: Math.ceil((days.firstDay + days.monthDays) / 7) * 7
                delegate: Item {
                    width: days.cell
                    height: UI.px(34)
                    readonly property int day: index - days.firstDay + 1
                    readonly property bool inMonth: day >= 1 && day <= days.monthDays
                    readonly property bool today: inMonth && day === UI.now.getDate() && cal.viewMonth === UI.now.getMonth() && cal.viewYear === UI.now.getFullYear()
                    Rectangle {
                        anchors.centerIn: parent
                        width: UI.px(30); height: width; radius: width / 2
                        color: parent.today ? UI.accent : "transparent"
                    }
                    Text {
                        anchors.centerIn: parent
                        text: parent.inMonth ? parent.day : ""
                        color: parent.today ? UI.accentText : UI.text
                        font.pixelSize: UI.px(12)
                        font.bold: parent.today
                    }
                }
            }
        }
    }
}
