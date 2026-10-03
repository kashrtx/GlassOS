#!/usr/bin/env python3
"""
Generates the GlassOS icon set into qml/icons/*.svg.

Style rules (keep new icons consistent):
  * UI glyphs: 24x24 grid, 1.8px round strokes, light ink (#EEF2F8).
  * App icons: 64x64 rounded squircle, two-stop vertical gradient, soft top
    highlight, white glyph drawn from the same 24-grid glyph set.
  * Places & files: glossy folders with an emblem; document pages with a
    folded corner and a color band identifying the file type.
  * Weather: full-color condition icons on a 64 grid.

Run:  python tools/make_icons.py
"""

import math
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "qml" / "icons"
INK = "#EEF2F8"

# --------------------------------------------------------------- 24-grid glyphs
# Each value is SVG markup drawn with stroke=currentColor-ish (filled in below).
def gear_path():
    pts = []
    for i in range(16):
        a = math.pi * 2 * i / 16 - math.pi / 2
        r = 9.2 if i % 2 == 0 else 7.0
        for da in (-0.13, 0.13):
            pts.append((12 + r * math.cos(a + da), 12 + r * math.sin(a + da)))
    d = "M" + " L".join(f"{x:.2f} {y:.2f}" for x, y in pts) + "Z"
    return f'<path d="{d}"/><circle cx="12" cy="12" r="3"/>'


def sun_rays(cx=12, cy=12, r1=6.8, r2=9.4, n=8):
    out = []
    for i in range(n):
        a = math.pi * 2 * i / n
        out.append(f"M{cx + r1 * math.cos(a):.2f} {cy + r1 * math.sin(a):.2f}L{cx + r2 * math.cos(a):.2f} {cy + r2 * math.sin(a):.2f}")
    return "".join(out)


GLYPHS = {
    "back": '<path d="M15 5l-7 7 7 7"/>',
    "forward": '<path d="M9 5l7 7-7 7"/>',
    "up": '<path d="M12 19V5M6 11l6-6 6 6"/>',
    "down": '<path d="M12 5v14M6 13l6 6 6-6"/>',
    "chevron-left": '<path d="M14.5 6l-6 6 6 6"/>',
    "chevron-right": '<path d="M9.5 6l6 6-6 6"/>',
    "chevron-down": '<path d="M6 9.5l6 6 6-6"/>',
    "chevron-up": '<path d="M6 14.5l6-6 6 6"/>',
    "refresh": '<path d="M19.5 12a7.5 7.5 0 1 1-2.2-5.3"/><path d="M19.5 4.5v4.5H15"/>',
    "close": '<path d="M6.5 6.5l11 11M17.5 6.5l-11 11"/>',
    "minimize": '<path d="M5.5 12h13"/>',
    "maximize": '<rect x="5.5" y="5.5" width="13" height="13" rx="2"/>',
    "restore": '<rect x="5" y="8.5" width="10.5" height="10.5" rx="2"/><path d="M8.5 5.5h8a2 2 0 0 1 2 2v8"/>',
    "search": '<circle cx="10.8" cy="10.8" r="6.3"/><path d="M15.6 15.6L20 20"/>',
    "plus": '<path d="M12 5v14M5 12h14"/>',
    "minus": '<path d="M5 12h14"/>',
    "check": '<path d="M5 12.5l4.5 4.5L19 7.5"/>',
    "more": '<circle cx="6" cy="12" r="1.3" class="f"/><circle cx="12" cy="12" r="1.3" class="f"/><circle cx="18" cy="12" r="1.3" class="f"/>',
    "menu": '<path d="M4.5 7h15M4.5 12h15M4.5 17h15"/>',
    "grid": '<rect x="4.5" y="4.5" width="6" height="6" rx="1.5"/><rect x="13.5" y="4.5" width="6" height="6" rx="1.5"/><rect x="4.5" y="13.5" width="6" height="6" rx="1.5"/><rect x="13.5" y="13.5" width="6" height="6" rx="1.5"/>',
    "list": '<path d="M9 7h11M9 12h11M9 17h11"/><circle cx="5" cy="7" r="1" class="f"/><circle cx="5" cy="12" r="1" class="f"/><circle cx="5" cy="17" r="1" class="f"/>',
    "home": '<path d="M4 11l8-7 8 7"/><path d="M6 9.5V19a1 1 0 0 0 1 1h3.5v-5.5h3V20H17a1 1 0 0 0 1-1V9.5"/>',
    "star": '<path d="M12 3.8l2.5 5.2 5.7.8-4.1 4 1 5.7-5.1-2.7-5.1 2.7 1-5.7-4.1-4 5.7-.8z"/>',
    "shield": '<path d="M12 3l7 2.8v5.4c0 4.4-2.9 8.1-7 9.8-4.1-1.7-7-5.4-7-9.8V5.8z"/>',
    "shield-check": '<path d="M12 3l7 2.8v5.4c0 4.4-2.9 8.1-7 9.8-4.1-1.7-7-5.4-7-9.8V5.8z"/><path d="M8.8 12.2l2.2 2.2 4.3-4.6"/>',
    "play": '<path d="M8 5.5v13l10.5-6.5z" class="f"/>',
    "pause": '<rect x="6.5" y="5" width="3.6" height="14" rx="1" class="f"/><rect x="13.9" y="5" width="3.6" height="14" rx="1" class="f"/>',
    "stop": '<rect x="6" y="6" width="12" height="12" rx="2" class="f"/>',
    "next": '<path d="M5.5 6v12l9-6z" class="f"/><path d="M18 6v12"/>',
    "prev": '<path d="M18.5 6v12l-9-6z" class="f"/><path d="M6 6v12"/>',
    "shuffle": '<path d="M4 7h2.5c5.5 0 5.5 10 11 10H20M4 17h2.5c1.8 0 2.9-1.1 3.8-2.6M13.7 9.6C14.6 8.1 15.7 7 17.5 7H20M17.5 4.5L20 7l-2.5 2.5M17.5 14.5L20 17l-2.5 2.5"/>',
    "repeat": '<path d="M17 3.5L19.5 6 17 8.5M4.5 11.5V10a4 4 0 0 1 4-4h11M7 20.5L4.5 18 7 15.5M19.5 12.5V14a4 4 0 0 1-4 4h-11"/>',
    "repeat-one": '<path d="M17 3.5L19.5 6 17 8.5M4.5 11.5V10a4 4 0 0 1 4-4h11M7 20.5L4.5 18 7 15.5M19.5 12.5V14a4 4 0 0 1-4 4h-11"/><path d="M11.2 10.6l1.3-.9v4.8"/>',
    "volume": '<path d="M4 9.5h3.5L12 5.5v13l-4.5-4H4z"/><path d="M15.5 9.2a4 4 0 0 1 0 5.6M18.2 6.5a7.7 7.7 0 0 1 0 11"/>',
    "volume-low": '<path d="M4 9.5h3.5L12 5.5v13l-4.5-4H4z"/><path d="M15.5 9.2a4 4 0 0 1 0 5.6"/>',
    "mute": '<path d="M4 9.5h3.5L12 5.5v13l-4.5-4H4z"/><path d="M15.5 9.5l5 5M20.5 9.5l-5 5"/>',
    "wifi": '<path d="M2.8 9a14 14 0 0 1 18.4 0M5.8 12.4a9.5 9.5 0 0 1 12.4 0M8.9 15.7a5 5 0 0 1 6.2 0"/><circle cx="12" cy="19" r="1.2" class="f"/>',
    "settings": gear_path(),
    "power": '<path d="M12 3.5v8"/><path d="M6.6 7a7.8 7.8 0 1 0 10.8 0"/>',
    "lock": '<rect x="5" y="10.5" width="14" height="10" rx="2.2"/><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5"/>',
    "trash": '<path d="M4.5 7h15M9.5 7V4.5h5V7M6.5 7l.9 12.2a1 1 0 0 0 1 .8h7.2a1 1 0 0 0 1-.8L17.5 7M10.2 11v5.5M13.8 11v5.5"/>',
    "edit": '<path d="M4.5 19.5h4l10-10a2.8 2.8 0 0 0-4-4l-10 10z"/><path d="M13.5 6.5l4 4"/>',
    "copy": '<rect x="8.5" y="8.5" width="11.5" height="11.5" rx="2"/><path d="M15.5 8.5V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v7.5a2 2 0 0 0 2 2h2.5"/>',
    "cut": '<circle cx="6.5" cy="17.5" r="2.8"/><circle cx="17.5" cy="17.5" r="2.8"/><path d="M8.6 15.6L18 4.5M15.4 15.6L6 4.5"/>',
    "paste": '<rect x="5.5" y="5" width="13" height="15.5" rx="2"/><rect x="9" y="3.2" width="6" height="3.6" rx="1"/>',
    "folder": '<path d="M3.5 7.5a2 2 0 0 1 2-2h3.8l2 2h7.2a2 2 0 0 1 2 2v7.5a2 2 0 0 1-2 2h-13a2 2 0 0 1-2-2z"/>',
    "folder-plus": '<path d="M3.5 7.5a2 2 0 0 1 2-2h3.8l2 2h7.2a2 2 0 0 1 2 2v7.5a2 2 0 0 1-2 2h-13a2 2 0 0 1-2-2z"/><path d="M12 10.5v5M9.5 13h5"/>',
    "file": '<path d="M6.5 3.5h7l5 5v11a1 1 0 0 1-1 1h-11a1 1 0 0 1-1-1v-15a1 1 0 0 1 1-1z"/><path d="M13.5 3.5v5h5"/>',
    "file-plus": '<path d="M6.5 3.5h7l5 5v11a1 1 0 0 1-1 1h-11a1 1 0 0 1-1-1v-15a1 1 0 0 1 1-1z"/><path d="M13.5 3.5v5h5M12 11.5v6M9 14.5h6"/>',
    "download": '<path d="M12 4v11M7.5 10.5L12 15l4.5-4.5M5 20h14"/>',
    "import": '<path d="M12 3.5v10M8 9.5l4 4 4-4M4.5 14v4.5a1.5 1.5 0 0 0 1.5 1.5h12a1.5 1.5 0 0 0 1.5-1.5V14"/>',
    "export": '<path d="M12 14V3.5M8 7.5l4-4 4 4M4.5 14v4.5a1.5 1.5 0 0 0 1.5 1.5h12a1.5 1.5 0 0 0 1.5-1.5V14"/>',
    "info": '<circle cx="12" cy="12" r="8.5"/><path d="M12 11v5.5"/><circle cx="12" cy="7.8" r="1" class="f"/>',
    "warning": '<path d="M12 4l8.8 15.5H3.2z"/><path d="M12 10v4.2"/><circle cx="12" cy="17" r="1" class="f"/>',
    "error": '<circle cx="12" cy="12" r="8.5"/><path d="M9 9l6 6M15 9l-6 6"/>',
    "check-circle": '<circle cx="12" cy="12" r="8.5"/><path d="M8.3 12.3l2.5 2.5 4.9-5.1"/>',
    "bell": '<path d="M6 16.5V11a6 6 0 0 1 12 0v5.5l1.8 1.8H4.2z"/><path d="M10 20.5a2.2 2.2 0 0 0 4 0"/>',
    "calendar": '<rect x="4" y="5.5" width="16" height="14.5" rx="2"/><path d="M4 10h16M8.5 3.5v4M15.5 3.5v4"/>',
    "clock": '<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>',
    "sun": '<circle cx="12" cy="12" r="4"/>' + f'<path d="{sun_rays()}"/>',
    "moon": '<path d="M19.5 14.5A8 8 0 1 1 9.5 4.5a6.3 6.3 0 0 0 10 10z"/>',
    "drop": '<path d="M12 3.5c3.4 4.3 6 7.5 6 10.8a6 6 0 0 1-12 0c0-3.3 2.6-6.5 6-10.8z"/>',
    "wind": '<path d="M3.5 8.5h10.5a2.8 2.8 0 1 0-2.8-2.8M3.5 12h15a2.8 2.8 0 1 1-2.8 2.8M3.5 15.5h7"/>',
    "zoom-in": '<circle cx="10.8" cy="10.8" r="6.3"/><path d="M15.6 15.6L20 20M10.8 8v5.6M8 10.8h5.6"/>',
    "zoom-out": '<circle cx="10.8" cy="10.8" r="6.3"/><path d="M15.6 15.6L20 20M8 10.8h5.6"/>',
    "rotate": '<path d="M4.5 12a7.5 7.5 0 1 0 2.2-5.3"/><path d="M4.5 4.5V9H9"/>',
    "fit": '<path d="M4.5 9V5.5a1 1 0 0 1 1-1H9M15 4.5h3.5a1 1 0 0 1 1 1V9M19.5 15v3.5a1 1 0 0 1-1 1H15M9 19.5H5.5a1 1 0 0 1-1-1V15"/>',
    "fullscreen": '<path d="M4.5 9V4.5H9M19.5 9V4.5H15M4.5 15v4.5H9M19.5 15v4.5H15"/>',
    "exit-fullscreen": '<path d="M9 4.5V9H4.5M15 4.5V9h4.5M9 19.5V15H4.5M15 19.5V15h4.5"/>',
    "image": '<rect x="3.5" y="5" width="17" height="14" rx="2"/><circle cx="8.5" cy="10" r="1.6"/><path d="M20.5 15.5l-4.5-4.5-8 8"/>',
    "pin": '<path d="M9 3.5h6l-.8 5.5 3.3 3.3H6.5L9.8 9z"/><path d="M12 12.3v8.2"/>',
    "monitor": '<rect x="3" y="4.5" width="18" height="12" rx="2"/><path d="M8.5 20h7M12 16.5V20"/>',
    "terminal": '<rect x="3" y="4.5" width="18" height="15" rx="2.2"/><path d="M7 9.5l3 2.5-3 2.5M12.5 15h4.5"/>',
    "history": '<path d="M4.5 12a7.5 7.5 0 1 0 2.2-5.3"/><path d="M4.5 4.5V9H9M12 8.5V12l2.8 1.8"/>',
    "undo": '<path d="M9 14L4.5 9.5 9 5"/><path d="M4.5 9.5h10a5 5 0 0 1 0 10h-3"/>',
    "redo": '<path d="M15 14l4.5-4.5L15 5"/><path d="M19.5 9.5h-10a5 5 0 0 0 0 10h3"/>',
    "save": '<path d="M5.5 3.5h10.5l4 4v12a1 1 0 0 1-1 1h-13.5a1 1 0 0 1-1-1v-15a1 1 0 0 1 1-1z"/><path d="M8 3.5v4.5h7V3.5M7.5 20.5v-6.5h9v6.5"/>',
    "folder-open": '<path d="M3.5 17V7.5a2 2 0 0 1 2-2h3.8l2 2h6.2a2 2 0 0 1 2 2v1"/><path d="M3.5 17l2.6-6a1.6 1.6 0 0 1 1.5-1h13l-2.9 7.2a1.5 1.5 0 0 1-1.4.9H5a1.5 1.5 0 0 1-1.5-1.1z"/>',
    "wrap": '<path d="M4.5 6.5h15M4.5 12h12a3 3 0 0 1 0 6h-4M14.5 16l-2 2 2 2M4.5 18H9"/>',
    "code": '<path d="M8.5 7l-5 5 5 5M15.5 7l5 5-5 5M13.8 4.5l-3.6 15"/>',
    "type": '<path d="M5.5 19.5l5.6-15h1.8l5.6 15M8 14h8"/>',
    "cpu": '<rect x="7" y="7" width="10" height="10" rx="1.5"/><rect x="10" y="10" width="4" height="4" rx=".6"/><path d="M10 3.5V7M14 3.5V7M10 17v3.5M14 17v3.5M3.5 10H7M3.5 14H7M17 10h3.5M17 14h3.5"/>',
    "activity": '<path d="M3 12h4l3-7.5 4 15 3-7.5h4"/>',
    "sparkles": '<path d="M10 3.5l1.6 4.4 4.4 1.6-4.4 1.6L10 15.5l-1.6-4.4L4 9.5l4.4-1.6zM17.5 13.5l.9 2.1 2.1.9-2.1.9-.9 2.1-.9-2.1-2.1-.9 2.1-.9z"/>',
    "user": '<circle cx="12" cy="8.5" r="4"/><path d="M4.5 20.5a7.5 7.5 0 0 1 15 0"/>',
    "keyboard": '<rect x="2.5" y="6" width="19" height="12" rx="2"/><path d="M6 10h.01M9.5 10h.01M13 10h.01M16.5 10h.01M8 14h8"/>',
    "palette": '<path d="M12 3.5a8.5 8.5 0 1 0 0 17c1.2 0 1.8-.9 1.4-2l-.4-1a1.7 1.7 0 0 1 1.6-2.3H17a3.5 3.5 0 0 0 3.5-3.5c0-4.6-3.8-8.2-8.5-8.2z"/><circle cx="7.8" cy="11" r="1.1" class="f"/><circle cx="10.5" cy="7.3" r="1.1" class="f"/><circle cx="15" cy="7.8" r="1.1" class="f"/>',
    "accessibility": '<circle cx="12" cy="4.8" r="1.6" class="f"/><path d="M5 8.5l7 1.5 7-1.5M12 10v4.5M12 14.5l-3 6M12 14.5l3 6"/>',
    "external": '<path d="M14 4.5h5.5V10M19.5 4.5l-8.5 8.5M17.5 14v4.5a1 1 0 0 1-1 1h-11a1 1 0 0 1-1-1v-11a1 1 0 0 1 1-1H10"/>',
    "bookmark": '<path d="M6.5 3.5h11v17l-5.5-3.8-5.5 3.8z"/>',
    "globe": '<circle cx="12" cy="12" r="8.5"/><path d="M3.5 12h17M12 3.5c2.4 2.6 3.6 5.4 3.6 8.5s-1.2 5.9-3.6 8.5c-2.4-2.6-3.6-5.4-3.6-8.5s1.2-5.9 3.6-8.5z"/>',
    "compass": '<circle cx="12" cy="12" r="8.5"/><path d="M15.5 8.5l-2 5-5 2 2-5z"/>',
    "music": '<path d="M9 17.5V5.5l10.5-2v12"/><circle cx="6.5" cy="17.5" r="2.5"/><circle cx="17" cy="15.5" r="2.5"/>',
    "film": '<rect x="3.5" y="4.5" width="17" height="15" rx="2"/><path d="M7.5 4.5v15M16.5 4.5v15M3.5 9.5h4M3.5 14.5h4M16.5 9.5h4M16.5 14.5h4"/>',
    "media": '<circle cx="12" cy="12" r="8.5"/><path d="M10 8.5v7l5.5-3.5z" class="f"/>',
    "playlist": '<path d="M4 6.5h11M4 11h11M4 15.5h6"/><path d="M17 18.5v-7.5l3.5-1"/><circle cx="15.3" cy="18.5" r="1.8"/>',
    "speed": '<path d="M4.5 16.5a7.5 7.5 0 1 1 15 0"/><path d="M12 16.5l3.5-5"/>',
    "location": '<path d="M12 21s-6.8-6.1-6.8-11.6a6.8 6.8 0 0 1 13.6 0C18.8 14.9 12 21 12 21z"/><circle cx="12" cy="9.5" r="2.5"/>',
    "thermometer": '<path d="M10 14.5V5.5a2 2 0 0 1 4 0v9a4 4 0 1 1-4 0z"/><path d="M12 9v7"/>',
    "gauge": '<circle cx="12" cy="12" r="8.5"/><path d="M12 12l4-3.5M7 15.5h10"/>',
    "sunrise": f'<path d="M7.5 17.5a4.5 4.5 0 0 1 9 0M3.5 17.5h17M12 9.5V3.5M9.5 6l2.5-2.5L14.5 6"/>',
    "sunset": f'<path d="M7.5 17.5a4.5 4.5 0 0 1 9 0M3.5 17.5h17M12 3.5v6M9.5 7l2.5 2.5L14.5 7"/>',
    "cloud": '<path d="M7 18.5a4.5 4.5 0 0 1-.5-9 6 6 0 0 1 11.4 1.4 3.8 3.8 0 0 1-.4 7.6z"/>',
    "diamond": '<path d="M7 4.5h10l3.5 5L12 20 3.5 9.5z"/><path d="M3.5 9.5h17M9.5 4.5L12 20l2.5-15.5"/>',
    "brightness": '<circle cx="12" cy="12" r="3.6"/>' + f'<path d="{sun_rays(r1=6, r2=8.6)}"/>',
    "link": '<path d="M10 14a4.5 4.5 0 0 0 6.4 0l3-3a4.5 4.5 0 0 0-6.4-6.4l-1 1M14 10a4.5 4.5 0 0 0-6.4 0l-3 3a4.5 4.5 0 0 0 6.4 6.4l1-1"/>',
    "tab": '<rect x="3.5" y="5.5" width="17" height="14" rx="2"/><path d="M3.5 9.5h17M8.5 5.5v4"/>',
    "calculator": '<rect x="5" y="3.5" width="14" height="17" rx="2.5"/><path d="M8 7.5h8M8.5 12h.01M12 12h.01M15.5 12h.01M8.5 16h.01M12 16h.01M15.5 16h.01"/>',
    "snake": '<path d="M17.5 5.5H9.2a3.3 3.3 0 0 0 0 6.6h5.6a3.3 3.3 0 0 1 0 6.6H5.5"/><circle cx="18.5" cy="5.5" r="1.2" class="f"/>',
    "photo-stack": '<rect x="6" y="3.5" width="14.5" height="12.5" rx="2"/><path d="M3.5 7.5v10.5a2 2 0 0 0 2 2H17"/><path d="M20.5 13l-4-4-6 6"/>',
    "weather": '<circle cx="9" cy="9" r="3.2"/><path d="M9 2.8v1.2M3 9h1.2M4.8 4.8l.9.9M13.2 4.8l-.9.9"/><path d="M9.5 19.5a3.8 3.8 0 0 1-.4-7.6 5 5 0 0 1 9.6 1.3 3.2 3.2 0 0 1-.3 6.3z"/>',
    "broom": '<path d="M14 4l6 6M12.5 8.5l3 3M4 20c1-4 2.5-7.5 5.5-9.5l4 4C11.5 17.5 8 19 4 20z"/>',
    "devtools": '<rect x="3" y="4.5" width="18" height="15" rx="2"/><path d="M8 10l-2 2 2 2M16 10l2 2-2 2M13 9l-2 6"/>',
    "privacy": '<path d="M12 3l7 2.8v5.4c0 4.4-2.9 8.1-7 9.8-4.1-1.7-7-5.4-7-9.8V5.8z"/><circle cx="12" cy="11" r="2"/><path d="M12 13v3"/>',
    "puzzle": '<path d="M9.5 4.5h3.2a1.8 1.8 0 1 1 3.6 0h3.2v4.2a1.8 1.8 0 1 1 0 3.6v4.2h-4.2a1.8 1.8 0 1 0-3.6 0H4.5v-4.2a1.8 1.8 0 1 0 0-3.6V4.5z"/>',
    "details-pane": '<rect x="3.5" y="4.5" width="17" height="15" rx="2"/><path d="M14.5 4.5v15M16.8 8.5h1.4M16.8 11.5h1.4"/>',
    "queue-add": '<path d="M4 6.5h11M4 11h11M4 15.5h7M17.5 13v7M14 16.5h7"/>',
    "send": '<path d="M4 12l16-7.5-6 16-2.5-6.5z"/><path d="M11.5 14L20 4.5"/>',
}

# Light-on-dark default; a few glyph variants with intrinsic color
COLORED_GLYPHS = {
    "star-filled": ("star", "#FACC15", True),
    "shield-on": ("shield-check", "#4ADE80", False),
    "warning-color": ("warning", "#FBBF24", False),
    "error-color": ("error", "#F87171", False),
    "success": ("check-circle", "#4ADE80", False),
    "info-color": ("info", "#60A5FA", False),
}


def solid(body, color):
    """Dots/filled shapes are tagged class="f"; turn them into presentation attributes
    (Qt's SVG renderer implements SVG Tiny 1.2, so avoid relying on CSS)."""
    return body.replace('class="f"', f'fill="{color}" stroke="none"')


def stroked(body, color, width, fill="none"):
    return (f'<g fill="{fill}" stroke="{color}" stroke-width="{width}" stroke-linecap="round" '
            f'stroke-linejoin="round">{solid(body, color)}</g>')


def glyph_svg(body, color=INK, fill=False):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
            f'{stroked(body, color, 1.8, color if fill else "none")}</svg>')


# ------------------------------------------------------------------ app icons
APPS = {
    "app-files": ("folder", "#FCD34D", "#F59E0B"),
    "app-browser": ("compass", "#38BDF8", "#6366F1"),
    "app-notepad": ("edit", "#FDBA74", "#F43F5E"),
    "app-terminal": ("terminal", "#475569", "#0F172A"),
    "app-calculator": ("calculator", "#4ADE80", "#059669"),
    "app-weather": ("weather", "#7DD3FC", "#2563EB"),
    "app-photos": ("photo-stack", "#F9A8D4", "#A855F7"),
    "app-media": ("media", "#FB7185", "#7C3AED"),
    "app-taskmanager": ("activity", "#C4B5FD", "#6D28D9"),
    "app-snake": ("snake", "#BEF264", "#16A34A"),
    "app-settings": ("settings", "#CBD5E1", "#475569"),
}


def app_svg(glyph, c1, c2):
    body = GLYPHS[glyph]
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
<defs>
 <linearGradient id="bg" x1="0" y1="0" x2="0.35" y2="1"><stop offset="0" stop-color="{c1}"/><stop offset="1" stop-color="{c2}"/></linearGradient>
 <linearGradient id="hl" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF" stop-opacity="0.38"/><stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/></linearGradient>
</defs>
<rect x="3" y="3" width="58" height="58" rx="15" fill="url(#bg)"/>
<path d="M18 3h28a15 15 0 0 1 15 15v4C47 28 17 28 3 22v-4A15 15 0 0 1 18 3z" fill="url(#hl)"/>
<rect x="3.5" y="3.5" width="57" height="57" rx="14.5" fill="none" stroke="#FFFFFF" stroke-opacity="0.22"/>
<g transform="translate(12.8 12.8) scale(1.6)">{stroked(body, "#FFFFFF", 1.9)}</g>
</svg>'''


# --------------------------------------------------------- places and files
def folder_svg(emblem=None, c1="#6CC4FF", c2="#2F86E0"):
    em = ""
    if emblem:
        em = f'<g transform="translate(18 24.5) scale(0.5)" opacity="0.92">{stroked(GLYPHS[emblem], "#FFFFFF", 2.4)}</g>'
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
<defs>
 <linearGradient id="b" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{c2}"/><stop offset="1" stop-color="#1D5FAF"/></linearGradient>
 <linearGradient id="f" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{c1}"/><stop offset="1" stop-color="{c2}"/></linearGradient>
</defs>
<path d="M5 12a3 3 0 0 1 3-3h10l4 4h18a3 3 0 0 1 3 3v20a3 3 0 0 1-3 3H8a3 3 0 0 1-3-3z" fill="url(#b)"/>
<path d="M5 18a3 3 0 0 1 3-3h32a3 3 0 0 1 3 3v18a3 3 0 0 1-3 3H8a3 3 0 0 1-3-3z" fill="url(#f)"/>
<path d="M8 15.6h32a2.4 2.4 0 0 1 2.4 2.4v1H5.6v-1A2.4 2.4 0 0 1 8 15.6z" fill="#FFFFFF" fill-opacity="0.28"/>
{em}
</svg>'''


FILE_TYPES = {
    "file-generic": ("#94A3B8", "#64748B", None, ""),
    "file-text": ("#93C5FD", "#3B82F6", None, "TXT"),
    "file-code": ("#A78BFA", "#7C3AED", "code", ""),
    "file-image": ("#F9A8D4", "#DB2777", "image", ""),
    "file-audio": ("#FCA5A5", "#E11D48", "music", ""),
    "file-video": ("#FDBA74", "#EA580C", "film", ""),
    "file-archive": ("#FDE68A", "#CA8A04", None, "ZIP"),
    "file-pdf": ("#FCA5A5", "#DC2626", None, "PDF"),
}


def file_svg(c1, c2, emblem, label):
    inner = ""
    if emblem:
        inner = f'<g transform="translate(15 21) scale(0.75)">{stroked(GLYPHS[emblem], c2, 2.2)}</g>'
    elif label:
        inner = (f'<text x="24" y="35" text-anchor="middle" font-family="Segoe UI, Arial, sans-serif" font-size="8.5" '
                 f'font-weight="700" fill="{c2}">{label}</text>')
    else:
        inner = f'<path d="M15 24h18M15 29h18M15 34h12" stroke="#94A3B8" stroke-width="2" stroke-linecap="round"/>'
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
<defs><linearGradient id="p" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF"/><stop offset="1" stop-color="#E2E8F0"/></linearGradient>
<linearGradient id="t" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="{c1}"/><stop offset="1" stop-color="{c2}"/></linearGradient></defs>
<path d="M11 4h18l10 10v28a2 2 0 0 1-2 2H11a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2z" fill="url(#p)"/>
<path d="M29 4v8a2 2 0 0 0 2 2h8z" fill="#CBD5E1"/>
<rect x="9" y="38" width="30" height="6" fill="url(#t)"/>
<path d="M9 38h30v4a2 2 0 0 1-2 2H11a2 2 0 0 1-2-2z" fill="url(#t)"/>
{inner}
</svg>'''


PC_SVG = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
<defs><linearGradient id="s" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#7DD3FC"/><stop offset="0.55" stop-color="#6366F1"/><stop offset="1" stop-color="#A855F7"/></linearGradient>
<linearGradient id="b" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#E2E8F0"/><stop offset="1" stop-color="#94A3B8"/></linearGradient></defs>
<rect x="4" y="7" width="40" height="27" rx="3" fill="#1E293B"/><rect x="6.5" y="9.5" width="35" height="22" rx="1.5" fill="url(#s)"/>
<path d="M6.5 9.5h35v8C30 21 18 21 6.5 26z" fill="#FFFFFF" fill-opacity="0.18"/>
<path d="M19 34h10l1.5 6h-13z" fill="url(#b)"/><rect x="13" y="40" width="22" height="3" rx="1.5" fill="url(#b)"/>
</svg>'''


def trash_svg(full):
    paper = ('<path d="M17 13l4-6 5 4 4-5 3 7z" fill="#F8FAFC" stroke="#CBD5E1" stroke-width="0.8"/>'
             '<path d="M21 13l3-4 5 2 2 2z" fill="#E2E8F0"/>') if full else ""
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#CBD5E1" stop-opacity="0.75"/><stop offset="0.5" stop-color="#F8FAFC" stop-opacity="0.9"/><stop offset="1" stop-color="#94A3B8" stop-opacity="0.75"/></linearGradient></defs>
{paper}
<path d="M11 13h26l-2.6 28a3 3 0 0 1-3 2.7H16.6a3 3 0 0 1-3-2.7z" fill="url(#g)" stroke="#E2E8F0" stroke-opacity="0.9"/>
<path d="M18 18l1 20M24 18v20M30 18l-1 20" stroke="#64748B" stroke-opacity="0.55" stroke-width="1.6" stroke-linecap="round"/>
<rect x="8.5" y="10" width="31" height="4.5" rx="2.2" fill="#E2E8F0"/>
</svg>'''


# ----------------------------------------------------------------- weather
def wx(sun=False, moon=False, cloud=False, dark=False, rain=0, snow=False, bolt=False, fog=False, small_cloud=False):
    parts = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><defs>'
             '<radialGradient id="sun" cx="0.4" cy="0.35" r="0.7"><stop offset="0" stop-color="#FEF08A"/><stop offset="1" stop-color="#F59E0B"/></radialGradient>'
             '<linearGradient id="cl" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF"/><stop offset="1" stop-color="#CBD5E1"/></linearGradient>'
             '<linearGradient id="dk" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#94A3B8"/><stop offset="1" stop-color="#475569"/></linearGradient>'
             '<linearGradient id="mn" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#E0E7FF"/><stop offset="1" stop-color="#A5B4FC"/></linearGradient>'
             '</defs>']
    if sun:
        cx, cy, r = (32, 32, 12) if not cloud else (24, 22, 10)
        rays = "".join(
            f'<path d="M{cx + (r + 4) * math.cos(a):.1f} {cy + (r + 4) * math.sin(a):.1f}L{cx + (r + 9) * math.cos(a):.1f} {cy + (r + 9) * math.sin(a):.1f}"/>'
            for a in [i * math.pi / 4 for i in range(8)])
        parts.append(f'<g stroke="#FBBF24" stroke-width="3.2" stroke-linecap="round">{rays}</g>')
        parts.append(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="url(#sun)"/>')
    if moon:
        tx = "" if not cloud else ' transform="translate(-8 -9) scale(0.85)"'
        parts.append(f'<path{tx} d="M44 40A17 17 0 1 1 26 14a13.5 13.5 0 0 0 18 26z" fill="url(#mn)"/>')
    if cloud:
        fill = "url(#dk)" if dark else "url(#cl)"
        if small_cloud:
            parts.append(f'<path d="M22 50a9 9 0 0 1-1-18 12 12 0 0 1 23 3 7.5 7.5 0 0 1-1 15z" fill="{fill}"/>')
        else:
            parts.append(f'<path d="M18 46a10 10 0 0 1-1.2-19.9A14 14 0 0 1 43.5 29 8.5 8.5 0 0 1 43 46z" fill="{fill}"/>')
    if rain:
        drops = [(22, 52), (32, 54), (42, 52)][:rain]
        parts.append('<g stroke="#38BDF8" stroke-width="3" stroke-linecap="round">' +
                     "".join(f'<path d="M{x} {y}l-2.5 6"/>' for x, y in drops) + "</g>")
    if snow:
        parts.append('<g fill="#E0F2FE">' + "".join(f'<circle cx="{x}" cy="{y}" r="2.6"/>' for x, y in [(22, 54), (32, 57), (42, 54)]) + "</g>")
    if bolt:
        parts.append('<path d="M34 44l-7 10h6l-3 8 9-12h-6l3-6z" fill="#FACC15"/>')
    if fog:
        parts.append('<g stroke="#CBD5E1" stroke-width="3.2" stroke-linecap="round"><path d="M12 50h40M18 57h28"/></g>')
    parts.append("</svg>")
    return "".join(parts)


WEATHER = {
    "wx-clear-day": dict(sun=True),
    "wx-clear-night": dict(moon=True),
    "wx-partly-day": dict(sun=True, cloud=True, small_cloud=True),
    "wx-partly-night": dict(moon=True, cloud=True, small_cloud=True),
    "wx-cloudy": dict(cloud=True),
    "wx-fog": dict(cloud=True, fog=True),
    "wx-drizzle": dict(cloud=True, rain=2),
    "wx-rain": dict(cloud=True, dark=True, rain=3),
    "wx-snow": dict(cloud=True, snow=True),
    "wx-thunder": dict(cloud=True, dark=True, bolt=True),
}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob("*.svg"):
        old.unlink()
    n = 0

    def write(name, svg):
        nonlocal n
        (OUT / f"{name}.svg").write_text(svg, encoding="utf-8")
        n += 1

    for name, body in GLYPHS.items():
        write(name, glyph_svg(body))
    for name, (base, color, fill) in COLORED_GLYPHS.items():
        write(name, glyph_svg(GLYPHS[base], color, fill))
    for name, (glyph, c1, c2) in APPS.items():
        write(name, app_svg(glyph, c1, c2))
    write("place-folder", folder_svg())
    for emblem, name in [("monitor", "desktop"), ("file", "documents"), ("download", "downloads"),
                         ("image", "pictures"), ("music", "music"), ("film", "videos"), ("home", "home")]:
        write(f"place-{name}", folder_svg(emblem))
    write("place-pc", PC_SVG)
    write("place-trash", trash_svg(False))
    write("place-trash-full", trash_svg(True))
    for name, (c1, c2, emblem, label) in FILE_TYPES.items():
        write(name, file_svg(c1, c2, emblem, label))
    for name, spec in WEATHER.items():
        write(name, wx(**spec))
    print(f"wrote {n} icons to {OUT}")


if __name__ == "__main__":
    main()
