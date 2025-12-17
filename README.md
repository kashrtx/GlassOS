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

### 🖥️ Window Management
- **Smart Snapping** - Snap windows to edges (half-screen, quarter-screen)
- **Frameless Windows** - Custom-decorated, draggable windows
- **Multitasking** - Run multiple applications simultaneously

### 📱 Built-in Applications
| App | Description |
|-----|-------------|
| 🌐 **AeroBrowser** | Full Chromium-based web browser |
| 📝 **GlassPad** | Rich text editor with formatting |
| 🌤️ **Weather** | Real-time weather with beautiful UI |
| 🧮 **Calculator** | Intuitive glass calculator |
| 📁 **AeroExplorer** | Fast file manager with VFS |

### ⚡ Performance
- **Mojo Integration** - Performance-critical modules in Mojo
- **Efficient VFS** - Virtual File System with fast indexing
- **Optimized Rendering** - Hardware-accelerated blur effects

---

## 🚀 Quick Start

### Prerequisites
- Python 3.10 or higher
- PySide6 6.6+
- Mojo (optional, for performance modules)

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/GlassOS.git
cd GlassOS

# Create virtual environment
python -m venv venv
venv\Scripts\activate  # Windows
# source venv/bin/activate  # Linux/macOS

# Install dependencies
pip install -r requirements.txt

# Run GlassOS
python main.py
```

---

## 🏗️ Architecture

```
GlassOS/
├── main.py                 # Entry point
├── core/                   # Core system modules
│   ├── window_manager.py   # Window management & snapping
│   ├── taskbar.py          # Taskbar component
│   ├── desktop.py          # Desktop environment
│   └── vfs.py              # Virtual File System
├── apps/                   # Built-in applications
│   ├── browser/            # AeroBrowser
│   ├── notepad/            # GlassPad
│   ├── weather/            # Weather app
│   ├── calculator/         # Glass Calculator
│   └── explorer/           # AeroExplorer
├── qml/                    # QML UI definitions
│   ├── theme/              # Glass Aero theme
│   ├── components/         # Reusable QML components
│   └── windows/            # Window templates
├── mojo/                   # Mojo performance modules
│   ├── vfs_indexer.mojo    # Fast VFS indexing
│   └── blur_engine.mojo    # Optimized blur calculations
├── assets/                 # Icons, images, fonts
└── vfs_data/               # Virtual file system storage
```

---

## 🎯 Technical Details

### Python + Mojo Stack
- **GUI Framework**: PySide6 (Qt for Python)
- **UI Language**: QML with JavaScript
- **Performance**: Mojo for compute-intensive tasks
- **Networking**: `requests` for API calls

### Glass Aero Theme
The theme uses advanced QML features:
- `GraphicalEffects` for blur and glow
- Custom shaders for reflections
- Gradient overlays for depth

---

## 📄 License

MIT License - See [LICENSE](LICENSE) for details.

---

<p align="center">
  <b>Made with 💎 by the GlassOS Team</b>
</p>
