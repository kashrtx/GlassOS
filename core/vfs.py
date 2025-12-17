"""
GlassOS Virtual File System (VFS)
Provides a sandboxed file system for applications.
"""

import json
import os
import shutil
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, asdict
from enum import Enum
import threading


class FileType(Enum):
    """Enumeration of file types."""
    FILE = "file"
    DIRECTORY = "directory"
    LINK = "link"


@dataclass
class VFSNode:
    """Represents a node (file or directory) in the VFS."""
    name: str
    path: str
    file_type: FileType
    size: int = 0
    created: str = ""
    modified: str = ""
    content: Optional[str] = None
    children: List[str] = None
    metadata: Dict[str, Any] = None
    
    def __post_init__(self):
        if self.children is None:
            self.children = []
        if self.metadata is None:
            self.metadata = {}
        if not self.created:
            self.created = datetime.now().isoformat()
        if not self.modified:
            self.modified = self.created
    
    def to_dict(self) -> Dict:
        """Convert node to dictionary."""
        return {
            "name": self.name,
            "path": self.path,
            "file_type": self.file_type.value,
            "size": self.size,
            "created": self.created,
            "modified": self.modified,
            "content": self.content,
            "children": self.children,
            "metadata": self.metadata,
        }
    
    @classmethod
    def from_dict(cls, data: Dict) -> "VFSNode":
        """Create node from dictionary."""
        return cls(
            name=data["name"],
            path=data["path"],
            file_type=FileType(data["file_type"]),
            size=data.get("size", 0),
            created=data.get("created", ""),
            modified=data.get("modified", ""),
            content=data.get("content"),
            children=data.get("children", []),
            metadata=data.get("metadata", {}),
        )


class VirtualFileSystem:
    """
    Virtual File System for GlassOS.
    Provides file operations in a sandboxed environment.
    """
    
    def __init__(self, root_path: Path):
        """
        Initialize the VFS.
        
        Args:
            root_path: Physical path on disk where VFS data is stored
        """
        self.root_path = Path(root_path)
        self.index_path = self.root_path / ".vfs_index.json"
        self.data_path = self.root_path / "data"
        self._nodes: Dict[str, VFSNode] = {}
        self._index: Dict[str, List[str]] = {}  # Search index
        self._lock = threading.RLock()
    
    def initialize(self) -> bool:
        """Initialize the VFS structure."""
        try:
            # Create root directories
            self.root_path.mkdir(parents=True, exist_ok=True)
            self.data_path.mkdir(parents=True, exist_ok=True)
            
            # Load or create index
            if self.index_path.exists():
                self._load_index()
            else:
                self._create_default_structure()
                self._save_index()
            
            print(f"📁 VFS initialized at: {self.root_path}")
            return True
        except Exception as e:
            print(f"❌ VFS initialization failed: {e}")
            return False
    
    def _create_default_structure(self):
        """Create the default VFS directory structure."""
        # Create root node
        root = VFSNode(
            name="root",
            path="/",
            file_type=FileType.DIRECTORY,
        )
        self._nodes["/"] = root
        
        # Default directories
        default_dirs = [
            "/Desktop",
            "/Documents",
            "/Documents/Notes",
            "/Downloads",
            "/Pictures",
            "/Music",
            "/Videos",
            "/Applications",
        ]
        
        for dir_path in default_dirs:
            self.create_directory(dir_path)
        
        # Create welcome document
        welcome_content = """# Welcome to GlassOS! 🌟

Thank you for using GlassOS - your beautiful glass-themed desktop environment.

## Getting Started

- **Desktop**: Your main workspace with shortcuts
- **Taskbar**: Quick access to running apps and system status
- **Applications**: Launch built-in apps from the start menu

## Built-in Applications

1. **AeroBrowser** - Browse the web with style
2. **GlassPad** - Create beautiful notes and documents
3. **Weather** - Check the weather with a stunning UI
4. **Calculator** - Quick calculations with glass aesthetics
5. **AeroExplorer** - Manage your files efficiently

## Tips

- Drag windows to screen edges to snap them
- Use the taskbar clock for quick time checks
- Right-click the desktop for context menu options

Enjoy your GlassOS experience! 💎
"""
        self.create_file("/Documents/Notes/Welcome.md", welcome_content)
    
    def _load_index(self):
        """Load VFS index from disk."""
        with self._lock:
            try:
                with open(self.index_path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                
                self._nodes = {
                    path: VFSNode.from_dict(node_data)
                    for path, node_data in data.get("nodes", {}).items()
                }
                self._index = data.get("search_index", {})
            except Exception as e:
                print(f"⚠️  Error loading VFS index: {e}")
                self._create_default_structure()
    
    def _save_index(self):
        """Save VFS index to disk."""
        with self._lock:
            try:
                data = {
                    "nodes": {
                        path: node.to_dict()
                        for path, node in self._nodes.items()
                    },
                    "search_index": self._index,
                }
                with open(self.index_path, "w", encoding="utf-8") as f:
                    json.dump(data, f, indent=2)
            except Exception as e:
                print(f"⚠️  Error saving VFS index: {e}")
    
    def _update_search_index(self, node: VFSNode):
        """Update search index with node information."""
        # Index by name parts
        name_lower = node.name.lower()
        words = name_lower.replace("_", " ").replace("-", " ").split()
        
        for word in words:
            if word not in self._index:
                self._index[word] = []
            if node.path not in self._index[word]:
                self._index[word].append(node.path)
    
    def _normalize_path(self, path: str) -> str:
        """Normalize a VFS path."""
        # Ensure path starts with /
        if not path.startswith("/"):
            path = "/" + path
        # Remove trailing slash (except for root)
        if path != "/" and path.endswith("/"):
            path = path.rstrip("/")
        # Normalize separators
        path = path.replace("\\", "/")
        return path
    
    def _get_parent_path(self, path: str) -> str:
        """Get the parent directory path."""
        if path == "/":
            return "/"
        return str(Path(path).parent).replace("\\", "/")
    
    def exists(self, path: str) -> bool:
        """Check if a path exists in the VFS."""
        path = self._normalize_path(path)
        return path in self._nodes
    
    def is_directory(self, path: str) -> bool:
        """Check if path is a directory."""
        path = self._normalize_path(path)
        node = self._nodes.get(path)
        return node is not None and node.file_type == FileType.DIRECTORY
    
    def is_file(self, path: str) -> bool:
        """Check if path is a file."""
        path = self._normalize_path(path)
        node = self._nodes.get(path)
        return node is not None and node.file_type == FileType.FILE
    
    def create_directory(self, path: str) -> bool:
        """Create a directory at the specified path."""
        path = self._normalize_path(path)
        
        if self.exists(path):
            return False
        
        with self._lock:
            # Create parent directories if needed
            parent_path = self._get_parent_path(path)
            if parent_path != "/" and not self.exists(parent_path):
                self.create_directory(parent_path)
            
            # Create the directory node
            name = Path(path).name
            node = VFSNode(
                name=name,
                path=path,
                file_type=FileType.DIRECTORY,
            )
            self._nodes[path] = node
            
            # Add to parent's children
            if parent_path in self._nodes:
                parent = self._nodes[parent_path]
                if path not in parent.children:
                    parent.children.append(path)
            
            self._update_search_index(node)
            self._save_index()
            return True
    
    def create_file(self, path: str, content: str = "") -> bool:
        """Create a file at the specified path with optional content."""
        path = self._normalize_path(path)
        
        with self._lock:
            # Ensure parent directory exists
            parent_path = self._get_parent_path(path)
            if not self.exists(parent_path):
                self.create_directory(parent_path)
            
            # Create or update the file node
            name = Path(path).name
            now = datetime.now().isoformat()
            
            node = VFSNode(
                name=name,
                path=path,
                file_type=FileType.FILE,
                size=len(content.encode("utf-8")),
                content=content,
                created=self._nodes[path].created if path in self._nodes else now,
                modified=now,
            )
            
            is_new = path not in self._nodes
            self._nodes[path] = node
            
            # Add to parent's children if new
            if is_new and parent_path in self._nodes:
                parent = self._nodes[parent_path]
                if path not in parent.children:
                    parent.children.append(path)
            
            self._update_search_index(node)
            self._save_index()
            return True
    
    def read_file(self, path: str) -> Optional[str]:
        """Read the content of a file."""
        path = self._normalize_path(path)
        node = self._nodes.get(path)
        
        if node and node.file_type == FileType.FILE:
            return node.content
        return None
    
    def write_file(self, path: str, content: str) -> bool:
        """Write content to a file."""
        return self.create_file(path, content)
    
    def delete(self, path: str) -> bool:
        """Delete a file or directory."""
        path = self._normalize_path(path)
        
        if not self.exists(path) or path == "/":
            return False
        
        with self._lock:
            node = self._nodes[path]
            
            # If directory, recursively delete children
            if node.file_type == FileType.DIRECTORY:
                for child_path in list(node.children):
                    self.delete(child_path)
            
            # Remove from parent's children
            parent_path = self._get_parent_path(path)
            if parent_path in self._nodes:
                parent = self._nodes[parent_path]
                if path in parent.children:
                    parent.children.remove(path)
            
            # Delete the node
            del self._nodes[path]
            
            self._save_index()
            return True
    
    def list_directory(self, path: str) -> List[VFSNode]:
        """List contents of a directory."""
        path = self._normalize_path(path)
        node = self._nodes.get(path)
        
        if not node or node.file_type != FileType.DIRECTORY:
            return []
        
        return [
            self._nodes[child_path]
            for child_path in node.children
            if child_path in self._nodes
        ]
    
    def search(self, query: str, path: str = "/") -> List[VFSNode]:
        """
        Search for files/directories matching the query.
        Uses the search index for fast lookups.
        """
        query_lower = query.lower()
        results = set()
        
        # Search in index
        for word in query_lower.split():
            if word in self._index:
                for node_path in self._index[word]:
                    if node_path.startswith(path):
                        results.add(node_path)
        
        # Also do substring matching
        for node_path, node in self._nodes.items():
            if node_path.startswith(path) and query_lower in node.name.lower():
                results.add(node_path)
        
        return [
            self._nodes[path]
            for path in results
            if path in self._nodes
        ]
    
    def get_node(self, path: str) -> Optional[VFSNode]:
        """Get a node by path."""
        path = self._normalize_path(path)
        return self._nodes.get(path)
    
    def rename(self, old_path: str, new_name: str) -> bool:
        """Rename a file or directory."""
        old_path = self._normalize_path(old_path)
        
        if not self.exists(old_path):
            return False
        
        parent_path = self._get_parent_path(old_path)
        new_path = f"{parent_path}/{new_name}" if parent_path != "/" else f"/{new_name}"
        
        if self.exists(new_path):
            return False
        
        with self._lock:
            node = self._nodes[old_path]
            node.name = new_name
            node.path = new_path
            node.modified = datetime.now().isoformat()
            
            # Update parent's children
            if parent_path in self._nodes:
                parent = self._nodes[parent_path]
                if old_path in parent.children:
                    parent.children.remove(old_path)
                    parent.children.append(new_path)
            
            # Move node to new path
            del self._nodes[old_path]
            self._nodes[new_path] = node
            
            # Update children paths if directory
            if node.file_type == FileType.DIRECTORY:
                self._update_children_paths(node, old_path, new_path)
            
            self._update_search_index(node)
            self._save_index()
            return True
    
    def _update_children_paths(self, node: VFSNode, old_base: str, new_base: str):
        """Recursively update children paths after rename."""
        new_children = []
        for child_path in node.children:
            new_child_path = child_path.replace(old_base, new_base, 1)
            
            if child_path in self._nodes:
                child_node = self._nodes[child_path]
                child_node.path = new_child_path
                
                del self._nodes[child_path]
                self._nodes[new_child_path] = child_node
                
                if child_node.file_type == FileType.DIRECTORY:
                    self._update_children_paths(child_node, old_base, new_base)
            
            new_children.append(new_child_path)
        
        node.children = new_children
    
    def get_size(self, path: str) -> int:
        """Get the size of a file or total size of a directory."""
        path = self._normalize_path(path)
        node = self._nodes.get(path)
        
        if not node:
            return 0
        
        if node.file_type == FileType.FILE:
            return node.size
        
        total = 0
        for child_path in node.children:
            total += self.get_size(child_path)
        return total
    
    def get_stats(self) -> Dict[str, Any]:
        """Get VFS statistics."""
        files = sum(1 for n in self._nodes.values() if n.file_type == FileType.FILE)
        dirs = sum(1 for n in self._nodes.values() if n.file_type == FileType.DIRECTORY)
        total_size = sum(n.size for n in self._nodes.values() if n.file_type == FileType.FILE)
        
        return {
            "total_files": files,
            "total_directories": dirs,
            "total_size": total_size,
            "total_nodes": len(self._nodes),
        }
