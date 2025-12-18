"""
GlassOS Core: System Services
- Supervisor/Sentinel for crash handling
- App Registry for file associations
- Accessibility settings (safe presets only)
"""

import sys
import json
from pathlib import Path
from typing import Optional, Dict, Any, Callable
from PySide6.QtCore import QObject, Signal, Slot, Property, QTimer


class AccessibilitySettings(QObject):
    """System-wide accessibility settings with safe presets."""
    
    settingsChanged = Signal()
    
    def __init__(self, storage_root: Path):
        super().__init__()
        self._storage_root = storage_root
        self._settings_dir = storage_root / "Settings"
        self._settings_dir.mkdir(parents=True, exist_ok=True)
        self._settings_file = self._settings_dir / "accessibility.json"
        
        # Safe presets only (no dynamic scaling that causes crashes)
        self._font_size_preset = 1  # 0=Small, 1=Normal, 2=Large, 3=XLarge
        self._high_contrast = False
        self._bold_text = False
        
        self._load_settings()
    
    def _load_settings(self):
        try:
            if self._settings_file.exists():
                data = json.loads(self._settings_file.read_text())
                self._font_size_preset = data.get("fontSizePreset", 1)
                self._high_contrast = data.get("highContrast", False)
                self._bold_text = data.get("boldText", False)
                print(f"🔧 Accessibility: preset={self._font_size_preset}")
        except Exception as e:
            print(f"Error loading accessibility: {e}")
    
    def _save_settings(self):
        try:
            data = {
                "fontSizePreset": self._font_size_preset,
                "highContrast": self._high_contrast,
                "boldText": self._bold_text
            }
            self._settings_file.write_text(json.dumps(data, indent=2))
        except Exception as e:
            print(f"Error saving accessibility: {e}")
    
    @Property(int, notify=settingsChanged)
    def fontSizePreset(self) -> int:
        return self._font_size_preset
    
    @Slot(int)
    def setFontSizePreset(self, preset: int):
        preset = max(0, min(3, preset))
        if self._font_size_preset != preset:
            self._font_size_preset = preset
            self.settingsChanged.emit()
            self._save_settings()
    
    @Property(int, notify=settingsChanged)
    def baseFontSize(self) -> int:
        """Return fixed font size based on preset."""
        sizes = [10, 12, 14, 16]  # Small, Normal, Large, XLarge
        return sizes[self._font_size_preset]
    
    @Property(bool, notify=settingsChanged)
    def highContrast(self) -> bool:
        return self._high_contrast
    
    @Slot(bool)
    def setHighContrast(self, enabled: bool):
        if self._high_contrast != enabled:
            self._high_contrast = enabled
            self.settingsChanged.emit()
            self._save_settings()

    @Property(bool, notify=settingsChanged)
    def boldText(self) -> bool:
        return self._bold_text
    
    @Slot(bool)
    def setBoldText(self, enabled: bool):
        if self._bold_text != enabled:
            self._bold_text = enabled
            self.settingsChanged.emit()
            self._save_settings()


class FileAssociations(QObject):
    """File extension to application mapping."""
    
    def __init__(self):
        super().__init__()
        
        self._associations: Dict[str, Dict[str, Any]] = {
            # Text files -> All open in GlassPad (Notepad)
            ".txt": {"app": "GlassPad", "icon": "📝", "actions": ["open", "edit"]},
            ".md": {"app": "GlassPad", "icon": "📝", "actions": ["open", "edit"]},
            ".log": {"app": "GlassPad", "icon": "📄", "actions": ["open"]},
            ".ini": {"app": "GlassPad", "icon": "📋", "actions": ["open", "edit"]},
            ".cfg": {"app": "GlassPad", "icon": "📋", "actions": ["open", "edit"]},
            ".json": {"app": "GlassPad", "icon": "📋", "actions": ["open", "edit"]},
            ".xml": {"app": "GlassPad", "icon": "📋", "actions": ["open", "edit"]},
            ".yaml": {"app": "GlassPad", "icon": "📋", "actions": ["open", "edit"]},
            ".yml": {"app": "GlassPad", "icon": "📋", "actions": ["open", "edit"]},
            
            # Code files
            ".py": {"app": "GlassPad", "icon": "🐍", "actions": ["edit", "run"]},
            ".qml": {"app": "GlassPad", "icon": "📜", "actions": ["edit"]},
            ".html": {"app": "GlassPad", "icon": "🌐", "actions": ["open", "edit"]},
            ".css": {"app": "GlassPad", "icon": "🎨", "actions": ["edit"]},
            ".js": {"app": "GlassPad", "icon": "📜", "actions": ["edit"]},
            
            # Images
            ".jpg": {"app": "ImageViewer", "icon": "🖼", "actions": ["open", "wallpaper"]},
            ".jpeg": {"app": "ImageViewer", "icon": "🖼", "actions": ["open", "wallpaper"]},
            ".png": {"app": "ImageViewer", "icon": "🖼", "actions": ["open", "wallpaper"]},
            ".gif": {"app": "ImageViewer", "icon": "🖼", "actions": ["open"]},
            ".bmp": {"app": "ImageViewer", "icon": "🖼", "actions": ["open", "wallpaper"]},
            ".webp": {"app": "ImageViewer", "icon": "🖼", "actions": ["open", "wallpaper"]},
            
            # Media
            ".mp4": {"app": "MediaPlayer", "icon": "🎬", "actions": ["open"]},
            ".mp3": {"app": "MediaPlayer", "icon": "🎵", "actions": ["open"]},
            ".wav": {"app": "MediaPlayer", "icon": "🎵", "actions": ["open"]},
        }
    
    @Slot(str, result=str)
    def getAppForExtension(self, ext: str) -> str:
        ext = ext.lower() if ext.startswith(".") else f".{ext.lower()}"
        return self._associations.get(ext, {}).get("app", "GlassPad")
    
    @Slot(str, result=str)
    def getIconForExtension(self, ext: str) -> str:
        ext = ext.lower() if ext.startswith(".") else f".{ext.lower()}"
        return self._associations.get(ext, {}).get("icon", "📄")
    
    @Slot(str, result=bool)
    def isExecutable(self, ext: str) -> bool:
        ext = ext.lower() if ext.startswith(".") else f".{ext.lower()}"
        return "run" in self._associations.get(ext, {}).get("actions", [])
    
    @Slot(str, result=bool)
    def isImage(self, ext: str) -> bool:
        ext = ext.lower() if ext.startswith(".") else f".{ext.lower()}"
        return ext in [".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp"]
    
    @Slot(str, result=bool)
    def isTextFile(self, ext: str) -> bool:
        ext = ext.lower() if ext.startswith(".") else f".{ext.lower()}"
        text_exts = [".txt", ".md", ".log", ".ini", ".cfg", ".json", ".xml", 
                     ".yaml", ".yml", ".py", ".qml", ".html", ".css", ".js"]
        return ext in text_exts


class AppRegistry(QObject):
    """Registry of installed applications."""
    
    appInstalled = Signal(str)
    
    def __init__(self, storage_root: Path):
        super().__init__()
        self._storage_root = storage_root
        self._apps_dir = storage_root / "Apps"
        self._settings_dir = storage_root / "Settings"
        self._settings_dir.mkdir(parents=True, exist_ok=True)
        self._registry_file = self._settings_dir / "apps.json"
        self._apps_dir.mkdir(parents=True, exist_ok=True)
        
        self._builtin_apps = {
            "Calculator": {"icon": "🔢", "component": "Calculator"},
            "GlassPad": {"icon": "📝", "component": "Notepad"},
            "AeroExplorer": {"icon": "📁", "component": "Explorer"},
            "Weather": {"icon": "🌤", "component": "Weather"},
            "AeroBrowser": {"icon": "🌐", "component": "Browser"},
            "Settings": {"icon": "⚙", "component": "SettingsApp"},
            "ImageViewer": {"icon": "🖼", "component": "ImageViewer"},
        }
        
        self._sideloaded_apps: Dict[str, Dict] = {}
        self._load_registry()
    
    def _load_registry(self):
        try:
            if self._registry_file.exists():
                data = json.loads(self._registry_file.read_text())
                self._sideloaded_apps = data.get("sideloaded", {})
        except Exception as e:
            print(f"Error loading app registry: {e}")
    
    @Slot(result=list)
    def getInstalledApps(self) -> list:
        apps = []
        for name, info in self._builtin_apps.items():
            apps.append({"name": name, "icon": info["icon"], "builtin": True})
        return apps


class GlassSentinel(QObject):
    """Global exception handler to prevent OS crashes."""
    
    errorOccurred = Signal(str, str)
    
    _instance = None
    
    @classmethod
    def install(cls):
        cls._instance = cls()
        sys.excepthook = cls._instance._handle_exception
        print("🛡️ GlassSentinel active")
        return cls._instance
    
    def __init__(self):
        super().__init__()
        self._crash_log = []
    
    def _handle_exception(self, exc_type, exc_value, exc_traceback):
        import traceback
        
        error_text = "".join(traceback.format_exception(exc_type, exc_value, exc_traceback))
        
        print("\n" + "="*60)
        print("🛡️ GLASS SENTINEL - Exception Caught")
        print("="*60)
        print(error_text)
        print("="*60 + "\n")
        
        self._crash_log.append({
            "type": str(exc_type.__name__),
            "message": str(exc_value)
        })
        
        self.errorOccurred.emit(
            f"Error: {exc_type.__name__}",
            str(exc_value)
        )
    
    @Slot(result=list)
    def getCrashLog(self) -> list:
        return self._crash_log[-10:]


class ResourceMonitor(QObject):
    """System resource monitor."""
    
    updated = Signal()
    
    def __init__(self):
        super().__init__()
        self._cpu_percent = 0.0
        self._memory_percent = 0.0
        self._memory_used_gb = 0.0
        self._memory_total_gb = 0.0
        
        self._timer = QTimer(self)
        self._timer.timeout.connect(self._update)
        self._timer.start(3000)  # Every 3 seconds
        self._update()
    
    def _update(self):
        try:
            import psutil
            self._cpu_percent = psutil.cpu_percent(interval=None)
            mem = psutil.virtual_memory()
            self._memory_percent = mem.percent
            self._memory_used_gb = mem.used / (1024**3)
            self._memory_total_gb = mem.total / (1024**3)
            self.updated.emit()
        except ImportError:
            # psutil not installed - gracefully degrade
            pass
        except Exception as e:
            # Log but don't crash on monitoring failures
            print(f"⚠️ Resource monitoring error: {e}")
    
    @Property(float, notify=updated)
    def cpuPercent(self) -> float:
        return self._cpu_percent
    
    @Property(float, notify=updated)
    def memoryPercent(self) -> float:
        return self._memory_percent
    
    @Property(float, notify=updated)
    def memoryUsedGB(self) -> float:
        return round(self._memory_used_gb, 1)
    
    @Property(float, notify=updated)
    def memoryTotalGB(self) -> float:
        return round(self._memory_total_gb, 1)
