import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../ui"
import "../components"

FocusScope {
    id: wx
    property var hostWindow: null
    readonly property var cur: WeatherService.current
    readonly property bool fahrenheit: Prefs.weatherUnit === "F"
    property bool searching: false

    // Choosing a city clears searchResults, which destroys the delegate that was
    // clicked; so all UI work happens here (root context) before the model changes.
    function pick(i) {
        search.text = ""
        searching = false
        wx.forceActiveFocus()
        WeatherService.choose(i)
    }

    function t(c) { return UI.temp(c, false) }   // shared converter (same as taskbar and desktop)
    function windDir(deg) { return ["N", "NE", "E", "SE", "S", "SW", "W", "NW"][Math.round(((deg % 360) / 45)) % 8] }
    function uvText(u) { return u < 3 ? "Low" : u < 6 ? "Moderate" : u < 8 ? "High" : u < 11 ? "Very high" : "Extreme" }

    readonly property var skyTop: !WeatherService.hasData ? "#1e3a5f" : (cur.isDay ? (cur.condition.indexOf("Clear") >= 0 || cur.condition.indexOf("Mainly") >= 0 ? "#2f7dd1" : "#4b5d78") : "#0d1530")
    readonly property var skyBottom: !WeatherService.hasData ? "#0f1c30" : (cur.isDay ? "#163056" : "#05070f")

    Component.onCompleted: { WeatherService.refreshIfStale(); if (hostWindow) hostWindow.title = "Weather" }

    Rectangle {
        anchors.fill: parent
        opacity: 0.85
        gradient: Gradient {
            GradientStop { position: 0; color: wx.skyTop }
            GradientStop { position: 1; color: wx.skyBottom }
        }
    }

    // ------------------------------------------------------------ top bar
    RowLayout {
        id: topBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 6
        GTextField {
            id: search
            Layout.fillWidth: true
            leading: "search"
            placeholderText: "Search for a city…"
            onTextEdited: debounce.restart()
            onAccepted: { WeatherService.search(text); wx.searching = true }
            onActiveFocusChanged: if (activeFocus) wx.searching = true
            Keys.onEscapePressed: { text = ""; wx.searching = false; wx.forceActiveFocus() }
            Keys.onDownPressed: results.forceActiveFocus()
            Timer { id: debounce; interval: 350; onTriggered: { WeatherService.search(search.text); wx.searching = search.text.length > 0 } }
        }
        GButton {
            text: wx.fahrenheit ? "°F" : "°C"
            onClicked: Prefs.setWeatherUnit(wx.fahrenheit ? "C" : "F")
        }
        IconButton {
            iconName: "refresh"; tip: "Refresh"
            enabled: !WeatherService.loading
            onClicked: WeatherService.refresh()
            RotationAnimation on rotation { running: WeatherService.loading; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
        }
    }

    // ------------------------------------------------------------ content
    Flickable {
        id: flick
        anchors.top: topBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: 8
        contentHeight: content.implicitHeight + 24
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        visible: WeatherService.hasData
        ScrollBar.vertical: GScrollBar {}

        Column {
            id: content
            width: flick.width - 24
            x: 12
            spacing: 14

            // hero
            Item {
                width: parent.width
                height: UI.px(170)
                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text { text: WeatherService.city; color: "white"; font.pixelSize: UI.px(26); font.weight: Font.DemiBold }
                    Text { font.weight: UI.textWeight; text: WeatherService.region; color: Qt.rgba(1, 1, 1, 0.7); font.pixelSize: UI.px(13); visible: text !== "" }
                    Text { text: wx.t(wx.cur.temp); color: "white"; font.pixelSize: UI.px(78); font.weight: Font.Light }
                    Text { font.weight: UI.textWeight; text: wx.cur.condition + "  ·  Feels like " + wx.t(wx.cur.feelsLike); color: Qt.rgba(1, 1, 1, 0.85); font.pixelSize: UI.px(14) }
                }
                Icon {
                    anchors.right: parent.right
                    anchors.rightMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    name: wx.cur.icon || ""
                    size: UI.px(130)
                    transform: Translate { id: bob }
                    SequentialAnimation {
                        running: UI.animations && wx.visible
                        loops: Animation.Infinite
                        NumberAnimation { target: bob; property: "y"; from: -4; to: 4; duration: 2600; easing.type: Easing.InOutSine }
                        NumberAnimation { target: bob; property: "y"; from: 4; to: -4; duration: 2600; easing.type: Easing.InOutSine }
                    }
                }
                Text {
                    elide: Text.ElideRight
                    font.weight: UI.textWeight
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: 8
                    text: "H " + wx.t(wx.cur.high) + "   L " + wx.t(wx.cur.low) + "   ·   Updated " + (wx.cur.updated || "")
                    color: Qt.rgba(1, 1, 1, 0.6)
                    font.pixelSize: UI.px(11.5)
                }
            }

            // hourly
            Rectangle {
                width: parent.width
                height: UI.px(118)
                radius: UI.radius
                color: Qt.rgba(0, 0, 0, 0.22)
                border.color: UI.border
                ListView {
                    id: hourly
                    anchors.fill: parent
                    anchors.margins: 8
                    orientation: ListView.Horizontal
                    clip: true
                    spacing: 4
                    model: WeatherService.hourly
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.horizontal: GScrollBar {}
                    delegate: Column {
                        width: UI.px(58)
                        spacing: 5
                        topPadding: 6
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.time; color: index === 0 ? "white" : UI.textDim; font.pixelSize: UI.px(11.5); font.bold: index === 0 }
                        Icon { name: modelData.icon; size: UI.px(22); anchors.horizontalCenter: parent.horizontalCenter }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: wx.t(modelData.temp); color: "white"; font.pixelSize: UI.px(13); font.weight: Font.DemiBold }
                        Text { font.weight: UI.textWeight; anchors.horizontalCenter: parent.horizontalCenter; text: modelData.rain > 0 ? modelData.rain + "%" : " "; color: "#7cc4ff"; font.pixelSize: UI.px(10) }
                    }
                }
            }

            // 7-day + details side by side when wide
            Flow {
                width: parent.width
                spacing: 14

                Rectangle {
                    id: daily
                    width: content.width >= 680 ? (content.width - 14) * 0.55 : content.width
                    height: dayCol.implicitHeight + 20
                    radius: UI.radius
                    color: Qt.rgba(0, 0, 0, 0.22)
                    border.color: UI.border
                    readonly property real minT: { var m = 999; WeatherService.forecast.forEach(function (d) { m = Math.min(m, d.low) }); return m }
                    readonly property real maxT: { var m = -999; WeatherService.forecast.forEach(function (d) { m = Math.max(m, d.high) }); return m }
                    Column {
                        id: dayCol
                        x: 14; y: 10
                        width: parent.width - 28
                        Text { font.weight: UI.textWeight; text: "7-day forecast"; color: UI.textDim; font.pixelSize: UI.px(11.5); bottomPadding: 6 }
                        Repeater {
                            model: WeatherService.forecast
                            delegate: Item {
                                width: dayCol.width
                                height: UI.px(38)
                                Text { elide: Text.ElideRight; font.weight: UI.textWeight; id: dname; width: UI.px(54); text: modelData.day; color: "white"; font.pixelSize: UI.px(13); anchors.verticalCenter: parent.verticalCenter }
                                Icon { name: modelData.icon; size: UI.px(18); id: dicon; x: dname.width; width: UI.px(36); anchors.verticalCenter: parent.verticalCenter }
                                Text {
                                    elide: Text.ElideRight
                                    font.weight: UI.textWeight
                                    id: drain; x: dicon.x + dicon.width; width: UI.px(40)
                                    text: modelData.rain >= 20 ? modelData.rain + "%" : ""
                                    color: "#7cc4ff"; font.pixelSize: UI.px(11); anchors.verticalCenter: parent.verticalCenter
                                }
                                Text { elide: Text.ElideRight; font.weight: UI.textWeight; id: lowT; x: drain.x + drain.width; width: UI.px(36); text: wx.t(modelData.low); color: UI.textDim; font.pixelSize: UI.px(13); horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
                                Rectangle {
                                    id: track
                                    x: lowT.x + lowT.width + 10
                                    width: parent.width - x - UI.px(46)
                                    height: 5; radius: 2.5
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Qt.rgba(1, 1, 1, 0.12)
                                    readonly property real span: Math.max(1, daily.maxT - daily.minT)
                                    Rectangle {
                                        x: (modelData.low - daily.minT) / track.span * track.width
                                        width: Math.max(6, (modelData.high - modelData.low) / track.span * track.width)
                                        height: parent.height; radius: 2.5
                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop { position: 0; color: "#5ec8ff" }
                                            GradientStop { position: 1; color: modelData.high > 25 ? "#ff9f43" : "#ffe066" }
                                        }
                                    }
                                }
                                Text { elide: Text.ElideRight; font.weight: UI.textWeight; anchors.right: parent.right; width: UI.px(36); text: wx.t(modelData.high); color: "white"; font.pixelSize: UI.px(13); horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
                            }
                        }
                    }
                }

                Grid {
                    width: content.width >= 680 ? (content.width - 14) * 0.45 : content.width
                    columns: 2
                    spacing: 10
                    Repeater {
                        model: [
                            { icon: "wind", label: "Wind", value: (wx.cur.windSpeed || 0) + " km/h " + wx.windDir(wx.cur.windDirection || 0) },
                            { icon: "drop", label: "Humidity", value: (wx.cur.humidity || 0) + "%" },
                            { icon: "sun", label: "UV index", value: (wx.cur.uvIndex || 0) + " · " + wx.uvText(wx.cur.uvIndex || 0) },
                            { icon: "cloud", label: "Cloud cover", value: (wx.cur.cloudCover || 0) + "%" },
                            { icon: "sunrise", label: "Sunrise", value: wx.cur.sunrise || "–" },
                            { icon: "sunset", label: "Sunset", value: wx.cur.sunset || "–" },
                            { icon: "gauge", label: "Pressure", value: (wx.cur.pressure || 0) + " hPa" },
                            { icon: "thermometer", label: "Feels like", value: wx.t(wx.cur.feelsLike) }
                        ]
                        delegate: Rectangle {
                            width: (parent.width - 10) / 2
                            height: UI.px(70)
                            radius: UI.radius
                            color: Qt.rgba(0, 0, 0, 0.22)
                            border.color: UI.border
                            Column {
                                x: 12
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4
                                Row { spacing: 6; Icon { name: modelData.icon; size: UI.px(14); anchors.verticalCenter: parent.verticalCenter } Text { font.weight: UI.textWeight; text: modelData.label; color: UI.textDim; font.pixelSize: UI.px(11.5) } }
                                Text { text: modelData.value; color: "white"; font.pixelSize: UI.px(15); font.weight: Font.DemiBold }
                            }
                        }
                    }
                }
            }

            Text { font.weight: UI.textWeight; text: "Data: Open-Meteo.com"; color: UI.textFaint; font.pixelSize: UI.px(10.5) }
        }
    }

    // ------------------------------------------------------------ empty / error
    Column {
        visible: !WeatherService.hasData
        anchors.centerIn: parent
        spacing: 12
        width: parent.width - 60
        BusyIndicator { anchors.horizontalCenter: parent.horizontalCenter; running: WeatherService.loading; visible: running }
        Icon { visible: !WeatherService.loading; anchors.horizontalCenter: parent.horizontalCenter; name: WeatherService.error !== "" ? "wifi" : "wx-partly-day"; size: 72; opacity: WeatherService.error !== "" ? 0.6 : 1 }
        Text {
            font.weight: UI.textWeight
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: WeatherService.loading ? "Fetching the forecast for " + WeatherService.city + "…"
                 : (WeatherService.error !== "" ? WeatherService.error : "No weather yet")
            color: "white"
            font.pixelSize: UI.px(15)
        }
        GButton {
            visible: !WeatherService.loading
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Try again"; kind: "primary"
            onClicked: WeatherService.refresh()
        }
    }

    // ------------------------------------------------------------ search results
    Rectangle {
        visible: wx.searching && (WeatherService.searchResults.length > 0 || WeatherService.searching || search.text.length >= 2)
        anchors.top: topBar.bottom
        anchors.left: topBar.left
        anchors.topMargin: 4
        width: search.width
        height: Math.min(UI.px(320), Math.max(UI.px(44), results.contentHeight + 12))
        radius: UI.radius
        color: "#182030"
        border.color: UI.borderStrong
        z: 10
        ListView {
            id: results
            anchors.fill: parent
            anchors.margins: 6
            clip: true
            model: WeatherService.searchResults
            keyNavigationEnabled: true
            Keys.onReturnPressed: wx.pick(currentIndex)
            Keys.onEscapePressed: { wx.searching = false; search.forceActiveFocus() }
            highlight: Rectangle { radius: UI.radiusSmall; color: UI.accentSoft }
            delegate: Item {
                width: results.width
                height: UI.px(42)
                Column {
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    Text { font.weight: UI.textWeight; text: modelData.name; color: UI.text; font.pixelSize: UI.px(13) }
                    Text { font.weight: UI.textWeight; text: [modelData.admin, modelData.country].filter(function (s) { return s }).join(", "); color: UI.textFaint; font.pixelSize: UI.px(11) }
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: results.currentIndex = index
                    onClicked: wx.pick(index)
                }
            }
            Text {
                font.weight: UI.textWeight
                visible: results.count === 0
                anchors.centerIn: parent
                text: WeatherService.searching ? "Searching…" : "No places found"
                color: UI.textFaint; font.pixelSize: UI.px(12)
            }
        }
    }
}
