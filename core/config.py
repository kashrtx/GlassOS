"""
GlassOS Configuration Module
Manages all system settings and preferences.
"""

import json
from pathlib import Path
from dataclasses import dataclass, field, asdict
from typing import Dict, Any, Optional


@dataclass
class ThemeConfig:
    """Theme configuration settings."""
    # Glass effect settings
    blur_radius: int = 40
    blur_opacity: float = 0.75
    glass_tint: str = "#1a1a2e"
    glass_tint_opacity: float = 0.6
    
    # Accent colors
    accent_color: str = "#00b4d8"
    accent_glow: str = "#48cae4"
    highlight_color: str = "#90e0ef"
    
    # Window colors
    window_border_color: str = "#4cc9f0"
    window_border_opacity: float = 0.8
    window_shadow_color: str = "#000000"
    window_shadow_opacity: float = 0.5
    
    # Text colors
    text_primary: str = "#ffffff"
    text_secondary: str = "#b0b0b0"
    text_disabled: str = "#666666"
    
    # Taskbar settings
    taskbar_height: int = 48
    taskbar_blur: int = 50
    taskbar_tint: str = "#0a0a15"
    taskbar_opacity: float = 0.85


@dataclass
class SystemConfig:
    """System configuration settings."""
    # Display settings
    screen_width: int = 1920
    screen_height: int = 1080
    start_maximized: bool = True
    
    # Animation settings
    animation_duration: int = 250
    animation_easing: str = "OutCubic"
    enable_animations: bool = True
    
    # Window snapping
    snap_threshold: int = 20
    snap_enabled: bool = True
    
    # Performance
    enable_blur: bool = True
    blur_quality: str = "high"  # low, medium, high
    
    # Weather API
    weather_api_key: str = ""
    weather_city: str = "New York"
    weather_units: str = "metric"


@dataclass
class Config:
    """Main configuration class for GlassOS."""
    theme: ThemeConfig = field(default_factory=ThemeConfig)
    system: SystemConfig = field(default_factory=SystemConfig)
    _config_path: Optional[Path] = field(default=None, repr=False)
    
    def __post_init__(self):
        """Initialize configuration from file if exists."""
        if self._config_path is None:
            self._config_path = Path(__file__).parent.parent / "config.json"
        self.load()
    
    def load(self) -> bool:
        """Load configuration from JSON file."""
        if self._config_path and self._config_path.exists():
            try:
                with open(self._config_path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                
                # Update theme settings
                if "theme" in data:
                    for key, value in data["theme"].items():
                        if hasattr(self.theme, key):
                            setattr(self.theme, key, value)
                
                # Update system settings
                if "system" in data:
                    for key, value in data["system"].items():
                        if hasattr(self.system, key):
                            setattr(self.system, key, value)
                
                return True
            except (json.JSONDecodeError, IOError) as e:
                print(f"⚠️  Error loading config: {e}")
                return False
        return False
    
    def save(self) -> bool:
        """Save configuration to JSON file."""
        if self._config_path:
            try:
                data = {
                    "theme": asdict(self.theme),
                    "system": asdict(self.system),
                }
                with open(self._config_path, "w", encoding="utf-8") as f:
                    json.dump(data, f, indent=2)
                return True
            except IOError as e:
                print(f"⚠️  Error saving config: {e}")
                return False
        return False
    
    def to_qml_properties(self) -> Dict[str, Any]:
        """Convert configuration to QML-compatible properties."""
        return {
            # Theme properties
            "blurRadius": self.theme.blur_radius,
            "blurOpacity": self.theme.blur_opacity,
            "glassTint": self.theme.glass_tint,
            "glassTintOpacity": self.theme.glass_tint_opacity,
            "accentColor": self.theme.accent_color,
            "accentGlow": self.theme.accent_glow,
            "highlightColor": self.theme.highlight_color,
            "windowBorderColor": self.theme.window_border_color,
            "windowBorderOpacity": self.theme.window_border_opacity,
            "textPrimary": self.theme.text_primary,
            "textSecondary": self.theme.text_secondary,
            "taskbarHeight": self.theme.taskbar_height,
            "taskbarBlur": self.theme.taskbar_blur,
            "taskbarTint": self.theme.taskbar_tint,
            "taskbarOpacity": self.theme.taskbar_opacity,
            
            # System properties
            "animationDuration": self.system.animation_duration,
            "animationEasing": self.system.animation_easing,
            "enableAnimations": self.system.enable_animations,
            "snapThreshold": self.system.snap_threshold,
            "snapEnabled": self.system.snap_enabled,
            "enableBlur": self.system.enable_blur,
        }


# Default configuration instance
DEFAULT_CONFIG = Config()
