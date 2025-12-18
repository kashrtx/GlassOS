// GlassOS Weather App - Modern Design with Dynamic Search
// Complete overhaul with hourly forecast, better UI, and city persistence
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../components"

Rectangle {
    id: weatherApp
    color: "transparent"
    
    // Use real weather service if available
    property bool hasWeatherService: typeof WeatherService !== 'undefined'
    
    // Weather data bindings
    property string city: hasWeatherService ? WeatherService.city : "New York"
    property string country: hasWeatherService ? WeatherService.country : "US"
    property int temp: hasWeatherService ? WeatherService.temp : 22
    property int feelsLike: hasWeatherService ? WeatherService.feelsLike : 20
    property string condition: hasWeatherService ? WeatherService.condition : "Loading..."
    property string weatherIcon: hasWeatherService ? WeatherService.icon : "⏳"
    property int humidity: hasWeatherService ? WeatherService.humidity : 0
    property int windSpeed: hasWeatherService ? WeatherService.windSpeed : 0
    property int windDirection: hasWeatherService ? WeatherService.windDirection : 0
    property int pressure: hasWeatherService ? WeatherService.pressure : 0
    property int cloudCover: hasWeatherService ? WeatherService.cloudCover : 0
    property int high: hasWeatherService ? WeatherService.high : 0
    property int low: hasWeatherService ? WeatherService.low : 0
    property string sunrise: hasWeatherService ? WeatherService.sunrise : ""
    property string sunset: hasWeatherService ? WeatherService.sunset : ""
    property int uvIndex: hasWeatherService ? WeatherService.uvIndex : 0
    property string lastUpdated: hasWeatherService ? WeatherService.lastUpdated : ""
    property bool isLoading: hasWeatherService ? WeatherService.isLoading : false
    property var forecast: hasWeatherService ? WeatherService.forecast : []
    property var searchResults: hasWeatherService ? WeatherService.searchResults : []
    
    property bool useCelsius: true
    property bool showSearch: false
    property string searchQuery: ""
    
    // Temperature conversion
    function toFahrenheit(celsius) {
        return Math.round(celsius * 9/5 + 32)
    }
    
    function displayTemp(celsius) {
        if (typeof celsius !== 'number') return "—"
        return useCelsius ? celsius + "°" : toFahrenheit(celsius) + "°"
    }
    
    function displayTempFull(celsius) {
        if (typeof celsius !== 'number') return "—"
        return useCelsius ? celsius + "°C" : toFahrenheit(celsius) + "°F"
    }
    
    // Wind direction to text
    function windDirectionText(degrees) {
        var directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                          "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        var index = Math.round(degrees / 22.5) % 16
        return directions[index]
    }
    
    // Format time from ISO string
    function formatTime(isoString) {
        if (!isoString) return "—"
        try {
            var date = new Date(isoString)
            return date.toLocaleTimeString(Qt.locale(), "h:mm AP")
        } catch (e) {
            return "—"
        }
    }
    
    // UV Index description
    function uvDescription(index) {
        if (index <= 2) return "Low"
        if (index <= 5) return "Moderate"
        if (index <= 7) return "High"
        if (index <= 10) return "Very High"
        return "Extreme"
    }
    
    function uvColor(index) {
        if (index <= 2) return "#22c55e"  // Green
        if (index <= 5) return "#eab308"  // Yellow
        if (index <= 7) return "#f97316"  // Orange
        if (index <= 10) return "#ef4444" // Red
        return "#7c3aed"  // Purple
    }
    
    // Get current date info
    function getCurrentDate() {
        var now = new Date()
        var options = { weekday: 'long', month: 'long', day: 'numeric' }
        return now.toLocaleDateString('en-US', options)
    }
    
    // Select city from search results
    function selectCity(index) {
        if (hasWeatherService) {
            WeatherService.selectSearchResult(index)
            showSearch = false
            searchQuery = ""
        }
    }
    
    Component.onCompleted: {
        if (hasWeatherService) {
            WeatherService.refresh()
        }
    }
    
    // Dynamic background gradient based on weather
    Rectangle {
        anchors.fill: parent
        radius: 0
        
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { 
                position: 0.0
                color: {
                    var cond = condition.toLowerCase()
                    if (cond.includes("rain") || cond.includes("thunder")) return "#1a365d"
                    if (cond.includes("cloud") || cond.includes("overcast")) return "#374151"
                    if (cond.includes("snow")) return "#4b5563"
                    if (cond.includes("fog")) return "#3f3f46"
                    return "#0369a1"  // Blue sky
                }
            }
            GradientStop { 
                position: 1.0
                color: {
                    var cond = condition.toLowerCase()
                    if (cond.includes("rain") || cond.includes("thunder")) return "#0f172a"
                    if (cond.includes("cloud") || cond.includes("overcast")) return "#1f2937"
                    if (cond.includes("snow")) return "#374151"
                    if (cond.includes("fog")) return "#27272a"
                    return "#075985"
                }
            }
        }
    }
    
    // ===== MAIN LAYOUT =====
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        
        // ===== HEADER WITH SEARCH =====
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            color: Qt.rgba(0, 0, 0, 0.2)
            
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 12
                
                // Search Bar
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: 20
                    color: Qt.rgba(0, 0, 0, 0.3)
                    border.width: searchInput.activeFocus ? 2 : 1
                    border.color: searchInput.activeFocus ? "#60a5fa" : Qt.rgba(1, 1, 1, 0.1)
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 12
                        spacing: 10
                        
                        Text {
                            text: showSearch ? "🔍" : "📍"
                            font.pixelSize: 16
                        }
                        
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            
                            // City display
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !showSearch
                                spacing: 8
                                
                                Text {
                                    text: city
                                    font.pixelSize: 15
                                    font.family: "Segoe UI"
                                    font.weight: Font.Medium
                                    color: "#ffffff"
                                }
                                
                                Text {
                                    text: country ? "(" + country + ")" : ""
                                    font.pixelSize: 12
                                    color: Qt.rgba(1, 1, 1, 0.6)
                                    visible: country !== ""
                                }
                            }
                            
                            // Search input
                            TextInput {
                                id: searchInput
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                visible: showSearch
                                font.pixelSize: 14
                                font.family: "Segoe UI"
                                color: "#ffffff"
                                clip: true
                                selectByMouse: true
                                
                                onTextChanged: {
                                    searchQuery = text
                                    if (text.length >= 2 && hasWeatherService) {
                                        searchDebounce.restart()
                                    }
                                }
                                
                                onAccepted: {
                                    if (searchResults.length > 0) {
                                        weatherApp.selectCity(0)
                                    }
                                }
                                
                                Keys.onEscapePressed: {
                                    showSearch = false
                                    text = ""
                                }
                                
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Search for a city..."
                                    font: parent.font
                                    color: "#666"
                                    visible: !searchInput.text && !searchInput.activeFocus
                                }
                            }
                        }
                        
                        // Search toggle button
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: searchToggleMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                            
                            Text {
                                anchors.centerIn: parent
                                text: showSearch ? "✕" : "🔍"
                                font.pixelSize: 14
                            }
                            
                            MouseArea {
                                id: searchToggleMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    showSearch = !showSearch
                                    if (showSearch) {
                                        searchInput.text = ""
                                        searchInput.forceActiveFocus()
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Unit toggle (C/F)
                Rectangle {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 40
                    radius: 20
                    color: unitMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.3)
                    
                    Text {
                        anchors.centerIn: parent
                        text: useCelsius ? "°C" : "°F"
                        font.pixelSize: 14
                        font.bold: true
                        color: "#ffffff"
                    }
                    
                    MouseArea {
                        id: unitMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: useCelsius = !useCelsius
                    }
                }
                
                // Refresh
                Rectangle {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    radius: 20
                    color: refreshMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.3)
                    
                    Text {
                        anchors.centerIn: parent
                        text: "↻"
                        font.pixelSize: 18
                        color: "#ffffff"
                        
                        RotationAnimation on rotation {
                            running: isLoading
                            from: 0; to: 360
                            duration: 1000
                            loops: Animation.Infinite
                        }
                    }
                    
                    MouseArea {
                        id: refreshMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (hasWeatherService) WeatherService.refresh()
                    }
                }
            }
        }
        
        // Search debounce timer
        Timer {
            id: searchDebounce
            interval: 400
            onTriggered: {
                if (hasWeatherService && searchQuery.length >= 2) {
                    WeatherService.searchCity(searchQuery)
                }
            }
        }
        
        // ===== SEARCH RESULTS DROPDOWN =====
        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.preferredHeight: showSearch && searchResults.length > 0 ? Math.min(280, searchResults.length * 50 + 16) : 0
            visible: height > 0
            radius: 12
            color: Qt.rgba(0.1, 0.12, 0.16, 0.98)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.1)
            clip: true
            z: 100
            
            Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
            
            // Shadow
            Rectangle {
                anchors.fill: parent
                anchors.margins: -8
                radius: 16
                color: Qt.rgba(0, 0, 0, 0.4)
                z: -1
            }
            
            ListView {
                anchors.fill: parent
                anchors.margins: 8
                model: searchResults
                clip: true
                spacing: 4
                
                delegate: Rectangle {
                    width: ListView.view.width
                    height: 46
                    radius: 8
                    color: resultMouse.containsMouse ? Qt.rgba(0.3, 0.5, 0.8, 0.4) : Qt.rgba(1, 1, 1, 0.05)
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12
                        
                        Text {
                            text: "📍"
                            font.pixelSize: 16
                        }
                        
                        Column {
                            Layout.fillWidth: true
                            spacing: 2
                            
                            Text {
                                text: modelData.name
                                font.pixelSize: 14
                                font.weight: Font.Medium
                                color: "#ffffff"
                            }
                            
                            Text {
                                text: (modelData.admin1 ? modelData.admin1 + ", " : "") + modelData.country
                                font.pixelSize: 11
                                color: Qt.rgba(1, 1, 1, 0.6)
                            }
                        }
                        
                        Text {
                            text: modelData.country_code || ""
                            font.pixelSize: 11
                            color: Qt.rgba(1, 1, 1, 0.4)
                        }
                    }
                    
                    MouseArea {
                        id: resultMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: weatherApp.selectCity(index)
                    }
                }
            }
        }
        
        // ===== MAIN CONTENT =====
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            
            ColumnLayout {
                width: weatherApp.width
                spacing: 16
                
                // ===== CURRENT WEATHER HERO =====
                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 20
                    Layout.rightMargin: 20
                    Layout.topMargin: 16
                    Layout.preferredHeight: 200
                    radius: 20
                    color: Qt.rgba(0, 0, 0, 0.15)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.08)
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 24
                        spacing: 24
                        
                        // Left - Temperature & Condition
                        Column {
                            Layout.fillWidth: true
                            spacing: 8
                            
                            // Date
                            Text {
                                text: getCurrentDate()
                                font.pixelSize: 13
                                color: Qt.rgba(1, 1, 1, 0.7)
                            }
                            
                            // Icon + Temp row
                            Row {
                                spacing: 20
                                
                                Text {
                                    text: weatherIcon
                                    font.pixelSize: 80
                                    
                                    SequentialAnimation on y {
                                        loops: Animation.Infinite
                                        NumberAnimation { to: -5; duration: 2500; easing.type: Easing.InOutSine }
                                        NumberAnimation { to: 0; duration: 2500; easing.type: Easing.InOutSine }
                                    }
                                }
                                
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 0
                                    
                                    Text {
                                        text: displayTemp(temp)
                                        font.pixelSize: 72
                                        font.family: "Segoe UI"
                                        font.weight: Font.Light
                                        color: "#ffffff"
                                    }
                                    
                                    Text {
                                        text: condition
                                        font.pixelSize: 20
                                        color: Qt.rgba(1, 1, 1, 0.9)
                                    }
                                }
                            }
                            
                            // High/Low and Feels Like
                            Row {
                                spacing: 24
                                
                                Row {
                                    spacing: 12
                                    Text { 
                                        text: "↑ " + displayTemp(high)
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        color: "#fbbf24"
                                    }
                                    Text { 
                                        text: "↓ " + displayTemp(low)
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        color: "#60a5fa"
                                    }
                                }
                                
                                Text {
                                    text: "Feels like " + displayTemp(feelsLike)
                                    font.pixelSize: 14
                                    color: Qt.rgba(1, 1, 1, 0.7)
                                }
                            }
                        }
                        
                        // Vertical divider
                        Rectangle {
                            Layout.fillHeight: true
                            Layout.preferredWidth: 1
                            color: Qt.rgba(1, 1, 1, 0.1)
                        }
                        
                        // Right - Key Stats Grid
                        GridLayout {
                            columns: 2
                            rowSpacing: 16
                            columnSpacing: 24
                            
                            WeatherStatCard { icon: "💧"; label: "Humidity"; value: humidity + "%" }
                            WeatherStatCard { icon: "💨"; label: "Wind"; value: windSpeed + " km/h " + windDirectionText(windDirection) }
                            WeatherStatCard { icon: "🌡"; label: "Pressure"; value: pressure + " hPa" }
                            WeatherStatCard { icon: "☁️"; label: "Cloud Cover"; value: cloudCover + "%" }
                            WeatherStatCard { icon: "🌅"; label: "Sunrise"; value: formatTime(sunrise) }
                            WeatherStatCard { icon: "🌇"; label: "Sunset"; value: formatTime(sunset) }
                        }
                    }
                    
                    // Loading overlay
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Qt.rgba(0, 0, 0, 0.7)
                        visible: isLoading
                        
                        Column {
                            anchors.centerIn: parent
                            spacing: 16
                            
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "⏳"
                                font.pixelSize: 40
                                
                                RotationAnimation on rotation {
                                    running: isLoading
                                    from: 0; to: 360
                                    duration: 1200
                                    loops: Animation.Infinite
                                }
                            }
                            
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Fetching weather..."
                                font.pixelSize: 14
                                color: "#ffffff"
                            }
                        }
                    }
                }
                
                // ===== UV INDEX BAR =====
                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 20
                    Layout.rightMargin: 20
                    Layout.preferredHeight: 60
                    radius: 14
                    color: Qt.rgba(0, 0, 0, 0.15)
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 16
                        
                        Text {
                            text: "☀️"
                            font.pixelSize: 24
                        }
                        
                        Column {
                            Layout.fillWidth: true
                            spacing: 6
                            
                            RowLayout {
                                width: parent.width
                                
                                Text {
                                    text: "UV Index"
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                    color: Qt.rgba(1, 1, 1, 0.8)
                                }
                                
                                Item { Layout.fillWidth: true }
                                
                                Rectangle {
                                    width: uvLabelRow.width + 16
                                    height: 22
                                    radius: 11
                                    color: uvColor(uvIndex)
                                    opacity: 0.9
                                    
                                    Row {
                                        id: uvLabelRow
                                        anchors.centerIn: parent
                                        spacing: 4
                                        
                                        Text {
                                            text: uvIndex
                                            font.pixelSize: 12
                                            font.bold: true
                                            color: "#ffffff"
                                        }
                                        Text {
                                            text: "•"
                                            font.pixelSize: 8
                                            color: Qt.rgba(1, 1, 1, 0.7)
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: uvDescription(uvIndex)
                                            font.pixelSize: 11
                                            color: "#ffffff"
                                        }
                                    }
                                }
                            }
                            
                            // UV gradient bar
                            Rectangle {
                                width: parent.width
                                height: 8
                                radius: 4
                                
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: "#22c55e" }
                                    GradientStop { position: 0.27; color: "#eab308" }
                                    GradientStop { position: 0.54; color: "#f97316" }
                                    GradientStop { position: 0.81; color: "#ef4444" }
                                    GradientStop { position: 1.0; color: "#7c3aed" }
                                }
                                
                                // Indicator
                                Rectangle {
                                    x: parent.width * Math.min(uvIndex / 11, 1) - 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 12
                                    height: 12
                                    radius: 6
                                    color: "#ffffff"
                                    border.width: 2
                                    border.color: uvColor(uvIndex)
                                    
                                    Behavior on x { NumberAnimation { duration: 300 } }
                                }
                            }
                        }
                    }
                }
                
                // ===== 7-DAY FORECAST HEADER =====
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 20
                    Layout.rightMargin: 20
                    Layout.topMargin: 8
                    
                    Text {
                        text: "7-Day Forecast"
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        color: "#ffffff"
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    Text {
                        text: lastUpdated ? "Updated " + lastUpdated : ""
                        font.pixelSize: 11
                        color: Qt.rgba(1, 1, 1, 0.5)
                    }
                }
                
                // ===== 7-DAY FORECAST HORIZONTAL CARDS =====
                ScrollView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 140
                    Layout.leftMargin: 12
                    Layout.rightMargin: 12
                    clip: true
                    ScrollBar.horizontal.policy: ScrollBar.AsNeeded
                    ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                    
                    Row {
                        spacing: 10
                        padding: 8
                        
                        Repeater {
                            model: forecast
                            
                            Rectangle {
                                width: 110
                                height: 120
                                radius: 14
                                color: forecastMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
                                border.width: forecastMouse.containsMouse ? 1 : 0
                                border.color: Qt.rgba(1, 1, 1, 0.2)
                                
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.day || ""
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                        color: Qt.rgba(1, 1, 1, 0.8)
                                    }
                                    
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.icon || "❓"
                                        font.pixelSize: 32
                                    }
                                    
                                    Row {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: 8
                                        
                                        Text {
                                            text: displayTemp(modelData.high)
                                            font.pixelSize: 15
                                            font.bold: true
                                            color: "#ffffff"
                                        }
                                        
                                        Text {
                                            text: "/"
                                            font.pixelSize: 13
                                            color: Qt.rgba(1, 1, 1, 0.4)
                                        }
                                        
                                        Text {
                                            text: displayTemp(modelData.low)
                                            font.pixelSize: 13
                                            color: Qt.rgba(1, 1, 1, 0.5)
                                        }
                                    }
                                    
                                    // Precipitation indicator
                                    Row {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: 4
                                        visible: (modelData.precipitation || 0) > 0
                                        
                                        Text {
                                            text: "💧"
                                            font.pixelSize: 10
                                        }
                                        Text {
                                            text: (modelData.precipitation || 0).toFixed(1) + " mm"
                                            font.pixelSize: 10
                                            color: "#60a5fa"
                                        }
                                    }
                                }
                                
                                MouseArea {
                                    id: forecastMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    
                                    ToolTip.visible: containsMouse
                                    ToolTip.text: (modelData.condition || "") + 
                                        "\nPrecipitation: " + (modelData.precipitation || 0).toFixed(1) + " mm" +
                                        "\nUV Index: " + (modelData.uv_index || 0)
                                    ToolTip.delay: 400
                                }
                                
                                scale: forecastMouse.containsMouse ? 1.03 : 1.0
                                Behavior on scale { NumberAnimation { duration: 100 } }
                            }
                        }
                    }
                }
                
                // Bottom spacer
                Item { Layout.preferredHeight: 20 }
            }
        }
    }
    
    // ===== COMPONENT: Weather Stat Card =====
    component WeatherStatCard: Row {
        property string icon: ""
        property string label: ""
        property string value: ""
        
        spacing: 8
        
        Text {
            text: icon
            font.pixelSize: 16
        }
        
        Column {
            spacing: 2
            
            Text {
                text: label
                font.pixelSize: 10
                color: Qt.rgba(1, 1, 1, 0.6)
            }
            
            Text {
                text: value
                font.pixelSize: 12
                font.weight: Font.Medium
                color: "#ffffff"
            }
        }
    }
}
