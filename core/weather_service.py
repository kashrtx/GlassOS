"""
GlassOS Weather Service - Real Weather Data Provider
Uses Open-Meteo API (free, no API key required)
"""

import json
from typing import Optional, Dict, Any, List
from PySide6.QtCore import QObject, Signal, Slot, Property, QUrl, QThread
from PySide6.QtNetwork import QNetworkAccessManager, QNetworkRequest, QNetworkReply


class WeatherWorker(QObject):
    """Worker for fetching weather data in background."""
    
    finished = Signal(dict)
    error = Signal(str)
    
    def __init__(self, network_manager: QNetworkAccessManager):
        super().__init__()
        self.network_manager = network_manager
        self._pending_replies = []
    
    def fetch_weather(self, lat: float, lon: float, city_name: str):
        """Fetch weather data from Open-Meteo API."""
        # Open-Meteo API - completely free, no API key needed
        url = (
            f"https://api.open-meteo.com/v1/forecast?"
            f"latitude={lat}&longitude={lon}"
            f"&current=temperature_2m,relative_humidity_2m,apparent_temperature,"
            f"weather_code,wind_speed_10m,wind_direction_10m,precipitation,cloud_cover,pressure_msl"
            f"&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,"
            f"wind_speed_10m_max,sunrise,sunset,uv_index_max"
            f"&timezone=auto"
            f"&forecast_days=7"
        )
        
        request = QNetworkRequest(QUrl(url))
        request.setHeader(QNetworkRequest.KnownHeaders.UserAgentHeader, "GlassOS Weather/1.0")
        
        reply = self.network_manager.get(request)
        reply.setProperty("city_name", city_name)
        reply.setProperty("latitude", lat)
        reply.setProperty("longitude", lon)
        reply.finished.connect(lambda: self._handle_response(reply))
        self._pending_replies.append(reply)
    
    def _handle_response(self, reply: QNetworkReply):
        """Handle the API response."""
        if reply in self._pending_replies:
            self._pending_replies.remove(reply)
        
        if reply.error() != QNetworkReply.NetworkError.NoError:
            self.error.emit(f"Network error: {reply.errorString()}")
            reply.deleteLater()
            return
        
        try:
            data = json.loads(reply.readAll().data().decode())
            city_name = reply.property("city_name")
            
            # Parse the response
            result = self._parse_weather_data(data, city_name)
            self.finished.emit(result)
        except Exception as e:
            self.error.emit(f"Parse error: {str(e)}")
        finally:
            reply.deleteLater()
    
    def _parse_weather_data(self, data: dict, city_name: str) -> dict:
        """Parse Open-Meteo response into our format."""
        current = data.get("current", {})
        daily = data.get("daily", {})
        
        # Weather code to condition mapping
        weather_codes = {
            0: ("Clear", "☀️"),
            1: ("Mainly Clear", "🌤️"),
            2: ("Partly Cloudy", "⛅"),
            3: ("Overcast", "☁️"),
            45: ("Foggy", "🌫️"),
            48: ("Icy Fog", "🌫️"),
            51: ("Light Drizzle", "🌦️"),
            53: ("Drizzle", "🌦️"),
            55: ("Heavy Drizzle", "🌧️"),
            61: ("Light Rain", "🌧️"),
            63: ("Rain", "🌧️"),
            65: ("Heavy Rain", "🌧️"),
            71: ("Light Snow", "🌨️"),
            73: ("Snow", "🌨️"),
            75: ("Heavy Snow", "❄️"),
            77: ("Snow Grains", "🌨️"),
            80: ("Light Showers", "🌦️"),
            81: ("Showers", "🌧️"),
            82: ("Heavy Showers", "🌧️"),
            85: ("Light Snow Showers", "🌨️"),
            86: ("Snow Showers", "🌨️"),
            95: ("Thunderstorm", "⛈️"),
            96: ("Thunderstorm + Hail", "⛈️"),
            99: ("Severe Thunderstorm", "🌩️"),
        }
        
        code = current.get("weather_code", 0)
        condition, icon = weather_codes.get(code, ("Unknown", "❓"))
        
        # Build forecast
        forecast = []
        days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        
        if daily.get("time"):
            for i in range(min(7, len(daily["time"]))):
                day_code = daily.get("weather_code", [0])[i] if i < len(daily.get("weather_code", [])) else 0
                day_cond, day_icon = weather_codes.get(day_code, ("Unknown", "❓"))
                
                # Get day name from date
                date_str = daily["time"][i]
                from datetime import datetime
                date_obj = datetime.strptime(date_str, "%Y-%m-%d")
                day_name = days[date_obj.weekday()]
                
                forecast.append({
                    "day": day_name,
                    "date": date_str,
                    "icon": day_icon,
                    "condition": day_cond,
                    "high": round(daily.get("temperature_2m_max", [0])[i]) if i < len(daily.get("temperature_2m_max", [])) else 0,
                    "low": round(daily.get("temperature_2m_min", [0])[i]) if i < len(daily.get("temperature_2m_min", [])) else 0,
                    "precipitation": daily.get("precipitation_sum", [0])[i] if i < len(daily.get("precipitation_sum", [])) else 0,
                    "uv_index": daily.get("uv_index_max", [0])[i] if i < len(daily.get("uv_index_max", [])) else 0,
                    "sunrise": daily.get("sunrise", [""])[i] if i < len(daily.get("sunrise", [])) else "",
                    "sunset": daily.get("sunset", [""])[i] if i < len(daily.get("sunset", [])) else "",
                })
        
        return {
            "city": city_name,
            "temp": round(current.get("temperature_2m", 0)),
            "feels_like": round(current.get("apparent_temperature", 0)),
            "condition": condition,
            "icon": icon,
            "humidity": round(current.get("relative_humidity_2m", 0)),
            "wind_speed": round(current.get("wind_speed_10m", 0)),
            "wind_direction": current.get("wind_direction_10m", 0),
            "pressure": round(current.get("pressure_msl", 0)),
            "cloud_cover": current.get("cloud_cover", 0),
            "precipitation": current.get("precipitation", 0),
            "high": round(daily.get("temperature_2m_max", [0])[0]) if daily.get("temperature_2m_max") else 0,
            "low": round(daily.get("temperature_2m_min", [0])[0]) if daily.get("temperature_2m_min") else 0,
            "sunrise": daily.get("sunrise", [""])[0] if daily.get("sunrise") else "",
            "sunset": daily.get("sunset", [""])[0] if daily.get("sunset") else "",
            "uv_index": daily.get("uv_index_max", [0])[0] if daily.get("uv_index_max") else 0,
            "forecast": forecast,
            "timezone": data.get("timezone", ""),
        }


class GeocodingWorker(QObject):
    """Worker for geocoding city names to coordinates."""
    
    finished = Signal(list)
    error = Signal(str)
    
    def __init__(self, network_manager: QNetworkAccessManager):
        super().__init__()
        self.network_manager = network_manager
    
    def search_city(self, query: str):
        """Search for cities by name using Open-Meteo Geocoding API."""
        url = f"https://geocoding-api.open-meteo.com/v1/search?name={query}&count=10&language=en&format=json"
        
        request = QNetworkRequest(QUrl(url))
        request.setHeader(QNetworkRequest.KnownHeaders.UserAgentHeader, "GlassOS Weather/1.0")
        
        reply = self.network_manager.get(request)
        reply.finished.connect(lambda: self._handle_response(reply))
    
    def _handle_response(self, reply: QNetworkReply):
        """Handle geocoding response."""
        if reply.error() != QNetworkReply.NetworkError.NoError:
            self.error.emit(f"Search error: {reply.errorString()}")
            reply.deleteLater()
            return
        
        try:
            data = json.loads(reply.readAll().data().decode())
            results = data.get("results", [])
            
            cities = []
            for r in results:
                cities.append({
                    "name": r.get("name", ""),
                    "country": r.get("country", ""),
                    "country_code": r.get("country_code", ""),
                    "admin1": r.get("admin1", ""),  # State/Province
                    "latitude": r.get("latitude", 0),
                    "longitude": r.get("longitude", 0),
                    "population": r.get("population", 0),
                })
            
            self.finished.emit(cities)
        except Exception as e:
            self.error.emit(f"Parse error: {str(e)}")
        finally:
            reply.deleteLater()


class WeatherProvider(QObject):
    """Main weather provider exposed to QML."""
    
    # Signals
    weatherUpdated = Signal()
    forecastUpdated = Signal()
    searchResultsReady = Signal()
    loadingChanged = Signal()
    errorOccurred = Signal(str)
    
    def __init__(self, parent=None):
        super().__init__(parent)
        
        self._network_manager = QNetworkAccessManager(self)
        self._weather_worker = WeatherWorker(self._network_manager)
        self._geocoding_worker = GeocodingWorker(self._network_manager)
        
        # Connect signals
        self._weather_worker.finished.connect(self._on_weather_received)
        self._weather_worker.error.connect(self._on_error)
        self._geocoding_worker.finished.connect(self._on_search_results)
        self._geocoding_worker.error.connect(self._on_error)
        
        # Current weather data
        self._city = "New York"
        self._country = "US"
        self._temp = 0
        self._feels_like = 0
        self._condition = "Loading..."
        self._icon = "⏳"
        self._humidity = 0
        self._wind_speed = 0
        self._wind_direction = 0
        self._pressure = 0
        self._cloud_cover = 0
        self._precipitation = 0
        self._high = 0
        self._low = 0
        self._sunrise = ""
        self._sunset = ""
        self._uv_index = 0
        self._forecast = []
        self._search_results = []
        self._is_loading = False
        self._last_updated = ""
        
        # Current location
        self._latitude = 40.7128  # NYC default
        self._longitude = -74.0060
    
    def _on_weather_received(self, data: dict):
        """Handle received weather data."""
        self._city = data.get("city", self._city)
        self._temp = data.get("temp", 0)
        self._feels_like = data.get("feels_like", 0)
        self._condition = data.get("condition", "Unknown")
        self._icon = data.get("icon", "❓")
        self._humidity = data.get("humidity", 0)
        self._wind_speed = data.get("wind_speed", 0)
        self._wind_direction = data.get("wind_direction", 0)
        self._pressure = data.get("pressure", 0)
        self._cloud_cover = data.get("cloud_cover", 0)
        self._precipitation = data.get("precipitation", 0)
        self._high = data.get("high", 0)
        self._low = data.get("low", 0)
        self._sunrise = data.get("sunrise", "")
        self._sunset = data.get("sunset", "")
        self._uv_index = data.get("uv_index", 0)
        self._forecast = data.get("forecast", [])
        
        from datetime import datetime
        self._last_updated = datetime.now().strftime("%H:%M")
        
        self._is_loading = False
        self.loadingChanged.emit()
        self.weatherUpdated.emit()
        self.forecastUpdated.emit()
        
        print(f"🌤️ Weather updated for {self._city}: {self._temp}°C, {self._condition}")
    
    def _on_search_results(self, results: list):
        """Handle search results."""
        self._search_results = results
        self._is_loading = False
        self.loadingChanged.emit()
        self.searchResultsReady.emit()
    
    def _on_error(self, error: str):
        """Handle errors."""
        self._is_loading = False
        self.loadingChanged.emit()
        self.errorOccurred.emit(error)
        print(f"⚠️ Weather error: {error}")
    
    # QML accessible methods
    @Slot()
    def refresh(self):
        """Refresh current weather."""
        self._is_loading = True
        self.loadingChanged.emit()
        self._weather_worker.fetch_weather(self._latitude, self._longitude, self._city)
    
    @Slot(str)
    def searchCity(self, query: str):
        """Search for a city."""
        if len(query) < 2:
            return
        self._is_loading = True
        self.loadingChanged.emit()
        self._geocoding_worker.search_city(query)
    
    @Slot(int)
    def selectSearchResult(self, index: int):
        """Select a city from search results."""
        if 0 <= index < len(self._search_results):
            city = self._search_results[index]
            self._city = city["name"]
            self._country = city["country_code"]
            self._latitude = city["latitude"]
            self._longitude = city["longitude"]
            self._search_results = []
            self.searchResultsReady.emit()
            self.refresh()
    
    @Slot(float, float, str)
    def setLocation(self, lat: float, lon: float, name: str):
        """Set location directly."""
        self._latitude = lat
        self._longitude = lon
        self._city = name
        self.refresh()
    
    # Properties
    @Property(str, notify=weatherUpdated)
    def city(self): return self._city
    
    @Property(str, notify=weatherUpdated)
    def country(self): return self._country
    
    @Property(int, notify=weatherUpdated)
    def temp(self): return self._temp
    
    @Property(int, notify=weatherUpdated)
    def feelsLike(self): return self._feels_like
    
    @Property(str, notify=weatherUpdated)
    def condition(self): return self._condition
    
    @Property(str, notify=weatherUpdated)
    def icon(self): return self._icon
    
    @Property(int, notify=weatherUpdated)
    def humidity(self): return self._humidity
    
    @Property(int, notify=weatherUpdated)
    def windSpeed(self): return self._wind_speed
    
    @Property(int, notify=weatherUpdated)
    def windDirection(self): return self._wind_direction
    
    @Property(int, notify=weatherUpdated)
    def pressure(self): return self._pressure
    
    @Property(int, notify=weatherUpdated)
    def cloudCover(self): return self._cloud_cover
    
    @Property(float, notify=weatherUpdated)
    def precipitation(self): return self._precipitation
    
    @Property(int, notify=weatherUpdated)
    def high(self): return self._high
    
    @Property(int, notify=weatherUpdated)
    def low(self): return self._low
    
    @Property(str, notify=weatherUpdated)
    def sunrise(self): return self._sunrise
    
    @Property(str, notify=weatherUpdated)
    def sunset(self): return self._sunset
    
    @Property(int, notify=weatherUpdated)
    def uvIndex(self): return self._uv_index
    
    @Property(str, notify=weatherUpdated)
    def lastUpdated(self): return self._last_updated
    
    @Property(list, notify=forecastUpdated)
    def forecast(self): return self._forecast
    
    @Property(list, notify=searchResultsReady)
    def searchResults(self): return self._search_results
    
    @Property(bool, notify=loadingChanged)
    def isLoading(self): return self._is_loading
