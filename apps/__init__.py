"""
GlassOS Built-in Applications Package
"""

from .base_app import BaseApp
from .calculator import CalculatorApp
from .notepad import NotepadApp
from .browser import BrowserApp
from .explorer import ExplorerApp
from .weather import WeatherApp

__all__ = [
    "BaseApp",
    "CalculatorApp",
    "NotepadApp", 
    "BrowserApp",
    "ExplorerApp",
    "WeatherApp",
]
