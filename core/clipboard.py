"""
GlassOS clipboard, exposed to QML as ``Clipboard``.

* Text history (newest first, 50 entries, pinned items persist across reboots),
  recorded from the real system clipboard, so copies made in *any* app count.
* File copy/paste with the host OS:
    - copying files in GlassOS also puts their real file URLs on the system
      clipboard, so you can paste them in Windows Explorer / Finder / Nautilus;
    - copying files in the host file manager makes them pastable inside GlassOS
      (they're imported). "Last copy wins", exactly like a desktop OS.
"""

from __future__ import annotations

import time
from typing import List, Optional

from PySide6.QtCore import QMimeData, QObject, Property, QUrl, Signal, Slot

from . import log as _log

log = _log.get("clipboard")

OWN_MARKER = "application/x-glassos-files"
MAX_ITEMS = 50
MAX_TEXT = 100_000


class ClipHistory:
    """Pure clipboard-history logic (unit-tested without Qt)."""

    def __init__(self, pinned: Optional[List[str]] = None):
        self.items: List[dict] = []
        self._seq = 0
        for text in (pinned or [])[:MAX_ITEMS]:
            if isinstance(text, str) and text:
                self._seq += 1
                self.items.append({"id": self._seq, "text": text, "pinned": True, "time": 0})

    def add(self, text: str) -> bool:
        if not isinstance(text, str) or not text.strip() or len(text) > MAX_TEXT:
            return False
        for i, it in enumerate(self.items):
            if it["text"] == text:          # re-copying moves it to the top
                it["time"] = time.time()
                self.items.insert(0, self.items.pop(i))
                return True
        self._seq += 1
        self.items.insert(0, {"id": self._seq, "text": text, "pinned": False, "time": time.time()})
        unpinned = [it for it in self.items if not it["pinned"]]
        if len(unpinned) > MAX_ITEMS:
            drop = unpinned[-1]
            self.items = [it for it in self.items if it is not drop]
        return True

    def toggle_pin(self, item_id: int):
        for it in self.items:
            if it["id"] == item_id:
                it["pinned"] = not it["pinned"]

    def remove(self, item_id: int):
        self.items = [it for it in self.items if it["id"] != item_id]

    def clear(self, keep_pinned: bool = True):
        self.items = [it for it in self.items if keep_pinned and it["pinned"]]

    def pinned_texts(self) -> List[str]:
        return [it["text"] for it in self.items if it["pinned"]]


class ClipboardService(QObject):
    historyChanged = Signal()
    hostFilesChanged = Signal()

    def __init__(self, prefs, storage, parent=None):
        super().__init__(parent)
        from PySide6.QtGui import QGuiApplication
        self._prefs = prefs
        self._storage = storage
        self._cb = QGuiApplication.clipboard()
        self._hist = ClipHistory(prefs.value("clipboard.pinned", []))
        self._host_urls: List[str] = []
        self._writing = False
        self._cb.dataChanged.connect(self._on_system_change)
        storage.clipboardChanged.connect(self._on_storage_clipboard)

    # ------------------------------------------------------------ system clipboard
    def _on_system_change(self):
        if self._writing:
            return
        try:
            md = self._cb.mimeData()
        except RuntimeError:
            return
        if md is None or md.hasFormat(OWN_MARKER):
            return
        if md.hasUrls():
            urls = [u.toString() for u in md.urls() if u.isLocalFile()]
            if urls:
                self._host_urls = urls
                self.hostFilesChanged.emit()
                if self._storage.canPaste:            # last copy wins
                    self._storage.copy([])
                return
        if md.hasText():
            if self._host_urls:
                self._host_urls = []
                self.hostFilesChanged.emit()
            if self._hist.add(md.text()):
                self.historyChanged.emit()

    def _on_storage_clipboard(self):
        """GlassOS copied/cut files: mirror them onto the host clipboard as file URLs."""
        paths = self._storage.clipboardPaths
        if not paths:
            return
        urls = []
        for p in paths:
            real = self._storage.real_path(p)
            if real is not None and real.exists():
                urls.append(QUrl.fromLocalFile(str(real)))
        if not urls:
            return
        md = QMimeData()
        md.setUrls(urls)
        md.setData(OWN_MARKER, b"1")
        self._write(lambda: self._cb.setMimeData(md))
        if self._host_urls:
            self._host_urls = []
            self.hostFilesChanged.emit()

    def _write(self, fn):
        self._writing = True
        try:
            fn()
        finally:
            self._writing = False

    # ------------------------------------------------------------ QML API
    @Property("QVariantList", notify=historyChanged)
    def history(self) -> list:
        return [dict(it) for it in self._hist.items]

    @Property("QVariantList", notify=hostFilesChanged)
    def hostFiles(self) -> list:
        return list(self._host_urls)

    @Slot(str)
    def copyText(self, text: str):
        if not text:
            return
        self._write(lambda: self._cb.setText(text))
        if self._hist.add(text):
            self.historyChanged.emit()

    @Slot(str, result=bool)
    def copyImageFile(self, real_path: str) -> bool:
        from PySide6.QtGui import QImage
        img = QImage(real_path)
        if img.isNull():
            return False
        self._write(lambda: self._cb.setImage(img))
        return True

    @Slot(int)
    def togglePin(self, item_id: int):
        self._hist.toggle_pin(item_id)
        self._prefs.setValue("clipboard.pinned", self._hist.pinned_texts())
        self.historyChanged.emit()

    @Slot(int)
    def remove(self, item_id: int):
        self._hist.remove(item_id)
        self._prefs.setValue("clipboard.pinned", self._hist.pinned_texts())
        self.historyChanged.emit()

    @Slot()
    def clear(self):
        self._hist.clear(keep_pinned=True)
        self.historyChanged.emit()
