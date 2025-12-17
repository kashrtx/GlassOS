# 🌟 GlassOS - Aero-Mojo Operating System Environment

<p align="center">
  <img src="assets/logo.png" alt="GlassOS Logo" width="200"/>
</p>

> **A stunning, high-performance desktop environment with a liquid glass aesthetic, built with Python + PySide6 + Mojo**

[![Python](https://img.shields.io/badge/Python-3.10+-blue.svg)](https://python.org)
[![PySide6](https://img.shields.io/badge/PySide6-6.6+-green.svg)](https://doc.qt.io/qtforpython/)
[![License](https://img.shields.io/badge/License-MIT-purple.svg)](LICENSE)

---

## ✨ Features

### 🎨 Glass Aero Aesthetic
- **Liquid Glass Effects** - Realistic translucent blur on all UI elements
- **Dynamic Reflections** - Light-responsive window frames and taskbar
- **Smooth Animations** - Buttery 60fps transitions throughout
- **Premium Dark Theme** - Modern dark glass aesthetic with blue accents

### 🖥️ Desktop Environment
- **Animated Wallpapers** - Custom wallpaper support with subtle animations
- **Desktop Icons** - Draggable icons with context menus
- **Recycle Bin** - Full delete/restore functionality
- **Windows 11-style Taskbar** - Running apps, system tray, and live clock

### 🪟 Window Management
- **Smart Snapping** - Snap windows to edges (half-screen, quarter-screen)
- **Frameless Windows** - Custom-decorated, draggable, resizable windows
- **Window Preview** - Hover taskbar icons for live window previews
- **Minimize/Maximize/Close** - Full window control support

### 📱 Built-in Applications

| App | Description |
|-----|-------------|
| 🌐 **AeroBrowser** | Full Chromium-based web browser with tabs, bookmarks, downloads, and **built-in ad blocker** |
| 📝 **GlassPad** | Rich text editor with formatting and file save/load |
| 🌤️ **Weather** | **Real-time weather** from Open-Meteo API with city search, 7-day forecast, UV index, sunrise/sunset |
| 🧮 **Calculator** | Intuitive glass calculator with history |
| 📁 **AeroExplorer** | Fast file manager with VFS, image preview, wallpaper setting |
| ⚙️ **Settings** | System settings including wallpaper, accessibility, personalization |
| 🖼️ **Image Viewer** | View images with zoom and set as wallpaper |

### 🛡️ Privacy & Security
- **Built-in Ad Blocker** - Blocks 100+ ad networks and trackers
- **Pattern-based Blocking** - Blocks tracking pixels and analytics
- **Whitelist Support** - Allow trusted domains
- **Real-time Counter** - See how many ads/trackers blocked

### 📅 System Widgets
- **Live Clock** - Real-time updating clock in taskbar
- **Calendar Popup** - Windows 11-style calendar with month navigation
- **Volume Control** - Popup slider for system volume
- **Network Status** - Connection indicator in system tray

### ⚡ Performance Optimizations
- **Threaded Rendering** - UI renders on separate thread for smoothness
- **Hardware Acceleration** - OpenGL-accelerated graphics
- **Multi-process Browser** - Chromium runs in separate processes
- **Elevated Priority** - Process runs at above-normal priority
- **Mojo Integration** - Performance-critical modules in Mojo

---

## 🚀 Quick Start

### Prerequisites
- **Python 3.10** or higher
- **PySide6 6.6+** (Qt for Python)
- **Internet connection** (for Weather app and browser)
- Mojo (optional, for performance modules)

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/GlassOS.git
cd GlassOS

# Create virtual environment (recommended)
python -m venv venv
venv\Scripts\activate          # Windows
# source venv/bin/activate     # Linux/macOS

# Install dependencies
pip install -r requirements.txt

# Run GlassOS
python main.py
```

### Running GlassOS

```bash
# Standard launch
python main.py

# The application will:
# 1. Initialize Qt WebEngine for browser support
# 2. Set up the Virtual File System
# 3. Load your saved wallpaper and settings
# 4. Display the full desktop environment
```

### Controls
| Action | Shortcut/Method |
|--------|-----------------|
| Open Start Menu | Click ⊞ button or press Windows key |
| Search Apps | Type in Start Menu search bar |
| Launch App | Click app icon in Start Menu |
| Close Window | Click ✕ or press Alt+F4 |
| Minimize Window | Click — button |
| Maximize Window | Click □ button |
| Show Desktop | Click far-right edge of taskbar |
| Open Calendar | Click clock in taskbar |
| Adjust Volume | Click speaker icon |
| Exit GlassOS | Press Ctrl+Q or click Power in Start Menu |

---

## 🏗️ Architecture

```
GlassOS/
├── main.py                     # Entry point with performance optimizations
├── requirements.txt            # Python dependencies
├── core/                       # Core system modules
│   ├── desktop_environment.py  # Main desktop controller
│   ├── vfs.py                  # Virtual File System
│   ├── storage.py              # Persistent storage provider
│   ├── adblocker.py            # Ad blocker with URL interception
│   ├── weather_service.py      # Real weather API integration
│   ├── accessibility.py        # Accessibility features
│   └── sentinel.py             # Error handling & recovery
├── qml/                        # QML UI definitions
│   ├── Main.qml                # Main desktop window
│   ├── apps/                   # Application UIs
│   │   ├── Browser.qml         # AeroBrowser
│   │   ├── Weather.qml         # Weather app
│   │   ├── Calculator.qml      # Calculator
│   │   ├── Notepad.qml         # GlassPad
│   │   ├── Explorer.qml        # File Explorer
│   │   └── Settings.qml        # Settings app
│   └── components/             # Reusable components
│       ├── Taskbar.qml         # Taskbar with calendar
│       ├── StartMenu.qml       # Start menu with search
│       ├── GlassWindow.qml     # Window frame component
│       ├── GlassButton.qml     # Glass-style buttons
│       └── Theme.qml           # Color theme definitions
├── mojo/                       # Mojo performance modules
│   └── vfs_indexer.mojo        # Fast file indexing
├── assets/                     # Icons, images, fonts
├── Storage/                    # User data storage
│   └── User/
│       ├── Pictures/Wallpapers/
│       ├── Documents/
│       └── Downloads/
└── vfs_data/                   # Virtual file system data
```

---

## 🎯 Technical Details

### Technology Stack
| Component | Technology |
|-----------|------------|
| GUI Framework | PySide6 (Qt 6 for Python) |
| UI Language | QML with JavaScript |
| Browser Engine | QtWebEngine (Chromium) |
| Weather API | Open-Meteo (free, no API key) |
| Performance | Mojo for compute-intensive tasks |
| Storage | SQLite-backed persistent storage |

### Key Features Implementation

#### 🛡️ Ad Blocker
- Uses `QWebEngineUrlRequestInterceptor` for real-time URL blocking
- Blocks 100+ known ad/tracker domains
- Pattern matching for tracking URLs
- Configurable whitelist

#### 🌤️ Weather Service
- Fetches from Open-Meteo Geocoding + Weather APIs
- City search with autocomplete
- 7-day forecast with precipitation and UV index
- Celsius/Fahrenheit toggle

#### 📅 Calendar Widget
- Full month calendar view
- Navigate between months
- Highlights current day
- "Go to Today" quick button

### Glass Aero Theme
The theme uses advanced QML features:
- Custom gradients for glass effect
- `Qt.rgba()` for translucency
- Smooth animations with `Behavior`
- Canvas for custom icons
- Blur overlays for depth

---

## 📋 Requirements

```
PySide6>=6.6.0
PySide6-Addons>=6.6.0
```

For browser functionality, you also need:
```
PySide6-WebEngine>=6.6.0
```

---

## 🐛 Troubleshooting

### Browser not working
Make sure you have `PySide6-WebEngine` installed:
```bash
pip install PySide6-WebEngine
```

### Weather not loading
The Weather app requires an internet connection. It uses the free Open-Meteo API which doesn't require an API key.

### Slow performance
GlassOS automatically enables performance optimizations, but you can also:
- Close unused applications
- Reduce the number of open windows
- Ensure hardware acceleration is available

---

## 📄 License

MIT License - See [LICENSE](LICENSE) for details.

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

<p align="center">
  <b>Made with 💎 by the GlassOS Team</b>
  <br>
  <i>Experience the future of desktop environments</i>
</p>
