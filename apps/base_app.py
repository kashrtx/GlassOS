"""
GlassOS Base Application Class
All built-in apps inherit from this class.
"""

from abc import abstractmethod, ABCMeta
from typing import Optional, Dict, Any
from PySide6.QtCore import QObject, Signal, Slot, Property


class CombinedMeta(type(QObject), ABCMeta):
    """Metaclass that combines QObject and ABC metaclasses."""
    pass


class BaseApp(QObject, metaclass=CombinedMeta):
    """
    Base class for all GlassOS applications.
    Provides common interface for window management integration.
    """
    
    # Signals
    titleChanged = Signal(str)
    iconChanged = Signal(str)
    contentChanged = Signal()
    closeRequested = Signal()
    
    def __init__(self, window_id: str, vfs=None, parent=None):
        super().__init__(parent)
        self._window_id = window_id
        self._vfs = vfs
        self._title = "Application"
        self._icon = "🪟"
        self._is_running = False
    
    @Property(str, notify=titleChanged)
    def title(self) -> str:
        return self._title
    
    @title.setter
    def title(self, value: str):
        if self._title != value:
            self._title = value
            self.titleChanged.emit(value)
    
    @Property(str, notify=iconChanged)
    def icon(self) -> str:
        return self._icon
    
    @icon.setter
    def icon(self, value: str):
        if self._icon != value:
            self._icon = value
            self.iconChanged.emit(value)
    
    @Property(str)
    def windowId(self) -> str:
        return self._window_id
    
    @Property(bool)
    def isRunning(self) -> bool:
        return self._is_running
    
    @Slot()
    def start(self):
        """Start the application."""
        self._is_running = True
        self.onStart()
    
    @Slot()
    def stop(self):
        """Stop the application."""
        self.onStop()
        self._is_running = False
    
    @abstractmethod
    def onStart(self):
        """Called when the application starts. Override in subclass."""
        pass
    
    @abstractmethod
    def onStop(self):
        """Called when the application stops. Override in subclass."""
        pass
    
    @abstractmethod
    def getQmlComponent(self) -> str:
        """Return the path to the QML component for this app."""
        pass
    
    def saveState(self) -> Dict[str, Any]:
        """Save application state. Override for persistence."""
        return {}
    
    def restoreState(self, state: Dict[str, Any]):
        """Restore application state. Override for persistence."""
        pass
