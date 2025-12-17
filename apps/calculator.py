"""
GlassOS Calculator Application
A beautiful glass-themed calculator.
"""

from typing import Dict, Any
from PySide6.QtCore import QObject, Signal, Slot, Property
from .base_app import BaseApp


class CalculatorApp(BaseApp):
    """Glass Calculator application."""
    
    displayChanged = Signal()
    historyChanged = Signal()
    
    def __init__(self, window_id: str, vfs=None, parent=None):
        super().__init__(window_id, vfs, parent)
        self._title = "Calculator"
        self._icon = "🧮"
        self._display = "0"
        self._current_value = 0.0
        self._pending_operation = None
        self._waiting_for_operand = True
        self._history = []
    
    @Property(str, notify=displayChanged)
    def display(self) -> str:
        return self._display
    
    @display.setter
    def display(self, value: str):
        if self._display != value:
            self._display = value
            self.displayChanged.emit()
    
    @Property(list, notify=historyChanged)
    def history(self) -> list:
        return self._history[-5:]  # Last 5 operations
    
    @Slot(str)
    def digitPressed(self, digit: str):
        """Handle digit button press."""
        if self._waiting_for_operand:
            self._display = digit
            self._waiting_for_operand = False
        else:
            if self._display == "0" and digit != ".":
                self._display = digit
            elif digit == "." and "." in self._display:
                return  # Already has decimal
            else:
                self._display = self._display + digit
        self.displayChanged.emit()
    
    @Slot(str)
    def operatorPressed(self, operator: str):
        """Handle operator button press."""
        operand = float(self._display)
        
        if self._pending_operation:
            self._calculate()
        else:
            self._current_value = operand
        
        self._pending_operation = operator
        self._waiting_for_operand = True
    
    @Slot()
    def equalsPressed(self):
        """Handle equals button press."""
        if self._pending_operation:
            operand = float(self._display)
            expression = f"{self._current_value} {self._pending_operation} {operand}"
            self._calculate()
            
            # Add to history
            self._history.append(f"{expression} = {self._display}")
            self.historyChanged.emit()
            
            self._pending_operation = None
    
    def _calculate(self):
        """Perform the pending calculation."""
        operand = float(self._display)
        result = 0.0
        
        if self._pending_operation == "+":
            result = self._current_value + operand
        elif self._pending_operation == "-":
            result = self._current_value - operand
        elif self._pending_operation == "×":
            result = self._current_value * operand
        elif self._pending_operation == "÷":
            if operand != 0:
                result = self._current_value / operand
            else:
                self._display = "Error"
                self._waiting_for_operand = True
                self.displayChanged.emit()
                return
        
        self._current_value = result
        
        # Format result
        if result == int(result):
            self._display = str(int(result))
        else:
            self._display = f"{result:.10g}"
        
        self._waiting_for_operand = True
        self.displayChanged.emit()
    
    @Slot()
    def clearPressed(self):
        """Clear the calculator."""
        self._display = "0"
        self._current_value = 0.0
        self._pending_operation = None
        self._waiting_for_operand = True
        self.displayChanged.emit()
    
    @Slot()
    def clearEntryPressed(self):
        """Clear current entry."""
        self._display = "0"
        self._waiting_for_operand = True
        self.displayChanged.emit()
    
    @Slot()
    def backspacePressed(self):
        """Remove last digit."""
        if len(self._display) > 1:
            self._display = self._display[:-1]
        else:
            self._display = "0"
            self._waiting_for_operand = True
        self.displayChanged.emit()
    
    @Slot()
    def negatePressed(self):
        """Toggle sign of current number."""
        value = float(self._display)
        value = -value
        if value == int(value):
            self._display = str(int(value))
        else:
            self._display = str(value)
        self.displayChanged.emit()
    
    @Slot()
    def percentPressed(self):
        """Calculate percentage."""
        value = float(self._display)
        value = value / 100.0
        self._display = f"{value:.10g}"
        self.displayChanged.emit()
    
    @Slot()
    def sqrtPressed(self):
        """Calculate square root."""
        value = float(self._display)
        if value >= 0:
            import math
            value = math.sqrt(value)
            self._display = f"{value:.10g}"
        else:
            self._display = "Error"
        self._waiting_for_operand = True
        self.displayChanged.emit()
    
    def onStart(self):
        """Initialize calculator."""
        pass
    
    def onStop(self):
        """Cleanup calculator."""
        pass
    
    def getQmlComponent(self) -> str:
        return "apps/Calculator.qml"
    
    def saveState(self) -> Dict[str, Any]:
        return {
            "history": self._history
        }
    
    def restoreState(self, state: Dict[str, Any]):
        self._history = state.get("history", [])
        self.historyChanged.emit()
