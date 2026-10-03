"""Logging setup for GlassOS.  Level comes from the ``GLASSOS_LOG`` env var (default INFO)."""

from __future__ import annotations

import logging
import os
import sys

_FORMAT = "%(asctime)s %(levelname)-7s %(name)s: %(message)s"


def configure() -> None:
    level = getattr(logging, os.environ.get("GLASSOS_LOG", "INFO").upper(), logging.INFO)
    root = logging.getLogger("glassos")
    if root.handlers:
        return
    handler = logging.StreamHandler(sys.stderr)
    handler.setFormatter(logging.Formatter(_FORMAT, "%H:%M:%S"))
    root.addHandler(handler)
    root.setLevel(level)
    root.propagate = False


def get(name: str) -> logging.Logger:
    return logging.getLogger(f"glassos.{name}")


# Known-harmless Qt notices that only confuse users
_QT_NOISE = ("Please use WebEngineProfilePrototype for profile creation",)


def install_qt_handler():
    """Route Qt/QML messages through GlassOS logging (dropping known-harmless noise)."""
    try:
        from PySide6.QtCore import QtMsgType, qInstallMessageHandler
    except ImportError:  # pragma: no cover
        return
    qt_log = get("qt")
    levels = {QtMsgType.QtDebugMsg: logging.DEBUG, QtMsgType.QtInfoMsg: logging.INFO,
              QtMsgType.QtWarningMsg: logging.WARNING, QtMsgType.QtCriticalMsg: logging.ERROR,
              QtMsgType.QtFatalMsg: logging.CRITICAL}

    def handler(mode, context, message):
        if any(n in message for n in _QT_NOISE):
            return
        if context is not None and getattr(context, "category", "") == "js":
            # console output of websites (YouTube, ...) - their bugs, not ours
            qt_log.debug("web: %s", message)
            return
        where = f"{context.file}:{context.line}: " if context and context.file else ""
        qt_log.log(levels.get(mode, logging.WARNING), "%s%s", where, message)

    qInstallMessageHandler(handler)
