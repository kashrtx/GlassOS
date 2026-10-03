"""
GlassOS thumbnails, exposed to QML as ``Thumbs``.

* Images: Pillow on a small thread pool (JPEG "draft" decoding makes even 24 MP
  photos take a few ms), EXIF rotation respected.
* Video: an off-screen QMediaPlayer + QVideoSink grabs a frame ~15 % in.
* Audio: embedded cover art from the file's metadata.
* Results are cached on disk as small JPEGs keyed by path + size + mtime, with a
  sidecar of metadata (pixel size, duration) for the Files details pane.

QML calls ``request(path)``: it returns the cached URL immediately when there
is one, otherwise "" and the thumbnail arrives later through ``ready(path, url)``.
Media jobs run one at a time with a timeout, so a broken file can't stall the queue.
"""

from __future__ import annotations

import hashlib
import json
import threading
from collections import deque
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Optional

from PySide6.QtCore import QObject, Qt, QTimer, QUrl, Signal, Slot

from . import log as _log
from .storage import kind_for

log = _log.get("thumbs")

SIZE = 320
MEDIA_TIMEOUT_MS = 7000


class ThumbnailService(QObject):
    ready = Signal(str, str)             # vpath, file url ("" if none could be made)
    _imageDone = Signal(str, str, str)   # vpath, out path, meta json (worker -> GUI thread)

    def __init__(self, storage, cache_dir: Path, parent=None):
        super().__init__(parent)
        self._storage = storage
        self._dir = Path(cache_dir)
        self._dir.mkdir(parents=True, exist_ok=True)
        self._pool = ThreadPoolExecutor(max_workers=2, thread_name_prefix="glassos-thumb")
        self._inflight = set()
        self._failed = set()
        self._media_queue = deque()
        self._media = None               # lazily created player pipeline
        self._job = None
        self._imageDone.connect(self._on_image_done, Qt.QueuedConnection)

    # ------------------------------------------------------------ helpers
    def _key(self, real: Path) -> Optional[str]:
        try:
            st = real.stat()
        except OSError:
            return None
        return hashlib.sha1(f"{real}|{st.st_size}|{st.st_mtime_ns}|v2".encode()).hexdigest()[:20]

    def _paths(self, vpath: str):
        real = self._storage.real_path(vpath)
        if real is None or not real.is_file():
            return None, None, None
        key = self._key(real)
        if key is None:
            return None, None, None
        return real, self._dir / f"{key}.jpg", self._dir / f"{key}.json"

    # ------------------------------------------------------------ QML API
    @Slot(str, result=str)
    def request(self, vpath: str) -> str:
        kind = kind_for(vpath or "")
        if kind not in ("image", "video", "audio"):
            return ""
        real, out, meta = self._paths(vpath)
        if real is None:
            return ""
        if out.exists():
            return QUrl.fromLocalFile(str(out)).toString()
        if out.name in self._failed or vpath in self._inflight:
            return ""
        self._inflight.add(vpath)
        if kind == "image":
            self._pool.submit(self._image_worker, vpath, real, out, meta)
        else:
            self._media_queue.append((vpath, kind, real, out, meta))
            QTimer.singleShot(0, self._next_media)
        return ""

    @Slot(str, result="QVariantMap")
    def meta(self, vpath: str) -> dict:
        real, out, meta = self._paths(vpath)
        if meta is None or not meta.exists():
            return {}
        try:
            return json.loads(meta.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            return {}

    # ------------------------------------------------------------ images
    def _image_worker(self, vpath, real: Path, out: Path, meta: Path):
        info = {}
        try:
            from PIL import Image, ImageOps
            with Image.open(real) as im:
                info = {"width": im.width, "height": im.height}
                im.draft("RGB", (SIZE * 2, SIZE * 2))
                im = ImageOps.exif_transpose(im)
                im = im.convert("RGB")
                im.thumbnail((SIZE, SIZE))
                tmp = out.with_suffix(".part")
                im.save(tmp, "JPEG", quality=84)
                tmp.replace(out)
        except Exception as exc:
            log.debug("image thumbnail failed for %s: %s", vpath, exc)
            self._imageDone.emit(vpath, "", "")
            return
        self._imageDone.emit(vpath, str(out), json.dumps(info))

    @Slot(str, str, str)
    def _on_image_done(self, vpath, out, info):
        self._finish(vpath, Path(out) if out else None, info)

    def _finish(self, vpath, out: Optional[Path], info: str = ""):
        self._inflight.discard(vpath)
        if out is not None and out.exists():
            if info:
                try:
                    out.with_suffix(".json").write_text(info, encoding="utf-8")
                except OSError:
                    pass
            self.ready.emit(vpath, QUrl.fromLocalFile(str(out)).toString())
        else:
            _, o, _ = self._paths(vpath)
            if o is not None:
                self._failed.add(o.name)
            self.ready.emit(vpath, "")

    # ------------------------------------------------------------ video / audio
    def _ensure_media(self) -> bool:
        if self._media is not None:
            return self._media is not False
        try:
            from PySide6.QtMultimedia import QAudioOutput, QMediaPlayer, QVideoSink
        except ImportError:
            self._media = False
            return False
        player = QMediaPlayer(self)
        audio = QAudioOutput(self)
        audio.setMuted(True)
        player.setAudioOutput(audio)
        sink = QVideoSink(self)
        player.setVideoSink(sink)
        player.mediaStatusChanged.connect(self._on_status)
        player.errorOccurred.connect(lambda *a: self._media_fail("error"))
        sink.videoFrameChanged.connect(self._on_frame)
        timer = QTimer(self)
        timer.setSingleShot(True)
        timer.setInterval(MEDIA_TIMEOUT_MS)
        timer.timeout.connect(lambda: self._media_fail("timeout"))
        self._media = {"player": player, "audio": audio, "sink": sink, "timer": timer}
        return True

    def _next_media(self):
        if self._job is not None or not self._media_queue:
            return
        if not self._ensure_media():
            while self._media_queue:
                self._finish(self._media_queue.popleft()[0], None)
            return
        vpath, kind, real, out, meta = self._media_queue.popleft()
        self._job = {"vpath": vpath, "kind": kind, "out": out, "target": 0, "frames": 0, "seeking": False}
        m = self._media
        m["timer"].start()
        m["player"].setSource(QUrl.fromLocalFile(str(real)))

    def _on_status(self, status):
        job = self._job
        if job is None:
            return
        from PySide6.QtMultimedia import QMediaMetaData, QMediaPlayer
        player = self._media["player"]
        if status == QMediaPlayer.MediaStatus.InvalidMedia:
            self._media_fail("invalid")
            return
        if status not in (QMediaPlayer.MediaStatus.LoadedMedia, QMediaPlayer.MediaStatus.BufferedMedia) or job["seeking"]:
            return
        duration = max(0, player.duration())
        md = player.metaData()
        job["info"] = {"duration": duration}
        try:
            res = md.value(QMediaMetaData.Key.Resolution)
            if res is not None and hasattr(res, "width"):
                job["info"].update({"width": res.width(), "height": res.height()})
        except Exception:
            pass
        if job["kind"] == "audio" or not player.hasVideo():
            img = None
            for key in (QMediaMetaData.Key.ThumbnailImage, QMediaMetaData.Key.CoverArtImage):
                try:
                    v = md.value(key)
                    if v is not None and hasattr(v, "isNull") and not v.isNull():
                        img = v
                        break
                except Exception:
                    continue
            self._save_and_next(img)
            return
        job["seeking"] = True
        job["target"] = int(min(max(duration * 0.15, 0), 20000)) if duration > 0 else 0
        if job["target"] > 0:
            player.setPosition(job["target"])
        player.play()

    def _on_frame(self, frame):
        job = self._job
        if job is None or job["kind"] != "video" or not job["seeking"]:
            return
        job["frames"] += 1
        player = self._media["player"]
        if player.position() + 400 < job["target"] and job["frames"] < 12:
            return  # still before the seek target
        try:
            img = frame.toImage()
        except Exception:
            img = None
        self._save_and_next(img if img is not None and not img.isNull() else None)

    def _save_and_next(self, img):
        job, self._job = self._job, None
        m = self._media
        m["timer"].stop()
        m["player"].stop()
        m["player"].setSource(QUrl())
        out = None
        if img is not None:
            try:
                scaled = img.scaled(SIZE, SIZE, Qt.KeepAspectRatio, Qt.SmoothTransformation)
                if scaled.save(str(job["out"]), "JPG", 84):
                    out = job["out"]
            except Exception as exc:
                log.debug("saving thumbnail failed: %s", exc)
        if out is None and job.get("info"):
            # no picture (e.g. audio without cover art): still remember the duration
            try:
                job["out"].with_suffix(".json").write_text(json.dumps(job["info"]), encoding="utf-8")
            except OSError:
                pass
        self._finish(job["vpath"], out, json.dumps(job.get("info", {})))
        QTimer.singleShot(0, self._next_media)

    def _media_fail(self, why):
        if self._job is None:
            return
        log.debug("media thumbnail %s for %s", why, self._job["vpath"])
        self._save_and_next(None)
