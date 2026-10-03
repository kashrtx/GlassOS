"""
Syntax highlighting for GlassOS, exposed to QML as ``Syntax``.

One small tokenizer drives both:
* live highlighting in GlassPad (a QSyntaxHighlighter attached to the
  editor's QTextDocument), and
* colored HTML for read-only previews (Files details pane).

It is deliberately simple and fast (one linear pass per line, no regex
backtracking on whole documents) and tracks multi-line state - block comments,
Python triple-quoted strings, markup comments - via QTextBlock state.
Very large documents (> 2 MB) are left plain so typing never lags.
"""

from __future__ import annotations

import html
import json
import re
from pathlib import PurePosixPath
from typing import List, Optional, Tuple

from PySide6.QtCore import QObject, Slot

from . import log as _log

log = _log.get("syntax")

MAX_HIGHLIGHT_CHARS = 2_000_000

# One Dark-inspired palette, tuned for dark glass
THEME = {
    "keyword": ("#C678DD", False, False),
    "string": ("#98C379", False, False),
    "number": ("#D19A66", False, False),
    "comment": ("#7F8B9A", False, True),
    "function": ("#61AFEF", False, False),
    "type": ("#E5C07B", False, False),
    "builtin": ("#56B6C2", False, False),
    "tag": ("#E06C75", False, False),
    "attr": ("#D19A66", False, False),
    "heading": ("#61AFEF", True, False),
    "punct": ("#ABB2BF", False, False),
}

EXT_LANG = {
    "py": "python", "pyw": "python", "js": "javascript", "mjs": "javascript", "cjs": "javascript",
    "jsx": "javascript", "ts": "typescript", "tsx": "typescript", "qml": "qml", "json": "json",
    "c": "c", "h": "c", "cpp": "cpp", "cc": "cpp", "cxx": "cpp", "hpp": "cpp", "cs": "csharp",
    "java": "java", "kt": "kotlin", "go": "go", "rs": "rust", "swift": "swift", "php": "php",
    "rb": "ruby", "lua": "lua", "sh": "shell", "bash": "shell", "zsh": "shell", "ps1": "powershell",
    "bat": "batch", "cmd": "batch", "html": "html", "htm": "html", "xml": "xml", "svg": "xml",
    "css": "css", "scss": "css", "less": "css", "yaml": "yaml", "yml": "yaml", "toml": "ini",
    "ini": "ini", "cfg": "ini", "conf": "ini", "md": "markdown", "markdown": "markdown", "sql": "sql",
}
LANG_NAMES = {
    "python": "Python", "javascript": "JavaScript", "typescript": "TypeScript", "qml": "QML", "json": "JSON",
    "c": "C", "cpp": "C++", "csharp": "C#", "java": "Java", "kotlin": "Kotlin", "go": "Go", "rust": "Rust",
    "swift": "Swift", "php": "PHP", "ruby": "Ruby", "lua": "Lua", "shell": "Shell", "powershell": "PowerShell",
    "batch": "Batch", "html": "HTML", "xml": "XML", "css": "CSS", "yaml": "YAML", "ini": "INI/TOML",
    "markdown": "Markdown", "sql": "SQL",
}

_C_KW = ("if else for while do switch case default break continue return goto sizeof typedef struct union enum "
         "static const volatile extern inline register auto signed unsigned void char short int long float double "
         "bool true false NULL nullptr")
_KEYWORDS = {
    "python": "False None True and as assert async await break class continue def del elif else except finally for "
              "from global if import in is lambda nonlocal not or pass raise return try while with yield match case self",
    "javascript": "break case catch class const continue debugger default delete do else export extends finally for "
                  "function if import in instanceof let new of return super switch this throw try typeof var void while "
                  "with yield async await static get set null undefined true false",
    "qml": "import property readonly signal function var let const if else for while return true false null undefined "
           "new this alias required default on in of typeof instanceof break continue switch case component pragma",
    "c": _C_KW, "cpp": _C_KW + " class public private protected virtual override template typename namespace using "
                        "new delete this throw try catch operator friend constexpr noexcept explicit mutable",
    "csharp": "abstract as base bool break byte case catch char class const continue decimal default delegate do double "
              "else enum event explicit extern false finally fixed float for foreach goto if implicit in int interface "
              "internal is lock long namespace new null object operator out override params private protected public "
              "readonly ref return sealed short static string struct switch this throw true try typeof uint using var "
              "virtual void volatile while async await get set",
    "java": "abstract assert boolean break byte case catch char class const continue default do double else enum extends "
            "final finally float for if implements import instanceof int interface long native new package private "
            "protected public return short static super switch synchronized this throw throws try void volatile while "
            "true false null var record",
    "kotlin": "val var fun class object interface if else when for while do return break continue is in as null true "
              "false this super import package override open data sealed private public internal protected companion",
    "go": "break case chan const continue default defer else fallthrough for func go goto if import interface map "
          "package range return select struct switch type var true false nil",
    "rust": "as async await break const continue crate dyn else enum extern false fn for if impl in let loop match mod "
            "move mut pub ref return self Self static struct super trait true type unsafe use where while",
    "swift": "class deinit enum extension func import init let protocol struct subscript typealias var break case continue "
             "default do else fallthrough for guard if in repeat return switch where while as false is nil self super "
             "true try throw throws",
    "php": "abstract and array as break case catch class clone const continue declare default do echo else elseif "
           "empty extends final for foreach function global if implements include interface isset list namespace new "
           "or print private protected public require return static switch throw try unset use var while true false null",
    "ruby": "alias and begin break case class def defined do else elsif end ensure false for if in module next nil not "
            "or redo rescue retry return self super then true undef unless until when while yield",
    "lua": "and break do else elseif end false for function goto if in local nil not or repeat return then true until while",
    "shell": "if then else elif fi case esac for while until do done in function return break continue local export "
             "readonly echo exit source alias unset shift",
    "powershell": "begin break catch class continue data do dynamicparam else elseif end exit filter finally for foreach "
                  "from function if in param process return switch throw trap try until using while",
    "batch": "echo set if else goto call exit for in do not exist defined errorlevel rem setlocal endlocal",
    "sql": "select from where insert into values update set delete create table drop alter add primary key foreign "
           "references join left right inner outer on group by order having limit offset as and or not null is in "
           "like between distinct union all case when then else end index view default unique",
}
_KEYWORDS["typescript"] = _KEYWORDS["javascript"] + " interface type enum implements declare readonly public private " \
                                                    "protected abstract namespace keyof any unknown never string number boolean"
_BUILTINS = {
    "python": "print len range str int float list dict set tuple open isinstance super object type enumerate zip map "
              "filter sorted min max sum abs any all repr bool bytes iter next getattr setattr hasattr Exception",
    "javascript": "console window document Math JSON Object Array String Number Promise Map Set Date Error parseInt "
                  "parseFloat setTimeout setInterval require module",
    "qml": "parent Qt console Math JSON Component anchors",
}
_BUILTINS["typescript"] = _BUILTINS["javascript"]

_LINE_COMMENT = {"python": "#", "shell": "#", "ruby": "#", "yaml": "#", "ini": "#", "powershell": "#",
                 "sql": "--", "lua": "--", "batch": "::"}
_BLOCK_COMMENT = {"c-like": ("/*", "*/"), "lua": ("--[[", "]]"), "powershell": ("<#", "#>")}
_C_LIKE = {"javascript", "typescript", "qml", "c", "cpp", "csharp", "java", "kotlin", "go", "rust", "swift", "php", "css"}
_CASE_INSENSITIVE = {"sql", "batch"}

_IDENT = re.compile(r"[A-Za-z_$][A-Za-z0-9_$]*")
_NUMBER = re.compile(r"(?:0[xX][0-9a-fA-F_]+|0[bB][01_]+|(?:\d[\d_]*\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)[a-zA-Z]*")

# block states (QTextBlock userState): -1/0 none, 1 block comment, 2 triple ", 3 triple ', 4 markup comment
NONE, BLOCK, TRIPLE_D, TRIPLE_S, MARKUP_COMMENT = 0, 1, 2, 3, 4

Span = Tuple[int, int, str]


def language_for(path: str) -> str:
    name = PurePosixPath(path or "").name.lower()
    if name in ("makefile", "dockerfile"):
        return "shell"
    ext = name.rsplit(".", 1)[-1] if "." in name else ""
    return EXT_LANG.get(ext, "")


def _sets(lang):
    kw = set(_KEYWORDS.get(lang, "").split())
    bi = set(_BUILTINS.get(lang, "").split())
    if lang in _CASE_INSENSITIVE:
        kw = {k.lower() for k in kw}
    return kw, bi


_CACHE = {}


def tokenize_line(line: str, lang: str, state: int = NONE) -> Tuple[List[Span], int]:
    """Spans (start, length, kind) for one line, plus the state carried to the next line."""
    if lang in ("html", "xml"):
        return _markup_line(line, state)
    if lang == "markdown":
        return _markdown_line(line), NONE
    if lang not in _CACHE:
        _CACHE[lang] = _sets(lang)
    kw, bi = _CACHE[lang]
    spans: List[Span] = []
    n, i = len(line), 0
    block = _BLOCK_COMMENT.get(lang) or (_BLOCK_COMMENT["c-like"] if lang in _C_LIKE else None)
    line_c = _LINE_COMMENT.get(lang) or ("//" if lang in _C_LIKE and lang != "css" else None)

    # continue a multi-line construct
    if state == BLOCK and block:
        end = line.find(block[1])
        if end < 0:
            return [(0, n, "comment")], BLOCK
        spans.append((0, end + len(block[1]), "comment"))
        i = end + len(block[1])
    elif state in (TRIPLE_D, TRIPLE_S):
        q = '"""' if state == TRIPLE_D else "'''"
        end = line.find(q)
        if end < 0:
            return [(0, n, "string")], state
        spans.append((0, end + 3, "string"))
        i = end + 3

    while i < n:
        c = line[i]
        if block and line.startswith(block[0], i):
            end = line.find(block[1], i + len(block[0]))
            if end < 0:
                spans.append((i, n - i, "comment"))
                return spans, BLOCK
            spans.append((i, end + len(block[1]) - i, "comment"))
            i = end + len(block[1])
            continue
        if line_c and line.startswith(line_c, i) and not (lang == "batch" and i > 0):
            spans.append((i, n - i, "comment"))
            break
        if lang == "batch" and line[i:i + 4].lower() == "rem " and not line[:i].strip():
            spans.append((i, n - i, "comment"))
            break
        if lang == "python" and line.startswith(('"""', "'''"), i):
            q = line[i:i + 3]
            end = line.find(q, i + 3)
            if end < 0:
                spans.append((i, n - i, "string"))
                return spans, TRIPLE_D if q == '"""' else TRIPLE_S
            spans.append((i, end + 3 - i, "string"))
            i = end + 3
            continue
        if c in "\"'`":
            j = i + 1
            while j < n and line[j] != c:
                j += 2 if line[j] == "\\" else 1
            j = min(j + 1, n)
            kind = "string"
            if lang in ("json", "yaml") or (lang in _C_LIKE and lang != "css"):
                rest = line[j:].lstrip()
                if lang in ("json", "yaml") and rest.startswith(":"):
                    kind = "attr"              # object keys
            spans.append((i, j - i, kind))
            i = j
            continue
        if c.isdigit() or (c == "." and i + 1 < n and line[i + 1].isdigit()):
            if i == 0 or not (line[i - 1].isalnum() or line[i - 1] == "_"):
                m = _NUMBER.match(line, i)
                if m:
                    spans.append((i, m.end() - i, "number"))
                    i = m.end()
                    continue
        if lang == "css" and c in "#." and i + 1 < n and (line[i + 1].isalnum() or line[i + 1] == "-"):
            j = i + 1
            while j < n and (line[j].isalnum() or line[j] in "-_"):
                j += 1
            if c == "#" and re.fullmatch(r"#[0-9a-fA-F]{3,8}", line[i:j]):
                spans.append((i, j - i, "number"))
            else:
                spans.append((i, j - i, "type"))
            i = j
            continue
        if c == "@" and lang in ("css", "python", "java", "kotlin", "csharp", "typescript", "javascript", "qml"):
            m = _IDENT.match(line, i + 1)
            if m:
                spans.append((i, m.end() - i, "keyword" if lang == "css" else "builtin"))
                i = m.end()
                continue
        if c.isalpha() or c in "_$":
            m = _IDENT.match(line, i)
            word = m.group()
            end = m.end()
            key = word.lower() if lang in _CASE_INSENSITIVE else word
            nxt = line[end:end + 1]
            if lang == "css":
                if line[end:].lstrip().startswith(":") and "{" not in line[:i]:
                    spans.append((i, end - i, "attr"))
            elif lang in ("yaml", "ini"):
                if not line[:i].strip() and (line[end:].lstrip()[:1] in (":", "=")):
                    spans.append((i, end - i, "attr"))
                elif word in ("true", "false", "null", "yes", "no", "on", "off"):
                    spans.append((i, end - i, "keyword"))
            elif key in kw:
                spans.append((i, end - i, "keyword"))
            elif word in bi:
                spans.append((i, end - i, "builtin"))
            elif nxt == "(":
                spans.append((i, end - i, "function"))
            elif word[:1].isupper() and lang not in ("shell", "batch", "sql") and len(word) > 1:
                spans.append((i, end - i, "type"))
            elif lang == "shell" and line[i - 1:i] == "$":
                spans.append((i - 1, end - i + 1, "builtin"))
            i = end
            continue
        if lang == "ini" and c == "[" and not line[:i].strip():
            end = line.find("]", i)
            if end > 0:
                spans.append((i, end + 1 - i, "type"))
                i = end + 1
                continue
        i += 1
    return spans, NONE


def _markup_line(line: str, state: int):
    spans: List[Span] = []
    n, i = len(line), 0
    if state == MARKUP_COMMENT:
        end = line.find("-->")
        if end < 0:
            return [(0, n, "comment")], MARKUP_COMMENT
        spans.append((0, end + 3, "comment"))
        i = end + 3
    while i < n:
        if line.startswith("<!--", i):
            end = line.find("-->", i + 4)
            if end < 0:
                spans.append((i, n - i, "comment"))
                return spans, MARKUP_COMMENT
            spans.append((i, end + 3 - i, "comment"))
            i = end + 3
            continue
        if line[i] == "<":
            m = re.match(r"</?[\w:.-]+", line[i:])
            if m:
                spans.append((i, m.end(), "tag"))
                i += m.end()
                while i < n and line[i] != ">":
                    am = re.match(r"\s*([\w:.-]+)", line[i:])
                    if am and am.group(1):
                        spans.append((i + am.start(1), len(am.group(1)), "attr"))
                        i += am.end()
                        continue
                    if line[i] in "\"'":
                        q = line[i]
                        j = line.find(q, i + 1)
                        j = n if j < 0 else j + 1
                        spans.append((i, j - i, "string"))
                        i = j
                        continue
                    i += 1
                if i < n:
                    spans.append((i, 1, "tag"))
                    i += 1
                continue
        if line[i] == "&":
            m = re.match(r"&#?\w+;", line[i:])
            if m:
                spans.append((i, m.end(), "number"))
                i += m.end()
                continue
        i += 1
    return spans, NONE


def _markdown_line(line: str) -> List[Span]:
    s = line.lstrip()
    if s.startswith("#"):
        return [(0, len(line), "heading")]
    spans: List[Span] = []
    if s[:2] in ("- ", "* ", "+ ") or re.match(r"\d+\. ", s):
        lead = len(line) - len(s)
        spans.append((lead, 1 if not s[0].isdigit() else s.index(".") + 1, "keyword"))
    if s.startswith(">"):
        spans.append((0, len(line), "comment"))
    for m in re.finditer(r"`[^`]+`", line):
        spans.append((m.start(), m.end() - m.start(), "string"))
    for m in re.finditer(r"(\*\*|__)[^*_]+\1", line):
        spans.append((m.start(), m.end() - m.start(), "type"))
    for m in re.finditer(r"\[[^\]]+\]\([^)]+\)", line):
        spans.append((m.start(), m.end() - m.start(), "function"))
    return spans


def to_html(text: str, lang: str, max_lines: int = 60) -> str:
    """Highlighted HTML (for Text { textFormat: Text.RichText })."""
    lines = (text or "").splitlines()[:max_lines]
    out, state = [], NONE
    for line in lines:
        spans, state = tokenize_line(line, lang, state) if lang else ([], NONE)
        spans = sorted(spans)
        pos, parts = 0, []
        for start, length, kind in spans:
            if start < pos:
                continue
            parts.append(html.escape(line[pos:start]))
            color, bold, italic = THEME.get(kind, THEME["punct"])
            style = f"color:{color};" + ("font-weight:600;" if bold else "") + ("font-style:italic;" if italic else "")
            parts.append(f'<span style="{style}">{html.escape(line[start:start + length])}</span>')
            pos = start + length
        parts.append(html.escape(line[pos:]))
        out.append("".join(parts) or " ")
    return '<pre style="margin:0">' + "\n".join(out) + "</pre>"


def format_json(text: str) -> dict:
    try:
        return {"ok": True, "text": json.dumps(json.loads(text), indent=2, ensure_ascii=False) + "\n", "error": ""}
    except ValueError as exc:
        return {"ok": False, "text": text, "error": f"Not valid JSON: {exc}"}


def indent_for_newline(line: str, lang: str) -> str:
    """Indentation for the line after ``line`` (auto-indent on Enter)."""
    base = line[: len(line) - len(line.lstrip())]
    stripped = line.rstrip()
    opener = stripped.endswith(("{", "[", "(")) or (lang == "python" and stripped.endswith(":")) or \
        (lang in ("lua", "ruby") and re.search(r"\b(do|then|function)\b\s*$", stripped) is not None)
    return base + ("    " if opener else "")


# ---------------------------------------------------------------- Qt side
try:
    from PySide6.QtGui import QColor, QFont, QSyntaxHighlighter, QTextCharFormat

    class CodeHighlighter(QSyntaxHighlighter):
        def __init__(self, document, lang: str):
            super().__init__(document)
            self.lang = lang
            self.formats = {}
            for kind, (color, bold, italic) in THEME.items():
                f = QTextCharFormat()
                f.setForeground(QColor(color))
                if bold:
                    f.setFontWeight(QFont.Weight.DemiBold)
                if italic:
                    f.setFontItalic(True)
                self.formats[kind] = f

        def highlightBlock(self, text):  # noqa: N802 (Qt API)
            try:
                doc = self.document()
                if doc is not None and doc.characterCount() > MAX_HIGHLIGHT_CHARS:
                    return
                prev = self.previousBlockState()
                spans, state = tokenize_line(text, self.lang, prev if prev > 0 else NONE)
                for start, length, kind in spans:
                    self.setFormat(start, length, self.formats.get(kind, self.formats["punct"]))
                self.setCurrentBlockState(state)
            except Exception as exc:  # a highlighter bug must never break typing
                log.debug("highlight failed: %s", exc)
except ImportError:  # pragma: no cover - tests run without QtGui
    CodeHighlighter = None


class SyntaxService(QObject):
    def __init__(self, parent=None):
        super().__init__(parent)
        # Strong references: the highlighter is a *Python subclass* (highlightBlock is
        # overridden in Python). Parenting it to the C++ document keeps the C++ half
        # alive, but if the Python wrapper is garbage-collected the override is lost
        # and it silently colors nothing. That was the missing colors in GlassPad.
        self._live = {}

    @Slot(str, result=str)
    def languageFor(self, path: str) -> str:
        return language_for(path)

    @Slot(str, result=str)
    def languageName(self, lang: str) -> str:
        return LANG_NAMES.get(lang, "Plain text")

    @Slot(QObject, str, result=bool)
    def attach(self, quick_document, lang: str) -> bool:
        """Attach (or replace / remove with lang="") the highlighter of a TextEdit's textDocument."""
        if quick_document is None or CodeHighlighter is None:
            return False
        try:
            doc = quick_document.textDocument()
        except Exception as exc:
            log.debug("no text document: %s", exc)
            return False
        if doc is None:
            return False
        key = id(doc)
        old = self._live.pop(key, None)
        if old is not None:
            try:
                old[1].setDocument(None)
                old[1].deleteLater()
            except RuntimeError:
                pass
        if not lang:
            return True
        hl = CodeHighlighter(doc, lang)
        self._live[key] = (doc, hl)
        try:   # forget it when the editor (and its document) goes away
            doc.destroyed.connect(lambda *_a, k=key: self._live.pop(k, None))
        except (RuntimeError, TypeError):
            pass
        hl.rehighlight()
        return True

    @Slot(str, str, int, result=str)
    def toHtml(self, text: str, path: str, max_lines: int = 60) -> str:
        return to_html(text, language_for(path), max_lines)

    @Slot(str, result="QVariantMap")
    def formatJson(self, text: str) -> dict:
        return format_json(text)

    @Slot(str, str, result=str)
    def newlineIndent(self, line: str, lang: str) -> str:
        return indent_for_newline(line, lang)
