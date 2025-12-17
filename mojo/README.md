# GlassOS Mojo Performance Modules

This directory contains Mojo source files for performance-critical operations.

## Modules

### vfs_indexer.mojo
High-performance Virtual File System indexer for fast search operations.

### blur_engine.mojo  
Optimized blur calculations for the Glass Aero theme effects.

## Building

Mojo modules can be compiled and called from Python using Mojo's native interoperability.

```bash
# Install Mojo
curl https://get.modular.com | sh
modular install mojo

# Build modules
mojo build vfs_indexer.mojo
mojo build blur_engine.mojo
```

## Integration

The Python code includes fallback implementations. When Mojo modules are available, 
they will be automatically used for improved performance.

## Performance Notes

- VFS Indexer: ~10x faster file scanning and indexing
- Blur Engine: Hardware-optimized blur calculations

These are optional - GlassOS runs perfectly fine with pure Python fallbacks.
