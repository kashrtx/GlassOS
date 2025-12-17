# GlassOS VFS Indexer - High Performance File Indexing
# This Mojo module provides fast file system indexing and search

from collections import Dict, List
from memory import memset_zero
from sys import sizeof

struct FileNode:
    var name: String
    var path: String
    var is_directory: Bool
    var size: Int
    var children_count: Int

struct VFSIndex:
    """Fast Virtual File System indexer using Mojo's performance."""
    
    var nodes: List[FileNode]
    var word_index: Dict[String, List[Int]]
    
    fn __init__(inout self):
        self.nodes = List[FileNode]()
        self.word_index = Dict[String, List[Int]]()
    
    fn add_node(inout self, name: String, path: String, is_dir: Bool, size: Int):
        """Add a node to the index."""
        var node = FileNode(name, path, is_dir, size, 0)
        var index = len(self.nodes)
        self.nodes.append(node)
        
        # Index words in the name
        self._index_words(name, index)
    
    fn _index_words(inout self, name: String, node_index: Int):
        """Index individual words from the filename."""
        var word = String("")
        for char in name:
            if char == '_' or char == '-' or char == ' ' or char == '.':
                if len(word) > 0:
                    self._add_to_word_index(word.lower(), node_index)
                    word = String("")
            else:
                word += char
        
        if len(word) > 0:
            self._add_to_word_index(word.lower(), node_index)
    
    fn _add_to_word_index(inout self, word: String, node_index: Int):
        """Add a word to the search index."""
        if word not in self.word_index:
            self.word_index[word] = List[Int]()
        self.word_index[word].append(node_index)
    
    fn search(self, query: String) -> List[Int]:
        """Search for nodes matching the query."""
        var results = List[Int]()
        var query_lower = query.lower()
        
        # Search in word index
        if query_lower in self.word_index:
            for idx in self.word_index[query_lower]:
                if idx not in results:
                    results.append(idx)
        
        # Also do substring matching for comprehensive results
        for i in range(len(self.nodes)):
            if query_lower in self.nodes[i].name.lower():
                if i not in results:
                    results.append(i)
        
        return results
    
    fn get_node(self, index: Int) -> FileNode:
        """Get a node by index."""
        return self.nodes[index]
    
    fn count(self) -> Int:
        """Get total number of indexed nodes."""
        return len(self.nodes)


fn create_index() -> VFSIndex:
    """Create a new VFS index instance."""
    return VFSIndex()
