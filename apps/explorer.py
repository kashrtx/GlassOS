"""
GlassOS File Explorer (AeroExplorer) Application
File manager with VFS integration.
"""

from typing import Dict, Any, List, Optional
from PySide6.QtCore import QObject, Signal, Slot, Property
from .base_app import BaseApp


class ExplorerApp(BaseApp):
    """AeroExplorer - File manager application."""
    
    currentPathChanged = Signal()
    itemsChanged = Signal()
    selectionChanged = Signal()
    viewModeChanged = Signal()
    
    def __init__(self, window_id: str, vfs=None, parent=None):
        super().__init__(window_id, vfs, parent)
        self._title = "AeroExplorer"
        self._icon = "📁"
        self._current_path = "/"
        self._items = []
        self._selected_items = []
        self._view_mode = "grid"  # "grid" or "list"
        self._history = ["/"]
        self._history_index = 0
    
    @Property(str, notify=currentPathChanged)
    def currentPath(self) -> str:
        return self._current_path
    
    @currentPath.setter
    def currentPath(self, value: str):
        if self._current_path != value:
            self._current_path = value
            self.currentPathChanged.emit()
            self._refresh_items()
            self._update_title()
    
    @Property(list, notify=itemsChanged)
    def items(self) -> List[Dict[str, Any]]:
        return self._items
    
    @Property(list, notify=selectionChanged)
    def selectedItems(self) -> List[str]:
        return self._selected_items
    
    @Property(str, notify=viewModeChanged)
    def viewMode(self) -> str:
        return self._view_mode
    
    @viewMode.setter
    def viewMode(self, value: str):
        if self._view_mode != value:
            self._view_mode = value
            self.viewModeChanged.emit()
    
    @Property(bool)
    def canGoBack(self) -> bool:
        return self._history_index > 0
    
    @Property(bool)
    def canGoForward(self) -> bool:
        return self._history_index < len(self._history) - 1
    
    def _update_title(self):
        """Update window title based on current path."""
        folder_name = self._current_path.split("/")[-1] or "Root"
        self.title = f"{folder_name} - AeroExplorer"
    
    def _refresh_items(self):
        """Refresh the items list from VFS."""
        if not self._vfs:
            return
        
        nodes = self._vfs.list_directory(self._current_path)
        self._items = []
        
        for node in sorted(nodes, key=lambda x: (x.file_type.value != "directory", x.name.lower())):
            item = {
                "name": node.name,
                "path": node.path,
                "isDirectory": node.file_type.value == "directory",
                "size": self._format_size(node.size),
                "sizeBytes": node.size,
                "modified": node.modified,
                "icon": self._get_icon(node),
            }
            self._items.append(item)
        
        self.itemsChanged.emit()
    
    def _format_size(self, size: int) -> str:
        """Format file size to human-readable string."""
        if size < 1024:
            return f"{size} B"
        elif size < 1024 * 1024:
            return f"{size / 1024:.1f} KB"
        elif size < 1024 * 1024 * 1024:
            return f"{size / (1024 * 1024):.1f} MB"
        else:
            return f"{size / (1024 * 1024 * 1024):.1f} GB"
    
    def _get_icon(self, node) -> str:
        """Get emoji icon for file type."""
        if node.file_type.value == "directory":
            return "📁"
        
        name = node.name.lower()
        if name.endswith((".txt", ".md", ".doc", ".docx")):
            return "📄"
        elif name.endswith((".jpg", ".jpeg", ".png", ".gif", ".bmp")):
            return "🖼️"
        elif name.endswith((".mp3", ".wav", ".ogg", ".flac")):
            return "🎵"
        elif name.endswith((".mp4", ".avi", ".mkv", ".mov")):
            return "🎬"
        elif name.endswith((".py", ".js", ".html", ".css")):
            return "💻"
        elif name.endswith((".zip", ".rar", ".7z", ".tar")):
            return "📦"
        else:
            return "📄"
    
    @Slot(str)
    def navigateTo(self, path: str):
        """Navigate to a directory."""
        if not self._vfs:
            return
        
        if self._vfs.is_directory(path):
            # Add to history
            self._history = self._history[:self._history_index + 1]
            self._history.append(path)
            self._history_index = len(self._history) - 1
            
            self.currentPath = path
    
    @Slot()
    def goBack(self):
        """Go back in history."""
        if self.canGoBack:
            self._history_index -= 1
            self.currentPath = self._history[self._history_index]
    
    @Slot()
    def goForward(self):
        """Go forward in history."""
        if self.canGoForward:
            self._history_index += 1
            self.currentPath = self._history[self._history_index]
    
    @Slot()
    def goUp(self):
        """Navigate to parent directory."""
        if self._current_path != "/":
            parent = "/".join(self._current_path.split("/")[:-1]) or "/"
            self.navigateTo(parent)
    
    @Slot(str)
    def openItem(self, path: str):
        """Open a file or directory."""
        if not self._vfs:
            return
        
        if self._vfs.is_directory(path):
            self.navigateTo(path)
        else:
            # Would open with appropriate app
            pass
    
    @Slot(str)
    def selectItem(self, path: str):
        """Toggle selection of an item."""
        if path in self._selected_items:
            self._selected_items.remove(path)
        else:
            self._selected_items.append(path)
        self.selectionChanged.emit()
    
    @Slot()
    def selectAll(self):
        """Select all items."""
        self._selected_items = [item["path"] for item in self._items]
        self.selectionChanged.emit()
    
    @Slot()
    def clearSelection(self):
        """Clear selection."""
        self._selected_items = []
        self.selectionChanged.emit()
    
    @Slot(str, result=bool)
    def createFolder(self, name: str) -> bool:
        """Create a new folder."""
        if not self._vfs:
            return False
        
        path = f"{self._current_path}/{name}" if self._current_path != "/" else f"/{name}"
        if self._vfs.create_directory(path):
            self._refresh_items()
            return True
        return False
    
    @Slot(str, result=bool)
    def deleteItem(self, path: str) -> bool:
        """Delete an item."""
        if not self._vfs:
            return False
        
        if self._vfs.delete(path):
            self._refresh_items()
            return True
        return False
    
    @Slot(str, str, result=bool)
    def renameItem(self, path: str, new_name: str) -> bool:
        """Rename an item."""
        if not self._vfs:
            return False
        
        if self._vfs.rename(path, new_name):
            self._refresh_items()
            return True
        return False
    
    @Slot(str, result=list)
    def search(self, query: str) -> List[Dict[str, Any]]:
        """Search for files."""
        if not self._vfs or not query:
            return []
        
        nodes = self._vfs.search(query, self._current_path)
        return [
            {
                "name": n.name,
                "path": n.path,
                "isDirectory": n.file_type.value == "directory",
                "icon": self._get_icon(n),
            }
            for n in nodes
        ]
    
    @Slot()
    def refresh(self):
        """Refresh current directory."""
        self._refresh_items()
    
    def onStart(self):
        """Initialize explorer."""
        self._refresh_items()
        self._update_title()
    
    def onStop(self):
        """Cleanup explorer."""
        pass
    
    def getQmlComponent(self) -> str:
        return "apps/Explorer.qml"
    
    def saveState(self) -> Dict[str, Any]:
        return {
            "current_path": self._current_path,
            "view_mode": self._view_mode,
        }
    
    def restoreState(self, state: Dict[str, Any]):
        self._current_path = state.get("current_path", "/")
        self._view_mode = state.get("view_mode", "grid")
        self._refresh_items()
        self._update_title()
        self.viewModeChanged.emit()
