"""
GlassOS Preferences
===================

A single JSON-backed settings store exposed to QML as ``Prefs``.

* Frequently-bound values are real Qt properties with change signals.
* Apps can store anything else with ``Prefs.value(key, default)`` /
  ``Prefs.setValue(key, value)``.
* Writes are debounced (one disk write per burst of changes) and atomic.
* The wallpaper is stored as a *virtual* path, so settings are portable
  between machines (the old build stored ``S:/...`` absolute paths).
* A blurred, darkened copy of the wallpaper is rendered in a worker thread
  with Pillow. Windows, the taskbar and the start menu sample it to get a
  frosted-glass ("Mica") look for free at runtime.
"""

from __future__ import annotations

import copy
import hashlib
import json
import os
import threading
from pathlib import Path
from typing import Any, Optional

from PySide6.QtCore import QObject, Property, Qt, QTimer, QUrl, Signal, Slot
from PySide6.QtGui import QColor

from . import log as _log

log = _log.get("settings")

def to_plain(value, _depth=0):
    """Convert values arriving from QML into plain JSON-compatible Python data.

    PySide6 delivers JS arrays/objects passed to a "QVariant" slot as QJSValue
    objects (which can't be copied or serialized), so unwrap them recursively.
    """
    if _depth > 32:
        raise ValueError("value nested too deeply")
    if hasattr(value, "toVariant") and not isinstance(value, (str, bytes)):
        value = value.toVariant()
    if isinstance(value, dict):
        return {str(k): to_plain(v, _depth + 1) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [to_plain(v, _depth + 1) for v in value]
    if value is None or isinstance(value, (bool, int, float, str)):
        return value
    raise TypeError(f"unsupported value type {type(value).__name__}")


ACCENTS = ["#4cc2ff", "#a78bfa", "#f472b6", "#fb923c", "#facc15", "#34d399", "#2dd4bf", "#f87171"]
TEXT_SCALES = [0.9, 1.0, 1.15, 1.3]

DEFAULTS: dict = {
    "accent": ACCENTS[0],
    "wallpaper": "",
    "volume": 60,
    "muted": False,
    "use24h": False,
    "textSize": 1,
    "glass": True,
    "animations": True,
    "nightLight": False,
    "userName": "",
    "fullscreen": True,
    "adblock": True,
    "showDesktopClock": True,
    "boldText": True,
    "weatherUnit": "C",
    "data": {},  # free-form per-app storage
}


class Prefs(QObject):
    accentChanged = Signal()
    wallpaperChanged = Signal()
    blurredWallpaperChanged = Signal()
    volumeChanged = Signal()
    clockChanged = Signal()
    textSizeChanged = Signal()
    effectsChanged = Signal()
    userChanged = Signal()
    miscChanged = Signal()
    valueChanged = Signal(str)

    _blurDone = Signal(int, str, str)  # (generation, wallpaper vpath, file path) - worker -> GUI thread

    def __init__(self, system_dir: Path, storage, parent: Optional[QObject] = None):
        super().__init__(parent)
        self._dir = Path(system_dir)
        self._dir.mkdir(parents=True, exist_ok=True)
        self._cache = self._dir / "cache"
        self._cache.mkdir(exist_ok=True)
        self._file = self._dir / "settings.json"
        self._storage = storage
        self._data = copy.deepcopy(DEFAULTS)
        self._blur_url = ""
        self._screen = (1920, 1080)
        self._blur_generation = 0              # bumped per request; stale results are dropped
        self._blur_lock = threading.Lock()     # one decode at a time (bounded CPU & memory)

        self._save_timer = QTimer(self)
        self._save_timer.setSingleShot(True)
        self._save_timer.setInterval(400)
        self._save_timer.timeout.connect(self.flush)
        self._blurDone.connect(self._on_blur_done, Qt.QueuedConnection)

        self._load()
        self._validate_wallpaper()

    # ------------------------------------------------------------ persistence
    def _load(self):
        if self._file.exists():
            try:
                stored = json.loads(self._file.read_text(encoding="utf-8"))
                if isinstance(stored, dict):
                    for key, value in stored.items():
                        # exact type match: bool is a subclass of int, so isinstance() is too lax
                        if key in DEFAULTS and type(value) is type(DEFAULTS[key]):
                            self._data[key] = value
                        elif key in DEFAULTS:
                            log.warning("ignoring setting %r with unexpected type %s", key, type(value).__name__)
            except (OSError, ValueError) as exc:
                log.warning("settings file unreadable, using defaults: %s", exc)
                self._backup_corrupt()
        else:
            self._migrate_legacy()
        self._data["textSize"] = max(0, min(3, int(self._data["textSize"])))
        self._data["volume"] = max(0, min(100, int(self._data["volume"])))
        if not QColor(self._data["accent"]).isValid():
            self._data["accent"] = ACCENTS[0]

    def _backup_corrupt(self):
        try:
            os.replace(self._file, self._file.with_suffix(".corrupt.json"))
        except OSError:
            pass

    def _migrate_legacy(self):
        """Import settings from the old GlassOS layout (Storage/User/Settings)."""
        old = self._storage.root / "Settings" / "system_settings.json"
        try:
            legacy = json.loads(old.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            return
        if isinstance(legacy.get("volume"), int):
            self._data["volume"] = legacy["volume"]
        wp = str(legacy.get("wallpaper", ""))
        if wp:
            # old builds stored absolute paths from another machine: keep only the file name
            name = wp.replace("\\", "/").rsplit("/", 1)[-1]
            self._data["wallpaper"] = f"/Pictures/Wallpapers/{name}"
        log.info("migrated settings from the previous GlassOS version")
        self._schedule()

    def _schedule(self):
        self._save_timer.start()

    @Slot()
    def flush(self):
        self._save_timer.stop()
        tmp = self._file.with_suffix(".tmp")
        try:
            payload = json.dumps(self._data, indent=2, ensure_ascii=False)
        except (TypeError, ValueError) as exc:  # should be impossible: setValue validates
            log.error("settings not serializable, not saving: %s", exc)
            return
        try:
            tmp.write_text(payload, encoding="utf-8")
            os.replace(tmp, self._file)
        except OSError as exc:
            log.error("could not save settings: %s", exc)

    def _set(self, key: str, value: Any, signal: Signal) -> bool:
        if self._data.get(key) == value:
            return False
        self._data[key] = value
        signal.emit()
        self._schedule()
        return True

    # ------------------------------------------------------------ generic API
    @Slot(str, "QVariant", result="QVariant")
    def value(self, key: str, default=None):
        if key in self._data["data"]:
            return copy.deepcopy(self._data["data"][key])
        try:
            return to_plain(default)
        except (TypeError, ValueError):
            return None

    @Slot(str, "QVariant")
    def setValue(self, key: str, value):
        if not isinstance(key, str) or not key:
            log.warning("setValue: invalid key %r", key)
            return
        try:
            value = to_plain(value)
            encoded = json.dumps(value)
        except (TypeError, ValueError):
            log.warning("setValue(%r): value is not JSON-serializable, ignored", key)
            return
        if len(encoded) > 2_000_000:
            log.warning("setValue(%r): value too large (%d bytes), ignored", key, len(encoded))
            return
        if self._data["data"].get(key) == value:
            return
        self._data["data"][key] = value
        self.valueChanged.emit(key)
        self._schedule()

    @Slot()
    def resetAll(self):
        keep_wallpaper = self._data["wallpaper"]
        self._data = copy.deepcopy(DEFAULTS)
        self._data["wallpaper"] = keep_wallpaper
        for sig in (self.accentChanged, self.volumeChanged, self.clockChanged, self.textSizeChanged,
                    self.effectsChanged, self.userChanged, self.miscChanged):
            sig.emit()
        self._schedule()

    # ----------------------------------------------------------------- accent
    @Property(QColor, notify=accentChanged)
    def accent(self) -> QColor:
        return QColor(self._data["accent"])

    @Slot(str)
    def setAccent(self, color: str):
        if QColor(color).isValid():
            self._set("accent", QColor(color).name(), self.accentChanged)

    @Property("QVariantList", constant=True)
    def accentPresets(self) -> list:
        return list(ACCENTS)

    # -------------------------------------------------------------- wallpaper
    def _validate_wallpaper(self):
        wp = self._data["wallpaper"]
        if not wp or not self._storage.exists(wp):
            walls = self._storage.wallpapers()
            preferred = [w for w in walls if "ian dooley" in w["name"].lower()]
            self._data["wallpaper"] = (preferred or walls or [{"path": ""}])[0]["path"]
            self._schedule()

    @Property(str, notify=wallpaperChanged)
    def wallpaper(self) -> str:
        return self._data["wallpaper"]

    @Property(str, notify=wallpaperChanged)
    def wallpaperUrl(self) -> str:
        return self._storage.fileUrl(self._data["wallpaper"]) if self._data["wallpaper"] else ""

    @Slot(str, result=bool)
    def setWallpaper(self, vpath: str) -> bool:
        if not self._storage.exists(vpath) or self._storage.kindOf(vpath) != "image":
            return False
        if self._set("wallpaper", vpath, self.wallpaperChanged):
            self._blur_url = ""
            self.blurredWallpaperChanged.emit()
            self.renderBlur()
        return True

    @Property(str, notify=blurredWallpaperChanged)
    def blurredWallpaperUrl(self) -> str:
        return self._blur_url

    @Slot(int, int)
    def setScreenSize(self, width: int, height: int):
        self._screen = (max(320, width), max(240, height))
        self.renderBlur()

    @Slot()
    def renderBlur(self):
        vpath = self._data["wallpaper"]
        real = self._storage.real_path(vpath) if vpath else None
        if real is None or not real.is_file():
            return
        try:
            import PIL  # noqa: F401  (optional dependency)
        except ImportError:
            log.info("Pillow not installed: glass falls back to a tinted surface")
            return
        self._blur_generation += 1
        threading.Thread(target=self._blur_worker, args=(self._blur_generation, vpath, real, self._screen),
                         daemon=True, name="glassos-blur").start()

    def _blur_target(self, real: Path, screen) -> Path:
        w, h = max(64, screen[0] // 4), max(64, screen[1] // 4)
        stamp = f"{real}:{real.stat().st_mtime_ns}:{w}x{h}:v4"
        return self._cache / f"blur-{hashlib.sha1(stamp.encode()).hexdigest()[:16]}.jpg"

    def _blur_worker(self, generation: int, vpath: str, real: Path, screen):
        """Runs on a worker thread. Never touches Qt objects except emitting a queued signal."""
        try:
            with self._blur_lock:
                if generation != self._blur_generation:
                    return  # a newer wallpaper was chosen while we waited
                out = self._blur_target(real, screen)
                if not out.exists():
                    self._render_blur(real, out, screen)
            self._blurDone.emit(generation, vpath, str(out))
        except Exception as exc:  # never let a bad image take the shell down
            log.warning("could not render glass wallpaper for %s: %s", vpath, exc)

    @staticmethod
    def _render_blur(real: Path, out: Path, screen):
        from PIL import Image, ImageEnhance, ImageFilter
        w, h = max(64, screen[0] // 4), max(64, screen[1] // 4)
        with Image.open(real) as im:
            im.draft("RGB", (w * 2, h * 2))  # fast reduced-size JPEG decode (DCT scaling)
            im = im.convert("RGB")
            # downscale only (no crop): QML cover-crops it exactly like the sharp
            # wallpaper, so the glass stays aligned at any window size
            scale = max(w / im.width, h / im.height)
            im = im.resize((max(1, round(im.width * scale)), max(1, round(im.height * scale))), Image.BILINEAR)
            im = im.filter(ImageFilter.GaussianBlur(radius=max(6, w // 48)))
            im = ImageEnhance.Color(im).enhance(1.25)
            im = ImageEnhance.Brightness(im).enhance(0.62)
            tmp = out.with_suffix(".part")
            im.save(tmp, "JPEG", quality=88)
            os.replace(tmp, out)  # atomic: QML never sees a half-written image

    @Slot(int, str, str)
    def _on_blur_done(self, generation: int, vpath: str, path: str):
        if generation != self._blur_generation or vpath != self._data["wallpaper"]:
            return
        url = QUrl.fromLocalFile(path).toString()
        if url != self._blur_url:
            self._blur_url = url
            self.blurredWallpaperChanged.emit()
        keep = Path(path).name
        for old in self._cache.glob("blur-*"):
            if old.name != keep:
                old.unlink(missing_ok=True)

    # ----------------------------------------------------------------- volume
    @Property(int, notify=volumeChanged)
    def volume(self) -> int:
        return self._data["volume"]

    @Slot(int)
    def setVolume(self, value: int):
        self._set("volume", max(0, min(100, int(value))), self.volumeChanged)

    @Property(bool, notify=volumeChanged)
    def muted(self) -> bool:
        return self._data["muted"]

    @Slot(bool)
    def setMuted(self, value: bool):
        self._set("muted", bool(value), self.volumeChanged)

    # ------------------------------------------------------------------ clock
    @Property(bool, notify=clockChanged)
    def use24h(self) -> bool:
        return self._data["use24h"]

    @Slot(bool)
    def setUse24h(self, value: bool):
        self._set("use24h", bool(value), self.clockChanged)

    # -------------------------------------------------------------- text size
    @Property(int, notify=textSizeChanged)
    def textSize(self) -> int:
        return self._data["textSize"]

    @Property(float, notify=textSizeChanged)
    def textScale(self) -> float:
        return TEXT_SCALES[self._data["textSize"]]

    @Slot(int)
    def setTextSize(self, preset: int):
        self._set("textSize", max(0, min(3, int(preset))), self.textSizeChanged)

    # ------------------------------------------------------------- bold text
    @Property(bool, notify=textSizeChanged)
    def boldText(self) -> bool:
        return self._data["boldText"]

    @Slot(bool)
    def setBoldText(self, value: bool):
        self._set("boldText", bool(value), self.textSizeChanged)

    # ---------------------------------------------------------------- effects
    @Property(bool, notify=effectsChanged)
    def glass(self) -> bool:
        return self._data["glass"]

    @Slot(bool)
    def setGlass(self, value: bool):
        self._set("glass", bool(value), self.effectsChanged)

    @Property(bool, notify=effectsChanged)
    def animations(self) -> bool:
        return self._data["animations"]

    @Slot(bool)
    def setAnimations(self, value: bool):
        self._set("animations", bool(value), self.effectsChanged)

    @Property(bool, notify=effectsChanged)
    def nightLight(self) -> bool:
        return self._data["nightLight"]

    @Slot(bool)
    def setNightLight(self, value: bool):
        self._set("nightLight", bool(value), self.effectsChanged)

    # ------------------------------------------------------------------- user
    @Property(str, notify=userChanged)
    def userName(self) -> str:
        return self._data["userName"] or _default_user()

    @Slot(str)
    def setUserName(self, name: str):
        self._set("userName", (name or "").strip()[:32], self.userChanged)

    # ------------------------------------------------------------------- misc
    @Property(bool, notify=miscChanged)
    def fullscreen(self) -> bool:
        return self._data["fullscreen"]

    @Slot(bool)
    def setFullscreen(self, value: bool):
        self._set("fullscreen", bool(value), self.miscChanged)

    @Property(bool, notify=miscChanged)
    def adblock(self) -> bool:
        return self._data["adblock"]

    @Slot(bool)
    def setAdblock(self, value: bool):
        self._set("adblock", bool(value), self.miscChanged)

    @Property(bool, notify=miscChanged)
    def showDesktopClock(self) -> bool:
        return self._data["showDesktopClock"]

    @Slot(bool)
    def setShowDesktopClock(self, value: bool):
        self._set("showDesktopClock", bool(value), self.miscChanged)

    @Property(str, notify=miscChanged)
    def weatherUnit(self) -> str:
        return self._data["weatherUnit"]

    @Slot(str)
    def setWeatherUnit(self, unit: str):
        if unit in ("C", "F"):
            self._set("weatherUnit", unit, self.miscChanged)


def _default_user() -> str:
    for var in ("USER", "USERNAME"):
        name = os.environ.get(var, "").strip()
        if name and name.lower() not in ("root", "admin", "administrator"):
            return name[:1].upper() + name[1:]
    return "Explorer"
