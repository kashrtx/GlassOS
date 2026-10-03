<div align="center">

# GlassOS 2.6.8

### A glassy desktop environment written in Python + Qt Quick

![Python](https://img.shields.io/badge/Python-3.10+-blue?logo=python&logoColor=white)
![Qt](https://img.shields.io/badge/Qt-6.5+-green?logo=qt&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-yellow)

</div>

GlassOS runs as a full-screen app on Windows, macOS or Linux and gives you a complete,
playful desktop: frosted-glass windows that snap and animate, a searchable Start menu,
a real terminal, a web browser, games and more. Your files live in a sandbox
(`Storage/User`) so you can experiment freely.

## Quick start

```bash
pip install -r requirements.txt
python main.py              # full screen
python main.py --windowed   # in a resizable window
```

| Flag | What it does |
|------|--------------|
| `--windowed`, `-w` | Run in a window instead of full screen |
| `--no-boot` | Skip the boot animation |
| `--software` | Software rendering, for VMs / remote desktops with broken GPU drivers |

Only **PySide6** is required. The rest is optional and GlassOS adapts if it's missing:

| Package | Enables |
|---------|---------|
| `PySide6-Addons` (QtWebEngine, QtMultimedia) | AeroBrowser and the Media Player (both ship with the full `PySide6` package) |
| `numpy` | Faster spectrum analysis for the music equalizer |
| `Pillow` | The frosted-glass blur behind windows, menus and the taskbar |
| `psutil` | Live CPU / memory stats in the tray, Task Manager and Settings |

## What's inside

**Desktop & windows**
- Drag a window to an edge or corner to snap it (with a live preview); drag the top edge to maximize
- Resize from any edge or corner; double-click a title bar to maximize; right-click it for a window menu
- Genie-style minimize, open/close animations, click-anywhere-to-focus
- Desktop icons you can drag, rubber-band select, drop onto folders or the Recycle Bin
- Big desktop clock with a greeting and the current weather

**Multitasking**
- **Snap Layouts**: hover a window's maximize button and pick halves, quarters (4-way split), rows, thirds or 2/3 + 1/3
- **Snap Assist**: after snapping one window, the empty slots offer your other windows; click to fill the layout
- Drag to edges/corners, or `Ctrl+Alt+arrows` (from a half, up/down goes to a quarter)
- **4 virtual workspaces**: `Ctrl+Alt+1…4`, `Ctrl+Alt+PgUp/PgDn`, the taskbar pills (scroll to switch);
  move windows with `Ctrl+Alt+Shift+1…4` or the title-bar menu. The dock and Alt+Tab show the current workspace
- **Session restore**: your windows, folders, files, pages and workspaces come back after a restart (Settings ▸ Personalization)

**Media, previews & full screen**
- Thumbnails everywhere: photos, video frames and album art in Files, on the desktop, in Photos and the Media Player
- Files **details pane** (Alt+P): big preview, type, size, dates, location, dimensions, length, item count
- Media Player works like VLC: one player, opening a file adds it to the queue and plays it (nothing is lost, Back works);
  play next / add to queue, reorder, saved **playlists**, `.m3u` import/export
- True full screen for web video, the Media Player and Photos: the taskbar hides, **Esc** always exits

**Clipboard, archives & screenshots**
- **Clipboard history** (`Ctrl+Alt+V`): search, pin (kept across restarts) and paste straight into the field you were typing in
- Files copied in GlassOS paste in your computer's file manager, and files copied there paste into GlassOS
- **Archives**: open ZIP / TAR / TAR.GZ / TAR.BZ2 / TAR.XZ to browse them, *Extract here*, *Compress to ZIP*;
  runs in the background, protected against path-traversal and decompression bombs. Terminal: `zip`, `unzip`, `lsarchive`
- **Screenshots**: `Print` / `Ctrl+Alt+S` (whole screen) and `Alt+Print` (active window), saved to Pictures ▸ Screenshots and copied to the clipboard
- `F1` shows every keyboard shortcut

**Drag & drop and your own files**
- Drag files and folders between Files windows side by side, onto folders, the desktop, or the Recycle Bin
  (hold **Ctrl** to copy instead of move; **Esc** cancels). Hovering a drag over a window brings it to the front
- Drag files **from your computer's file manager** straight into GlassOS (desktop or any Files window) to import them
- **Import** / **Export to computer…** in Files and on the desktop copy files in and out of GlassOS
- Drop a file onto GlassPad, Photos, AeroBrowser or Terminal to open it there
- Right-click the desktop to create folders and documents, add app shortcuts, or import files;
  right-click any app in Start to pin it to the taskbar or add it to the desktop

**Taskbar & Start**
- Centered dock that merges pinned and running apps, with window counts and right-click menus
- Start menu (`Ctrl+Space`) searches apps and files, answers maths instantly (`sqrt 2 * 10`) and searches the web
- Quick settings: volume, brightness, night light, glass/animation toggles, accent colors
- Clock flyout with notification history and calendar; weather chip on the left

**Apps**

| App | Highlights |
|-----|-----------|
| **Files** | Sidebar, back/forward, breadcrumbs, icon & list views, image thumbnails, sorting, filter, multi-select (Ctrl/Shift), cut/copy/paste, rename, properties, Recycle Bin with restore |
| **AeroBrowser** | Chromium with GPU rasterization. Brave-style shields: EasyList + EasyPrivacy network blocking (auto-updated) and ad-placeholder hiding. Persistent sessions, history autocomplete, favicons, find in page, DevTools (F12), downloads panel, permission prompts, tab audio/mute, reopen closed tab, background-tab freezing, choice of DuckDuckGo / Brave Search / Google / Bing / Startpage |
| **Media Player** | Video and music through Qt Multimedia's FFmpeg backend (MP4, MKV, WebM, MOV, AVI, MP3, FLAC, OGG, WAV, M4A…). Live spectrum equalizer computed from the actual audio, music & video library, queue, shuffle/repeat, speed, full screen, keyboard control |
| **GlassPad** | Open/save anywhere, find & replace, word wrap, zoom, monospace mode, line/column, "save changes?" protection |
| ⌨️ **Terminal** | Sandboxed shell: `ls cd cat echo > mkdir mv cp rm tree find open`, tab completion, history, `neofetch`, `cowsay`, `matrix`, `accent pink`… |
| **Calculator** | Type or click, live answer preview, scientific functions, DEG/RAD, history (safe parser, no `eval`) |
| **Weather** | Search any city, hourly & 7-day forecast, °C/°F, Open-Meteo (no API key) |
| **Photos** | Gallery, zoom around the cursor, pan, rotate, next/previous, set as wallpaper |
| **Task Manager** | Open windows (switch / end task) and live CPU & memory graphs |
| **Snake** | The classic, with a best score |
| **Settings** | Wallpapers, accent color, glass, text size, sound, clock, browser, storage, about |

## ⌨️ Shortcuts

| Keys | Action |
|------|--------|
| `Ctrl+Space` | Start / search |
| `Alt+Tab` or ``Alt+` `` | Switch windows (keep tapping Tab; it commits on its own) |
| `Ctrl+Alt+← → ↑ ↓` | Snap left / right / quarters, maximize, restore/minimize |
| `Ctrl+Alt+1…4` / `Ctrl+Alt+Shift+1…4` | Switch workspace / move window to workspace |
| `Ctrl+Alt+V` | Clipboard history |
| `Print` / `Alt+Print` | Screenshot (screen / active window) |
| `F1` | All keyboard shortcuts |
| `Ctrl+Alt+W` | Close the active window |
| `Ctrl+Alt+T` / `Ctrl+Alt+E` | Terminal / Files |
| `Ctrl+Alt+D` | Show desktop |
| `Ctrl+Alt+L` | Lock |
| `F11` | Toggle full screen |
| `Ctrl+Q` | Shut down (warns about unsaved work) |

Your host OS may reserve some of these (for example `Alt+Tab` on Windows); the alternatives above work everywhere.

## Project layout

```
main.py                     entry point & command-line flags
core/                       Python backend (exposed to QML as context objects)
  storage.py                sandboxed file system, clipboard, Recycle Bin   → Storage
  settings.py               persisted settings + frosted wallpaper renderer → Prefs
  system.py                 info, live stats, power, crash sentinel         → System
  shell.py                  terminal engine                                 → Shell
  calc.py                   calculator engine                               → Calc
  weather_service.py        Open-Meteo client                               → WeatherService
  adblocker.py, adblock_rules.py  browser ad blocker                        → AdBlocker
qml/
  Main.qml                  shell + window manager
  ui/UI.qml                 design system singleton (colors, sizes, clock)
  components/               window, taskbar, start menu, desktop, controls…
  apps/                     one file per app
  js/Apps.js                app registry (add your own app here!)
Storage/User/               your files (Desktop, Documents, Pictures, …)
Storage/System/             settings & cache (created at first run)
tests/                      backend unit tests
tools/                      developer checks (see below)
```

### Adding an app
1. Create `qml/apps/MyApp.qml` with a `FocusScope` root that declares `property var hostWindow: null`.
2. Add an entry to `qml/js/Apps.js`.
   Optional hooks: `function canClose()`, `property bool hasUnsavedChanges`, `function handleArgs(props)`.

## AeroBrowser search & speed dial
- Type anything in the address bar or the new-tab search box and press Enter: addresses open, everything else is searched
- Live suggestions from your search engine (toggle in Shields & settings), plus matching history and bookmarks
- Speed dial shows real page previews (captured as you browse) with each site's favicon; add, rename, remove or reset tiles

## Code editing
- GlassPad highlights Python, JavaScript/TypeScript, QML, C/C++/C#/Java/Go/Rust, JSON, HTML/XML, CSS, shell, YAML/INI, Markdown and SQL, with line numbers, current-line highlight, 4-space Tab, auto-indent and Format JSON
- The Files details pane previews code with the same colors

## Weather & location
- Settings ▸ Weather & location: search for your city, see current conditions, and pick °C or °F (used everywhere)

## Accessibility
- **Bold text** (on by default) and four text sizes: Settings ▸ Accessibility

## Icons
All icons are SVGs generated by `tools/make_icons.py` in one consistent style (24-grid line glyphs,
gradient squircle app icons, glossy folders, color-banded file types, full-color weather). Add an entry
there and re-run it to extend the set.

## Troubleshooting
- If GlassOS ever closes unexpectedly, `Storage/System/crash.log` has the details - please include it in bug reports.
- AeroBrowser uses GPU rasterization by default. If a graphics driver misbehaves, start with
  `--software`, or set your own `QTWEBENGINE_CHROMIUM_FLAGS`.
- Run with `set GLASSOS_LOG=debug` (Windows) or `GLASSOS_LOG=debug python main.py` for detailed logs.
- Settings live in `Storage/System/settings.json`; delete it to reset everything (your files are untouched).
- Blank or flickering window in a VM / remote desktop: `python main.py --software`.

## Development checks

```bash
python -m unittest discover -s tests -v   # backend tests (needs PySide6)
node tools/qmlcheck.js .                  # QML static check (needs Node + `npm i -g typescript`)
python tools/aritycheck.py .              # QML → Python call signature check
```

`qmlcheck` parses every QML file, syntax-checks all JavaScript, resolves every identifier
(ids, properties, delegate roles, component scope) and verifies every call from QML into
the Python services exists.

## Privacy & safety
- Apps can only see `Storage/User`; paths that try to escape it are rejected.
- Saves are atomic, so a crash never leaves a half-written file.
- The browser uses an off-the-record profile (no cookies kept between sessions).
- The volume slider is cosmetic (GlassOS has no sound effects); **Mute** really mutes browser tabs.

## License
MIT. Wallpapers belong to their respective authors (Unsplash and others).
