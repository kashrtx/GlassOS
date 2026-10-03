"""
GlassOS AdBlocker for AeroBrowser, exposed to QML as ``AdBlocker``.

* Blocks with EasyList + EasyPrivacy (downloaded in the background, refreshed
  every 4 days, cached in Storage/System/filters) plus a built-in fallback list.
* Lists are parsed on a worker thread; the finished engine is swapped in
  atomically, so browsing never waits for parsing.
* Exposes generic element-hiding CSS that AeroBrowser injects into pages.

Requires QtWebEngine (PySide6-Addons); GlassOS runs fine without it.
"""

from __future__ import annotations

import threading
import time
from pathlib import Path

from PySide6.QtCore import QObject, Property, Qt, QTimer, QUrl, Signal, Slot
from PySide6.QtNetwork import QNetworkAccessManager, QNetworkReply, QNetworkRequest
from PySide6.QtWebEngineCore import QWebEngineUrlRequestInfo, QWebEngineUrlRequestInterceptor

from . import log as _log
from .adblock_rules import FilterEngine, should_block
from .adblocker_lists import bundled_lists

log = _log.get("adblock")

FILTER_LISTS = {
    "easylist": "https://easylist.to/easylist/easylist.txt",
    "easyprivacy": "https://easylist.to/easylist/easyprivacy.txt",
}
REFRESH_SECONDS = 4 * 24 * 3600

_TYPE_NAMES = {
    "ResourceTypeStylesheet": "stylesheet", "ResourceTypeScript": "script", "ResourceTypeImage": "image",
    "ResourceTypeFontResource": "font", "ResourceTypeObject": "object", "ResourceTypeMedia": "media",
    "ResourceTypeXhr": "xmlhttprequest", "ResourceTypePing": "ping", "ResourceTypeSubFrame": "subdocument",
    "ResourceTypeWebSocket": "websocket", "ResourceTypeFavicon": "image",
}


class _Interceptor(QWebEngineUrlRequestInterceptor):
    def __init__(self, owner: "AdBlockerProvider"):
        super().__init__(owner)
        self._owner = owner

    def interceptRequest(self, info: QWebEngineUrlRequestInfo):  # noqa: N802 (Qt API)
        owner = self._owner
        if not owner._enabled:
            return
        url = info.requestUrl()
        rt = info.resourceType()
        name = getattr(rt, "name", "")
        main = name in ("ResourceTypeMainFrame", "ResourceTypeNavigationPreloadMainFrame")
        if should_block(url.toString(), url.host(), info.firstPartyUrl().host(), main,
                        owner._engine, _TYPE_NAMES.get(name, "other")):
            info.block(True)
            owner._bump()


class AdBlockerProvider(QObject):
    enabledChanged = Signal()
    blockedCountChanged = Signal()
    listsChanged = Signal()
    _parsed = Signal(object, int)   # engine, rule count  (worker -> GUI thread)

    def __init__(self, prefs, filters_dir: Path, parent=None):
        super().__init__(parent)
        self._prefs = prefs
        self._dir = Path(filters_dir)
        self._dir.mkdir(parents=True, exist_ok=True)
        self._enabled = prefs.adblock
        self._engine = None
        self._rules = 0
        self._css = ""
        self._updating = False
        self._count = 0
        self._nam = None
        self._pending = {}
        self._interceptor = _Interceptor(self)
        self._notify = QTimer(self)   # coalesce UI updates: pages fire hundreds of blocked requests
        self._notify.setSingleShot(True)
        self._notify.setInterval(300)
        self._notify.timeout.connect(self.blockedCountChanged.emit)
        self._parsed.connect(self._on_parsed, Qt.QueuedConnection)
        self._load_cached()
        if self._stale():
            QTimer.singleShot(6000, self.updateLists)   # don't compete with startup

    # ------------------------------------------------------------ install
    def install(self, profile) -> bool:
        if profile is not None and hasattr(profile, "setUrlRequestInterceptor"):
            profile.setUrlRequestInterceptor(self._interceptor)
            return True
        return False

    def _bump(self):
        self._count += 1
        if not self._notify.isActive():
            self._notify.start()

    # ------------------------------------------------------------ filter lists
    def _stale(self) -> bool:
        files = [self._dir / f"{k}.txt" for k in FILTER_LISTS]
        return not all(f.exists() for f in files) or \
            min(f.stat().st_mtime for f in files) < time.time() - REFRESH_SECONDS

    def _load_cached(self):
        texts, have = [], set()
        for key in FILTER_LISTS:
            f = self._dir / f"{key}.txt"
            if f.exists():
                try:
                    texts.append(f.read_text(encoding="utf-8", errors="replace"))
                    have.add(key)
                except OSError as exc:
                    log.warning("could not read %s: %s", f, exc)
        threading.Thread(target=self._parse_worker, args=(texts, have), daemon=True, name="glassos-adblock").start()

    def _parse_worker(self, texts, have=frozenset()):
        t = time.time()
        engine = FilterEngine()
        for text in bundled_lists(have) + texts:
            engine.add_text(text)
        log.info("filter lists parsed: %d rules (%d skipped) in %.1fs", engine.rule_count, engine.skipped, time.time() - t)
        self._parsed.emit(engine, engine.rule_count)

    @Slot(object, int)
    def _on_parsed(self, engine, count):
        self._engine = engine          # atomic swap: the interceptor reads one reference
        self._rules = count
        self._css = engine.cosmetic_css()
        self.listsChanged.emit()

    @Slot()
    def updateLists(self):
        if self._updating:
            return
        self._nam = self._nam or QNetworkAccessManager(self)
        self._updating = True
        self._pending = {}
        self.listsChanged.emit()
        for key, url in FILTER_LISTS.items():
            req = QNetworkRequest(QUrl(url))
            req.setTransferTimeout(30000)
            req.setHeader(QNetworkRequest.KnownHeaders.UserAgentHeader, "GlassOS/2.3 AeroBrowser")
            reply = self._nam.get(req)
            self._pending[key] = None
            reply.finished.connect(lambda r=reply, k=key: self._on_list(k, r))

    def _on_list(self, key, reply: QNetworkReply):
        reply.deleteLater()
        if reply.error() == QNetworkReply.NetworkError.NoError:
            data = bytes(reply.readAll().data())
            if data.lstrip().startswith(b"[Adblock") or b"||" in data[:20000]:
                (self._dir / f"{key}.txt").write_bytes(data)
                self._pending[key] = True
            else:
                log.warning("%s: unexpected content, keeping the cached copy", key)
                self._pending[key] = False
        else:
            log.warning("could not download %s: %s", key, reply.errorString())
            self._pending[key] = False
        if all(v is not None for v in self._pending.values()):
            self._updating = False
            if any(self._pending.values()):
                self._load_cached()
            self.listsChanged.emit()

    # ------------------------------------------------------------ properties
    @Property(bool, notify=enabledChanged)
    def enabled(self) -> bool:
        return self._enabled

    @Slot(bool)
    def setEnabled(self, value: bool):
        value = bool(value)
        if value != self._enabled:
            self._enabled = value
            self._prefs.setAdblock(value)
            self.enabledChanged.emit()

    @Property(int, notify=blockedCountChanged)
    def blockedCount(self) -> int:
        return self._count

    @Property(int, notify=listsChanged)
    def ruleCount(self) -> int:
        return self._rules

    @Property(bool, notify=listsChanged)
    def updating(self) -> bool:
        return self._updating

    @Property(str, notify=listsChanged)
    def listsUpdated(self) -> str:
        files = [self._dir / f"{k}.txt" for k in FILTER_LISTS if (self._dir / f"{k}.txt").exists()]
        if not files:
            return ""
        return time.strftime("%b %d, %H:%M", time.localtime(max(f.stat().st_mtime for f in files)))

    @Property(str, notify=listsChanged)
    def cosmeticCss(self) -> str:
        return self._css
