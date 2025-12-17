// GlassOS Weather App
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: weather
    color: "transparent"
    
    property var data: {
        "city": "New York, NY",
        "temp": 22,
        "condition": "Partly Cloudy",
        "icon": "⛅",
        "humidity": 65,
        "wind": 12,
        "high": 26,
        "low": 18,
        "forecast": [
            { day: "Mon", icon: "☀", high: 26, low: 18 },
            { day: "Tue", icon: "⛅", high: 24, low: 17 },
            { day: "Wed", icon: "🌧", high: 20, low: 14 },
            { day: "Thu", icon: "⛅", high: 22, low: 16 },
            { day: "Fri", icon: "☀", high: 25, low: 17 }
        ]
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 20
        
        // Current weather card
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 140
            radius: 12
            color: Qt.rgba(0, 0, 0, 0.2)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.1)
            
            Row {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 20
                
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    
                    Text {
                        text: data.city
                        font.pixelSize: 14
                        color: "#888888"
                    }
                    
                    Row {
                        spacing: 12
                        
                        Text {
                            text: data.icon
                            font.pixelSize: 48
                        }
                        
                        Text {
                            text: data.temp + "°"
                            font.pixelSize: 52
                            font.family: "Segoe UI"
                            font.weight: Font.Light
                            color: "#ffffff"
                        }
                    }
                    
                    Text {
                        text: data.condition
                        font.pixelSize: 14
                        color: "#aaaaaa"
                    }
                }
                
                Item { width: 40; height: 1 }
                
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    
                    DetailRow { label: "High / Low"; value: data.high + "° / " + data.low + "°" }
                    DetailRow { label: "Humidity"; value: data.humidity + "%" }
                    DetailRow { label: "Wind"; value: data.wind + " km/h" }
                }
            }
        }
        
        // Forecast header
        Text {
            text: "5-Day Forecast"
            font.pixelSize: 14
            font.bold: true
            color: "#888888"
        }
        
        // Forecast cards
        Row {
            Layout.fillWidth: true
            spacing: 8
            
            Repeater {
                model: data.forecast
                
                Rectangle {
                    width: (weather.width - 72) / 5
                    height: 100
                    radius: 8
                    color: Qt.rgba(0, 0, 0, 0.2)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.08)
                    
                    Column {
                        anchors.centerIn: parent
                        spacing: 6
                        
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.day
                            font.pixelSize: 11
                            color: "#888888"
                        }
                        
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.icon
                            font.pixelSize: 26
                        }
                        
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.high + "°"
                            font.pixelSize: 14
                            font.bold: true
                            color: "#ffffff"
                        }
                        
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.low + "°"
                            font.pixelSize: 11
                            color: "#888888"
                        }
                    }
                }
            }
        }
        
        Item { Layout.fillHeight: true }
    }
    
    component DetailRow: Row {
        property string label: ""
        property string value: ""
        
        spacing: 16
        
        Text {
            width: 80
            text: label
            font.pixelSize: 12
            color: "#888888"
        }
        
        Text {
            text: value
            font.pixelSize: 12
            font.bold: true
            color: "#ffffff"
        }
    }
}
