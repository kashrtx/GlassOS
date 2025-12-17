#!/usr/bin/env python3
"""
GlassOS - Aero-Mojo Operating System Environment
A stunning desktop environment with liquid glass aesthetics.

Author: GlassOS Team
License: MIT
"""

import sys
import os
from pathlib import Path

# Fix Windows console encoding for Unicode
if sys.platform == 'win32':
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

# Set Qt Quick Controls style to Basic for full customization support
os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"

# Add project root to path
PROJECT_ROOT = Path(__file__).parent
sys.path.insert(0, str(PROJECT_ROOT))

from PySide6.QtWidgets import QApplication
from PySide6.QtCore import Qt, QCoreApplication
from PySide6.QtGui import QFont, QFontDatabase
from PySide6.QtQml import QQmlApplicationEngine

# Initialize WebEngine BEFORE QApplication is created (required by Chromium)
try:
    from PySide6.QtWebEngineQuick import QtWebEngineQuick
    QtWebEngineQuick.initialize()
    print("🌐 QtWebEngineQuick initialized successfully")
except ImportError as e:
    print(f"⚠️ QtWebEngineQuick not available: {e}")
    print("   Browser functionality will be limited")

from core.desktop_environment import DesktopEnvironment
from core.vfs import VirtualFileSystem
from core.config import Config


def setup_application() -> QApplication:
    """Initialize and configure the Qt Application."""
    # Note: AA_EnableHighDpiScaling and AA_UseHighDpiPixmaps are enabled by default in Qt6
    
    app = QApplication(sys.argv)
    
    # Application metadata
    app.setApplicationName("GlassOS")
    app.setApplicationVersion("1.0.0")
    app.setOrganizationName("GlassOS Team")
    app.setOrganizationDomain("glassos.app")
    
    # Set application-wide font
    font = QFont("Segoe UI", 10)
    font.setStyleStrategy(QFont.PreferAntialias)
    app.setFont(font)
    
    return app


def load_fonts():
    """Load custom fonts for the glass aesthetic."""
    fonts_dir = PROJECT_ROOT / "assets" / "fonts"
    if fonts_dir.exists():
        for font_file in fonts_dir.glob("*.ttf"):
            QFontDatabase.addApplicationFont(str(font_file))
        for font_file in fonts_dir.glob("*.otf"):
            QFontDatabase.addApplicationFont(str(font_file))


def initialize_vfs():
    """Initialize the Virtual File System."""
    vfs_root = PROJECT_ROOT / "vfs_data"
    vfs = VirtualFileSystem(vfs_root)
    vfs.initialize()
    return vfs


def main():
    """Main entry point for GlassOS."""
    print("=" * 60)
    print("  🌟 GlassOS - Aero-Mojo Operating System Environment")
    print("  Version 1.0.0")
    print("=" * 60)
    print()
    
    # Initialize application
    app = setup_application()
    
    # Load configuration
    config = Config()
    
    # Load custom fonts
    load_fonts()
    
    # Initialize Virtual File System
    vfs = initialize_vfs()
    
    # Create and show desktop environment
    desktop = DesktopEnvironment(app, config, vfs)
    desktop.show()
    
    print("✅ GlassOS initialized successfully!")
    print("   Press Ctrl+Q to exit")
    print()
    
    # Run the application
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
