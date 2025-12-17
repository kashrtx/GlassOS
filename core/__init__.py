"""
GlassOS Core Package
Contains all core system modules.
"""

from .config import Config
from .vfs import VirtualFileSystem
from .desktop_environment import DesktopEnvironment
from .window_manager import WindowManager

__all__ = [
    "Config",
    "VirtualFileSystem", 
    "DesktopEnvironment",
    "WindowManager",
]
