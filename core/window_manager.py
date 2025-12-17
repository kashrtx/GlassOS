"""
GlassOS Window Manager
Handles window creation, management, snapping, and effects.
"""

from enum import Enum, auto
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Callable, Any
from PySide6.QtCore import QObject, Signal, Slot, QRect, QPoint, Property, QPropertyAnimation, QEasingCurve
from PySide6.QtWidgets import QWidget
from PySide6.QtGui import QScreen


class SnapZone(Enum):
    """Window snap zones."""
    NONE = auto()
    LEFT = auto()
    RIGHT = auto()
    TOP = auto()
    BOTTOM = auto()
    TOP_LEFT = auto()
    TOP_RIGHT = auto()
    BOTTOM_LEFT = auto()
    BOTTOM_RIGHT = auto()
    MAXIMIZE = auto()


@dataclass
class WindowState:
    """Stores the state of a managed window."""
    id: str
    title: str
    x: int = 100
    y: int = 100
    width: int = 800
    height: int = 600
    is_minimized: bool = False
    is_maximized: bool = False
    is_active: bool = False
    z_order: int = 0
    snap_zone: SnapZone = SnapZone.NONE
    restore_geometry: Optional[QRect] = None
    app_name: str = ""
    icon_path: str = ""
    
    def geometry(self) -> QRect:
        """Get window geometry as QRect."""
        return QRect(self.x, self.y, self.width, self.height)
    
    def set_geometry(self, rect: QRect):
        """Set window geometry from QRect."""
        self.x = rect.x()
        self.y = rect.y()
        self.width = rect.width()
        self.height = rect.height()


class WindowManager(QObject):
    """
    Manages all windows in GlassOS.
    Handles creation, positioning, snapping, and z-ordering.
    """
    
    # Signals
    windowCreated = Signal(str)  # window_id
    windowClosed = Signal(str)  # window_id
    windowActivated = Signal(str)  # window_id
    windowMoved = Signal(str, int, int)  # window_id, x, y
    windowResized = Signal(str, int, int)  # window_id, width, height
    windowMinimized = Signal(str)  # window_id
    windowMaximized = Signal(str)  # window_id
    windowRestored = Signal(str)  # window_id
    windowSnapped = Signal(str, str)  # window_id, snap_zone
    windowsChanged = Signal()  # General update signal
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self._windows: Dict[str, WindowState] = {}
        self._window_widgets: Dict[str, QWidget] = {}
        self._active_window: Optional[str] = None
        self._next_z_order = 0
        self._snap_threshold = 20
        self._screen_geometry: Optional[QRect] = None
        self._taskbar_height = 48
    
    def set_screen_geometry(self, geometry: QRect):
        """Set the available screen geometry."""
        self._screen_geometry = geometry
    
    def set_snap_threshold(self, threshold: int):
        """Set the snap detection threshold in pixels."""
        self._snap_threshold = threshold
    
    def set_taskbar_height(self, height: int):
        """Set the taskbar height for calculations."""
        self._taskbar_height = height
    
    @Property(list)
    def window_list(self) -> List[Dict[str, Any]]:
        """Get list of all windows for QML."""
        return [
            {
                "id": w.id,
                "title": w.title,
                "isMinimized": w.is_minimized,
                "isMaximized": w.is_maximized,
                "isActive": w.is_active,
                "appName": w.app_name,
                "iconPath": w.icon_path,
            }
            for w in sorted(self._windows.values(), key=lambda x: x.z_order)
        ]
    
    @Slot(str, str, str, str, result=str)
    def create_window(self, title: str, app_name: str = "", icon_path: str = "", 
                      window_id: str = None) -> str:
        """
        Create a new managed window.
        
        Args:
            title: Window title
            app_name: Application name
            icon_path: Path to window icon
            window_id: Custom window ID (auto-generated if None)
            
        Returns:
            The window ID
        """
        if window_id is None:
            window_id = f"window_{len(self._windows)}_{id(self)}"
        
        # Calculate initial position (cascade)
        offset = len(self._windows) * 30
        initial_x = 100 + offset
        initial_y = 100 + offset
        
        # Create window state
        state = WindowState(
            id=window_id,
            title=title,
            x=initial_x,
            y=initial_y,
            z_order=self._next_z_order,
            app_name=app_name,
            icon_path=icon_path,
        )
        self._next_z_order += 1
        
        self._windows[window_id] = state
        self.windowCreated.emit(window_id)
        self.windowsChanged.emit()
        
        # Auto-activate new window
        self.activate_window(window_id)
        
        return window_id
    
    @Slot(str)
    def close_window(self, window_id: str):
        """Close and remove a window."""
        if window_id in self._windows:
            del self._windows[window_id]
            
            if window_id in self._window_widgets:
                del self._window_widgets[window_id]
            
            if self._active_window == window_id:
                self._active_window = None
                # Activate the next window
                if self._windows:
                    next_window = max(self._windows.values(), key=lambda x: x.z_order)
                    self.activate_window(next_window.id)
            
            self.windowClosed.emit(window_id)
            self.windowsChanged.emit()
    
    @Slot(str)
    def activate_window(self, window_id: str):
        """Bring a window to the front and activate it."""
        if window_id not in self._windows:
            return
        
        # Deactivate current window
        if self._active_window and self._active_window in self._windows:
            self._windows[self._active_window].is_active = False
        
        # Activate new window
        window = self._windows[window_id]
        window.is_active = True
        window.z_order = self._next_z_order
        self._next_z_order += 1
        
        # Restore if minimized
        if window.is_minimized:
            window.is_minimized = False
            self.windowRestored.emit(window_id)
        
        self._active_window = window_id
        self.windowActivated.emit(window_id)
        self.windowsChanged.emit()
    
    @Slot(str, int, int)
    def move_window(self, window_id: str, x: int, y: int):
        """Move a window to a new position."""
        if window_id in self._windows:
            window = self._windows[window_id]
            window.x = x
            window.y = y
            self.windowMoved.emit(window_id, x, y)
    
    @Slot(str, int, int)
    def resize_window(self, window_id: str, width: int, height: int):
        """Resize a window."""
        if window_id in self._windows:
            window = self._windows[window_id]
            window.width = max(200, width)  # Minimum width
            window.height = max(150, height)  # Minimum height
            self.windowResized.emit(window_id, window.width, window.height)
    
    @Slot(str)
    def minimize_window(self, window_id: str):
        """Minimize a window."""
        if window_id in self._windows:
            window = self._windows[window_id]
            window.is_minimized = True
            
            # Activate next visible window
            if self._active_window == window_id:
                self._active_window = None
                visible_windows = [w for w in self._windows.values() if not w.is_minimized]
                if visible_windows:
                    next_window = max(visible_windows, key=lambda x: x.z_order)
                    self.activate_window(next_window.id)
            
            self.windowMinimized.emit(window_id)
            self.windowsChanged.emit()
    
    @Slot(str)
    def maximize_window(self, window_id: str):
        """Maximize a window."""
        if window_id not in self._windows or not self._screen_geometry:
            return
        
        window = self._windows[window_id]
        
        if window.is_maximized:
            # Restore
            if window.restore_geometry:
                window.set_geometry(window.restore_geometry)
            window.is_maximized = False
            window.snap_zone = SnapZone.NONE
            self.windowRestored.emit(window_id)
        else:
            # Save current geometry for restore
            window.restore_geometry = window.geometry()
            
            # Maximize
            available = self._get_available_geometry()
            window.set_geometry(available)
            window.is_maximized = True
            window.snap_zone = SnapZone.MAXIMIZE
            self.windowMaximized.emit(window_id)
        
        self.windowsChanged.emit()
    
    @Slot(str)
    def toggle_minimize(self, window_id: str):
        """Toggle window minimize state."""
        if window_id in self._windows:
            window = self._windows[window_id]
            if window.is_minimized:
                self.activate_window(window_id)
            else:
                if self._active_window == window_id:
                    self.minimize_window(window_id)
                else:
                    self.activate_window(window_id)
    
    def _get_available_geometry(self) -> QRect:
        """Get available screen geometry (excluding taskbar)."""
        if not self._screen_geometry:
            return QRect(0, 0, 1920, 1080 - self._taskbar_height)
        
        return QRect(
            self._screen_geometry.x(),
            self._screen_geometry.y(),
            self._screen_geometry.width(),
            self._screen_geometry.height() - self._taskbar_height
        )
    
    @Slot(str, int, int, result=str)
    def detect_snap_zone(self, window_id: str, x: int, y: int) -> str:
        """
        Detect which snap zone the window is being dragged to.
        
        Args:
            window_id: Window being dragged
            x: Current mouse X position
            y: Current mouse Y position
            
        Returns:
            SnapZone name as string
        """
        if not self._screen_geometry:
            return SnapZone.NONE.name
        
        available = self._get_available_geometry()
        threshold = self._snap_threshold
        
        at_left = x <= available.left() + threshold
        at_right = x >= available.right() - threshold
        at_top = y <= available.top() + threshold
        at_bottom = y >= available.bottom() - threshold
        
        # Corner detection
        if at_left and at_top:
            return SnapZone.TOP_LEFT.name
        if at_right and at_top:
            return SnapZone.TOP_RIGHT.name
        if at_left and at_bottom:
            return SnapZone.BOTTOM_LEFT.name
        if at_right and at_bottom:
            return SnapZone.BOTTOM_RIGHT.name
        
        # Edge detection
        if at_left:
            return SnapZone.LEFT.name
        if at_right:
            return SnapZone.RIGHT.name
        if at_top:
            return SnapZone.MAXIMIZE.name
        
        return SnapZone.NONE.name
    
    @Slot(str, str)
    def snap_window(self, window_id: str, zone_name: str):
        """
        Snap a window to the specified zone.
        
        Args:
            window_id: Window to snap
            zone_name: SnapZone name
        """
        if window_id not in self._windows or not self._screen_geometry:
            return
        
        window = self._windows[window_id]
        available = self._get_available_geometry()
        
        try:
            zone = SnapZone[zone_name]
        except KeyError:
            return
        
        if zone == SnapZone.NONE:
            return
        
        # Save restore geometry if not already snapped
        if window.snap_zone == SnapZone.NONE:
            window.restore_geometry = window.geometry()
        
        half_width = available.width() // 2
        half_height = available.height() // 2
        
        geometry_map = {
            SnapZone.LEFT: QRect(
                available.left(), available.top(),
                half_width, available.height()
            ),
            SnapZone.RIGHT: QRect(
                available.left() + half_width, available.top(),
                half_width, available.height()
            ),
            SnapZone.TOP: QRect(
                available.left(), available.top(),
                available.width(), half_height
            ),
            SnapZone.BOTTOM: QRect(
                available.left(), available.top() + half_height,
                available.width(), half_height
            ),
            SnapZone.TOP_LEFT: QRect(
                available.left(), available.top(),
                half_width, half_height
            ),
            SnapZone.TOP_RIGHT: QRect(
                available.left() + half_width, available.top(),
                half_width, half_height
            ),
            SnapZone.BOTTOM_LEFT: QRect(
                available.left(), available.top() + half_height,
                half_width, half_height
            ),
            SnapZone.BOTTOM_RIGHT: QRect(
                available.left() + half_width, available.top() + half_height,
                half_width, half_height
            ),
            SnapZone.MAXIMIZE: available,
        }
        
        if zone in geometry_map:
            window.set_geometry(geometry_map[zone])
            window.snap_zone = zone
            window.is_maximized = (zone == SnapZone.MAXIMIZE)
            self.windowSnapped.emit(window_id, zone_name)
            self.windowsChanged.emit()
    
    @Slot(str)
    def unsnap_window(self, window_id: str):
        """Remove window snap and restore previous geometry."""
        if window_id not in self._windows:
            return
        
        window = self._windows[window_id]
        
        if window.restore_geometry:
            window.set_geometry(window.restore_geometry)
        
        window.snap_zone = SnapZone.NONE
        window.is_maximized = False
        self.windowsChanged.emit()
    
    @Slot(str, result="QVariant")
    def get_window_state(self, window_id: str) -> Optional[Dict[str, Any]]:
        """Get the state of a window as a dictionary."""
        if window_id not in self._windows:
            return None
        
        window = self._windows[window_id]
        return {
            "id": window.id,
            "title": window.title,
            "x": window.x,
            "y": window.y,
            "width": window.width,
            "height": window.height,
            "isMinimized": window.is_minimized,
            "isMaximized": window.is_maximized,
            "isActive": window.is_active,
            "snapZone": window.snap_zone.name,
            "appName": window.app_name,
            "iconPath": window.icon_path,
        }
    
    @Slot(result=list)
    def get_all_windows(self) -> List[Dict[str, Any]]:
        """Get all window states."""
        return [
            self.get_window_state(wid)
            for wid in self._windows
        ]
    
    @Slot(result=str)
    def get_active_window_id(self) -> Optional[str]:
        """Get the ID of the currently active window."""
        return self._active_window
    
    def get_window_count(self) -> int:
        """Get the number of managed windows."""
        return len(self._windows)
    
    def register_widget(self, window_id: str, widget: QWidget):
        """Register a QWidget with a window ID."""
        self._window_widgets[window_id] = widget
    
    def get_widget(self, window_id: str) -> Optional[QWidget]:
        """Get the QWidget for a window ID."""
        return self._window_widgets.get(window_id)
