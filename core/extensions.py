"""
AeroBrowser extensions, exposed to QML as ``Extensions``.

SAFETY FIRST (learned the hard way): PySide6 6.10 can't convert
QWebEngineExtensionInfo to Python ("SbkConverter::copyToPython is null"), and
receiving one - from extensions() or any extension signal - crashes the whole
process. So Python NEVER touches Qt's extension manager. Python only does file
work (download, CRX unpack, Manifest V3 check, localized names) and hands a ready
path to qml/components/ExtensionHost.qml, which talks to Qt's manager directly.

Chrome extensions are opt-in ("experimental", off by default) and guarded: if
GlassOS dies while they're active, they're switched off on the next start.

Built on Qt WebEngine's extension manager (Qt 6.10+). Facts from Qt's docs that
shape this module:
* only **Manifest V3** extensions can be loaded (MV2 ones, like classic uBlock
  Origin, are refused) - we detect MV2 up front and say so;
* extensions are always **loaded disabled**: we enable them (unless the user
  switched one off, which we remember);
* ``installExtension`` persists extensions in the profile and needs the
  manifest at the top level of the zip/folder;
* extensions can't live in off-the-record profiles, and Qt 6.10.1 even crashes
  (QTBUG-142247) when listing extensions of one - so we only ever touch the
  manager of GlassOS's persistent profile.

uBlock Origin Lite (the MV3 edition of uBlock Origin, by the same author) is
installed from the Chrome Web Store on first run; Chrome Web Store pages get an
"Add to AeroBrowser" bar (CRX packages are downloaded and unpacked here).
"""

from __future__ import annotations

import io
import json
import os
import re
import shutil
import struct
import uuid
import zipfile
from pathlib import Path
from typing import Optional

from PySide6.QtCore import QObject, Property, QUrl, Signal, Slot

from . import archives
from . import log as _log

log = _log.get("extensions")

UBOL_ID = "ddkjiahejlhfcafbddmgiahcphecmpfh"       # uBlock Origin Lite (Chrome Web Store)
BUILTIN_IDS = {"mhjfbmdgcfjbbpaeojofohoefgiehjai",  # Chromium PDF viewer (internal)
               "nkeimhogjdpnpccoofpliimaahmaaome"}  # Google Hangouts (internal)
STORE_ID = re.compile(r"^https://(?:chromewebstore\.google\.com/detail/(?:[^/?#]+/)?|chrome\.google\.com/webstore/detail/(?:[^/?#]+/)?)([a-p]{32})(?:[/?#]|$)")
CRX_URL = ("https://clients2.google.com/service/update2/crx?response=redirect&prodversion=134.0.6998.208"
           "&acceptformat=crx2,crx3&x=id%3D{id}%26uc")
MAX_CRX = 200 * 1024 * 1024
MV2_MESSAGE = ("{name} uses Manifest V2, which Qt WebEngine (like current Chrome) can't run. "
               "Look for its Manifest V3 edition, e.g. uBlock Origin Lite instead of uBlock Origin.")


class ExtensionError(Exception):
    pass


def store_id(url: str) -> str:
    """Chrome Web Store extension id from a store page URL, or ''."""
    m = STORE_ID.match(url or "")
    return m.group(1) if m else ""


def crx_to_zip(data: bytes) -> bytes:
    """Strip the CRX2/CRX3 header and return the embedded ZIP archive."""
    if data[:2] == b"PK":
        return data
    if len(data) < 16 or data[:4] != b"Cr24":
        raise ExtensionError("Not a Chrome extension package.")
    version = struct.unpack("<I", data[4:8])[0]
    if version == 3:
        start = 12 + struct.unpack("<I", data[8:12])[0]
    elif version == 2:
        pub_len, sig_len = struct.unpack("<II", data[8:16])
        start = 16 + pub_len + sig_len
    else:
        raise ExtensionError(f"Unsupported CRX version {version}.")
    body = data[start:]
    if body[:2] != b"PK":
        raise ExtensionError("The extension package is damaged.")
    return body


def zip_manifest(zip_bytes: bytes):
    """(manifest dict, folder prefix inside the zip) - prefix is '' when it's top-level."""
    try:
        with zipfile.ZipFile(io.BytesIO(zip_bytes)) as zf:
            names = [n for n in zf.namelist() if n.rsplit("/", 1)[-1] == "manifest.json"]
            if not names:
                raise ExtensionError("The package has no manifest.json.")
            name = min(names, key=lambda n: n.count("/"))
            manifest = json.loads(zf.read(name).decode("utf-8-sig"))
    except (zipfile.BadZipFile, ValueError, UnicodeDecodeError) as exc:
        raise ExtensionError(f"The extension package is damaged ({exc}).")
    if not isinstance(manifest, dict):
        raise ExtensionError("The extension's manifest is invalid.")
    return manifest, name[: -len("manifest.json")]


def check_manifest(manifest: dict):
    if manifest.get("manifest_version") != 3:
        raise ExtensionError(MV2_MESSAGE.format(name=manifest.get("name") or "This extension"))


def localized_name(manifest: dict, zip_bytes: bytes = b"", prefix: str = "", folder: Optional[Path] = None) -> str:
    """Resolve "__MSG_extName__" style names from _locales/<default>/messages.json."""
    name = manifest.get("name") or "Extension"
    m = re.fullmatch(r"__MSG_(\w+)__", name)
    if not m:
        return name
    key = m.group(1).lower()
    for loc in [manifest.get("default_locale") or "en", "en", "en_US"]:
        rel = f"_locales/{loc}/messages.json"
        try:
            if folder is not None:
                raw = (folder / rel).read_bytes()
            else:
                with zipfile.ZipFile(io.BytesIO(zip_bytes)) as zf:
                    raw = zf.read(prefix + rel)
            msgs = {k.lower(): v for k, v in json.loads(raw.decode("utf-8-sig")).items()}
            if key in msgs and isinstance(msgs[key], dict) and msgs[key].get("message"):
                return msgs[key]["message"]
        except (KeyError, OSError, ValueError, zipfile.BadZipFile):
            continue
    return "Extension"


def purge_installed(browser_root: Path):
    """Remove extensions Qt installed into the profile (Qt auto-loads them at every startup)."""
    root = Path(browser_root)
    if not root.is_dir():
        return 0
    removed = 0
    for child in root.iterdir():
        if child.is_dir() and "extension" in child.name.lower():
            shutil.rmtree(child, ignore_errors=True)
            removed += 1
    return removed


class ExtensionService(QObject):
    """File-side half of extension support. Qt's manager is driven by ExtensionHost.qml."""
    changed = Signal()
    message = Signal(str, str)               # title, body (notification)
    installReady = Signal(str, str)          # path for manager.installExtension, display name

    def __init__(self, system_dir: Path, prefs, parent=None):
        super().__init__(parent)
        self._prefs = prefs
        self._sys = Path(system_dir)
        self._tmp = self._sys / "extensions-tmp"
        shutil.rmtree(self._tmp, ignore_errors=True)
        self._tmp.mkdir(parents=True, exist_ok=True)
        self._sentinel = self._sys / "extensions.running"
        self._busy = False
        self._nam = None
        self._crashed = False
        if self._sentinel.exists():          # we died last time while extensions were active
            self._sentinel.unlink(missing_ok=True)
            if self.experimental:
                self._crashed = True
                self._prefs.setValue("browser.extensions.experimental", False)
                purge_installed(self._sys / "browser")

    # ------------------------------------------------------------ state
    @Property(bool, constant=True)
    def allowed(self) -> bool:
        """Extensions crash inside Qt WebEngine 6.10's own native code (not catchable from
        Python or QML), so they're unavailable unless a developer opts in explicitly."""
        return os.environ.get("GLASSOS_EXTENSIONS") == "1"

    @Property(bool, notify=changed)
    def experimental(self) -> bool:
        return self.allowed and self._prefs.value("browser.extensions.experimental", False) is True

    @Slot(bool)
    def setExperimental(self, on: bool):
        self._prefs.setValue("browser.extensions.experimental", bool(on))
        self.changed.emit()

    @Property(bool, constant=True)
    def crashedLastTime(self) -> bool:
        return self._crashed

    @Property(bool, notify=changed)
    def busy(self) -> bool:
        return self._busy

    @Slot()
    def markActive(self):
        """ExtensionHost is about to touch Qt's manager: arm the crash guard."""
        try:
            self._sentinel.write_text("1", encoding="utf-8")
        except OSError:
            pass

    @Slot()
    def markInactive(self):
        self._sentinel.unlink(missing_ok=True)

    @Slot(str, result=str)
    def storeId(self, url: str) -> str:
        return store_id(url)

    # ------------------------------------------------------------ preparing packages
    def _prepare_zip(self, zip_bytes: bytes) -> tuple:
        manifest, prefix = zip_manifest(zip_bytes)
        check_manifest(manifest)
        name = localized_name(manifest, zip_bytes, prefix)
        tmp_zip = self._tmp / f"{uuid.uuid4().hex[:8]}.zip"
        tmp_zip.write_bytes(zip_bytes)
        if prefix == "":
            return str(tmp_zip), name
        # manifest in a subfolder: Qt needs it at the top, so unpack and point at that folder
        out = archives.extract(tmp_zip, self._tmp, "unpacked-" + uuid.uuid4().hex[:6])
        tmp_zip.unlink(missing_ok=True)
        return str(out / prefix.rstrip("/")), name

    @Slot(str)
    def prepareFromFile(self, path_or_url: str):
        src = Path(QUrl(path_or_url).toLocalFile() if path_or_url.startswith("file:") else path_or_url)
        try:
            if src.is_dir():
                mf = src / "manifest.json"
                if not mf.exists():
                    raise ExtensionError("That folder has no manifest.json at its top level.")
                manifest = json.loads(mf.read_text(encoding="utf-8-sig"))
                check_manifest(manifest)
                self.installReady.emit(str(src), localized_name(manifest, folder=src))
                return
            if src.stat().st_size > MAX_CRX:
                raise ExtensionError("The extension is too large.")
            path, name = self._prepare_zip(crx_to_zip(src.read_bytes()))
        except (OSError, ValueError, ExtensionError, archives.ArchiveError) as exc:
            self.message.emit("Couldn't install the extension", str(exc))
            return
        self.installReady.emit(path, name)

    @Slot(str)
    def prepareFromStore(self, ext_id: str):
        if not re.fullmatch(r"[a-p]{32}", ext_id or "") or self._busy:
            return
        from PySide6.QtNetwork import QNetworkAccessManager, QNetworkReply, QNetworkRequest
        self._nam = self._nam or QNetworkAccessManager(self)
        req = QNetworkRequest(QUrl(CRX_URL.format(id=ext_id)))
        req.setAttribute(QNetworkRequest.Attribute.RedirectPolicyAttribute,
                         QNetworkRequest.RedirectPolicy.NoLessSafeRedirectPolicy)
        req.setTransferTimeout(90000)
        reply = self._nam.get(req)
        self._busy = True
        self.changed.emit()

        def done():
            reply.deleteLater()
            self._busy = False
            self.changed.emit()
            if reply.error() != QNetworkReply.NetworkError.NoError:
                self.message.emit("Download failed", reply.errorString())
                return
            try:
                data = bytes(reply.readAll().data())
                if len(data) > MAX_CRX:
                    raise ExtensionError("The extension is too large.")
                path, name = self._prepare_zip(crx_to_zip(data))
            except (ExtensionError, archives.ArchiveError, OSError) as exc:
                self.message.emit("Couldn't install the extension", str(exc))
                return
            self.installReady.emit(path, name)

        reply.finished.connect(done)
