"""
GlassOS Notepad (GlassPad) Application
A rich text editor with formatting capabilities.
"""

from typing import Dict, Any, Optional
from PySide6.QtCore import QObject, Signal, Slot, Property
from .base_app import BaseApp


class NotepadApp(BaseApp):
    """GlassPad - Rich text editor application."""
    
    contentChanged = Signal()
    filePathChanged = Signal()
    modifiedChanged = Signal()
    
    def __init__(self, window_id: str, vfs=None, parent=None):
        super().__init__(window_id, vfs, parent)
        self._title = "GlassPad"
        self._icon = "📝"
        self._content = ""
        self._file_path = ""
        self._is_modified = False
    
    @Property(str, notify=contentChanged)
    def content(self) -> str:
        return self._content
    
    @content.setter
    def content(self, value: str):
        if self._content != value:
            self._content = value
            self._is_modified = True
            self.contentChanged.emit()
            self.modifiedChanged.emit()
            self._update_title()
    
    @Property(str, notify=filePathChanged)
    def filePath(self) -> str:
        return self._file_path
    
    @Property(bool, notify=modifiedChanged)
    def isModified(self) -> bool:
        return self._is_modified
    
    def _update_title(self):
        """Update window title based on file state."""
        filename = self._file_path.split("/")[-1] if self._file_path else "Untitled"
        modified = "*" if self._is_modified else ""
        self.title = f"{modified}{filename} - GlassPad"
    
    @Slot(str)
    def setContent(self, content: str):
        """Set content from QML."""
        self.content = content
    
    @Slot(result=bool)
    def newFile(self) -> bool:
        """Create a new empty file."""
        if self._is_modified:
            # Would show save dialog in real implementation
            pass
        
        self._content = ""
        self._file_path = ""
        self._is_modified = False
        self.contentChanged.emit()
        self.filePathChanged.emit()
        self.modifiedChanged.emit()
        self._update_title()
        return True
    
    @Slot(str, result=bool)
    def openFile(self, path: str) -> bool:
        """Open a file from the VFS."""
        if not self._vfs:
            return False
        
        content = self._vfs.read_file(path)
        if content is not None:
            self._content = content
            self._file_path = path
            self._is_modified = False
            self.contentChanged.emit()
            self.filePathChanged.emit()
            self.modifiedChanged.emit()
            self._update_title()
            return True
        return False
    
    @Slot(result=bool)
    def save(self) -> bool:
        """Save the current file."""
        if not self._file_path:
            return False
        return self.saveAs(self._file_path)
    
    @Slot(str, result=bool)
    def saveAs(self, path: str) -> bool:
        """Save file to specified path."""
        if not self._vfs:
            return False
        
        if self._vfs.write_file(path, self._content):
            self._file_path = path
            self._is_modified = False
            self.filePathChanged.emit()
            self.modifiedChanged.emit()
            self._update_title()
            return True
        return False
    
    def onStart(self):
        """Initialize notepad."""
        self._update_title()
    
    def onStop(self):
        """Cleanup notepad."""
        pass
    
    def getQmlComponent(self) -> str:
        return "apps/Notepad.qml"
    
    def saveState(self) -> Dict[str, Any]:
        return {
            "content": self._content,
            "file_path": self._file_path,
            "is_modified": self._is_modified,
        }
    
    def restoreState(self, state: Dict[str, Any]):
        self._content = state.get("content", "")
        self._file_path = state.get("file_path", "")
        self._is_modified = state.get("is_modified", False)
        self.contentChanged.emit()
        self.filePathChanged.emit()
        self.modifiedChanged.emit()
        self._update_title()
