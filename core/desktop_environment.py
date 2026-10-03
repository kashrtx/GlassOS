"""
GlassOS desktop environment: creates every backend service, exposes them to
QML as context properties and loads ``qml/Main.qml``.

Context properties available in every QML file:

=================  ============================================================
``Storage``        sandboxed file system (core.storage)
``Prefs``          settings + frosted wallpaper (core.settings)
``System``         info, live resources, power actions (core.system)
``Shell``          terminal engine (core.shell)
``Calc``           calculator engine (core.calc)
``WeatherService`` weather (core.weather_service)
``AdBlocker``      ad blocker, or ``null`` without QtWebEngine
``HasWebEngine``   bool
``LaunchArgs``     {"windowed": bool, "skipBoot": bool}
=================  ============================================================
"""

from __future__ import annotations

from pathlib import Path

from PySide6.QtCore import QObject, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

from . import log as _log
from .calc import CalcProvider
from .media import AudioVisualizer
from .settings import Prefs
from .shell import ShellProvider
from .storage import StorageProvider
from .system import SystemProvider
from .weather_service import WeatherProvider

PROJECT_ROOT = Path(__file__).resolve().parent.parent
log = _log.get("desktop")
qml_log = _log.get("qml")


class DesktopEnvironment(QObject):
    def __init__(self, app: QGuiApplication, has_webengine: bool, windowed: bool = False,
                 skip_boot: bool = False, storage_dir: Path | None = None):
        super().__init__()
        self.app = app
        base = Path(storage_dir) if storage_dir else PROJECT_ROOT / "Storage"
        self.storage = StorageProvider(base / "User", self)
        self.prefs = Prefs(base / "System", self.storage, self)
        self.system = SystemProvider(self.storage.root, self)
        self.system.install_excepthook()
        self.shell = ShellProvider(self.storage, self.prefs, self.system, self)
        self.calc = CalcProvider(self)
        self.weather = WeatherProvider(self.prefs, self)
        self.visualizer = AudioVisualizer(self)
        from .highlight import SyntaxService
        self.syntax = SyntaxService(self)
        from .clipboard import ClipboardService
        try:
            self.clipboard = ClipboardService(self.prefs, self.storage, self)
        except Exception as exc:  # pragma: no cover - no system clipboard (e.g. headless)
            log.warning("clipboard integration unavailable: %s", exc)
            self.clipboard = None
        try:
            import PySide6.QtMultimedia  # noqa: F401
            self.has_multimedia = True
        except ImportError:
            self.has_multimedia = False
            log.warning("QtMultimedia not available - the Media Player is disabled")

        # native crashes (Qt/Chromium) leave a Python traceback here
        try:
            import faulthandler
            (base / "System").mkdir(parents=True, exist_ok=True)
            self._crash_log = open(base / "System" / "crash.log", "a", encoding="utf-8")
            faulthandler.enable(self._crash_log, all_threads=True)
        except Exception as exc:  # pragma: no cover
            log.debug("faulthandler unavailable: %s", exc)
        from .extensions import ExtensionService, purge_installed
        self.extensions = ExtensionService(base / "System", self.prefs, self)
        if not self.extensions.experimental:
            # Qt auto-loads installed extensions at every startup; with the feature off,
            # make sure nothing (e.g. a half-finished install) gets loaded at all
            if purge_installed(base / "System" / "browser"):
                log.info("removed installed browser extensions (extensions are switched off)")
        self.adblocker = None
        self.browser_profile = None
        if has_webengine:
            try:
                from PySide6.QtWebEngineCore import QWebEngineProfile

                from .adblocker import AdBlockerProvider
                from .browser import create_profile
                self.adblocker = AdBlockerProvider(self.prefs, base / "System" / "filters", self)
                self.adblocker.install(QWebEngineProfile.defaultProfile())
                self.browser_profile = create_profile(base / "System", self.storage.downloadsDir, self.adblocker)
                if self.browser_profile is not None:
                    self.browser_profile.setParent(self)
                    log.info("AeroBrowser: persistent profile with ad blocking")
            except Exception as exc:  # pragma: no cover - environment specific
                log.warning("browser services limited: %s", exc)
        from .thumbnails import ThumbnailService
        self.thumbs = ThumbnailService(self.storage, base / "System" / "cache" / "thumbs", self)
        from .browser import BrowserService
        self.browser = BrowserService(self.prefs, base / "System", self.browser_profile, self)
        app.aboutToQuit.connect(self.browser.flush)

        screen = app.primaryScreen()
        if screen is not None:
            size = screen.size()
            self.prefs.setScreenSize(size.width(), size.height())
        else:
            self.prefs.renderBlur()

        app.aboutToQuit.connect(self.prefs.flush)
        app.aboutToQuit.connect(self.extensions.markInactive)   # clean exit disarms the crash guard
        # "Bold text" accessibility option: the application font drives every
        # text item that doesn't set its own weight
        self._apply_font_weight()
        self.prefs.textSizeChanged.connect(self._apply_font_weight)

        self.engine = QQmlApplicationEngine(self)
        self.engine.addImportPath(str(PROJECT_ROOT / "qml"))
        ctx = self.engine.rootContext()
        ctx.setContextProperty("Storage", self.storage)
        ctx.setContextProperty("Prefs", self.prefs)
        ctx.setContextProperty("System", self.system)
        ctx.setContextProperty("Shell", self.shell)
        ctx.setContextProperty("Calc", self.calc)
        ctx.setContextProperty("WeatherService", self.weather)
        ctx.setContextProperty("AdBlocker", self.adblocker)
        ctx.setContextProperty("HasWebEngine", bool(has_webengine))
        ctx.setContextProperty("HasMultimedia", self.has_multimedia)
        ctx.setContextProperty("Visualizer", self.visualizer)
        ctx.setContextProperty("Clipboard", self.clipboard)
        ctx.setContextProperty("Thumbs", self.thumbs)
        ctx.setContextProperty("Syntax", self.syntax)
        ctx.setContextProperty("Extensions", self.extensions)
        # NB: not "Browser" - that name is taken by qml/apps/Browser.qml, and inside
        # that folder QML resolves the *type* first, which silently broke every call.
        ctx.setContextProperty("Web", self.browser)
        ctx.setContextProperty("BrowserProfile", self.browser_profile)
        ctx.setContextProperty("LaunchArgs", {"windowed": windowed, "skipBoot": skip_boot})

        self.engine.warnings.connect(self._on_warnings)

    @staticmethod
    def _on_warnings(warnings):
        for w in warnings:
            qml_log.warning("%s", w.toString())

    def _apply_font_weight(self):
        try:
            from PySide6.QtGui import QFont
            f = self.app.font()
            f.setWeight(QFont.Weight.DemiBold if self.prefs.boldText else QFont.Weight.Normal)
            self.app.setFont(f)
        except Exception as exc:  # pragma: no cover
            log.debug("font weight: %s", exc)

    def shutdown(self):
        """Tear the QML engine down *before* the Python services it binds to.

        Otherwise bindings re-evaluate against already-freed context objects
        during interpreter shutdown and spam "Cannot read property ... of null".
        """
        self.prefs.flush()
        engine, self.engine = self.engine, None
        if engine is None:
            return
        try:
            import shiboken6
            for obj in engine.rootObjects():
                shiboken6.delete(obj)
            shiboken6.delete(engine)
        except Exception as exc:  # pragma: no cover - best effort during exit
            log.debug("engine teardown: %s", exc)

    def show(self) -> bool:
        main_qml = PROJECT_ROOT / "qml" / "Main.qml"
        self.engine.load(QUrl.fromLocalFile(str(main_qml)))
        if not self.engine.rootObjects():
            log.critical("GlassOS could not load its interface - see the QML errors above")
            return False
        return True
