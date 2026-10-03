"""
GlassOS archive support: browse, extract and create archives.

Formats: .zip, .tar, .tar.gz/.tgz, .tar.bz2/.tbz2, .tar.xz/.txz (all through the
standard library, whose decompressors are C-accelerated).

Safety (archives are untrusted input):
* path traversal ("zip slip"): absolute paths, drive letters and ".." are rejected,
  and every target is verified to stay inside the destination folder;
* tar links, devices and FIFOs are skipped (only regular files and folders);
* zip bombs: refuses archives whose declared uncompressed size exceeds
  MAX_TOTAL_BYTES, or whose compression ratio is absurd for a large payload;
* extraction goes to a temporary folder first and is renamed into place, so a
  failed or refused extraction never leaves half an archive behind.
"""

from __future__ import annotations

import os
import shutil
import stat
import tarfile
import uuid
import zipfile
from pathlib import Path, PurePosixPath
from typing import Iterable, List, Optional

MAX_TOTAL_BYTES = 20 * 1024 ** 3        # 20 GB uncompressed
MAX_RATIO = 250                          # uncompressed / compressed, for payloads > 512 MB
MAX_ENTRIES = 200_000
BUF = 1024 * 1024                        # 1 MB copy buffer

_TAR_SUFFIXES = (".tar", ".tar.gz", ".tgz", ".tar.bz2", ".tbz2", ".tbz", ".tar.xz", ".txz")


class ArchiveError(Exception):
    pass


def archive_kind(name: str) -> Optional[str]:
    n = name.lower()
    if n.endswith(".zip"):
        return "zip"
    if n.endswith(_TAR_SUFFIXES):
        return "tar"
    return None


def stem_of(name: str) -> str:
    n = name
    for suf in sorted((".zip",) + _TAR_SUFFIXES, key=len, reverse=True):
        if n.lower().endswith(suf):
            return n[: -len(suf)] or "archive"
    return os.path.splitext(n)[0] or "archive"


def _safe_rel(name: str) -> Optional[PurePosixPath]:
    """Archive member name -> safe relative path, or None if it must be skipped."""
    name = name.replace("\\", "/")
    if not name or name.startswith("/") or (len(name) > 1 and name[1] == ":"):
        return None
    parts = [p for p in PurePosixPath(name).parts if p not in ("", ".")]
    if not parts or any(p == ".." for p in parts):
        return None
    if any(c in p for p in parts for c in '<>:"|?*\0'):
        return None
    return PurePosixPath(*parts)


# ---------------------------------------------------------------- listing
def list_archive(path: Path, limit: int = 5000) -> dict:
    """{"entries": [...], "total": bytes, "count": n, "truncated": bool}"""
    kind = archive_kind(path.name)
    entries: List[dict] = []
    total = count = 0
    try:
        if kind == "zip":
            with zipfile.ZipFile(path) as zf:
                for info in zf.infolist():
                    count += 1
                    total += info.file_size
                    if len(entries) < limit:
                        entries.append({"name": info.filename.rstrip("/"), "size": info.file_size,
                                        "packed": info.compress_size, "isDir": info.is_dir()})
        elif kind == "tar":
            with tarfile.open(path) as tf:
                for m in tf:
                    count += 1
                    total += max(0, m.size)
                    if len(entries) < limit:
                        entries.append({"name": m.name.rstrip("/"), "size": m.size, "packed": 0, "isDir": m.isdir()})
        else:
            raise ArchiveError("This archive format isn't supported (use ZIP or TAR).")
    except (zipfile.BadZipFile, tarfile.TarError, OSError, EOFError) as exc:
        raise ArchiveError(f"The archive is damaged or unreadable ({exc}).")
    return {"entries": entries, "total": total, "count": count, "truncated": count > len(entries)}


# ---------------------------------------------------------------- extraction
def _check_bomb(total: int, packed: int, count: int):
    if count > MAX_ENTRIES:
        raise ArchiveError(f"The archive has too many entries ({count:,}).")
    if total > MAX_TOTAL_BYTES:
        raise ArchiveError("The archive would expand to more than 20 GB.")
    if total > 512 * 1024 ** 2 and packed > 0 and total / packed > MAX_RATIO:
        raise ArchiveError("The archive looks like a decompression bomb and was not extracted.")


def extract(path: Path, dest_dir: Path, folder_name: str) -> Path:
    """Extract ``path`` into a new folder ``dest_dir/folder_name`` (made unique). Returns it."""
    kind = archive_kind(path.name)
    if kind is None:
        raise ArchiveError("This archive format isn't supported (use ZIP or TAR).")
    staging = dest_dir / f".extract-{uuid.uuid4().hex[:8]}"
    staging.mkdir(parents=True)
    root = staging.resolve()
    try:
        if kind == "zip":
            _extract_zip(path, root)
        else:
            _extract_tar(path, root)
        # single top-level folder named like the archive? use it directly (no "a/a/" nesting)
        children = [c for c in staging.iterdir()]
        source = staging
        if len(children) == 1 and children[0].is_dir() and children[0].name == folder_name:
            source = children[0]
        target = _unique(dest_dir / folder_name)
        os.replace(source, target)
        return target
    finally:
        shutil.rmtree(staging, ignore_errors=True)


def _target(root: Path, rel: PurePosixPath) -> Path:
    t = (root / Path(*rel.parts)).resolve()
    if t != root and root not in t.parents:
        raise ArchiveError("The archive tried to write outside its folder.")
    return t


def _extract_zip(path: Path, root: Path):
    with zipfile.ZipFile(path) as zf:
        infos = zf.infolist()
        _check_bomb(sum(i.file_size for i in infos), sum(i.compress_size for i in infos), len(infos))
        written = 0
        for info in infos:
            rel = _safe_rel(info.filename)
            if rel is None:
                continue
            # skip symlinks stored in zips (unix mode in external_attr)
            if stat.S_ISLNK(info.external_attr >> 16):
                continue
            target = _target(root, rel)
            if info.is_dir():
                target.mkdir(parents=True, exist_ok=True)
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            with zf.open(info) as src, open(target, "wb") as dst:
                while True:
                    chunk = src.read(BUF)
                    if not chunk:
                        break
                    written += len(chunk)
                    if written > MAX_TOTAL_BYTES:  # sizes in the header can lie
                        raise ArchiveError("The archive expanded beyond 20 GB and was stopped.")
                    dst.write(chunk)


def _extract_tar(path: Path, root: Path):
    with tarfile.open(path) as tf:
        members = tf.getmembers()
        total = sum(max(0, m.size) for m in members if m.isfile())
        _check_bomb(total, path.stat().st_size, len(members))
        for m in members:
            rel = _safe_rel(m.name)
            if rel is None or not (m.isfile() or m.isdir()):
                continue  # links, devices, fifos are never extracted
            target = _target(root, rel)
            if m.isdir():
                target.mkdir(parents=True, exist_ok=True)
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            src = tf.extractfile(m)
            if src is None:
                continue
            with src, open(target, "wb") as dst:
                shutil.copyfileobj(src, dst, BUF)


# ---------------------------------------------------------------- creation
def compress(sources: Iterable[Path], zip_path: Path) -> int:
    """Create ``zip_path`` from files/folders. Returns the number of files stored."""
    sources = list(sources)
    tmp = zip_path.with_name(f".{zip_path.name}.{uuid.uuid4().hex[:6]}.part")
    count = 0
    try:
        with zipfile.ZipFile(tmp, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as zf:
            for src in sources:
                if src.is_dir():
                    base = src.parent
                    for dirpath, dirnames, filenames in os.walk(src):
                        dirnames[:] = sorted(d for d in dirnames if not d.startswith("."))
                        rel_dir = Path(dirpath).relative_to(base).as_posix()
                        if not filenames and not dirnames:
                            zf.writestr(rel_dir + "/", "")
                        for f in sorted(filenames):
                            if f.startswith("."):
                                continue
                            full = Path(dirpath) / f
                            if full.is_symlink():
                                continue
                            zf.write(full, f"{rel_dir}/{f}")
                            count += 1
                elif src.is_file():
                    zf.write(src, src.name)
                    count += 1
        os.replace(tmp, zip_path)
        return count
    finally:
        if tmp.exists():
            tmp.unlink()


def _unique(p: Path) -> Path:
    if not p.exists():
        return p
    n = 2
    while True:
        c = p.with_name(f"{p.name} ({n})")
        if not c.exists():
            return c
        n += 1
