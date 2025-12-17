"""
GlassOS Web Browser (AeroBrowser) Application
Chromium-based web browser using Qt WebEngine.
"""

from typing import Dict, Any, List
from PySide6.QtCore import QObject, Signal, Slot, Property, QUrl
from .base_app import BaseApp


class BrowserApp(BaseApp):
    """AeroBrowser - Web browser application."""
    
    urlChanged = Signal()
    titleChanged = Signal()
    loadingChanged = Signal()
    canGoBackChanged = Signal()
    canGoForwardChanged = Signal()
    bookmarksChanged = Signal()
    historyChanged = Signal()
    
    def __init__(self, window_id: str, vfs=None, parent=None):
        super().__init__(window_id, vfs, parent)
        self._title = "AeroBrowser"
        self._icon = "🌐"
        self._url = "https://www.google.com"
        self._page_title = "New Tab"
        self._is_loading = False
        self._can_go_back = False
        self._can_go_forward = False
        self._bookmarks = [
            {"title": "Google", "url": "https://www.google.com"},
            {"title": "YouTube", "url": "https://www.youtube.com"},
            {"title": "GitHub", "url": "https://www.github.com"},
            {"title": "Wikipedia", "url": "https://www.wikipedia.org"},
        ]
        self._history = []
    
    @Property(str, notify=urlChanged)
    def url(self) -> str:
        return self._url
    
    @url.setter
    def url(self, value: str):
        if self._url != value:
            self._url = value
            self.urlChanged.emit()
            self._add_to_history(value)
    
    @Property(str, notify=titleChanged)
    def pageTitle(self) -> str:
        return self._page_title
    
    @pageTitle.setter
    def pageTitle(self, value: str):
        if self._page_title != value:
            self._page_title = value
            self.title = f"{value} - AeroBrowser"
            self.titleChanged.emit()
    
    @Property(bool, notify=loadingChanged)
    def isLoading(self) -> bool:
        return self._is_loading
    
    @isLoading.setter
    def isLoading(self, value: bool):
        if self._is_loading != value:
            self._is_loading = value
            self.loadingChanged.emit()
    
    @Property(bool, notify=canGoBackChanged)
    def canGoBack(self) -> bool:
        return self._can_go_back
    
    @canGoBack.setter
    def canGoBack(self, value: bool):
        if self._can_go_back != value:
            self._can_go_back = value
            self.canGoBackChanged.emit()
    
    @Property(bool, notify=canGoForwardChanged)
    def canGoForward(self) -> bool:
        return self._can_go_forward
    
    @canGoForward.setter
    def canGoForward(self, value: bool):
        if self._can_go_forward != value:
            self._can_go_forward = value
            self.canGoForwardChanged.emit()
    
    @Property(list, notify=bookmarksChanged)
    def bookmarks(self) -> List[Dict[str, str]]:
        return self._bookmarks
    
    @Property(list, notify=historyChanged)
    def history(self) -> List[Dict[str, str]]:
        return self._history[-20:]  # Last 20 entries
    
    @Slot(str)
    def navigate(self, url: str):
        """Navigate to a URL."""
        # Add protocol if missing
        if not url.startswith(("http://", "https://", "file://")):
            if "." in url:
                url = "https://" + url
            else:
                # Treat as search query
                url = f"https://www.google.com/search?q={url.replace(' ', '+')}"
        self.url = url
    
    @Slot()
    def goBack(self):
        """Go back in history."""
        self.canGoBack = len(self._history) > 1
    
    @Slot()
    def goForward(self):
        """Go forward in history."""
        pass
    
    @Slot()
    def reload(self):
        """Reload current page."""
        current_url = self._url
        self.urlChanged.emit()
    
    @Slot()
    def stopLoading(self):
        """Stop loading the current page."""
        self.isLoading = False
    
    @Slot(str, str)
    def addBookmark(self, title: str, url: str):
        """Add a bookmark."""
        self._bookmarks.append({"title": title, "url": url})
        self.bookmarksChanged.emit()
    
    @Slot(int)
    def removeBookmark(self, index: int):
        """Remove a bookmark by index."""
        if 0 <= index < len(self._bookmarks):
            self._bookmarks.pop(index)
            self.bookmarksChanged.emit()
    
    def _add_to_history(self, url: str):
        """Add URL to browsing history."""
        from datetime import datetime
        self._history.append({
            "url": url,
            "title": self._page_title,
            "timestamp": datetime.now().isoformat()
        })
        self.historyChanged.emit()
    
    @Slot()
    def clearHistory(self):
        """Clear browsing history."""
        self._history = []
        self.historyChanged.emit()
    
    def onStart(self):
        """Initialize browser."""
        self.navigate("https://www.google.com")
    
    def onStop(self):
        """Cleanup browser."""
        pass
    
    def getQmlComponent(self) -> str:
        return "apps/Browser.qml"
    
    def saveState(self) -> Dict[str, Any]:
        return {
            "url": self._url,
            "history": self._history,
            "bookmarks": self._bookmarks,
        }
    
    def restoreState(self, state: Dict[str, Any]):
        self._url = state.get("url", "https://www.google.com")
        self._history = state.get("history", [])
        self._bookmarks = state.get("bookmarks", self._bookmarks)
        self.urlChanged.emit()
        self.historyChanged.emit()
        self.bookmarksChanged.emit()
