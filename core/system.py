"""
GlassOS system services, exposed to QML as ``System``.

* static info (version, host OS, Python/Qt versions)
* live CPU / memory / disk usage (psutil if available, sampled every 2 s)
* power actions (quit, restart)
* the *Sentinel*: a global exception hook that turns Python errors into a
  friendly notification instead of a crash, with rate limiting.
"""

from __future__ import annotations

import os
import platform
import sys
import time
import traceback
from pathlib import Path

from PySide6 import __version__ as PYSIDE_VERSION
from PySide6.QtCore import QObject, Property, QTimer, Signal, Slot, qVersion
from PySide6.QtGui import QGuiApplication

from . import log as _log

log = _log.get("system")

VERSION = "2.6.8"

try:
    import psutil  # optional
except ImportError:  # pragma: no cover - depends on environment
    psutil = None


class SystemProvider(QObject):
    statsChanged = Signal()
    errorOccurred = Signal(str, str)  # title, message

    def __init__(self, storage_root: Path, parent=None):
        super().__init__(parent)
        self._root = storage_root
        self._started = time.time()
        self._cpu = 0.0
        self._mem_pct = 0.0
        self._mem_used = 0.0
        self._mem_total = 0.0
        self._disk_pct = 0.0
        self._app_mem = 0.0
        self._cpu_history = [0.0] * 60
        self._mem_history = [0.0] * 60
        self._last_error = 0.0
        self._proc = psutil.Process() if psutil else None
        if psutil:
            psutil.cpu_percent(interval=None)  # prime the counter
        self._timer = QTimer(self)
        self._timer.setInterval(2000)
        self._timer.timeout.connect(self._sample)
        self._timer.start()
        self._sample()

    # ---------------------------------------------------------------- sentinel
    def install_excepthook(self):
        previous = sys.excepthook

        def hook(exc_type, exc, tb):
            if issubclass(exc_type, KeyboardInterrupt):
                previous(exc_type, exc, tb)
                return
            log.error("unhandled exception:\n%s", "".join(traceback.format_exception(exc_type, exc, tb)))
            now = time.time()
            if now - self._last_error > 2.0:  # don't flood the user
                self._last_error = now
                self.errorOccurred.emit(f"Something went wrong ({exc_type.__name__})", str(exc)[:300])

        sys.excepthook = hook

        import threading

        def thread_hook(args):  # worker threads (e.g. the blur renderer) report here too
            if args.exc_type is not SystemExit:
                hook(args.exc_type, args.exc_value, args.exc_traceback)

        threading.excepthook = thread_hook

    # ---------------------------------------------------------------- sampling
    def _sample(self):
        if psutil is None:
            return
        try:
            self._cpu = float(psutil.cpu_percent(interval=None))
            vm = psutil.virtual_memory()
            self._mem_pct = float(vm.percent)
            self._mem_used = vm.used / 1024 ** 3
            self._mem_total = vm.total / 1024 ** 3
            self._disk_pct = float(psutil.disk_usage(str(self._root)).percent)
            if self._proc is not None:
                self._app_mem = self._proc.memory_info().rss / 1024 ** 2
        except Exception as exc:  # monitoring must never break the shell
            log.debug("resource sampling failed: %s", exc)
            return
        self._cpu_history = self._cpu_history[1:] + [self._cpu]
        self._mem_history = self._mem_history[1:] + [self._mem_pct]
        self.statsChanged.emit()

    @Property(bool, constant=True)
    def hasStats(self) -> bool:
        return psutil is not None

    @Property(float, notify=statsChanged)
    def cpuPercent(self) -> float:
        return self._cpu

    @Property(float, notify=statsChanged)
    def memPercent(self) -> float:
        return self._mem_pct

    @Property(float, notify=statsChanged)
    def memUsedGB(self) -> float:
        return round(self._mem_used, 1)

    @Property(float, notify=statsChanged)
    def memTotalGB(self) -> float:
        return round(self._mem_total, 1)

    @Property(float, notify=statsChanged)
    def diskPercent(self) -> float:
        return self._disk_pct

    @Property(float, notify=statsChanged)
    def appMemMB(self) -> float:
        return round(self._app_mem, 1)

    @Property("QVariantList", notify=statsChanged)
    def cpuHistory(self) -> list:
        return list(self._cpu_history)

    @Property("QVariantList", notify=statsChanged)
    def memHistory(self) -> list:
        return list(self._mem_history)

    @Property(str, notify=statsChanged)
    def uptime(self) -> str:
        return _fmt_uptime(time.time() - self._started)

    # ------------------------------------------------------------- static info
    @Property(str, constant=True)
    def version(self) -> str:
        return VERSION

    @Property(str, constant=True)
    def hostOS(self) -> str:
        return f"{platform.system()} {platform.release()}".strip()

    @Property(str, constant=True)
    def pythonVersion(self) -> str:
        return platform.python_version()

    @Property(str, constant=True)
    def qtVersion(self) -> str:
        return f"{qVersion()} (PySide6 {PYSIDE_VERSION})"

    @Property(int, constant=True)
    def cpuCores(self) -> int:
        return os.cpu_count() or 1

    @Property(str, constant=True)
    def monoFont(self) -> str:
        from PySide6.QtGui import QFontDatabase
        return QFontDatabase.systemFont(QFontDatabase.SystemFont.FixedFont).family()

    @Property(str, constant=True)
    def cpuName(self) -> str:
        name = platform.processor() or platform.machine() or "Unknown CPU"
        return name[:60]

    def snapshot(self) -> dict:
        """Used by the terminal's neofetch."""
        return {
            "version": VERSION, "os": self.hostOS, "python": self.pythonVersion,
            "qt": qVersion(), "cpuCores": self.cpuCores, "cpuPercent": self._cpu,
            "memUsed": self._mem_used, "memTotal": self._mem_total,
            "uptime": _fmt_uptime(time.time() - self._started),
        }

    # ----------------------------------------------------------------- actions
    @Slot()
    def quit(self):
        QGuiApplication.quit()

    @Slot()
    def restart(self):
        """Relaunch GlassOS with the same arguments, then quit this instance."""
        import subprocess
        args = [sys.executable, os.path.abspath(sys.argv[0])] + sys.argv[1:]
        try:
            subprocess.Popen(args, cwd=os.getcwd(), close_fds=True)
        except OSError as exc:
            self.errorOccurred.emit("Could not restart", str(exc))
            return
        QGuiApplication.quit()

    @Slot(str)
    def log(self, message: str):
        log.info("[qml] %s", message)


def _fmt_uptime(seconds: float) -> str:
    seconds = int(seconds)
    h, rem = divmod(seconds, 3600)
    m, s = divmod(rem, 60)
    if h:
        return f"{h}h {m:02d}m"
    if m:
        return f"{m}m {s:02d}s"
    return f"{s}s"
