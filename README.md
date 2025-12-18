<div align="center">

# 🖥️ GlassOS

### A Modern Desktop Environment Built with Python & Qt

![Python](https://img.shields.io/badge/Python-3.10+-blue?logo=python&logoColor=white)
![Qt](https://img.shields.io/badge/Qt-6.x-green?logo=qt&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-yellow)
![Status](https://img.shields.io/badge/Status-Beta-orange)
![Views](https://api.visitorbadge.io/api/combined?path=KashRTX.GlassOS&labelColor=%23555555&countColor=%232631ef&style=flat)


*A lightweight, customizable desktop environment inspired by modern operating systems*

</div>

---

## ⚠️ Important Notice

> **This is beta software.** GlassOS is a demonstration project and proof-of-concept. It is not intended for production use and may contain bugs, incomplete features, or unexpected behavior. This project serves as an educational example of building a desktop environment using Python and QML.

---

## 📖 What is GlassOS?

GlassOS is a desktop environment simulation built entirely in Python using PySide6 (Qt for Python). It provides a Windows-inspired user interface with a modern, glass-like aesthetic.

The goal of this project is to demonstrate that it's possible to create a functional, visually appealing desktop environment using Python — making it accessible for learning, experimentation, and customization.

### ✨ Key Features

| Feature | Description |
|---------|-------------|
| 🪟 **Window Management** | Draggable, resizable windows with minimize, maximize, and close |
| 📁 **File Explorer** | Browse files with grid/details view, multi-select, and context menus |
| 📝 **Notepad** | Simple text editor with file operations |
| 🧮 **Calculator** | Scientific calculator with expression parsing and history |
| 🌤️ **Weather App** | Real-time weather data with city search and persistence |
| 🌐 **Web Browser** | Basic web browsing with tabs |
| ⚙️ **Settings** | Customize themes, wallpapers, and preferences |
| 🗑️ **Recycle Bin** | Delete and restore files |
| 🖼️ **Desktop Icons** | Drag-and-drop desktop with customizable icons |

---

## 🚀 Getting Started

### Prerequisites

- **Python 3.10** or higher
- **pip** (Python package manager)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/GlassOS.git
   cd GlassOS
   ```

2. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```
   
   Or install manually:
   ```bash
   pip install PySide6 requests
   ```

3. **Run GlassOS**
   ```bash
   python main.py
   ```

That's it! GlassOS should launch in a window.

---

## 📂 Project Structure

```
GlassOS/
├── main.py                 # Entry point - starts the application
├── requirements.txt        # Python dependencies
├── LICENSE                 # MIT License
│
├── core/                   # Core Python modules
│   ├── desktop_environment.py   # Main desktop logic
│   ├── window_manager.py        # Window management
│   ├── storage_manager.py       # Virtual file system
│   ├── weather_service.py       # Weather API integration
│   └── ...
│
├── qml/                    # User interface (QML files)
│   ├── Main.qml            # Main window layout
│   ├── apps/               # Application UIs
│   │   ├── Explorer.qml    # File Explorer
│   │   ├── Calculator.qml  # Calculator
│   │   ├── Weather.qml     # Weather app
│   │   ├── Notepad.qml     # Text editor
│   │   └── ...
│   └── components/         # Reusable UI components
│
├── assets/                 # Icons, images, and resources
│
└── Storage/                # Virtual file system data
    ├── User/               # User files (Documents, Pictures, etc.)
    └── Settings/           # App settings and preferences
```

---

## 🎮 How to Use

### Launching Apps
- **Double-click** a desktop icon to open an app
- Use the **taskbar** at the bottom to switch between open windows

### File Explorer
- Navigate folders by clicking in the sidebar or breadcrumb path
- **Right-click** for context menu (Cut, Copy, Paste, Delete, Rename)
- Use **Ctrl+Click** or **checkboxes** to select multiple files
- Toggle between **Grid** and **Details** view

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+C` | Copy |
| `Ctrl+X` | Cut |
| `Ctrl+V` | Paste |
| `Ctrl+A` | Select All |
| `Delete` | Move to Recycle Bin |
| `F5` | Refresh |
| `Ctrl+Q` | Exit GlassOS |

---

## 🛠️ Configuration

### Changing Wallpaper
1. Open **Settings** from the desktop
2. Go to the **Wallpaper** section
3. Select a new wallpaper or add your own

### Weather Location
1. Open the **Weather** app
2. Click the search icon (🔍)
3. Type a city name and select from results
4. Your selection is saved automatically

---

## 🤝 Contributing

Contributions are welcome! This project is open for anyone to improve.

### How to Contribute

1. **Fork** the repository
2. **Create a branch** for your feature or fix
   ```bash
   git checkout -b feature/my-new-feature
   ```
3. **Make your changes**
4. **Test** your changes thoroughly
5. **Commit** with a clear message
   ```bash
   git commit -m "Add: Description of your changes"
   ```
6. **Push** to your fork
   ```bash
   git push origin feature/my-new-feature
   ```
7. **Open a Pull Request**

### Ideas for Contributions

- 🐛 Bug fixes
- 🎨 UI/UX improvements
- 📱 New applications
- 🔧 Performance optimizations
- 📚 Documentation improvements
- 🌍 Translations

---

## ⚠️ Known Limitations

Since this is a beta project built for demonstration purposes:

- This is **not a real operating system** — it runs as a Python application
- Some features may be incomplete or have bugs
- Performance may vary depending on your system
- The virtual file system is separate from your actual files
- Internet connection required for Weather app

---

## 📜 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

You are free to:
- ✅ Use this code for any purpose
- ✅ Modify and customize it
- ✅ Distribute your own versions
- ✅ Use it in commercial projects

---

## 🙏 Acknowledgments

- Inspired by **Windows 11** and modern desktop environments
- Built with [PySide6](https://wiki.qt.io/Qt_for_Python) (Qt for Python)
- Weather data from [Open-Meteo](https://open-meteo.com/) (free, no API key needed)

---

## 📧 Contact

If you have questions, suggestions, or just want to say hi:

- Open an **Issue** on GitHub
- Submit a **Pull Request** with improvements

---

<div align="center">

**Made with ❤️ and Python**

*GlassOS is a learning project — not perfect, but hopefully useful!*

</div>
