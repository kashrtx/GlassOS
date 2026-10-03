"""
GlassOS calculator engine.

A small, safe expression evaluator (no ``eval``) with a Pratt parser.

Supported:
  numbers (``1.5``, ``.5``, ``1e3``), ``+ - * / ^`` (``^`` is right-associative),
  ``mod``, unary ``+``/``-``, postfix ``!`` (factorial) and ``%`` (percent),
  parentheses, implicit multiplication (``2pi``, ``3(4+1)``, ``(1+2)(3+4)``),
  constants ``pi``/``π``, ``e``, ``ans`` and functions
  ``sin cos tan asin acos atan sinh cosh tanh sqrt cbrt ln log log2 exp abs
  round floor ceil``.
Pretty symbols from the keypad (``× ÷ − √ π``) are accepted too.
"""

from __future__ import annotations

import math
import re
from typing import List, Tuple

from PySide6.QtCore import QObject, Slot


class CalcError(Exception):
    pass


_FUNCS = {
    "sin": math.sin, "cos": math.cos, "tan": math.tan,
    "asin": math.asin, "acos": math.acos, "atan": math.atan,
    "sinh": math.sinh, "cosh": math.cosh, "tanh": math.tanh,
    "sqrt": math.sqrt, "cbrt": lambda x: math.copysign(abs(x) ** (1 / 3), x),
    "ln": math.log, "log": math.log10, "log2": math.log2, "exp": math.exp,
    "abs": abs, "round": round, "floor": math.floor, "ceil": math.ceil,
}
_TRIG = {"sin", "cos", "tan"}
_INV_TRIG = {"asin", "acos", "atan"}
_CONSTS = {"pi": math.pi, "e": math.e, "tau": math.tau}
_REPLACE = {"×": "*", "÷": "/", "−": "-", "–": "-", "π": "pi", "√": "sqrt", "**": "^", "√(": "sqrt("}
_TOKEN = re.compile(r"\s*(?:(\d+\.?\d*(?:[eE][+-]?\d+)?|\.\d+(?:[eE][+-]?\d+)?)|([A-Za-z_]\w*)|(.))")


def tokenize(expr: str) -> List[Tuple[str, str]]:
    for a, b in _REPLACE.items():
        expr = expr.replace(a, b)
    tokens: List[Tuple[str, str]] = []
    pos = 0
    expr = expr.strip()
    while pos < len(expr):
        m = _TOKEN.match(expr, pos)
        if not m or m.end() == pos:
            break
        num, name, op = m.groups()
        pos = m.end()
        if num is not None:
            tokens.append(("num", num))
        elif name is not None:
            tokens.append(("name", name.lower()))
        elif op is not None and not op.isspace():
            if op not in "+-*/^()!%,":
                raise CalcError(f"Unexpected '{op}'")
            tokens.append(("op", op))
    # implicit multiplication: 2pi, 2(3), (1)(2), pi(2), 3sqrt(4), 5!2
    out: List[Tuple[str, str]] = []
    for tok in tokens:
        if out:
            prev = out[-1]
            prev_ends_value = prev[0] == "num" or (prev[0] == "name" and prev[1] not in _FUNCS) \
                or prev == ("op", ")") or prev == ("op", "!") or prev == ("op", "%")
            starts_value = tok[0] in ("num", "name") or tok == ("op", "(")
            if prev_ends_value and starts_value and not (tok[0] == "name" and tok[1] == "mod"):
                if not (prev[0] == "name" and prev[1] == "mod"):
                    out.append(("op", "*"))
        out.append(tok)
    return out


class _Parser:
    def __init__(self, tokens, degrees: bool, ans: float):
        self.t = tokens
        self.i = 0
        self.deg = degrees
        self.ans = ans

    def peek(self):
        return self.t[self.i] if self.i < len(self.t) else ("eof", "")

    def take(self):
        tok = self.peek()
        self.i += 1
        return tok

    def expect(self, value):
        tok = self.take()
        if tok != ("op", value):
            raise CalcError(f"Expected '{value}'")

    def parse(self) -> float:
        if not self.t:
            raise CalcError("Empty expression")
        value = self.expr(0)
        if self.peek()[0] != "eof":
            raise CalcError(f"Unexpected '{self.peek()[1]}'")
        return value

    # binding powers
    _INFIX = {"+": (10, 11), "-": (10, 11), "*": (20, 21), "/": (20, 21), "mod": (20, 21), "^": (41, 40)}

    def expr(self, min_bp: int) -> float:
        lhs = self.prefix()
        while True:
            kind, val = self.peek()
            if kind == "op" and val in ("!", "%"):
                if 50 < min_bp:
                    break
                self.take()
                lhs = _factorial(lhs) if val == "!" else lhs / 100.0
                continue
            key = val if (kind == "op" or (kind == "name" and val == "mod")) else None
            if key not in self._INFIX:
                break
            lbp, rbp = self._INFIX[key]
            if lbp < min_bp:
                break
            self.take()
            rhs = self.expr(rbp)
            lhs = _apply(key, lhs, rhs)
        return lhs

    def prefix(self) -> float:
        kind, val = self.take()
        if kind == "num":
            return float(val)
        if kind == "op" and val in "+-":
            operand = self.expr(30)  # binds tighter than * but looser than ^:  -2^2 = -4
            return -operand if val == "-" else operand
        if kind == "op" and val == "(":
            inner = self.expr(0)
            if self.peek() == ("op", ")"):
                self.take()
            elif self.peek()[0] != "eof":  # forgiving: allow a missing final ')'
                raise CalcError("Expected ')'")
            return inner
        if kind == "name":
            if val in _CONSTS:
                return _CONSTS[val]
            if val == "ans":
                return self.ans
            if val in _FUNCS:
                if self.peek() == ("op", "("):
                    self.take()
                    arg = self.expr(0)
                    if self.peek() == ("op", ")"):
                        self.take()
                else:
                    arg = self.expr(35)  # "sqrt 9", "sin 30"
                return self.call(val, arg)
            raise CalcError(f"Unknown name '{val}'")
        if kind == "eof":
            raise CalcError("Incomplete expression")
        raise CalcError(f"Unexpected '{val}'")

    def call(self, name: str, arg: float) -> float:
        try:
            if name in _TRIG and self.deg:
                arg = math.radians(arg)
                # snap tiny float noise: sin(180) -> 0, tan(45) -> 1
                result = _FUNCS[name](arg)
                return 0.0 if abs(result) < 1e-12 else result
            result = _FUNCS[name](arg)
            if name in _INV_TRIG and self.deg:
                return math.degrees(result)
            return float(result)
        except (ValueError, OverflowError):
            raise CalcError("Math error")


def _factorial(x: float) -> float:
    if x < 0 or x != int(x):
        raise CalcError("Factorial needs a whole number ≥ 0")
    if x > 170:
        raise CalcError("Overflow")
    return float(math.factorial(int(x)))


def _apply(op: str, a: float, b: float) -> float:
    try:
        if op == "+":
            return a + b
        if op == "-":
            return a - b
        if op == "*":
            return a * b
        if op == "/":
            if b == 0:
                raise CalcError("Can't divide by zero")
            return a / b
        if op == "mod":
            if b == 0:
                raise CalcError("Can't divide by zero")
            return math.fmod(a, b)
        if op == "^":
            if a < 0 and b != int(b):
                raise CalcError("Math error")
            return math.pow(a, b)
    except OverflowError:
        raise CalcError("Overflow")
    raise CalcError(f"Unknown operator {op}")


MAX_EXPRESSION_LENGTH = 1000


def evaluate(expr: str, degrees: bool = True, ans: float = 0.0) -> float:
    if not isinstance(expr, str):
        raise CalcError("Empty expression")
    if len(expr) > MAX_EXPRESSION_LENGTH:
        raise CalcError("Expression too long")
    if not math.isfinite(ans):
        ans = 0.0
    value = _Parser(tokenize(expr), degrees, ans).parse()
    if math.isnan(value):
        raise CalcError("Math error")
    if math.isinf(value):
        raise CalcError("Overflow")
    return value


def format_number(value: float) -> str:
    if value == 0:
        return "0"
    if abs(value) >= 1e15 or abs(value) < 1e-9:
        mant, exp = f"{value:.10e}".split("e")
        mant = mant.rstrip("0").rstrip(".")
        return f"{mant}e{int(exp)}"
    text = f"{value:.12g}"
    if "e" in text:
        text = f"{value:.12f}".rstrip("0").rstrip(".")
    return text


class CalcProvider(QObject):
    """Exposed to QML as ``Calc``."""

    @Slot(str, bool, str, result="QVariantMap")
    def evaluate(self, expr: str, degrees: bool = True, ans: str = "0") -> dict:
        try:
            ans_value = float(ans) if ans else 0.0
        except (TypeError, ValueError):
            ans_value = 0.0
        try:
            value = evaluate(expr, degrees, ans_value)
            return {"ok": True, "value": format_number(value), "error": ""}
        except CalcError as exc:
            return {"ok": False, "value": "", "error": str(exc)}
        except RecursionError:
            return {"ok": False, "value": "", "error": "Expression too complex"}

    @Slot(str, result=bool)
    def looksLikeMath(self, text: str) -> bool:
        """Used by Start-menu search to show an instant answer."""
        text = (text or "").strip()
        if len(text) < 3 or len(text) > 200 or not re.search(r"\d", text) or not re.search(r"[-+*/^×÷!%(]|sqrt|sin|cos|tan|log|ln", text):
            return False
        try:
            evaluate(text)
            return True
        except Exception:
            return False
