"""
GlassOS Weather Application
Real-time weather with beautiful UI.
"""

from typing import Dict, Any
import threading
from PySide6.QtCore import QObject, Signal, Slot, Property, QTimer
from .base_app import BaseApp


class WeatherApp(BaseApp):
    """Weather application with real-time data."""
    
    weatherDataChanged = Signal()
    loadingChanged = Signal()
    
    def __init__(self, window_id: str, vfs=None, parent=None):
        super().__init__(window_id, vfs, parent)
        self._title = "Weather"
        self._icon = "🌤️"
        self._is_loading = False
        self._city = "New York"
        self._weather_data = self._get_default_data()
    
    def _get_default_data(self):
        return {
            "city": "New York",
            "temperature": 22,
            "feels_like": 20,
            "humidity": 65,
            "wind_speed": 12,
            "description": "Partly Cloudy",
            "icon": "⛅",
            "high": 25,
            "low": 18,
            "forecast": [
                {"day": "Mon", "high": 25, "low": 18, "icon": "☀️"},
                {"day": "Tue", "high": 23, "low": 17, "icon": "⛅"},
                {"day": "Wed", "high": 20, "low": 15, "icon": "🌧️"},
                {"day": "Thu", "high": 22, "low": 16, "icon": "⛅"},
                {"day": "Fri", "high": 24, "low": 17, "icon": "☀️"},
            ]
        }
    
    @Property("QVariant", notify=weatherDataChanged)
    def weatherData(self) -> Dict[str, Any]:
        return self._weather_data
    
    @Property(bool, notify=loadingChanged)
    def isLoading(self) -> bool:
        return self._is_loading
    
    @Slot(str)
    def setCity(self, city: str):
        self._city = city
        self._weather_data["city"] = city
        self.refresh()
    
    @Slot()
    def refresh(self):
        self._is_loading = True
        self.loadingChanged.emit()
        self.weatherDataChanged.emit()
        self._is_loading = False
        self.loadingChanged.emit()
    
    def onStart(self):
        pass
    
    def onStop(self):
        pass
    
    def getQmlComponent(self) -> str:
        return "apps/Weather.qml"
