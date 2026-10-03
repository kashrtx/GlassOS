#!/usr/bin/env python3
"""
GlassOS - a glassy desktop environment written in Python + Qt Quick.

    python main.py              # full screen (default)
    python main.py --windowed   # run in a resizable window
    python main.py --no-boot    # skip the boot animation

Exit any time with Ctrl+Q (or Start ▸ Power ▸ Shut down).
"""

from __future__ import annotations

import argparse
import os
import sys

from core import log as _log
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(PROJECT_ROOT))


def parse_args(argv):
    p = argparse.ArgumentParser(prog="GlassOS", description="A glassy desktop environment in Python.")
    p.add_argument("--windowed", "-w", action="store_true", help="run in a window instead of full screen")
    p.add_argument("--no-boot", action="store_true", help="skip the boot animation")
    p.add_argument("--software", action="store_true",
                   help="use software rendering (for VMs / remote desktops with broken GPU drivers)")
    # Qt adds its own arguments (e.g. -platform); let them through
    return p.parse_known_args(argv)[0]


def configure_environment(args):
    # Only conservative, well-documented knobs. (The first GlassOS build forced
    # desktop OpenGL and blanked QT_QPA_PLATFORM_PLUGIN_PATH, which stops Qt
    # from starting on many machines.)
    os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")
    os.environ.setdefault("QT_QUICK_CONTROLS_CONF", str(PROJECT_ROOT / "qtquickcontrols2.conf"))
    os.environ.setdefault("QT_ENABLE_HIGHDPI_SCALING", "1")
    if args.software:
        os.environ["QT_QUICK_BACKEND"] = "software"
        os.environ.setdefault("QTWEBENGINE_CHROMIUM_FLAGS", "--disable-gpu")
    else:
        # GPU rasterization: without it Chromium rasterizes page tiles on the CPU and
        # shows black/checkered tiles while scrolling fast. Override with your own
        # QTWEBENGINE_CHROMIUM_FLAGS if a driver misbehaves (or use --software).
        os.environ.setdefault("QTWEBENGINE_CHROMIUM_FLAGS", " ".join([
            "--enable-gpu-rasterization",
            "--enable-zero-copy",
            "--ignore-gpu-blocklist",
            "--enable-smooth-scrolling",
            "--num-raster-threads=4",
            "--enable-features=CanvasOopRasterization,ParallelDownloading",
            "--log-level=3",   # Chromium internals log only fatal errors (no harmless DevTools/GPU noise)
        ]))
    if sys.platform == "win32":
        for stream in (sys.stdout, sys.stderr):  # emoji-safe console output
            try:
                stream.reconfigure(encoding="utf-8", errors="replace")
            except (AttributeError, ValueError):
                pass


def main(argv=None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    configure_environment(args)
    from core import log as glog
    glog.configure()
    log = glog.get("main")

    try:
        from PySide6.QtCore import Qt
        from PySide6.QtGui import QFont, QFontDatabase, QGuiApplication, QIcon
    except ImportError:
        print("GlassOS needs PySide6.  Install it with:\n\n    pip install -r requirements.txt\n")
        return 1

    has_webengine = False
    try:  # must happen before the QGuiApplication exists
        from PySide6.QtWebEngineQuick import QtWebEngineQuick
        QtWebEngineQuick.initialize()
        has_webengine = True
    except ImportError:
        log.info("QtWebEngine not installed - AeroBrowser disabled (pip install PySide6-Addons)")

    QGuiApplication.setHighDpiScaleFactorRoundingPolicy(Qt.HighDpiScaleFactorRoundingPolicy.PassThrough)
    app = QGuiApplication(sys.argv)
    _log.install_qt_handler()
    app.setApplicationName("GlassOS")
    app.setApplicationDisplayName("GlassOS")
    app.setOrganizationName("GlassOS")
    app.setApplicationVersion("2.6.8")

    fonts_dir = PROJECT_ROOT / "assets" / "fonts"
    if fonts_dir.is_dir():
        for f in list(fonts_dir.glob("*.ttf")) + list(fonts_dir.glob("*.otf")):
            QFontDatabase.addApplicationFont(str(f))
    font = QFont()
    font.setFamilies(["Segoe UI Variable Text", "Segoe UI", "Inter", "SF Pro Text", "Helvetica Neue",
                      "Ubuntu", "Cantarell", "Noto Sans", "Arial",
                      "Segoe UI Emoji", "Apple Color Emoji", "Noto Color Emoji"])
    font.setPixelSize(13)
    font.setHintingPreference(QFont.HintingPreference.PreferNoHinting)
    app.setFont(font)
    icon = PROJECT_ROOT / "assets" / "glassos.svg"
    if icon.exists():
        app.setWindowIcon(QIcon(str(icon)))

    from core.desktop_environment import DesktopEnvironment

    log.info("GlassOS %s starting%s", app.applicationVersion(), " (windowed)" if args.windowed else "")
    desktop = DesktopEnvironment(app, has_webengine, windowed=args.windowed, skip_boot=args.no_boot)
    if not desktop.show():
        return 1
    log.info("ready - press Ctrl+Q to shut down")
    code = app.exec()
    desktop.shutdown()
    return code


if __name__ == "__main__":
    sys.exit(main())
