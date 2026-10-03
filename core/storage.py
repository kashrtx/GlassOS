"""
GlassOS Storage
===============

Sandboxed access to the user's files under ``Storage/User``.

Every path the UI sees is a *virtual* POSIX path such as ``/Documents/notes.txt``.
All conversions to real paths go through :meth:`StorageProvider._resolve`, which
rejects anything that would escape the sandbox (``..``, absolute paths, symlinks
pointing outside, etc.).

Any operation that modifies the tree emits ``changed(dirPath)`` for each affected
directory so every open Explorer window and the desktop refresh themselves.
"""

from __future__ import annotations

import json
import os
import posixpath
import queue
import shutil
import threading
import time
import uuid
from pathlib import Path
from typing import Iterable, List, Optional

from PySide6.QtCore import QObject, Property, Qt, QTimer, QUrl, Signal, Slot

from . import archives
from . import log as _log

log = _log.get("storage")

TRASH = "/Recycle Bin"
TRASH_META_DIR = ".trashinfo"
MAX_TEXT_BYTES = 8 * 1024 * 1024  # refuse to open >8 MB in the text editor

SPECIAL_FOLDERS = [
    {"name": "Desktop", "path": "/Desktop", "icon": "place-desktop"},
    {"name": "Documents", "path": "/Documents", "icon": "place-documents"},
    {"name": "Downloads", "path": "/Downloads", "icon": "place-downloads"},
    {"name": "Pictures", "path": "/Pictures", "icon": "place-pictures"},
    {"name": "Music", "path": "/Music", "icon": "place-music"},
    {"name": "Videos", "path": "/Videos", "icon": "place-videos"},
]
_SPECIAL_ICONS = {f["path"]: f["icon"] for f in SPECIAL_FOLDERS}
_SPECIAL_ICONS["/Recycle Bin"] = "place-trash"

_KINDS = {
    "image": {".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp", ".svg", ".ico"},
    "text": {".txt", ".md", ".log", ".ini", ".cfg", ".conf", ".csv", ".rtf"},
    "code": {".py", ".qml", ".js", ".ts", ".json", ".xml", ".yaml", ".yml", ".html",
             ".htm", ".css", ".c", ".cpp", ".h", ".hpp", ".rs", ".go", ".java", ".sh",
             ".bat", ".ps1", ".toml", ".sql", ".lua", ".rb", ".php", ".mojo"},
    "audio": {".mp3", ".wav", ".ogg", ".flac", ".m4a", ".aac"},
    "video": {".mp4", ".mkv", ".avi", ".mov", ".webm"},
    "archive": {".zip", ".rar", ".7z", ".tar", ".gz", ".bz2", ".xz", ".tgz", ".tbz", ".tbz2", ".txz"},
    "pdf": {".pdf"},
    "playlist": {".m3u", ".m3u8"},
}
# icon names in qml/icons (see tools/make_icons.py)
_KIND_ICONS = {
    "folder": "place-folder", "image": "file-image", "text": "file-text", "code": "file-code",
    "audio": "file-audio", "video": "file-video", "archive": "file-archive", "pdf": "file-pdf",
    "file": "file-generic", "playlist": "file-audio",
}
_TYPE_NAMES = {
    "folder": "Folder", "image": "Image", "text": "Text document", "code": "Source code", "audio": "Audio",
    "video": "Video", "archive": "Archive", "pdf": "PDF document", "playlist": "Playlist", "file": "File",
}
_FORBIDDEN_NAME_CHARS = set('/\\:*?"<>|') | {chr(c) for c in range(32)}
# names Windows refuses to create (case-insensitive, with or without an extension)
_RESERVED_NAMES = {"con", "prn", "aux", "nul"} | {f"com{i}" for i in range(1, 10)} | {f"lpt{i}" for i in range(1, 10)}


def kind_for(name: str, is_dir: bool = False) -> str:
    if is_dir:
        return "folder"
    ext = os.path.splitext(name)[1].lower()
    for kind, exts in _KINDS.items():
        if ext in exts:
            return kind
    return "file"


def icon_for_kind(kind: str) -> str:
    return _KIND_ICONS.get(kind, "file-generic")


def normalize(vpath: str) -> str:
    """Normalise a virtual path to the form ``/a/b`` (root is ``/``)."""
    vpath = (vpath if isinstance(vpath, str) and vpath else "/").replace("\\", "/").strip()
    if not vpath.startswith("/"):
        vpath = "/" + vpath
    norm = posixpath.normpath(vpath)
    # normpath keeps a leading '//' on POSIX; collapse it
    while norm.startswith("//"):
        norm = norm[1:]
    return norm


def parent_of(vpath: str) -> str:
    return posixpath.dirname(normalize(vpath)) or "/"


def join(directory: str, name: str) -> str:
    return normalize(posixpath.join(normalize(directory), name))


def valid_name(name) -> bool:
    """A file/folder name that is safe on Windows, macOS and Linux."""
    if not isinstance(name, str) or not name or name in (".", "..") or name != name.strip():
        return False
    if name.endswith(".") or any(c in _FORBIDDEN_NAME_CHARS for c in name):
        return False
    if name.split(".", 1)[0].lower() in _RESERVED_NAMES:
        return False
    return len(name.encode("utf-8")) <= 240


def as_paths(value) -> List[str]:
    """Coerce a QML argument into a list of path strings.

    Guards against a single string being passed where a list is expected
    (iterating a string would yield characters such as "/").
    """
    if value is None:
        return []
    if hasattr(value, "toVariant") and not isinstance(value, str):  # QJSValue from QML
        value = value.toVariant()
    if isinstance(value, str):
        return [value] if value else []
    try:
        return [str(v) for v in value if isinstance(v, str) and v]
    except TypeError:
        return []


class StorageProvider(QObject):
    """File-system service exposed to QML as ``Storage``."""

    changed = Signal(str)            # directory whose contents changed
    clipboardChanged = Signal()
    trashChanged = Signal()
    transferStarted = Signal(int, str, int)          # job id, op, item count
    transferFinished = Signal(int, str, int, str)    # job id, op, items done, destination
    _jobDone = Signal(int, str, int, str, "QVariantList")  # worker -> GUI thread (queued)
    busyChanged = Signal()

    def __init__(self, root: Path, parent: Optional[QObject] = None):
        super().__init__(parent)
        self._root = Path(root).resolve()
        self._clip_paths: List[str] = []
        self._clip_mode = ""  # "copy" | "cut"
        self._trash_count: Optional[int] = None  # cached; invalidated whenever the bin changes
        self._quiet = threading.local()           # suppresses signals on the worker thread
        self._jobs: "queue.Queue" = queue.Queue()
        self._job_errors: dict = {}
        self._job_seq = 0
        self._worker: Optional[threading.Thread] = None
        self._busy_jobs = 0
        self._jobDone.connect(self._on_job_done, Qt.QueuedConnection)
        self._ensure_layout()
        self._watch_pending = set()
        self._watcher = None
        self._watch_timer = QTimer(self)
        self._watch_timer.setSingleShot(True)
        self._watch_timer.setInterval(150)       # coalesce bursts of file-system events
        self._watch_timer.timeout.connect(self._flush_watch)
        try:
            from PySide6.QtCore import QFileSystemWatcher
            self._watcher = QFileSystemWatcher(self)
            self._watcher.directoryChanged.connect(self._on_dir_changed)
            for v in ("/Desktop", TRASH):
                self.watch(v)
        except ImportError:  # pragma: no cover - minimal Qt builds
            pass
        self.trashChanged.connect(self._invalidate_trash_count)

    # ------------------------------------------------------------------ setup
    def _ensure_layout(self):
        for folder in SPECIAL_FOLDERS:
            (self._root / folder["path"].lstrip("/")).mkdir(parents=True, exist_ok=True)
        (self._root / "Pictures" / "Wallpapers").mkdir(parents=True, exist_ok=True)
        self._trash_dir.mkdir(parents=True, exist_ok=True)
        self._meta_dir.mkdir(parents=True, exist_ok=True)

    @property
    def root(self) -> Path:
        return self._root

    @property
    def _trash_dir(self) -> Path:
        return self._root / TRASH.lstrip("/")

    @property
    def _meta_dir(self) -> Path:
        return self._trash_dir / TRASH_META_DIR

    # ---------------------------------------------------------------- helpers
    def _resolve(self, vpath: str) -> Optional[Path]:
        """Map a virtual path to a real path, or ``None`` if it escapes the sandbox."""
        norm = normalize(vpath)
        real = (self._root / norm.lstrip("/")).resolve()
        try:
            real.relative_to(self._root)
        except ValueError:
            return None
        return real

    def to_virtual(self, real: Path) -> str:
        rel = Path(real).resolve().relative_to(self._root).as_posix()
        return "/" if rel in ("", ".") else "/" + rel

    def real_path(self, vpath: str) -> Optional[Path]:
        return self._resolve(vpath)

    def _unique_child(self, directory: Path, name: str) -> Path:
        candidate = directory / name
        if not candidate.exists():
            return candidate
        stem, ext = os.path.splitext(name)
        if (directory / name).is_dir():
            stem, ext = name, ""
        n = 2
        while True:
            candidate = directory / f"{stem} ({n}){ext}"
            if not candidate.exists():
                return candidate
            n += 1

    def _emit_dirs(self, dirs: Iterable[str]):
        if getattr(self._quiet, "dirs", None) is not None:   # running on the transfer worker
            self._quiet.dirs.update(dirs)
            return
        for d in sorted(set(dirs)):
            self.changed.emit(d)

    def _is_trash_path(self, vpath: str) -> bool:
        norm = normalize(vpath)
        return norm == TRASH or norm.startswith(TRASH + "/")

    def _entry(self, real: Path, vpath: str) -> dict:
        try:
            st = real.stat()
            size, mtime = st.st_size, st.st_mtime
        except OSError:
            size, mtime = 0, 0
        is_dir = real.is_dir()
        kind = kind_for(real.name, is_dir)
        return {
            "name": real.name,
            "path": vpath,
            "isDir": is_dir,
            "size": 0 if is_dir else size,
            "modified": int(mtime * 1000),
            "ext": "" if is_dir else real.suffix.lower().lstrip("."),
            "kind": kind,
            "icon": _SPECIAL_ICONS.get(vpath, icon_for_kind(kind)) if is_dir else icon_for_kind(kind),
            "originalPath": "",
            "deletedAt": 0,
        }

    # ---------------------------------------------------------------- listing
    @Slot(str, result="QVariantList")
    def list(self, vpath: str) -> list:
        vpath = normalize(vpath)
        real = self._resolve(vpath)
        if real is None or not real.is_dir():
            return []
        items = []
        try:
            for child in real.iterdir():
                if child.name.startswith(".") or child.name == "desktop.ini":
                    continue
                entry = self._entry(child, join(vpath, child.name))
                if vpath == TRASH:
                    meta = self._read_trash_meta(child.name)
                    if meta:
                        entry["name"] = meta.get("name", child.name)
                        entry["originalPath"] = meta.get("originalPath", "")
                        entry["deletedAt"] = int(meta.get("deletedAt", 0) * 1000)
                        kind = kind_for(entry["name"], entry["isDir"])
                        entry["kind"], entry["icon"] = kind, icon_for_kind(kind)
                items.append(entry)
        except OSError as exc:
            log.warning("list(%s) failed: %s", vpath, exc)
        items.sort(key=lambda e: (not e["isDir"], e["name"].lower()))
        return items

    @Slot(str, result="QVariantMap")
    def info(self, vpath: str) -> dict:
        real = self._resolve(vpath)
        if real is None or not real.exists():
            return {}
        entry = self._entry(real, normalize(vpath))
        try:
            st = real.stat()
            entry["created"] = int(getattr(st, "st_birthtime", st.st_ctime) * 1000)
        except OSError:
            entry["created"] = 0
        entry["typeName"] = (entry["ext"].upper() + " " if entry["ext"] and not entry["isDir"] else "") + _TYPE_NAMES.get(entry["kind"], "File")
        entry["location"] = parent_of(vpath)
        if entry["isDir"]:
            files = folders = total = 0
            for dirpath, dirnames, filenames in os.walk(real):
                dirnames[:] = [d for d in dirnames if not d.startswith(".")]
                folders += len(dirnames)
                for f in filenames:
                    if f.startswith("."):
                        continue
                    files += 1
                    try:
                        total += os.path.getsize(os.path.join(dirpath, f))
                    except OSError:
                        pass
            entry.update({"size": total, "files": files, "folders": folders})
        return entry

    @Slot(str, result="QVariantMap")
    def quickInfo(self, vpath: str) -> dict:
        """Like info(), but O(1): folders report their direct item count, not a recursive size."""
        real = self._resolve(vpath)
        if real is None or not real.exists():
            return {}
        e = self._entry(real, normalize(vpath))
        try:
            st = real.stat()
            e["created"] = int(getattr(st, "st_birthtime", st.st_ctime) * 1000)
        except OSError:
            e["created"] = 0
        e["typeName"] = (e["ext"].upper() + " " if e["ext"] and not e["isDir"] else "") + _TYPE_NAMES.get(e["kind"], "File")
        e["location"] = parent_of(vpath)
        if e["isDir"]:
            try:
                e["items"] = sum(1 for c in real.iterdir() if not c.name.startswith("."))
            except OSError:
                e["items"] = 0
        if real.parent == self._trash_dir:
            meta = self._read_trash_meta(real.name) or {}
            e["name"] = meta.get("name", e["name"])
            e["originalPath"] = meta.get("originalPath", "")
            e["deletedAt"] = int(meta.get("deletedAt", 0) * 1000)
        return e

    @Slot(str, int, result=str)
    def textPreview(self, vpath: str, max_chars: int = 3000) -> str:
        real = self._resolve(vpath)
        if real is None or not real.is_file():
            return ""
        try:
            with open(real, "rb") as fh:
                raw = fh.read(max(256, min(max_chars, 20000)) * 4)
        except OSError:
            return ""
        if b"\0" in raw[:2048]:
            return ""
        return raw.decode("utf-8", errors="replace")[:max_chars]

    @Slot(str, result="QVariantMap")
    def imageSize(self, vpath: str) -> dict:
        """Pixel size from the image header (cheap: doesn't decode the image)."""
        real = self._resolve(vpath)
        if real is None or not real.is_file():
            return {"w": 0, "h": 0}
        try:
            from PySide6.QtGui import QImageReader
            size = QImageReader(str(real)).size()
            if size.isValid():
                return {"w": size.width(), "h": size.height()}
        except (ImportError, AttributeError):
            pass
        try:
            from PIL import Image
            with Image.open(real) as im:
                return {"w": im.width, "h": im.height}
        except Exception:
            return {"w": 0, "h": 0}

    @Slot(str, result=bool)
    def exists(self, vpath: str) -> bool:
        real = self._resolve(vpath)
        return bool(real and real.exists())

    @Slot(str, result=bool)
    def isDir(self, vpath: str) -> bool:
        real = self._resolve(vpath)
        return bool(real and real.is_dir())

    @Slot(str, str, int, result="QVariantList")
    def search(self, query: str, vpath: str = "/", limit: int = 200) -> list:
        """Case-insensitive name search. ``limit`` <= 0 means the default (200); max 1000."""
        limit = 200 if not limit or limit <= 0 else min(int(limit), 1000)
        query = (query or "").strip().lower()
        base = self._resolve(vpath or "/")
        if not query or base is None or not base.is_dir():
            return []
        results = []
        for dirpath, dirnames, filenames in os.walk(base):
            dirnames[:] = sorted(d for d in dirnames
                                 if not d.startswith(".") and d != TRASH.lstrip("/"))
            for name in dirnames + sorted(filenames):
                if name.startswith(".") or query not in name.lower():
                    continue
                real = Path(dirpath) / name
                results.append(self._entry(real, self.to_virtual(real)))
                if len(results) >= limit:
                    return results
        return results

    @Slot(result="QVariantList")
    def specialFolders(self) -> list:
        return [dict(f) for f in SPECIAL_FOLDERS]

    @Slot(str, result=str)
    def fileUrl(self, vpath: str) -> str:
        real = self._resolve(vpath)
        if real is None or not real.exists():
            return ""
        return QUrl.fromLocalFile(str(real)).toString()

    @Slot(str, result=str)
    def kindOf(self, name: str) -> str:
        return kind_for(name)

    @Slot(str, result=str)
    def iconFor(self, name: str) -> str:
        return icon_for_kind(kind_for(name))

    @Slot(str, result=str)
    def parentOf(self, vpath: str) -> str:
        return parent_of(vpath)

    @Slot(str, str, result=str)
    def join(self, directory: str, name: str) -> str:
        return join(directory, name)

    @Slot(str, result=bool)
    def isValidName(self, name: str) -> bool:
        return valid_name(name)

    @Property(str, constant=True)
    def downloadsDir(self) -> str:
        return str(self._root / "Downloads")

    # ------------------------------------------------------------- read/write
    @Slot(str, result="QVariantMap")
    def readText(self, vpath: str) -> dict:
        real = self._resolve(vpath)
        if real is None or not real.is_file():
            return {"ok": False, "text": "", "error": "File not found"}
        try:
            if real.stat().st_size > MAX_TEXT_BYTES:
                return {"ok": False, "text": "", "error": "File is too large to open (over 8 MB)"}
            raw = real.read_bytes()
        except OSError as exc:
            return {"ok": False, "text": "", "error": str(exc)}
        if b"\0" in raw[:4096]:
            return {"ok": False, "text": "", "error": "This looks like a binary file"}
        for enc in ("utf-8-sig", "cp1252", "latin-1"):
            try:
                return {"ok": True, "text": raw.decode(enc), "error": ""}
            except UnicodeDecodeError:
                continue
        return {"ok": False, "text": "", "error": "Unknown text encoding"}

    @Slot(str, str, result=bool)
    def writeText(self, vpath: str, text: str) -> bool:
        real = self._resolve(vpath)
        if real is None or real == self._root or self._is_trash_path(vpath):
            return False
        if not valid_name(real.name):
            return False
        try:
            real.parent.mkdir(parents=True, exist_ok=True)
            tmp = real.with_name(f".{real.name}.{uuid.uuid4().hex[:6]}.tmp")
            tmp.write_text(text if isinstance(text, str) else "", encoding="utf-8", newline="")
            os.replace(tmp, real)  # atomic: never leaves a half-written file
        except OSError as exc:
            log.error("writeText(%s) failed: %s", vpath, exc)
            return False
        self._emit_dirs([parent_of(vpath)])
        return True

    # --------------------------------------------------------------- creation
    @Slot(str, str, result=str)
    def createFolder(self, parent_vpath: str, name: str) -> str:
        return self._create(parent_vpath, name or "New folder", is_dir=True)

    @Slot(str, str, result=str)
    def createFile(self, parent_vpath: str, name: str) -> str:
        return self._create(parent_vpath, name or "New text document.txt", is_dir=False)

    def _create(self, parent_vpath: str, name: str, is_dir: bool) -> str:
        name = name.strip()
        parent = self._resolve(parent_vpath)
        if (parent is None or not parent.is_dir() or not valid_name(name)
                or self._is_trash_path(parent_vpath)):
            return ""
        target = self._unique_child(parent, name)
        try:
            if is_dir:
                target.mkdir()
            else:
                target.touch(exist_ok=False)
        except OSError as exc:
            log.error("create(%s) failed: %s", name, exc)
            return ""
        self._emit_dirs([normalize(parent_vpath)])
        return self.to_virtual(target)

    @Slot(str, str, result=str)
    def uniqueName(self, parent_vpath: str, name: str) -> str:
        parent = self._resolve(parent_vpath)
        if parent is None:
            return name
        return self._unique_child(parent, name).name

    # --------------------------------------------------------------- renaming
    @Slot(str, str, result=str)
    def rename(self, vpath: str, new_name: str) -> str:
        self._release_watches_v([vpath])
        new_name = (new_name or "").strip()
        real = self._resolve(vpath)
        if (real is None or not real.exists() or real == self._root
                or not valid_name(new_name) or self._is_protected(vpath)):
            return ""
        if new_name == real.name:
            return normalize(vpath)
        target = real.parent / new_name
        # allow case-only renames on case-insensitive file systems
        if target.exists() and target.resolve() != real.resolve():
            return ""
        try:
            real.rename(target)
        except OSError as exc:
            log.error("rename(%s -> %s) failed: %s", vpath, new_name, exc)
            return ""
        self._emit_dirs([parent_of(vpath)])
        return self.to_virtual(target)

    def _is_protected(self, vpath: str) -> bool:
        norm = normalize(vpath)
        return norm in {f["path"] for f in SPECIAL_FOLDERS} | {TRASH, "/Pictures/Wallpapers"}

    # -------------------------------------------------------------- clipboard
    @Property(bool, notify=clipboardChanged)
    def canPaste(self) -> bool:
        return bool(self._clip_paths)

    @Property(str, notify=clipboardChanged)
    def clipboardMode(self) -> str:
        return self._clip_mode

    @Property("QVariantList", notify=clipboardChanged)
    def clipboardPaths(self) -> list:
        return list(self._clip_paths)

    @Slot("QVariantList")
    def copy(self, paths):
        self._set_clipboard(paths, "copy")

    @Slot("QVariantList")
    def cut(self, paths):
        self._set_clipboard(paths, "cut")

    def _set_clipboard(self, paths, mode):
        clean = list(dict.fromkeys(normalize(p) for p in as_paths(paths)
                                   if self.exists(p) and not self._is_protected(p)))
        self._clip_paths, self._clip_mode = clean, (mode if clean else "")
        self.clipboardChanged.emit()

    @Slot(str, result=int)
    def paste(self, dest_vpath: str) -> int:
        if not self._clip_paths:
            return 0
        if self._clip_mode == "cut":
            count = self.move(self._clip_paths, dest_vpath)
            self._clip_paths, self._clip_mode = [], ""
            self.clipboardChanged.emit()
            return count
        return self.copyTo(self._clip_paths, dest_vpath)

    @Slot("QVariantList", str, result=int)
    def copyTo(self, paths, dest_vpath: str) -> int:
        dest = self._resolve(dest_vpath)
        if dest is None or not dest.is_dir() or self._is_trash_path(dest_vpath):
            return 0
        count = 0
        for p in as_paths(paths):
            src = self._resolve(p)
            if src is None or not src.exists() or self._inside(dest, src):
                continue
            name = src.name
            if self._is_trash_path(p):
                meta = self._read_trash_meta(src.name) or {}
                name = meta.get("name", name)
            target = self._unique_child(dest, name)
            if target.parent == src.parent and target.name != src.name:
                stem, ext = os.path.splitext(name) if src.is_file() else (name, "")
                target = self._unique_child(dest, f"{stem} - Copy{ext}")
            try:
                if src.is_dir():
                    shutil.copytree(src, target)
                else:
                    shutil.copy2(src, target)
                count += 1
            except OSError as exc:
                log.error("copy(%s) failed: %s", p, exc)
        if count:
            self._emit_dirs([normalize(dest_vpath)])
        return count

    @Slot("QVariantList", str, result=int)
    def move(self, paths, dest_vpath: str) -> int:
        self._release_watches_v(as_paths(paths))
        dest = self._resolve(dest_vpath)
        if dest is None or not dest.is_dir() or self._is_trash_path(dest_vpath):
            return 0
        count, touched = 0, {normalize(dest_vpath)}
        for p in as_paths(paths):
            src = self._resolve(p)
            if (src is None or not src.exists() or self._is_protected(p)
                    or src.parent == dest or self._inside(dest, src)):
                continue
            target = self._unique_child(dest, src.name)
            try:
                shutil.move(str(src), str(target))
                count += 1
                touched.add(parent_of(p))
            except OSError as exc:
                log.error("move(%s) failed: %s", p, exc)
        if count:
            self._emit_dirs(touched)
        return count

    @staticmethod
    def _inside(candidate: Path, ancestor: Path) -> bool:
        """True if ``candidate`` is ``ancestor`` or lives inside it."""
        try:
            candidate.resolve().relative_to(ancestor.resolve())
            return True
        except ValueError:
            return False

    # ------------------------------------------------------------------ trash
    def _read_trash_meta(self, trash_name: str) -> Optional[dict]:
        meta = self._meta_dir / f"{trash_name}.json"
        try:
            return json.loads(meta.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            return None

    # ------------------------------------------------------ live folder watching
    @Slot(str)
    def watch(self, vpath: str):
        """Refresh views when this folder changes on disk, even from outside GlassOS."""
        if self._watcher is None:
            return
        real = self._resolve(vpath)
        if real is None or not real.is_dir():
            return
        dirs = self._watcher.directories()
        if str(real) in dirs:
            return
        keep = {str(self._resolve(v)) for v in ("/Desktop", TRASH)}
        extra = [d for d in dirs if d not in keep]
        if len(extra) >= 48:                     # bounded: drop the oldest watched folders
            self._watcher.removePaths(extra[:len(extra) - 47])
        self._watcher.addPath(str(real))

    def _release_watches(self, reals):
        """Stop watching these folders (and anything inside them) before they're deleted,
        moved or renamed: on Windows a watched folder keeps an open handle, which makes the
        operation fail with "Access is denied". GUI thread only (QFileSystemWatcher's thread)."""
        if self._watcher is None or getattr(self._quiet, "dirs", None) is not None:
            return
        roots = [str(Path(r)) for r in reals if r is not None]
        if not roots:
            return
        drop = [d for d in self._watcher.directories()
                if any(d == r or d.startswith(r.rstrip("\\/") + os.sep) or d.startswith(r.rstrip("\\/") + "/") for r in roots)]
        if drop:
            self._watcher.removePaths(drop)

    def _release_watches_v(self, vpaths):
        self._release_watches([self._resolve(v) for v in vpaths])

    def _on_dir_changed(self, real: str):
        if not Path(real).exists():      # the folder itself is gone: stop watching it
            try:
                self._watcher.removePath(real)
            except Exception:
                pass
        self._watch_pending.add(real)
        if Path(real) == self._trash_dir:
            self._trash_count = None
        self._watch_timer.start()

    def _flush_watch(self):
        pending, self._watch_pending = self._watch_pending, set()
        for real in pending:
            try:
                v = self.to_virtual(Path(real))
            except ValueError:
                continue
            if v == TRASH:
                self.trashChanged.emit()
            self.changed.emit(v)

    def _invalidate_trash_count(self):
        self._trash_count = None

    @Property(int, notify=trashChanged)
    def trashCount(self) -> int:
        if self._trash_count is not None and not self._trash_dir.exists():
            self._trash_count = None
        if self._trash_count is None:
            try:
                self._trash_count = sum(1 for c in self._trash_dir.iterdir() if not c.name.startswith("."))
            except OSError:
                self._trash_count = 0
        return self._trash_count

    @Slot("QVariantList", result=int)
    def trash(self, paths) -> int:
        self._release_watches_v(as_paths(paths))
        count, touched = 0, set()
        for p in as_paths(paths):
            norm = normalize(p)
            src = self._resolve(norm)
            if (src is None or not src.exists() or src == self._root
                    or self._is_trash_path(norm) or self._is_protected(norm)):
                continue
            trash_name = f"{int(time.time())}-{uuid.uuid4().hex[:8]}-{src.name}"
            try:
                shutil.move(str(src), str(self._trash_dir / trash_name))
                (self._meta_dir / f"{trash_name}.json").write_text(json.dumps({
                    "name": src.name, "originalPath": norm, "deletedAt": time.time(),
                }), encoding="utf-8")
                count += 1
                touched.add(parent_of(norm))
            except OSError as exc:
                log.error("trash(%s) failed: %s", norm, exc)
        if count:
            touched.add(TRASH)
            self._emit_dirs(touched)
            self.trashChanged.emit()
        return count

    @Slot("QVariantList", result=int)
    def restore(self, trash_paths) -> int:
        return len(self.restoreItems(trash_paths))

    @Slot("QVariantList", result="QVariantList")
    def restoreItems(self, trash_paths) -> list:
        """Restore items from the bin; returns where each one ended up."""
        restored, touched = [], {TRASH}
        for p in as_paths(trash_paths):
            src = self._resolve(p)
            if src is None or not src.exists() or src.parent != self._trash_dir:
                continue
            meta = self._read_trash_meta(src.name) or {}
            original = normalize(meta.get("originalPath") or join("/Documents", src.name))
            dest_dir = self._resolve(parent_of(original))
            if dest_dir is None:
                dest_dir = self._root / "Documents"
            try:
                dest_dir.mkdir(parents=True, exist_ok=True)
                target = self._unique_child(dest_dir, meta.get("name", src.name))
                shutil.move(str(src), str(target))
                (self._meta_dir / f"{src.name}.json").unlink(missing_ok=True)
                restored.append(self.to_virtual(target))
                touched.add(self.to_virtual(dest_dir))
            except OSError as exc:
                log.error("restore(%s) failed: %s", p, exc)
        if restored:
            self._emit_dirs(touched)
            self.trashChanged.emit()
        return restored

    @Slot("QVariantList", result=int)
    def deletePermanently(self, paths) -> int:
        self._release_watches_v(as_paths(paths))
        count, touched = 0, set()
        for p in as_paths(paths):
            norm = normalize(p)
            real = self._resolve(norm)
            if real is None or not real.exists() or real == self._root or self._is_protected(norm):
                continue
            try:
                if real.is_dir() and not real.is_symlink():
                    shutil.rmtree(real)
                else:
                    real.unlink()
                if real.parent == self._trash_dir:
                    (self._meta_dir / f"{real.name}.json").unlink(missing_ok=True)
                count += 1
                touched.add(parent_of(norm))
            except OSError as exc:
                log.error("delete(%s) failed: %s", norm, exc)
        if count:
            self._emit_dirs(touched)
            if TRASH in touched:
                self.trashChanged.emit()
        return count

    @Slot(result=int)
    def emptyTrash(self) -> int:
        self._release_watches([self._trash_dir])
        self.watch(TRASH)
        self._trash_dir.mkdir(parents=True, exist_ok=True)
        paths = [join(TRASH, c.name) for c in self._trash_dir.iterdir() if not c.name.startswith(".")]
        count = self.deletePermanently(paths)
        shutil.rmtree(self._meta_dir, ignore_errors=True)
        self._meta_dir.mkdir(parents=True, exist_ok=True)
        self.trashChanged.emit()
        return count

    # ------------------------------------------------------- background jobs
    @Slot(str, "QVariantList", str, result=int)
    def startTransfer(self, op: str, items, dest: str) -> int:
        """Queue a copy / move / import / export on the worker thread. Returns a job id
        (0 if the request is invalid). ``transferFinished`` fires when it's done."""
        items = as_paths(items)
        if op not in ("copy", "move", "import", "export", "extract", "compress") or not items or not dest:
            return 0
        if op == "move":
            self._release_watches_v(items)   # here, on the GUI thread, before the worker moves them
        self._job_seq += 1
        job = self._job_seq
        self._busy_jobs += 1
        self.transferStarted.emit(job, op, len(items))
        self.busyChanged.emit()
        self._jobs.put((job, op, items, dest))
        if self._worker is None or not self._worker.is_alive():
            self._worker = threading.Thread(target=self._work, daemon=True, name="glassos-transfers")
            self._worker.start()
        return job

    def _work(self):
        while True:
            try:
                job, op, items, dest = self._jobs.get(timeout=5)
            except queue.Empty:
                return  # idle: let the thread end; a new one starts on demand
            self._quiet.dirs = set()
            count = 0
            try:
                if op == "copy":
                    count = self.copyTo(items, dest)
                elif op == "move":
                    count = self.move(items, dest)
                elif op == "import":
                    count = self.importFiles(items, dest)
                elif op == "export":
                    count = self.exportFiles(items, dest)
                elif op == "extract":
                    count = self._extract(items[0], dest)
                elif op == "compress":
                    count = self._compress(items, dest)
            except archives.ArchiveError as exc:
                log.warning("transfer job %d (%s): %s", job, op, exc)
                self._job_errors[job] = str(exc)
            except Exception:
                log.exception("transfer job %d (%s) failed", job, op)
            dirs = sorted(self._quiet.dirs)
            self._quiet.dirs = None
            self._jobDone.emit(job, op, count, dest, dirs)

    @Slot(int, result=str)
    def jobError(self, job: int) -> str:
        """Why a finished job did nothing (e.g. 'The archive is damaged'), or ''."""
        return self._job_errors.pop(job, "")

    # ----------------------------------------------------------- archives
    @Slot(str, result="QVariantMap")
    def archiveInfo(self, vpath: str) -> dict:
        real = self._resolve(vpath)
        if real is None or not real.is_file():
            return {"ok": False, "error": "Archive not found"}
        if archives.archive_kind(real.name) is None:
            return {"ok": False, "error": "This archive format isn't supported yet (ZIP and TAR are)."}
        try:
            info = archives.list_archive(real)
        except archives.ArchiveError as exc:
            return {"ok": False, "error": str(exc)}
        info["ok"] = True
        info["error"] = ""
        return info

    @Slot(str, result=bool)
    def canExtract(self, vpath: str) -> bool:
        return archives.archive_kind(vpath) is not None

    def _extract(self, vpath: str, dest_vpath: str) -> int:
        src = self._resolve(vpath)
        dest = self._resolve(dest_vpath)
        if src is None or not src.is_file() or dest is None or not dest.is_dir() or self._is_trash_path(dest_vpath):
            raise archives.ArchiveError("Can't extract there.")
        archives.extract(src, dest, archives.stem_of(src.name))
        self._emit_dirs([normalize(dest_vpath)])
        return 1

    def _compress(self, paths, dest_vpath: str) -> int:
        dest = self._resolve(dest_vpath)
        if dest is None or not dest.is_dir() or self._is_trash_path(dest_vpath):
            raise archives.ArchiveError("Can't create an archive there.")
        reals = [r for r in (self._resolve(p) for p in paths) if r is not None and r.exists() and r != self._root]
        if not reals:
            return 0
        name = (reals[0].name if len(reals) == 1 else "Archive") + ".zip"
        target = self._unique_child(dest, name)
        archives.compress(reals, target)
        self._emit_dirs([normalize(dest_vpath)])
        return len(reals)

    # ----------------------------------------------------------- screenshots
    @Slot(result="QVariantMap")
    def newScreenshotPath(self) -> dict:
        folder = self._root / "Pictures" / "Screenshots"
        folder.mkdir(parents=True, exist_ok=True)
        target = self._unique_child(folder, time.strftime("Screenshot %Y-%m-%d %H%M%S.png"))
        return {"vpath": self.to_virtual(target), "real": str(target)}

    @Slot(int, str, int, str, "QVariantList")
    def _on_job_done(self, job, op, count, dest, dirs):
        self._busy_jobs = max(0, self._busy_jobs - 1)
        for d in dirs:
            self.changed.emit(d)
        self.transferFinished.emit(job, op, count, dest)
        self.busyChanged.emit()

    @Property(bool, notify=busyChanged)
    def busy(self) -> bool:
        return self._busy_jobs > 0

    # ----------------------------------------------------------- media library
    @Slot(str, result="QVariantList")
    def mediaFiles(self, kind: str) -> list:
        """All audio or video files in the user's storage (not the bin), newest first."""
        if kind not in ("audio", "video", "image"):
            return []
        out = []
        trash = self._trash_dir
        for dirpath, dirnames, filenames in os.walk(self._root):
            dirnames[:] = [d for d in dirnames if not d.startswith(".") and Path(dirpath, d) != trash]
            for name in filenames:
                if not name.startswith(".") and kind_for(name) == kind:
                    real = Path(dirpath) / name
                    out.append(self._entry(real, self.to_virtual(real)))
                    if len(out) >= 2000:
                        break
        out.sort(key=lambda e: -e["modified"])
        return out

    # ------------------------------------------------------------- wallpapers
    @Slot(result="QVariantList")
    def wallpapers(self) -> list:
        folder = self._root / "Pictures" / "Wallpapers"
        out = []
        if folder.is_dir():
            for child in sorted(folder.iterdir(), key=lambda c: c.name.lower()):
                if child.is_file() and kind_for(child.name) == "image" and child.suffix.lower() != ".svg":
                    out.append({
                        "name": child.stem.replace("_", " ").replace("-", " "),
                        "path": self.to_virtual(child),
                        "url": QUrl.fromLocalFile(str(child)).toString(),
                    })
        return out

    # ------------------------------------------------------- host import/export
    @staticmethod
    def _host_path(url) -> Optional[Path]:
        """file:// URL (or plain path) chosen by the user on the host -> Path."""
        url = str(url or "")
        if not url:
            return None
        if url.startswith("file:"):
            local = QUrl(url).toLocalFile() if hasattr(QUrl(url), "toLocalFile") else ""
            if not local:
                from urllib.parse import unquote, urlparse
                from urllib.request import url2pathname
                local = url2pathname(unquote(urlparse(url).path))
            url = local
        p = Path(url)
        return p if p.exists() else None

    @Slot("QVariantList", str, result=int)
    def importFiles(self, urls, dest_vpath: str) -> int:
        """Copy files/folders from the host computer (dialog or OS drag & drop) into GlassOS."""
        dest = self._resolve(dest_vpath)
        if dest is None or not dest.is_dir() or self._is_trash_path(dest_vpath):
            return 0
        count = 0
        for u in as_paths(urls):
            src = self._host_path(u)
            if src is None:
                log.warning("import: %s does not exist", u)
                continue
            if self._inside(src, self._root):   # already inside GlassOS: treat as a move
                count += self.move([self.to_virtual(src)], dest_vpath)
                continue
            target = self._unique_child(dest, src.name)
            try:
                if src.is_dir():
                    shutil.copytree(src, target, symlinks=False)
                else:
                    shutil.copy2(src, target)
                count += 1
            except OSError as exc:
                log.error("import(%s) failed: %s", src, exc)
        if count:
            self._emit_dirs([normalize(dest_vpath)])
        return count

    @Slot("QVariantList", str, result=int)
    def exportFiles(self, paths, folder_url: str) -> int:
        """Copy GlassOS items out to a folder on the host computer."""
        dest = self._host_path(folder_url)
        if dest is None or not dest.is_dir():
            return 0
        count = 0
        for p in as_paths(paths):
            src = self._resolve(p)
            if src is None or not src.exists() or src == self._root:
                continue
            name = src.name
            if src.parent == self._trash_dir:
                name = (self._read_trash_meta(src.name) or {}).get("name", name)
            target = self._unique_child(dest, name)
            try:
                if src.is_dir():
                    shutil.copytree(src, target)
                else:
                    shutil.copy2(src, target)
                count += 1
            except OSError as exc:
                log.error("export(%s) failed: %s", p, exc)
        return count

    @Slot(str)
    def notifyChanged(self, vpath: str):
        """Let QML announce external changes (e.g. a finished browser download)."""
        self.changed.emit(normalize(vpath))
