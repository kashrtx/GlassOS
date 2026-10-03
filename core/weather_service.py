"""
GlassOS Weather - Open-Meteo (free, no API key), exposed to QML as ``WeatherService``.

Data is always fetched in metric units; QML converts for display.
"""

from __future__ import annotations

import json
import time
from datetime import datetime
from typing import Optional

from PySide6.QtCore import QObject, Property, QUrl, QUrlQuery, Signal, Slot
from PySide6.QtNetwork import QNetworkAccessManager, QNetworkReply, QNetworkRequest

from . import log as _log

log = _log.get("weather")
MAX_RESPONSE_BYTES = 4 * 1024 * 1024

# code -> (description, day icon, night icon); icons live in qml/icons/wx-*.svg
WEATHER_CODES = {
    0: ("Clear", "wx-clear-day", "wx-clear-night"), 1: ("Mainly clear", "wx-partly-day", "wx-partly-night"),
    2: ("Partly cloudy", "wx-partly-day", "wx-partly-night"), 3: ("Overcast", "wx-cloudy", "wx-cloudy"),
    45: ("Fog", "wx-fog", "wx-fog"), 48: ("Icy fog", "wx-fog", "wx-fog"),
    51: ("Light drizzle", "wx-drizzle", "wx-drizzle"), 53: ("Drizzle", "wx-drizzle", "wx-drizzle"),
    55: ("Heavy drizzle", "wx-rain", "wx-rain"), 56: ("Freezing drizzle", "wx-drizzle", "wx-drizzle"),
    57: ("Freezing drizzle", "wx-drizzle", "wx-drizzle"), 61: ("Light rain", "wx-drizzle", "wx-drizzle"),
    63: ("Rain", "wx-rain", "wx-rain"), 65: ("Heavy rain", "wx-rain", "wx-rain"),
    66: ("Freezing rain", "wx-rain", "wx-rain"), 67: ("Freezing rain", "wx-rain", "wx-rain"),
    71: ("Light snow", "wx-snow", "wx-snow"), 73: ("Snow", "wx-snow", "wx-snow"), 75: ("Heavy snow", "wx-snow", "wx-snow"),
    77: ("Snow grains", "wx-snow", "wx-snow"), 80: ("Light showers", "wx-drizzle", "wx-drizzle"),
    81: ("Showers", "wx-rain", "wx-rain"), 82: ("Violent showers", "wx-thunder", "wx-thunder"),
    85: ("Snow showers", "wx-snow", "wx-snow"), 86: ("Snow showers", "wx-snow", "wx-snow"),
    95: ("Thunderstorm", "wx-thunder", "wx-thunder"), 96: ("Thunderstorm, hail", "wx-thunder", "wx-thunder"),
    99: ("Severe thunderstorm", "wx-thunder", "wx-thunder"),
}
DEFAULT_LOCATION = {"name": "New York", "country": "United States", "admin": "New York",
                    "latitude": 40.7128, "longitude": -74.006}


def describe(code, is_day=True):
    cond, day_icon, night_icon = WEATHER_CODES.get(int(code or 0), ("Unknown", "wx-cloudy", "wx-cloudy"))
    return cond, (day_icon if is_day else night_icon)


def _at(seq, i, default=0):
    try:
        value = seq[i]
        return default if value is None else value
    except (IndexError, TypeError):
        return default


def parse_forecast(data: dict) -> dict:
    """Turn an Open-Meteo /forecast response into the dict the UI consumes."""
    cur = data.get("current") or {}
    daily = data.get("daily") or {}
    hourly = data.get("hourly") or {}
    is_day = bool(cur.get("is_day", 1))
    cond, icon = describe(cur.get("weather_code", 0), is_day)

    days = []
    for i, date in enumerate(daily.get("time") or []):
        d_cond, d_icon = describe(_at(daily.get("weather_code"), i), True)
        try:
            label = datetime.strptime(date, "%Y-%m-%d").strftime("%a")
        except ValueError:
            label = date
        days.append({
            "day": "Today" if i == 0 else label, "date": date, "icon": d_icon, "condition": d_cond,
            "high": round(_at(daily.get("temperature_2m_max"), i)),
            "low": round(_at(daily.get("temperature_2m_min"), i)),
            "rain": int(round(_at(daily.get("precipitation_probability_max"), i))),
        })

    hours = []
    now_iso = str(cur.get("time", ""))
    times = hourly.get("time") or []
    start = 0
    for i, t in enumerate(times):
        if t[:13] >= now_iso[:13]:
            start = i
            break
    for i in range(start, min(start + 24, len(times))):
        _, h_icon = describe(_at(hourly.get("weather_code"), i), bool(_at(hourly.get("is_day"), i, 1)))
        hours.append({
            "time": "Now" if i == start else times[i][11:16],
            "temp": round(_at(hourly.get("temperature_2m"), i)),
            "icon": h_icon,
            "rain": int(round(_at(hourly.get("precipitation_probability"), i))),
        })

    return {
        "temp": round(cur.get("temperature_2m", 0) or 0),
        "feelsLike": round(cur.get("apparent_temperature", 0) or 0),
        "condition": cond, "icon": icon, "isDay": is_day,
        "humidity": int(round(cur.get("relative_humidity_2m", 0) or 0)),
        "windSpeed": int(round(cur.get("wind_speed_10m", 0) or 0)),
        "windDirection": int(round(cur.get("wind_direction_10m", 0) or 0)),
        "pressure": int(round(cur.get("pressure_msl", 0) or 0)),
        "cloudCover": int(round(cur.get("cloud_cover", 0) or 0)),
        "uvIndex": round(float(_at(daily.get("uv_index_max"), 0)), 1),
        "sunrise": str(_at(daily.get("sunrise"), 0, ""))[11:16],
        "sunset": str(_at(daily.get("sunset"), 0, ""))[11:16],
        "high": days[0]["high"] if days else 0,
        "low": days[0]["low"] if days else 0,
        "forecast": days, "hourly": hours,
    }


def _valid_location(loc):
    """Return a sanitized location dict, or None if ``loc`` is unusable."""
    if not isinstance(loc, dict):
        return None
    lat, lon = loc.get("latitude"), loc.get("longitude")
    if not isinstance(lat, (int, float)) or not isinstance(lon, (int, float)) \
            or not -90 <= lat <= 90 or not -180 <= lon <= 180:
        return None
    return {"name": str(loc.get("name", ""))[:80] or "Unknown", "country": str(loc.get("country", ""))[:80],
            "admin": str(loc.get("admin", ""))[:80], "latitude": float(lat), "longitude": float(lon)}


def parse_geocoding(data: dict) -> list:
    out = []
    for r in data.get("results") or []:
        if not isinstance(r, dict) or not isinstance(r.get("latitude"), (int, float)) \
                or not isinstance(r.get("longitude"), (int, float)):
            continue
        out.append({
            "name": r.get("name", ""), "country": r.get("country", ""),
            "admin": r.get("admin1", "") or "", "latitude": r.get("latitude", 0.0),
            "longitude": r.get("longitude", 0.0),
        })
    return out


class WeatherProvider(QObject):
    weatherChanged = Signal()
    searchResultsChanged = Signal()
    stateChanged = Signal()

    def __init__(self, prefs, parent: Optional[QObject] = None):
        super().__init__(parent)
        self._prefs = prefs
        self._nam = QNetworkAccessManager(self)
        self._weather_reply: Optional[QNetworkReply] = None
        self._search_reply: Optional[QNetworkReply] = None
        self._location = _valid_location(prefs.value("weather.location", None)) or dict(DEFAULT_LOCATION)
        self._data = {}
        self._results = []
        self._loading = False
        self._searching = False
        self._error = ""
        self._fetched_at = 0.0

    # ----------------------------------------------------------- networking
    def _get(self, url: str, params: dict) -> QNetworkReply:
        q = QUrlQuery()
        for k, v in params.items():
            q.addQueryItem(k, str(v))
        u = QUrl(url)
        u.setQuery(q)
        req = QNetworkRequest(u)
        req.setHeader(QNetworkRequest.KnownHeaders.UserAgentHeader, "GlassOS/2.0 Weather")
        req.setTransferTimeout(12000)
        return self._nam.get(req)

    @Slot()
    def refresh(self):
        if self._weather_reply is not None:
            old, self._weather_reply = self._weather_reply, None
            old.abort()
        loc = self._location
        reply = self._get("https://api.open-meteo.com/v1/forecast", {
            "latitude": loc["latitude"], "longitude": loc["longitude"],
            "current": "temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,"
                       "cloud_cover,pressure_msl,wind_speed_10m,wind_direction_10m",
            "hourly": "temperature_2m,precipitation_probability,weather_code,is_day",
            "daily": "weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max,"
                     "precipitation_probability_max",
            "timezone": "auto", "forecast_days": 7,
        })
        self._weather_reply = reply
        self._set_state(loading=True)
        reply.finished.connect(lambda r=reply: self._on_weather(r))

    @Slot()
    def refreshIfStale(self):
        if not self._loading and time.time() - self._fetched_at > 600:
            self.refresh()

    def _on_weather(self, reply: QNetworkReply):
        reply.deleteLater()
        if reply is not self._weather_reply:
            return  # aborted or superseded by a newer request
        self._weather_reply = None
        if reply.error() != QNetworkReply.NetworkError.NoError:
            log.warning("forecast request failed: %s", reply.errorString())
            self._set_state(loading=False, error=_friendly(reply))
            return
        try:
            self._data = parse_forecast(_read_json(reply))
        except (ValueError, KeyError, TypeError) as exc:
            log.warning("unexpected forecast payload: %s", exc)
            self._set_state(loading=False, error="The weather service sent an unexpected response.")
            return
        self._data["updated"] = datetime.now().strftime("%H:%M")
        self._fetched_at = time.time()
        self._set_state(loading=False, error="")
        self.weatherChanged.emit()

    @Slot(str)
    def search(self, query: str):
        query = (query or "").strip()[:100]
        if self._search_reply is not None:
            old, self._search_reply = self._search_reply, None
            old.abort()
        if len(query) < 2:
            self._results = []
            self._searching = False
            self.searchResultsChanged.emit()
            self.stateChanged.emit()
            return
        reply = self._get("https://geocoding-api.open-meteo.com/v1/search",
                          {"name": query, "count": 8, "language": "en", "format": "json"})
        self._search_reply = reply
        self._searching = True
        self.stateChanged.emit()
        reply.finished.connect(lambda r=reply: self._on_search(r))

    def _on_search(self, reply: QNetworkReply):
        reply.deleteLater()
        if reply is not self._search_reply:
            return
        self._search_reply = None
        self._searching = False
        if reply.error() == QNetworkReply.NetworkError.NoError:
            try:
                self._results = parse_geocoding(_read_json(reply))
            except (ValueError, TypeError, AttributeError):
                self._results = []
        else:
            self._error = _friendly(reply)
        self.stateChanged.emit()
        self.searchResultsChanged.emit()

    @Slot(int)
    def choose(self, index: int):
        if 0 <= index < len(self._results):
            self._location = dict(self._results[index])
            self._prefs.setValue("weather.location", self._location)
            self._results = []
            self.searchResultsChanged.emit()
            self._data = {}
            self.weatherChanged.emit()
            self.refresh()

    def _set_state(self, loading=None, error=None):
        if loading is not None:
            self._loading = loading
        if error is not None:
            self._error = error
        self.stateChanged.emit()

    # ------------------------------------------------------------ properties
    @Property(bool, notify=stateChanged)
    def loading(self):
        return self._loading

    @Property(bool, notify=stateChanged)
    def searching(self):
        return self._searching

    @Property(str, notify=stateChanged)
    def error(self):
        return self._error

    @Property(bool, notify=weatherChanged)
    def hasData(self):
        return bool(self._data)

    @Property("QVariantMap", notify=weatherChanged)
    def current(self):
        return {k: v for k, v in self._data.items() if k not in ("forecast", "hourly")}

    @Property("QVariantList", notify=weatherChanged)
    def forecast(self):
        return self._data.get("forecast", [])

    @Property("QVariantList", notify=weatherChanged)
    def hourly(self):
        return self._data.get("hourly", [])

    @Property(str, notify=weatherChanged)
    def city(self):
        return self._location.get("name", "")

    @Property(str, notify=weatherChanged)
    def region(self):
        parts = [self._location.get("admin", ""), self._location.get("country", "")]
        return ", ".join(p for p in parts if p and p != self._location.get("name"))

    @Property("QVariantList", notify=searchResultsChanged)
    def searchResults(self):
        return self._results


def _read_json(reply: QNetworkReply):
    raw = bytes(reply.read(MAX_RESPONSE_BYTES + 1).data())
    if len(raw) > MAX_RESPONSE_BYTES:
        raise ValueError("response too large")
    data = json.loads(raw.decode("utf-8"))
    if not isinstance(data, dict):
        raise ValueError("expected a JSON object")
    return data


def _friendly(reply: QNetworkReply) -> str:
    err = reply.error()
    offline = {QNetworkReply.NetworkError.HostNotFoundError, QNetworkReply.NetworkError.UnknownNetworkError,
               QNetworkReply.NetworkError.TemporaryNetworkFailureError,
               QNetworkReply.NetworkError.NetworkSessionFailedError,
               QNetworkReply.NetworkError.ConnectionRefusedError}
    if err in offline:
        return "You appear to be offline."
    if err in (QNetworkReply.NetworkError.TimeoutError, QNetworkReply.NetworkError.OperationCanceledError):
        return "The weather service took too long to answer."
    return reply.errorString() or "Network error"
