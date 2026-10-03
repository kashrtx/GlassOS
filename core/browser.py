"""
AeroBrowser services, exposed to QML as ``Browser`` (+ ``BrowserProfile``).

* A persistent web profile: logins, cookies and cache survive restarts
  (stored in Storage/System/browser), downloads go to the user's Downloads,
  and the ad blocker is installed on it.
* Browsing history with ranked address-bar suggestions.
* Address normalization (search vs. URL, HTTPS by default) and search engines.
"""

from __future__ import annotations

import json
import os
import re
import time
from pathlib import Path
from typing import Optional
from urllib.parse import quote_plus

from PySide6.QtCore import QObject, Property, QTimer, QUrl, Signal, Slot

from . import log as _log

log = _log.get("browser")

SEARCH_ENGINES = {
    "DuckDuckGo": "https://duckduckgo.com/?q={}",
    "Brave Search": "https://search.brave.com/search?q={}",
    "Google": "https://www.google.com/search?q={}",
    "Bing": "https://www.bing.com/search?q={}",
    "Startpage": "https://www.startpage.com/do/search?q={}",
}
MAX_HISTORY = 5000
# OpenSearch-style suggestion endpoints: they all answer ["query", ["s1", "s2", ...]]
SUGGEST_URLS = {
    "DuckDuckGo": "https://duckduckgo.com/ac/?q={}&type=list",
    "Brave Search": "https://search.brave.com/api/suggest?q={}",
    "Google": "https://suggestqueries.google.com/complete/search?client=firefox&q={}",
    "Bing": "https://api.bing.com/osjson.aspx?query={}",
    "Startpage": "https://duckduckgo.com/ac/?q={}&type=list",
}
FAVICON_SOURCES = ("https://icons.duckduckgo.com/ip3/{host}.ico",
                   "https://www.google.com/s2/favicons?domain={host}&sz=64")
THUMB_MAX_AGE = 6 * 3600
DEFAULT_SHORTCUTS = [
    {"title": "YouTube", "url": "https://www.youtube.com/"},
    {"title": "Wikipedia", "url": "https://www.wikipedia.org/"},
    {"title": "GitHub", "url": "https://github.com/"},
    {"title": "Reddit", "url": "https://www.reddit.com/"},
    {"title": "DuckDuckGo", "url": "https://duckduckgo.com/"},
    {"title": "Hacker News", "url": "https://news.ycombinator.com/"},
    {"title": "Weather", "url": "https://open-meteo.com/"},
    {"title": "Maps", "url": "https://www.openstreetmap.org/"},
]


def host_of(url: str) -> str:
    m = re.match(r"^[a-z][a-z0-9+.\-]*://([^/?#:@]+)", (url or "").strip(), re.I)
    return m.group(1).lower() if m else ""


def parse_suggestions(data, limit: int = 6) -> list:
    """Parse an OpenSearch suggestion response; tolerant of junk."""
    if isinstance(data, list) and len(data) >= 2 and isinstance(data[1], list):
        out = []
        for s in data[1]:
            if isinstance(s, str) and s.strip() and s not in out:
                out.append(s.strip()[:200])
        return out[:limit]
    return []


def image_is_blank(img) -> bool:
    """True if a QImage is (nearly) one flat color: a failed page capture."""
    if img is None or img.isNull() or img.width() < 8 or img.height() < 8:
        return True
    w, h = img.width(), img.height()
    vals = []
    for i in range(1, 9):
        for j in range(1, 9):
            c = img.pixelColor(int(w * i / 9), int(h * j / 9))
            vals.append(c.red() * 0.3 + c.green() * 0.59 + c.blue() * 0.11)
    mean = sum(vals) / len(vals)
    return sum((v - mean) ** 2 for v in vals) / len(vals) < 12
_SCHEME = re.compile(r"^(https?|file|about|data|blob|view-source|chrome|ftp):", re.I)
_HOSTPORT = re.compile(r"^(localhost|\d{1,3}(\.\d{1,3}){3}|\[[0-9a-f:]+\])(:\d+)?(/.*)?$", re.I)
_DOMAIN = re.compile(r"^([a-z0-9-]+\.)+[a-z]{2,24}(:\d+)?([/?#].*)?$", re.I)


def normalize_address(text: str, engine: str = "DuckDuckGo") -> str:
    """What the address bar navigates to for ``text``."""
    t = (text or "").strip()
    if not t:
        return ""
    if _SCHEME.match(t):
        return t
    if " " not in t:
        if _HOSTPORT.match(t):
            return "http://" + t
        if _DOMAIN.match(t):
            return "https://" + t
    return SEARCH_ENGINES.get(engine, SEARCH_ENGINES["DuckDuckGo"]).format(quote_plus(t))


def _keepable(url: str) -> bool:
    return url.startswith(("http://", "https://")) and len(url) < 2048


def create_profile(system_dir: Path, downloads_dir: str, adblocker):
    """A persistent QQuickWebEngineProfile with the ad blocker installed, or None.

    Returns None (QML then uses the default profile) if this PySide build
    can't create one or can't attach the interceptor, so ad blocking is never
    silently lost.
    """
    try:
        from PySide6.QtWebEngineQuick import QQuickWebEngineProfile
    except ImportError:
        return None
    try:
        root = Path(system_dir) / "browser"
        (root / "cache").mkdir(parents=True, exist_ok=True)
        profile = QQuickWebEngineProfile()
        # properties via the meta-object: robust across PySide binding versions
        profile.setProperty("storageName", "GlassOS")
        profile.setProperty("offTheRecord", False)
        profile.setProperty("persistentStoragePath", str(root))
        profile.setProperty("cachePath", str(root / "cache"))
        profile.setProperty("httpCacheType", 1)             # DiskHttpCache
        profile.setProperty("httpCacheMaximumSize", 512 * 1024 * 1024)
        profile.setProperty("persistentCookiesPolicy", 1)   # AllowPersistentCookies
        profile.setProperty("downloadPath", downloads_dir)
        ua = str(profile.property("httpUserAgent") or "")
        if "QtWebEngine" in ua:  # some sites serve degraded pages to unknown engines
            profile.setProperty("httpUserAgent", re.sub(r"\s*QtWebEngine/[\d.]+", "", ua))
        if adblocker is not None and not adblocker.install(profile):
            log.warning("persistent profile can't host the ad blocker; using the default profile")
            return None
        return profile
    except Exception as exc:
        log.warning("persistent browser profile unavailable: %s", exc)
        return None


class BrowserService(QObject):
    historyChanged = Signal()
    settingsChanged = Signal()
    shortcutsChanged = Signal()
    suggestionsReady = Signal(str, "QVariantList")   # query, suggestions
    faviconReady = Signal(str, str)                  # host, file url
    thumbnailReady = Signal(str, str)                # host, file url

    def __init__(self, prefs, system_dir: Path, profile=None, parent=None):
        super().__init__(parent)
        self._prefs = prefs
        self._profile = profile
        root = Path(system_dir) / "browser"
        self._icons = root / "icons"
        self._thumbs = root / "thumbs"
        self._icons.mkdir(parents=True, exist_ok=True)
        self._thumbs.mkdir(parents=True, exist_ok=True)
        self._nam = None
        self._suggest_reply = None
        self._icon_pending = set()
        self._icon_failed = set()
        self._file = Path(system_dir) / "browser_history.json"
        self._history = {}
        self._save_timer = QTimer(self)
        self._save_timer.setSingleShot(True)
        self._save_timer.setInterval(2000)
        self._save_timer.timeout.connect(self.flush)
        self._load()

    # ------------------------------------------------------------ persistence
    def _load(self):
        try:
            data = json.loads(self._file.read_text(encoding="utf-8"))
            if isinstance(data, list):
                for e in data:
                    if isinstance(e, dict) and isinstance(e.get("url"), str) and _keepable(e["url"]):
                        self._history[e["url"]] = {"url": e["url"], "title": str(e.get("title", ""))[:300],
                                                   "visits": int(e.get("visits", 1)), "last": float(e.get("last", 0))}
        except (OSError, ValueError, TypeError):
            pass

    @Slot()
    def flush(self):
        self._save_timer.stop()
        items = sorted(self._history.values(), key=lambda e: -e["last"])[:MAX_HISTORY]
        tmp = self._file.with_suffix(".tmp")
        try:
            tmp.write_text(json.dumps(items, ensure_ascii=False), encoding="utf-8")
            os.replace(tmp, self._file)
        except OSError as exc:
            log.warning("could not save history: %s", exc)

    # ------------------------------------------------------------ settings
    @Property("QVariantList", constant=True)
    def searchEngines(self) -> list:
        return list(SEARCH_ENGINES)

    @Property(str, notify=settingsChanged)
    def searchEngine(self) -> str:
        v = self._prefs.value("browser.search", "DuckDuckGo")
        return v if v in SEARCH_ENGINES else "DuckDuckGo"

    @Slot(str)
    def setSearchEngine(self, name: str):
        if name in SEARCH_ENGINES:
            self._prefs.setValue("browser.search", name)
            self.settingsChanged.emit()

    @Slot(str, result=str)
    def normalize(self, text: str) -> str:
        return normalize_address(text, self.searchEngine)

    @Slot(str, result=str)
    def searchUrl(self, query: str) -> str:
        return SEARCH_ENGINES[self.searchEngine].format(quote_plus(query or ""))

    # ------------------------------------------------------------ network helper
    def _net(self):
        if self._nam is None:
            from PySide6.QtNetwork import QNetworkAccessManager
            self._nam = QNetworkAccessManager(self)
        return self._nam

    def _get(self, url: str, timeout_ms: int):
        from PySide6.QtNetwork import QNetworkRequest
        req = QNetworkRequest(QUrl(url))
        req.setTransferTimeout(timeout_ms)
        req.setAttribute(QNetworkRequest.Attribute.RedirectPolicyAttribute,
                         QNetworkRequest.RedirectPolicy.NoLessSafeRedirectPolicy)
        req.setHeader(QNetworkRequest.KnownHeaders.UserAgentHeader, "Mozilla/5.0 GlassOS AeroBrowser")
        return self._net().get(req)

    # ------------------------------------------------------------ search suggestions
    @Property(bool, notify=settingsChanged)
    def suggestionsEnabled(self) -> bool:
        return self._prefs.value("browser.suggest", True) is not False

    @Slot(bool)
    def setSuggestionsEnabled(self, on: bool):
        self._prefs.setValue("browser.suggest", bool(on))
        self.settingsChanged.emit()

    @Slot(str)
    def requestSuggestions(self, query: str):
        """Ask the current search engine for completions; answers via suggestionsReady."""
        query = (query or "").strip()[:200]
        if self._suggest_reply is not None:
            old, self._suggest_reply = self._suggest_reply, None
            old.abort()
        if not query or not self.suggestionsEnabled or _SCHEME.match(query):
            self.suggestionsReady.emit(query, [])
            return
        reply = self._get(SUGGEST_URLS.get(self.searchEngine, SUGGEST_URLS["DuckDuckGo"]).format(quote_plus(query)), 4000)
        self._suggest_reply = reply

        def done():
            reply.deleteLater()
            if reply is not self._suggest_reply:
                return  # superseded by newer typing
            self._suggest_reply = None
            from PySide6.QtNetwork import QNetworkReply
            items = []
            if reply.error() == QNetworkReply.NetworkError.NoError:
                try:
                    items = parse_suggestions(json.loads(bytes(reply.readAll().data()[:200000]).decode("utf-8", "replace")))
                except ValueError:
                    items = []
            self.suggestionsReady.emit(query, items)

        reply.finished.connect(done)

    # ------------------------------------------------------------ favicons
    def _icon_file(self, host: str) -> Path:
        return self._icons / (re.sub(r"[^a-z0-9.\-]", "_", host) + ".png")

    @Slot(str, result=str)
    def favicon(self, url: str) -> str:
        """Cached favicon file URL for a site, or "" (then fetched; see faviconReady)."""
        host = host_of(url)
        if not host:
            return ""
        f = self._icon_file(host)
        if f.exists():
            return QUrl.fromLocalFile(str(f)).toString()
        if host not in self._icon_pending and host not in self._icon_failed:
            self._icon_pending.add(host)
            self._fetch_icon(host, 0)
        return ""

    def _fetch_icon(self, host: str, source: int):
        if source >= len(FAVICON_SOURCES):
            self._icon_pending.discard(host)
            self._icon_failed.add(host)
            return
        reply = self._get(FAVICON_SOURCES[source].format(host=host), 6000)

        def done():
            reply.deleteLater()
            from PySide6.QtGui import QImage
            from PySide6.QtNetwork import QNetworkReply
            img = QImage()
            if reply.error() == QNetworkReply.NetworkError.NoError:
                img.loadFromData(bytes(reply.readAll().data()[:2_000_000]))
            if img.isNull() or img.width() < 8:
                self._fetch_icon(host, source + 1)
                return
            if img.width() > 64:
                from PySide6.QtCore import Qt
                img = img.scaled(64, 64, Qt.KeepAspectRatio, Qt.SmoothTransformation)
            f = self._icon_file(host)
            if img.save(str(f), "PNG"):
                self._icon_pending.discard(host)
                self.faviconReady.emit(host, QUrl.fromLocalFile(str(f)).toString())
            else:
                self._fetch_icon(host, source + 1)

        reply.finished.connect(done)

    # ------------------------------------------------------------ page thumbnails
    def _thumb_file(self, host: str) -> Path:
        return self._thumbs / (re.sub(r"[^a-z0-9.\-]", "_", host) + ".jpg")

    @Slot(str, result=str)
    def thumbnail(self, url: str) -> str:
        host = host_of(url)
        f = self._thumb_file(host) if host else None
        return QUrl.fromLocalFile(str(f)).toString() if f is not None and f.exists() else ""

    @Slot(str, result=str)
    def thumbnailTarget(self, url: str) -> str:
        """Where QML should save a fresh capture of this page, or "" if the cached one is recent."""
        host = host_of(url)
        if not host or not url.startswith(("http://", "https://")):
            return ""
        f = self._thumb_file(host)
        if f.exists() and time.time() - f.stat().st_mtime < THUMB_MAX_AGE:
            return ""
        return str(f.with_suffix(".part.png"))

    @Slot(str, str)
    def thumbnailSaved(self, url: str, part_path: str):
        """QML saved a capture: keep it unless it's blank, as a small JPEG."""
        host = host_of(url)
        part = Path(part_path)
        try:
            from PySide6.QtCore import Qt
            from PySide6.QtGui import QImage
            img = QImage(str(part))
            if host and not image_is_blank(img):
                img = img.scaled(480, 300, Qt.KeepAspectRatioByExpanding, Qt.SmoothTransformation)
                target = self._thumb_file(host)
                if img.save(str(target), "JPG", 82):
                    self.thumbnailReady.emit(host, QUrl.fromLocalFile(str(target)).toString() + "?v=" + str(int(time.time())))
        except Exception as exc:
            log.debug("thumbnail save failed: %s", exc)
        finally:
            part.unlink(missing_ok=True)

    # ------------------------------------------------------------ speed dial
    @Property("QVariantList", notify=shortcutsChanged)
    def shortcuts(self) -> list:
        stored = self._prefs.value("browser.shortcuts", None)
        if isinstance(stored, list):
            return [s for s in stored if isinstance(s, dict) and isinstance(s.get("url"), str)][:24]
        # not customized yet: most visited sites, topped up with popular defaults
        out, seen = [], set()
        for s in self.topSites(8) + DEFAULT_SHORTCUTS:
            h = host_of(s["url"])
            if h and h not in seen:
                seen.add(h)
                out.append({"title": s["title"], "url": s["url"]})
        return out[:8]

    def _store_shortcuts(self, items):
        self._prefs.setValue("browser.shortcuts", items[:24])
        self.shortcutsChanged.emit()

    @Slot(str, str)
    def addShortcut(self, title: str, url: str):
        url = normalize_address(url, self.searchEngine) if url and "://" not in url else (url or "")
        if not host_of(url):
            return
        items = [s for s in self.shortcuts if s["url"] != url]
        items.append({"title": (title or host_of(url)).strip()[:40], "url": url})
        self._store_shortcuts(items)

    @Slot(str, str, str)
    def updateShortcut(self, old_url: str, title: str, url: str):
        url = normalize_address(url, self.searchEngine) if url and "://" not in url else (url or "")
        if not host_of(url):
            return
        self._store_shortcuts([{"title": (title or host_of(url)).strip()[:40], "url": url} if s["url"] == old_url else s
                               for s in self.shortcuts])

    @Slot(str)
    def removeShortcut(self, url: str):
        self._store_shortcuts([s for s in self.shortcuts if s["url"] != url])

    @Slot()
    def resetShortcuts(self):
        self._prefs.setValue("browser.shortcuts", None)
        self.shortcutsChanged.emit()

    # ------------------------------------------------------------ history
    @Slot(str, str)
    def addVisit(self, url: str, title: str):
        if not _keepable(url or ""):
            return
        e = self._history.get(url)
        if e is None:
            e = self._history[url] = {"url": url, "title": "", "visits": 0, "last": 0.0}
            if len(self._history) > MAX_HISTORY * 1.2:
                for old in sorted(self._history.values(), key=lambda x: x["last"])[:len(self._history) - MAX_HISTORY]:
                    self._history.pop(old["url"], None)
        e["visits"] += 1
        e["last"] = time.time()
        if title:
            e["title"] = title[:300]
        self._save_timer.start()
        self.historyChanged.emit()
        if self._prefs.value("browser.shortcuts", None) is None:
            self.shortcutsChanged.emit()   # most-visited tiles may have changed

    @Slot(str, str)
    def setTitle(self, url: str, title: str):
        e = self._history.get(url)
        if e is not None and title and e["title"] != title:
            e["title"] = title[:300]
            self._save_timer.start()

    @Slot(str, int, result="QVariantList")
    def suggest(self, query: str, limit: int = 6) -> list:
        """Rank history entries for the address bar: prefix-of-host > word match, frequency, recency."""
        q = (query or "").strip().lower()
        if not q:
            return []
        now = time.time()
        scored = []
        for e in self._history.values():
            url_l = e["url"].lower()
            host = re.sub(r"^https?://(www\.)?", "", url_l)
            title_l = e["title"].lower()
            if host.startswith(q):
                base = 100
            elif q in host:
                base = 40
            elif q in title_l:
                base = 25
            else:
                continue
            age_days = (now - e["last"]) / 86400
            score = base + min(e["visits"], 50) * 2 - min(age_days, 60) * 0.5
            scored.append((score, e))
        scored.sort(key=lambda x: -x[0])
        return [{"url": e["url"], "title": e["title"]} for _, e in scored[:max(1, min(limit, 20))]]

    @Slot(int, result="QVariantList")
    def recent(self, limit: int = 200) -> list:
        items = sorted(self._history.values(), key=lambda e: -e["last"])[:max(1, min(limit, 2000))]
        return [{"url": e["url"], "title": e["title"], "last": int(e["last"] * 1000)} for e in items]

    @Slot(int, result="QVariantList")
    def topSites(self, limit: int = 8) -> list:
        """Most visited sites (one entry per host) for the new-tab page."""
        best = {}
        for e in self._history.values():
            host = re.sub(r"^https?://(www\.)?", "", e["url"]).split("/")[0]
            if host and (host not in best or e["visits"] > best[host]["visits"]):
                best[host] = e
        items = sorted(best.values(), key=lambda e: -e["visits"])[:max(1, min(limit, 24))]
        return [{"url": e["url"], "title": e["title"] or re.sub(r"^https?://(www\.)?", "", e["url"]).split("/")[0]} for e in items]

    @Slot(str)
    def removeHistory(self, url: str):
        if self._history.pop(url, None) is not None:
            self._save_timer.start()
            self.historyChanged.emit()

    @Slot()
    def clearHistory(self):
        self._history.clear()
        self.flush()
        self.historyChanged.emit()

    @Slot()
    def clearBrowsingData(self):
        """History + cache + cookies."""
        self.clearHistory()
        p = self._profile
        if p is None:
            return
        for name in ("clearHttpCache",):
            fn = getattr(p, name, None)
            if callable(fn):
                try:
                    fn()
                except Exception as exc:
                    log.debug("%s failed: %s", name, exc)
        store = getattr(p, "cookieStore", None)
        try:
            if callable(store):
                store().deleteAllCookies()
        except Exception as exc:
            log.debug("cookie clearing failed: %s", exc)
