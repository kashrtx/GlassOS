"""Bundled filter lists for AeroBrowser's built-in blocker (Qt-free, unit-tested)."""

from __future__ import annotations

from pathlib import Path

from . import log as _log

log = _log.get("adblock")

# uBlock Origin's own lists (from the official uBO release package), usable offline from the first launch
BUNDLED_PACK = Path(__file__).resolve().parent.parent / "assets" / "filters" / "ublock-origin-filters.zip"
_PACK_LISTS = ("ublock/filters.min.txt", "ublock/privacy.min.txt", "ublock/badware.min.txt",
               "ublock/unbreak.min.txt", "ublock/quick-fixes.min.txt",
               "thirdparties/urlhaus-filter/urlhaus-filter-online.txt")
_PACK_FALLBACK = {"easylist": "thirdparties/easylist/easylist.txt",
                  "easyprivacy": "thirdparties/easylist/easyprivacy.txt"}


def bundled_lists(have_downloaded):
    """Texts from the bundled uBO pack; EasyList/EasyPrivacy only if no fresher download exists."""
    import zipfile
    texts = []
    if not BUNDLED_PACK.exists():
        return texts
    try:
        with zipfile.ZipFile(BUNDLED_PACK) as zf:
            names = zf.namelist()
            wanted = list(_PACK_LISTS) + [v for k, v in _PACK_FALLBACK.items() if k not in have_downloaded]
            for want in wanted:
                match = next((n for n in names if n.endswith("assets/" + want)), None)
                if match:
                    texts.append(zf.read(match).decode("utf-8", "replace"))
    except (OSError, zipfile.BadZipFile) as exc:
        log.warning("bundled filter pack unreadable: %s", exc)
    return texts
