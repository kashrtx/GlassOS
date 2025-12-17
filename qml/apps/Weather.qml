// GlassOS Weather App - Real Weather Data with City Search
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
            return date.toLocaleTimeString(Qt.locale(), "HH:mm")
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
    
    // Background gradient based on time/weather
    Rectangle {
        anchors.fill: parent
        radius: 8
        
        gradient: Gradient {
            GradientStop { 
                position: 0.0
                color: {
                    var cond = condition.toLowerCase()
                    if (cond.includes("rain") || cond.includes("thunder")) return "#1e3a5f"
                    if (cond.includes("cloud") || cond.includes("overcast")) return "#2d3a4f"
                    if (cond.includes("snow")) return "#4a5568"
                    return "#2563eb"  // Blue sky
                }
            }
            GradientStop { 
                position: 1.0
                color: {
                    var cond = condition.toLowerCase()
                    if (cond.includes("rain") || cond.includes("thunder")) return "#0f172a"
                    if (cond.includes("cloud") || cond.includes("overcast")) return "#1a1f2e"
                    if (cond.includes("snow")) return "#374151"
                    return "#1e40af"
                }
            }
        }
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12
        
        // Header with search
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            
            // Location/Search toggle
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: 10
                color: Qt.rgba(0, 0, 0, 0.3)
                border.width: searchInput.activeFocus ? 2 : 1
                border.color: searchInput.activeFocus ? Qt.rgba(0.4, 0.7, 1, 0.7) : Qt.rgba(1, 1, 1, 0.15)
                
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10
                    
                    Text {
                        text: showSearch ? "🔍" : "📍"
                        font.pixelSize: 18
                    }
                    
                    // Show location or search input
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        
                        // Location display
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !showSearch
                            text: city
                            font.pixelSize: 16
                            font.family: "Segoe UI"
                            font.weight: Font.DemiBold
                            color: "#ffffff"
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
                                anchors.fill: parent
                                text: "Search for a city..."
                                font: parent.font
                                color: "#888888"
                                visible: !searchInput.text && !searchInput.activeFocus
                            }
                        }
                    }
                    
                    // Toggle search/location button
                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        color: toggleMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : "transparent"
                        
                        Text {
                            anchors.centerIn: parent
                            text: showSearch ? "✕" : "🔍"
                            font.pixelSize: 14
                        }
                        
                        MouseArea {
                            id: toggleMouse
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
            
            // Unit toggle
            Rectangle {
                Layout.preferredWidth: 50
                Layout.preferredHeight: 44
                radius: 10
                color: unitMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(0, 0, 0, 0.3)
                
                Text {
                    anchors.centerIn: parent
                    text: useCelsius ? "°C" : "°F"
                    font.pixelSize: 16
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
            
            // Refresh button
            Rectangle {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                radius: 10
                color: refreshMouse.containsMouse ? Qt.rgba(0.3, 0.6, 1, 0.5) : Qt.rgba(0, 0, 0, 0.3)
                
                Text {
                    anchors.centerIn: parent
                    text: "↻"
                    font.pixelSize: 20
                    color: "#ffffff"
                    
                    RotationAnimation on rotation {
                        running: isLoading
                        from: 0
                        to: 360
                        duration: 1000
                        loops: Animation.Infinite
                    }
                }
                
                MouseArea {
                    id: refreshMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (hasWeatherService) WeatherService.refresh()
                    }
                }
            }
        }
        
        // Search debounce timer
        Timer {
            id: searchDebounce
            interval: 500
            onTriggered: {
                if (hasWeatherService && searchQuery.length >= 2) {
                    WeatherService.searchCity(searchQuery)
                }
            }
        }
        
        // Search results dropdown
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: showSearch && searchResults.length > 0 ? Math.min(200, searchResults.length * 44) : 0
            visible: height > 0
            radius: 10
            color: Qt.rgba(0.1, 0.12, 0.18, 0.98)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.15)
            clip: true
            
            Behavior on height { NumberAnimation { duration: 150 } }
            
            ListView {
                anchors.fill: parent
                anchors.margins: 4
                model: searchResults
                clip: true
                
                delegate: Rectangle {
                    width: parent ? parent.width : 0
                    height: 40
                    radius: 6
                    color: resultMouse.containsMouse ? Qt.rgba(0.3, 0.5, 0.8, 0.4) : "transparent"
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8
                        
                        Text {
                            text: "📍"
                            font.pixelSize: 14
                        }
                        
                        Text {
                            Layout.fillWidth: true
                            text: modelData.name + (modelData.admin1 ? ", " + modelData.admin1 : "") + ", " + modelData.country
                            font.pixelSize: 13
                            color: "#ffffff"
                            elide: Text.ElideRight
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
        
        // Current weather - main card
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 180
            radius: 16
            color: Qt.rgba(0, 0, 0, 0.25)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.1)
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 20
                
                // Left - main weather display
                Column {
                    Layout.fillWidth: true
                    spacing: 8
                    
                    // Icon and temperature
                    Row {
                        spacing: 16
                        
                        Text {
                            text: weatherIcon
                            font.pixelSize: 72
                            
                            SequentialAnimation on y {
                                loops: Animation.Infinite
                                NumberAnimation { to: -4; duration: 2500; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 0; duration: 2500; easing.type: Easing.InOutSine }
                            }
                        }
                        
                        Column {
                            spacing: 0
                            
                            Text {
                                text: displayTemp(temp)
                                font.pixelSize: 64
                                font.family: "Segoe UI"
                                font.weight: Font.Light
                                color: "#ffffff"
                            }
                            
                            Text {
                                text: condition
                                font.pixelSize: 18
                                color: Qt.rgba(1, 1, 1, 0.85)
                            }
                        }
                    }
                    
                    // High/Low and Feels Like
                    Row {
                        spacing: 20
                        
                        Row {
                            spacing: 12
                            Text { text: "↑ " + displayTemp(high); font.pixelSize: 14; color: "#fbbf24" }
                            Text { text: "↓ " + displayTemp(low); font.pixelSize: 14; color: "#60a5fa" }
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
                    color: Qt.rgba(1, 1, 1, 0.15)
                }
                
                // Right - details grid
                GridLayout {
                    columns: 2
                    rowSpacing: 12
                    columnSpacing: 16
                    
                    WeatherStat { icon: "💧"; label: "Humidity"; value: humidity + "%" }
                    WeatherStat { icon: "💨"; label: "Wind"; value: windSpeed + " km/h " + windDirectionText(windDirection) }
                    WeatherStat { icon: "🌡️"; label: "Pressure"; value: pressure + " hPa" }
                    WeatherStat { icon: "☁️"; label: "Cloud Cover"; value: cloudCover + "%" }
                    WeatherStat { icon: "🌅"; label: "Sunrise"; value: formatTime(sunrise) }
                    WeatherStat { icon: "🌇"; label: "Sunset"; value: formatTime(sunset) }
                }
            }
            
            // Loading overlay
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Qt.rgba(0, 0, 0, 0.6)
                visible: isLoading
                
                Column {
                    anchors.centerIn: parent
                    spacing: 12
                    
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "⏳"
                        font.pixelSize: 36
                        
                        RotationAnimation on rotation {
                            running: isLoading
                            from: 0; to: 360; duration: 1200
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
        
        // UV Index bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            radius: 10
            color: Qt.rgba(0, 0, 0, 0.25)
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12
                
                Text {
                    text: "☀️"
                    font.pixelSize: 20
                }
                
                Column {
                    Layout.fillWidth: true
                    spacing: 4
                    
                    RowLayout {
                        width: parent.width
                        
                        Text {
                            text: "UV Index"
                            font.pixelSize: 12
                            color: Qt.rgba(1, 1, 1, 0.7)
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        Text {
                            text: uvIndex + " - " + uvDescription(uvIndex)
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: uvColor(uvIndex)
                        }
                    }
                    
                    // UV bar
                    Rectangle {
                        width: parent.width
                        height: 6
                        radius: 3
                        color: Qt.rgba(1, 1, 1, 0.15)
                        
                        Rectangle {
                            width: parent.width * Math.min(uvIndex / 11, 1)
                            height: parent.height
                            radius: parent.radius
                            color: uvColor(uvIndex)
                            
                            Behavior on width { NumberAnimation { duration: 300 } }
                        }
                    }
                }
            }
        }
        
        // 7-day forecast
        RowLayout {
            Layout.fillWidth: true
            
            Text {
                text: "7-Day Forecast"
                font.pixelSize: 14
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
        
        // Forecast scroll
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            
            Flow {
                width: parent.width
                spacing: 8
                
                Repeater {
                    model: forecast
                    
                    Rectangle {
                        width: (weatherApp.width - 48) / 7
                        height: 100
                        radius: 10
                        color: Qt.rgba(0, 0, 0, 0.25)
                        border.width: forecastMouse.containsMouse ? 1 : 0
                        border.color: Qt.rgba(1, 1, 1, 0.3)
                        
                        Column {
                            anchors.centerIn: parent
                            spacing: 4
                            
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.day || ""
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                color: Qt.rgba(1, 1, 1, 0.7)
                            }
                            
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.icon || "❓"
                                font.pixelSize: 26
                            }
                            
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: displayTemp(modelData.high)
                                font.pixelSize: 14
                                font.bold: true
                                color: "#ffffff"
                            }
                            
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: displayTemp(modelData.low)
                                font.pixelSize: 11
                                color: Qt.rgba(1, 1, 1, 0.5)
                            }
                        }
                        
                        MouseArea {
                            id: forecastMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            
                            ToolTip.visible: containsMouse
                            ToolTip.text: (modelData.condition || "") + 
                                "\nPrecip: " + (modelData.precipitation || 0) + " mm" +
                                "\nUV: " + (modelData.uv_index || 0)
                            ToolTip.delay: 300
                        }
                        
                        scale: forecastMouse.containsMouse ? 1.05 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }
                    }
                }
            }
        }
    }
    
    // Weather stat component
    component WeatherStat: Row {
        property string icon: ""
        property string label: ""
        property string value: ""
        
        spacing: 8
        
        Text {
            text: icon
            font.pixelSize: 14
        }
        
        Column {
            spacing: 1
            
            Text {
                text: label
                font.pixelSize: 10
                color: Qt.rgba(1, 1, 1, 0.6)
            }
            
            Text {
                text: value
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: "#ffffff"
            }
        }
    }
}
