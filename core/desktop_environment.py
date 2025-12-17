"""
GlassOS Desktop Environment
Main container for the desktop, taskbar, and applications.
"""

import sys
from pathlib import Path
from typing import Dict, Any, Optional
from PySide6.QtWidgets import QMainWindow, QWidget, QVBoxLayout, QApplication
from PySide6.QtCore import Qt, QUrl, QObject, Signal, Slot, Property, QTimer
from PySide6.QtGui import QScreen, QColor, QIcon
from PySide6.QtQml import QQmlApplicationEngine, QQmlContext, qmlRegisterType

from .config import Config
from .vfs import VirtualFileSystem
from .window_manager import WindowManager


class ThemeProvider(QObject):
    """Provides theme properties to QML."""
    
    themeChanged = Signal()
    
    def __init__(self, config: Config, parent=None):
        super().__init__(parent)
        self._config = config
    
    @Property(int, notify=themeChanged)
    def blurRadius(self):
        return self._config.theme.blur_radius
    
    @Property(float, notify=themeChanged)
    def blurOpacity(self):
        return self._config.theme.blur_opacity
    
    @Property(str, notify=themeChanged)
    def glassTint(self):
        return self._config.theme.glass_tint
    
    @Property(float, notify=themeChanged)
    def glassTintOpacity(self):
        return self._config.theme.glass_tint_opacity
    
    @Property(str, notify=themeChanged)
    def accentColor(self):
        return self._config.theme.accent_color
    
    @Property(str, notify=themeChanged)
    def accentGlow(self):
        return self._config.theme.accent_glow
    
    @Property(str, notify=themeChanged)
    def highlightColor(self):
        return self._config.theme.highlight_color
    
    @Property(str, notify=themeChanged)
    def windowBorderColor(self):
        return self._config.theme.window_border_color
    
    @Property(float, notify=themeChanged)
    def windowBorderOpacity(self):
        return self._config.theme.window_border_opacity
    
    @Property(str, notify=themeChanged)
    def textPrimary(self):
        return self._config.theme.text_primary
    
    @Property(str, notify=themeChanged)
    def textSecondary(self):
        return self._config.theme.text_secondary
    
    @Property(str, notify=themeChanged)
    def textDisabled(self):
        return self._config.theme.text_disabled
    
    @Property(int, notify=themeChanged)
    def taskbarHeight(self):
        return self._config.theme.taskbar_height
    
    @Property(int, notify=themeChanged)
    def taskbarBlur(self):
        return self._config.theme.taskbar_blur
    
    @Property(str, notify=themeChanged)
    def taskbarTint(self):
        return self._config.theme.taskbar_tint
    
    @Property(float, notify=themeChanged)
    def taskbarOpacity(self):
        return self._config.theme.taskbar_opacity
    
    @Property(int, notify=themeChanged)
    def animationDuration(self):
        return self._config.system.animation_duration
    
    @Property(bool, notify=themeChanged)
    def enableAnimations(self):
        return self._config.system.enable_animations
    
    @Property(bool, notify=themeChanged)
    def enableBlur(self):
        return self._config.system.enable_blur


class SystemProvider(QObject):
    """Provides system functions to QML."""
    
    timeChanged = Signal()
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self._timer = QTimer(self)
        self._timer.timeout.connect(self._on_timer)
        self._timer.start(1000)  # Update every second
    
    def _on_timer(self):
        self.timeChanged.emit()
    
    @Property(str, notify=timeChanged)
    def currentTime(self):
        from datetime import datetime
        return datetime.now().strftime("%I:%M %p")
    
    @Property(str, notify=timeChanged)
    def currentDate(self):
        from datetime import datetime
        return datetime.now().strftime("%A, %B %d, %Y")
    
    @Property(str, notify=timeChanged)
    def shortDate(self):
        from datetime import datetime
        return datetime.now().strftime("%m/%d/%Y")
    
    @Slot(result=str)
    def getVersion(self):
        return "1.0.0"
    
    @Slot()
    def exitOS(self):
        QApplication.quit()


class VFSProvider(QObject):
    """Provides VFS access to QML."""
    
    def __init__(self, vfs: VirtualFileSystem, parent=None):
        super().__init__(parent)
        self._vfs = vfs
    
    @Slot(str, result=list)
    def listDirectory(self, path: str) -> list:
        nodes = self._vfs.list_directory(path)
        return [
            {
                "name": n.name,
                "path": n.path,
                "isDirectory": n.file_type.value == "directory",
                "size": n.size,
                "modified": n.modified,
            }
            for n in nodes
        ]
    
    @Slot(str, result=str)
    def readFile(self, path: str) -> str:
        content = self._vfs.read_file(path)
        return content if content else ""
    
    @Slot(str, str, result=bool)
    def writeFile(self, path: str, content: str) -> bool:
        return self._vfs.write_file(path, content)
    
    @Slot(str, result=bool)
    def createDirectory(self, path: str) -> bool:
        return self._vfs.create_directory(path)
    
    @Slot(str, result=bool)
    def delete(self, path: str) -> bool:
        return self._vfs.delete(path)
    
    @Slot(str, result=bool)
    def exists(self, path: str) -> bool:
        return self._vfs.exists(path)
    
    @Slot(str, str, result=list)
    def search(self, query: str, path: str = "/") -> list:
        nodes = self._vfs.search(query, path)
        return [
            {
                "name": n.name,
                "path": n.path,
                "isDirectory": n.file_type.value == "directory",
            }
            for n in nodes
        ]


class StorageProvider(QObject):
    """Provides real file system access to the Storage/User directory."""
    
    wallpaperChanged = Signal()
    
    def __init__(self, storage_root: Path, parent=None):
        super().__init__(parent)
        self._storage_root = storage_root
        self._current_wallpaper = ""
        self._settings_file = storage_root / ".glassos_settings.json"
        self._ensure_directories()
        self._load_settings()
    
    def _ensure_directories(self):
        """Ensure required directories exist."""
        dirs = [
            "Documents", "Pictures", "Pictures/Wallpapers", 
            "Downloads", "Videos", "Apps"
        ]
        for d in dirs:
            (self._storage_root / d).mkdir(parents=True, exist_ok=True)
    
    def _load_settings(self):
        """Load persisted settings."""
        try:
            if self._settings_file.exists():
                import json
                with open(self._settings_file, "r") as f:
                    data = json.load(f)
                saved_wp = data.get("wallpaper", "")
                if saved_wp and Path(saved_wp).exists():
                    self._current_wallpaper = saved_wp
                    print(f"🖼️ Loaded saved wallpaper: {saved_wp}")
        except Exception as e:
            print(f"⚠️ Could not load settings: {e}")
    
    def _save_settings(self):
        """Save settings to disk."""
        try:
            import json
            data = {
                "wallpaper": self._current_wallpaper
            }
            with open(self._settings_file, "w") as f:
                json.dump(data, f, indent=2)
        except Exception as e:
            print(f"⚠️ Could not save settings: {e}")
    
    def _get_real_path(self, vfs_path: str) -> Path:
        """Convert VFS path to real storage path."""
        # Remove leading slash and normalize
        clean_path = vfs_path.lstrip("/").replace("\\", "/")
        return self._storage_root / clean_path
    
    def _is_safe_path(self, path: Path) -> bool:
        """Check if path is within storage root."""
        try:
            path.resolve().relative_to(self._storage_root.resolve())
            return True
        except ValueError:
            return False
    
    @Property(str, notify=wallpaperChanged)
    def currentWallpaper(self):
        return self._current_wallpaper
    
    @Slot(str)
    def setWallpaper(self, path: str):
        """Set the current wallpaper and save to settings."""
        real_path = self._get_real_path(path)
        if real_path.exists() and self._is_safe_path(real_path):
            self._current_wallpaper = str(real_path).replace("\\", "/")
            self._save_settings()
            self.wallpaperChanged.emit()
            print(f"🖼️ Wallpaper set: {self._current_wallpaper}")
    
    @Slot(result=str)
    def getWallpaperUrl(self):
        """Get the wallpaper as a file URL for QML."""
        if self._current_wallpaper and Path(self._current_wallpaper).exists():
            return "file:///" + self._current_wallpaper
        return ""

    
    @Slot(str, result=list)
    def listDirectory(self, vfs_path: str) -> list:
        """List contents of a directory."""
        real_path = self._get_real_path(vfs_path)
        
        if not real_path.exists() or not self._is_safe_path(real_path):
            return []
        
        items = []
        try:
            for entry in real_path.iterdir():
                items.append({
                    "name": entry.name,
                    "path": "/" + str(entry.relative_to(self._storage_root)).replace("\\", "/"),
                    "isDirectory": entry.is_dir(),
                    "size": entry.stat().st_size if entry.is_file() else 0,
                    "isImage": entry.suffix.lower() in [".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp"],
                })
        except Exception as e:
            print(f"Error listing directory: {e}")
        
        return sorted(items, key=lambda x: (not x["isDirectory"], x["name"].lower()))
    
    @Slot(str, result=list)
    def getWallpapers(self) -> list:
        """Get list of available wallpapers."""
        wallpaper_dir = self._storage_root / "Pictures" / "Wallpapers"
        
        if not wallpaper_dir.exists():
            return []
        
        wallpapers = []
        try:
            for entry in wallpaper_dir.iterdir():
                if entry.is_file() and entry.suffix.lower() in [".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp"]:
                    wallpapers.append({
                        "name": entry.stem,
                        "path": "/" + str(entry.relative_to(self._storage_root)).replace("\\", "/"),
                        "url": "file:///" + str(entry).replace("\\", "/"),
                    })
        except Exception as e:
            print(f"Error getting wallpapers: {e}")
        
        return wallpapers
    
    @Slot(str, result=str)
    def readFile(self, vfs_path: str) -> str:
        """Read text content from a file."""
        real_path = self._get_real_path(vfs_path)
        
        if not real_path.exists() or not self._is_safe_path(real_path):
            return ""
        
        try:
            return real_path.read_text(encoding="utf-8")
        except Exception as e:
            print(f"Error reading file: {e}")
            return ""
    
    @Slot(str, str, result=bool)
    def writeFile(self, vfs_path: str, content: str) -> bool:
        """Write text content to a file."""
        real_path = self._get_real_path(vfs_path)
        
        if not self._is_safe_path(real_path):
            return False
        
        try:
            real_path.parent.mkdir(parents=True, exist_ok=True)
            real_path.write_text(content, encoding="utf-8")
            return True
        except Exception as e:
            print(f"Error writing file: {e}")
            return False
    
    @Slot(str, result=bool)
    def exists(self, vfs_path: str) -> bool:
        """Check if a path exists."""
        real_path = self._get_real_path(vfs_path)
        return real_path.exists() and self._is_safe_path(real_path)
    
    @Slot(str, result=str)
    def getFileUrl(self, vfs_path: str) -> str:
        """Get file URL for QML Image element."""
        real_path = self._get_real_path(vfs_path)
        if real_path.exists() and self._is_safe_path(real_path):
            return "file:///" + str(real_path).replace("\\", "/")
        return ""
    
    @Property(str)
    def storageRoot(self):
        return str(self._storage_root).replace("\\", "/")




class DesktopEnvironment(QObject):
    """
    Main Desktop Environment controller.
    Manages the QML engine and all desktop components.
    """
    
    def __init__(self, app: QApplication, config: Config, vfs: VirtualFileSystem):
        super().__init__()
        self.app = app
        self.config = config
        self.vfs = vfs
        
        # Get primary screen info
        screen = app.primaryScreen()
        screen_geometry = screen.availableGeometry()
        
        # Initialize managers
        self.window_manager = WindowManager(self)
        self.window_manager.set_screen_geometry(screen_geometry)
        self.window_manager.set_taskbar_height(config.theme.taskbar_height)
        self.window_manager.set_snap_threshold(config.system.snap_threshold)
        
        # Initialize providers for QML
        self.theme_provider = ThemeProvider(config, self)
        self.system_provider = SystemProvider(self)
        self.vfs_provider = VFSProvider(vfs, self)
        
        # Initialize storage provider for real file access
        storage_root = Path(__file__).parent.parent / "Storage" / "User"
        self.storage_provider = StorageProvider(storage_root, self)
        
        # Only auto-set wallpaper if no saved wallpaper exists
        if not self.storage_provider.currentWallpaper:
            wallpapers = self.storage_provider.getWallpapers()
            if wallpapers:
                self.storage_provider.setWallpaper(wallpapers[0]["path"])
        
        # Initialize QML engine
        self.engine = QQmlApplicationEngine()
        self._setup_qml_context()
        
        # Store screen info
        self._screen_width = screen_geometry.width()
        self._screen_height = screen_geometry.height()
    
    def _setup_qml_context(self):
        """Set up QML context properties."""
        context = self.engine.rootContext()
        
        # Expose providers to QML
        context.setContextProperty("Theme", self.theme_provider)
        context.setContextProperty("System", self.system_provider)
        context.setContextProperty("VFS", self.vfs_provider)
        context.setContextProperty("Storage", self.storage_provider)
        context.setContextProperty("WindowManager", self.window_manager)
        context.setContextProperty("Desktop", self)
        
        # Add import paths
        qml_path = Path(__file__).parent.parent / "qml"
        self.engine.addImportPath(str(qml_path))

    
    @Property(int)
    def screenWidth(self):
        return self._screen_width
    
    @Property(int)
    def screenHeight(self):
        return self._screen_height
    
    @Slot(str)
    def openApp(self, app_name: str):
        """Open an application by name."""
        print(f"🚀 Opening application: {app_name}")
        
        # Create window for the app
        window_id = self.window_manager.create_window(
            title=app_name,
            app_name=app_name,
            icon_path=f"assets/icons/{app_name.lower()}.png"
        )
        
        # TODO: Load the actual app QML component
        return window_id
    
    @Slot(str)
    def log(self, message: str):
        """Log a message from QML."""
        print(f"[QML] {message}")
    
    def show(self):
        """Load and show the desktop QML."""
        qml_path = Path(__file__).parent.parent / "qml" / "Main.qml"
        
        print(f"📄 Loading QML from: {qml_path}")
        
        if not qml_path.exists():
            print(f"❌ QML file not found: {qml_path}")
            sys.exit(-1)
        
        # Connect to warnings
        def on_warnings(warnings):
            for warning in warnings:
                print(f"⚠️  QML Warning: {warning.toString()}")
        
        self.engine.warnings.connect(on_warnings)
        
        # Load the QML
        self.engine.load(QUrl.fromLocalFile(str(qml_path)))
        
        if not self.engine.rootObjects():
            print("❌ Failed to load QML - check for syntax errors above")
            sys.exit(-1)
        
        print("✅ QML loaded successfully")
    
    def _create_qml_files(self):
        """Create QML files if they don't exist (fallback)."""
        # This is handled by the separate QML file creation
        pass
