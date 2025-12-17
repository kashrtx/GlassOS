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
    volumeChanged = Signal()
    volumeChanged = Signal()
    clipboardChanged = Signal()
    desktopUpdated = Signal()
    
    def __init__(self, storage_root: Path, parent=None):
        super().__init__(parent)
        self._storage_root = storage_root
        self._current_wallpaper = ""
        self._system_volume = 75
        self._desktop_icons = [] # List of {name, icon, app, x, y}
        
        self._settings_dir = storage_root / "Settings"
        self._settings_dir.mkdir(parents=True, exist_ok=True)
        self._settings_file = self._settings_dir / "system_settings.json"
        
        # Ensure Recycle Bin exists
        self._trash_dir = storage_root / "Recycle Bin"
        self._trash_dir.mkdir(parents=True, exist_ok=True)
        
        self._ensure_directories()
        self._load_settings()
    
    def _ensure_directories(self):
        """Ensure required directories exist."""
        dirs = [
            "Documents", "Pictures", "Pictures/Wallpapers", 
            "Downloads", "Videos", "Apps", "Settings", "Desktop", "Recycle Bin"
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
                self._system_volume = data.get("volume", 75)
                self._desktop_icons = data.get("desktop_icons", [])
                saved_wp = data.get("wallpaper", "")
                if saved_wp:
                    # Handle both absolute and relative paths
                    if Path(saved_wp).exists():
                        self._current_wallpaper = str(Path(saved_wp)).replace("\\", "/")
                    else:
                        # Try as relative path
                        real_path = self._storage_root / saved_wp.lstrip("/")
                        if real_path.exists():
                            self._current_wallpaper = str(real_path).replace("\\", "/")
                    if self._current_wallpaper:
                        print(f"🖼️ Loaded wallpaper: {self._current_wallpaper}")
        except Exception as e:
            print(f"⚠️ Could not load settings: {e}")
    
    def _save_settings(self):
        """Save settings to disk."""
        try:
            import json
            data = {
                "wallpaper": self._current_wallpaper,
                "volume": self._system_volume,
                "desktop_icons": self._desktop_icons
            }
            with open(self._settings_file, "w") as f:
                json.dump(data, f, indent=2)
        except Exception as e:
            print(f"⚠️ Could not save settings: {e}")
    
    def _get_real_path(self, vfs_path: str) -> Path:
        """Convert VFS path to real storage path."""
        # Handle "Trash" or "Recycle Bin" special paths
        if vfs_path.startswith("/Recycle Bin"):
             clean_path = vfs_path.lstrip("/")
        else:
             clean_path = vfs_path.lstrip("/").replace("\\", "/")
        return self._storage_root / clean_path
    
    def _is_safe_path(self, path: Path) -> bool:
        """Check if path is within storage root."""
        try:
            # Check if it's within storage root or trash root
            path.resolve().relative_to(self._storage_root.resolve())
            return True
        except ValueError:
            return False
    
    @Property(str, notify=wallpaperChanged)
    def currentWallpaper(self):
        return self._current_wallpaper
    
    @Property(str, notify=wallpaperChanged)
    def wallpaperUrl(self):
        """Get the wallpaper as a file URL for QML."""
        if self._current_wallpaper:
            wp_path = Path(self._current_wallpaper)
            if wp_path.exists():
                return "file:///" + str(wp_path).replace("\\", "/")
        return ""
    
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
        """Get the wallpaper as a file URL for QML (legacy Slot)."""
        return self.wallpaperUrl

    # Clipboard Functionality
    _clipboard_path = ""
    _clipboard_op = "" # "copy" or "cut"

    @Property(str, notify=clipboardChanged)
    def clipboardPath(self):
        return self._clipboard_path
    
    @Property(str, notify=clipboardChanged)
    def clipboardOp(self):
        return self._clipboard_op

    @Slot(str, str)
    def setClipboard(self, vfs_path: str, operation: str):
        """Set a path and operation to the system clipboard."""
        self._clipboard_path = vfs_path
        self._clipboard_op = operation
        self.clipboardChanged.emit()
        print(f"📋 Clipboard: {operation} {vfs_path}")

    @Slot(str, result=bool)
    def paste(self, target_dir_vfs: str) -> bool:
        """Paste the item from clipboard into the target directory."""
        if not self._clipboard_path:
            return False
            
        source_real = self._get_real_path(self._clipboard_path)
        target_dir_real = self._get_real_path(target_dir_vfs)
        
        if not source_real.exists() or not target_dir_real.is_dir():
            return False
            
        target_path = target_dir_real / source_real.name
        
        # Avoid overwriting
        if target_path.exists():
             import time
             target_path = target_dir_real / f"Copy_{int(time.time())}_{source_real.name}"
             
        try:
            import shutil
            if self._clipboard_op == "copy":
                if source_real.is_dir():
                    shutil.copytree(source_real, target_path)
                else:
                    shutil.copy2(source_real, target_path)
            elif self._clipboard_op == "cut":
                shutil.move(source_real, target_path)
                self._clipboard_path = "" # Clear clipboard after cut
                self._clipboard_op = ""
                self.clipboardChanged.emit()
                
            print(f"📋 Pasted to {target_dir_vfs}")
            return True
        except Exception as e:
            print(f"Error during paste: {e}")
            return False
    
    @Slot(result=str)
    def getClipboardPath(self):
        return self._clipboard_path

    @Slot(result=str)
    def getClipboardOp(self):
        return self._clipboard_op
    
    @Slot(result=str)
    def getWallpaperPath(self):
        """Get the raw wallpaper path for comparison."""
        return self._current_wallpaper

    @Slot(int)
    def setSystemVolume(self, volume: int):
        volume = max(0, min(100, volume))
        if self._system_volume != volume:
            self._system_volume = volume
            self._save_settings()
            self.volumeChanged.emit()
    
    @Slot(result=int)
    def getSystemVolume(self):
        return self._system_volume

    @Property(int, notify=volumeChanged)
    def systemVolume(self):
        return self._system_volume

    @Slot(result=list)
    def getDesktopIcons(self):
        """Get list of desktop icons, synced with actual filesystem."""
        
        # 1. Define Standard System Icons (Always present unless user hid them, but for now we enforce)
        system_icon_names = {"Computer", "Recycle Bin", "Documents", "Calculator", "AeroBrowser", "GlassPad"}
        
        # 2. Get real files on Desktop
        desktop_path = self._storage_root / "Desktop"
        real_files = set()
        if desktop_path.exists():
            for item in desktop_path.iterdir():
                if item.name.startswith(".") or item.name == "desktop.ini":
                    continue
                real_files.add(item.name)
        
        # 3. Filter existing saved icons (Remove deleted files)
        current_icons = []
        if self._desktop_icons:
            for icon in self._desktop_icons:
                name = icon.get("name", "")
                is_system = name in system_icon_names

                # Keep if it's a system icon OR if the file exists on disk
                if is_system or name in real_files:
                    current_icons.append(icon)
        
        # 4. Add new files found on disk (not in current_icons)
        existing_names = {icon["name"] for icon in current_icons}
        
        new_icons = []
        # Find next free spot calculation could be here, but simpler to just append
        # The QML side handles overlapping usually, or we just put them at (16, 16) and let user arrange
        for filename in real_files:
            if filename not in existing_names:
                is_dir = (desktop_path / filename).is_dir()
                new_icons.append({
                    "name": filename,
                    "icon": "📁" if is_dir else "📄",
                    "app": "AeroExplorer" if is_dir else "GlassPad",
                    "x": 16, # Default spot, let QML overlap handler fix it or user move it
                    "y": 16
                })
        
        # Merge
        final_icons = current_icons + new_icons
        
        # If completely empty (first run), add defaults
        if not final_icons and not self._desktop_icons:
             return [
                { "name": "Computer", "icon": "💻", "app": "AeroExplorer", "x": 16, "y": 16 },
                { "name": "Documents", "icon": "📄", "app": "AeroExplorer", "x": 16, "y": 104 },
                { "name": "AeroBrowser", "icon": "🌐", "app": "AeroBrowser", "x": 16, "y": 192 },
                { "name": "GlassPad", "icon": "📝", "app": "GlassPad", "x": 16, "y": 280 },
                { "name": "Calculator", "icon": "🧮", "app": "Calculator", "x": 16, "y": 368 },
                { "name": "Recycle Bin", "icon": "🗑", "app": "RecycleBin", "x": 16, "y": 456 }
            ]
            
        self._desktop_icons = final_icons
        return self._desktop_icons

    @Slot(list)
    def saveDesktopIcons(self, icons_list):
        """Save desktop icons and positions."""
        self._desktop_icons = icons_list
        self._save_settings()

    @Slot(str, result=bool)
    def moveToTrash(self, vfs_path: str) -> bool:
        """Move an item to the Recycle Bin."""
        real_path = self._get_real_path(vfs_path)
        if not real_path.exists() or not self._is_safe_path(real_path):
            return False
            
        try:
            # Create unique name in trash to avoid collisions
            import time
            trash_name = f"{int(time.time())}_{real_path.name}"
            target_path = self._trash_dir / trash_name
            
            # Save metadata (original path)
            metadata = {
                "original_path": vfs_path,
                "deleted_at": time.time(),
                "trash_name": trash_name
            }
            meta_file = self._trash_dir / f"{trash_name}.json"
            import json
            with open(meta_file, "w") as f:
                json.dump(metadata, f)
            
            real_path.rename(target_path)
            print(f"🗑 Moved to Trash: {vfs_path} -> {trash_name}")
            
            # Emit signal if we touched the desktop
            if "/Desktop/" in vfs_path or vfs_path == "/Desktop":
                 self.desktopUpdated.emit()
                 
            return True
        except Exception as e:
            print(f"Error moving to trash: {e}")
            return False

    @Slot(str, result=bool)
    def restoreFromTrash(self, trash_name: str) -> bool:
        """Restore an item from the Recycle Bin."""
        trash_item = self._trash_dir / trash_name
        meta_file = self._trash_dir / f"{trash_name}.json"
        
        if not trash_item.exists() or not meta_file.exists():
            return False
            
        try:
            import json
            with open(meta_file, "r") as f:
                metadata = json.load(f)
            
            original_path = metadata["original_path"]
            target_path = self._get_real_path(original_path)
            
            # Ensure parent exists
            target_path.parent.mkdir(parents=True, exist_ok=True)
            
            # If target exists, find a new name
            if target_path.exists():
                target_path = target_path.parent / f"Restored_{target_path.name}"
                
            trash_item.rename(target_path)
            meta_file.unlink()
            print(f"♻ Restored from Trash: {trash_name} -> {target_path}")
            return True
        except Exception as e:
            print(f"Error restoring from trash: {e}")
            return False

    @Slot(result=bool)
    def emptyTrash(self) -> bool:
        """Permanently delete everything in the Recycle Bin."""
        try:
            import shutil
            for item in self._trash_dir.iterdir():
                if item.is_dir():
                    shutil.rmtree(item)
                else:
                    item.unlink()
            print("🧹 Recycle Bin emptied")
            return True
        except Exception as e:
            print(f"Error emptying trash: {e}")
            return False

    @Slot(str, result=list)
    def listDirectory(self, vfs_path: str) -> list:
        """List contents of a directory."""
        real_path = self._get_real_path(vfs_path)
        
        if not real_path.exists() or not self._is_safe_path(real_path):
            return []
        
        items = []
        try:
            for entry in real_path.iterdir():
                if entry.name.endswith(".json") and vfs_path == "/Recycle Bin":
                     continue # Skip metadata files in Recycle Bin view
                     
                items.append({
                    "name": entry.name,
                    "path": "/" + str(entry.relative_to(self._storage_root)).replace("\\", "/"),
                    "isDirectory": entry.is_dir(),
                    "size": entry.stat().st_size if entry.is_file() else 0,
                    "isImage": entry.suffix.lower() in [".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp"],
                    "trashName": entry.name if vfs_path == "/Recycle Bin" else ""
                })
        except Exception as e:
            print(f"Error listing directory: {e}")
        
        return sorted(items, key=lambda x: (not x["isDirectory"], x["name"].lower()))
    
    @Slot(result=list)
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
            if "/Desktop/" in vfs_path:
                self.desktopUpdated.emit()
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
    
    @Slot(str, result=bool)
    def createDirectory(self, vfs_path: str) -> bool:
        """Create a new directory."""
        real_path = self._get_real_path(vfs_path)
        
        if not self._is_safe_path(real_path):
            return False
        
        try:
            real_path.mkdir(parents=True, exist_ok=True)
            print(f"📁 Created directory: {vfs_path}")
            if "/Desktop/" in vfs_path:
                self.desktopUpdated.emit()
            return True
        except Exception as e:
            print(f"Error creating directory: {e}")
            return False
    
    @Slot(str, result=bool)
    def deleteItem(self, vfs_path: str) -> bool:
        """Permanently delete a file or directory."""
        real_path = self._get_real_path(vfs_path)
        
        if not real_path.exists() or not self._is_safe_path(real_path):
            return False
        
        try:
            if real_path.is_dir():
                import shutil
                shutil.rmtree(real_path)
            else:
                real_path.unlink()
            print(f"🗑 Permanently Deleted: {vfs_path}")
            if "/Desktop/" in vfs_path:
                self.desktopUpdated.emit()
            return True
        except Exception as e:
            print(f"Error deleting item: {e}")
            return False
    
    @Slot(str, str, result=bool)
    def renameItem(self, vfs_path: str, new_name: str) -> bool:
        """Rename a file or directory."""
        real_path = self._get_real_path(vfs_path)
        
        if not real_path.exists() or not self._is_safe_path(real_path):
            return False
            
        try:
            new_path = real_path.parent / new_name
            
            real_path.rename(new_path)
            print(f"✏ Renamed: {real_path.name} -> {new_name}")
            if "/Desktop/" in vfs_path:
                self.desktopUpdated.emit()
            return True
        except Exception as e:
            print(f"Error renaming item: {e}")
            return False
    
    @Slot(str, str, result=bool)
    def moveItem(self, source_vfs: str, dest_dir_vfs: str) -> bool:
        """Move a file or directory to a different directory."""
        source_real = self._get_real_path(source_vfs)
        dest_dir_real = self._get_real_path(dest_dir_vfs)
        
        if not source_real.exists() or not dest_dir_real.is_dir():
            return False
            
        if not self._is_safe_path(source_real) or not self._is_safe_path(dest_dir_real):
            return False
            
        try:
            target_path = dest_dir_real / source_real.name
            if target_path.exists():
                import time
                target_path = dest_dir_real / f"Moved_{int(time.time())}_{source_real.name}"
                
            import shutil
            shutil.move(str(source_real), str(target_path))
            print(f"📦 Moved: {source_vfs} -> {dest_dir_vfs}")
            
            # Check if source or dest is desktop to signal update
            if "/Desktop/" in source_vfs or "/Desktop/" in dest_dir_vfs:
                self.desktopUpdated.emit()
                
            return True
        except Exception as e:
            print(f"Error moving item: {e}")
            return False
    
    @Slot(result=str)
    def getSystemInfo(self) -> str:
        """Get system information as JSON string."""
        import platform
        import json
        
        try:
            import psutil
            cpu_percent = psutil.cpu_percent(interval=0.1)
            memory = psutil.virtual_memory()
            disk = psutil.disk_usage(str(self._storage_root))
            
            info = {
                "cpu": {
                    "name": platform.processor() or "Unknown",
                    "cores": psutil.cpu_count(),
                    "usage": cpu_percent
                },
                "memory": {
                    "total": round(memory.total / (1024**3), 1),  # GB
                    "used": round(memory.used / (1024**3), 1),
                    "percent": memory.percent
                },
                "storage": {
                    "total": round(disk.total / (1024**3), 1),
                    "used": round(disk.used / (1024**3), 1),
                    "percent": disk.percent
                },
                "os": platform.system() + " " + platform.release(),
                "python": platform.python_version()
            }
            return json.dumps(info)
        except ImportError:
            return json.dumps({
                "cpu": {"name": platform.processor() or "Unknown", "cores": 0, "usage": 0},
                "memory": {"total": 0, "used": 0, "percent": 0},
                "storage": {"total": 0, "used": 0, "percent": 0},
                "os": platform.system() + " " + platform.release(),
                "python": platform.python_version()
            })
        except Exception as e:
            print(f"Error getting system info: {e}")
            return "{}"


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
        
        # Initialize system services
        from .system_services import (
            AccessibilitySettings, FileAssociations, AppRegistry, 
            GlassSentinel, ResourceMonitor
        )
        
        self.accessibility = AccessibilitySettings(storage_root)
        self.file_associations = FileAssociations()
        self.app_registry = AppRegistry(storage_root)
        self.resource_monitor = ResourceMonitor()
        
        # Install Sentinel (global exception handler)
        self.sentinel = GlassSentinel.install()
        
        # Initialize AdBlocker for web browsing
        try:
            from .adblocker import AdBlockerProvider
            from PySide6.QtWebEngineCore import QWebEngineProfile
            
            self.adblocker = AdBlockerProvider(self)
            # Install on default profile
            default_profile = QWebEngineProfile.defaultProfile()
            self.adblocker.install_on_profile(default_profile)
        except ImportError as e:
            print(f"⚠️ AdBlocker not available: {e}")
            self.adblocker = None
        
        # Initialize Weather Service
        try:
            from .weather_service import WeatherProvider
            self.weather_provider = WeatherProvider(self)
            print("🌤️ Weather service initialized")
        except ImportError as e:
            print(f"⚠️ Weather service not available: {e}")
            self.weather_provider = None
        
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
        
        # Core providers
        context.setContextProperty("Theme", self.theme_provider)
        context.setContextProperty("System", self.system_provider)
        context.setContextProperty("VFS", self.vfs_provider)
        context.setContextProperty("Storage", self.storage_provider)
        context.setContextProperty("WindowManager", self.window_manager)
        context.setContextProperty("Desktop", self)
        
        # System services
        context.setContextProperty("Accessibility", self.accessibility)
        context.setContextProperty("FileAssoc", self.file_associations)
        context.setContextProperty("AppRegistry", self.app_registry)
        context.setContextProperty("Sentinel", self.sentinel)
        context.setContextProperty("ResourceMonitor", self.resource_monitor)
        
        # Browser services
        if self.adblocker:
            context.setContextProperty("AdBlocker", self.adblocker)
        
        # Weather service
        if self.weather_provider:
            context.setContextProperty("WeatherService", self.weather_provider)
        
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
