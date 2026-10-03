"""
GlassShell - the GlassOS terminal.

A tiny sandboxed shell that operates on the virtual file system through
:class:`core.storage.StorageProvider`. It never touches the host shell.

``run(cwd, line)`` returns a dict::

    {"lines": [{"text": str, "color": "" | "accent" | "ok" | "err" | "dim" | "warn"}],
     "cwd": str, "clear": bool, "actions": [{"type": ..., ...}]}

``actions`` are side effects the QML shell performs (open an app, set the accent,
start the matrix rain, close the window, ...).
"""

from __future__ import annotations

import datetime as _dt
import platform
import random
import shlex
from typing import List

from PySide6.QtCore import QObject, Slot

from . import archives as _archives
from . import calc as _calc
from . import log as _log
from .storage import TRASH, join, normalize, parent_of

log = _log.get("shell")

APP_ALIASES = {
    "explorer": "AeroExplorer", "files": "AeroExplorer", "browser": "AeroBrowser",
    "web": "AeroBrowser", "notepad": "GlassPad", "pad": "GlassPad", "edit": "GlassPad",
    "calc": "Calculator", "calculator": "Calculator", "weather": "Weather",
    "settings": "Settings", "terminal": "Terminal", "taskmgr": "TaskManager",
    "tasks": "TaskManager", "snake": "Snake", "images": "ImageViewer",
}

FORTUNES = [
    "A clean desktop is a sign of a cluttered Recycle Bin.",
    "There is no place like 127.0.0.1",
    "It works on my machine. Ship the machine.",
    "Glass is just sand that believed in itself.",
    "Today's lucky number is the number of tabs you have open.",
    "Real programmers count from 0.",
    "You will find a missing semicolon in an unexpected place.",
    "Have you tried turning it off and on again?",
]

HELP = [
    ("Files", ""),
    ("  ls [-l] [path]", "list a folder"),
    ("  cd <path>", "change folder (.., ~, /)"),
    ("  pwd", "show current folder"),
    ("  tree [path]", "show folder tree"),
    ("  cat <file>", "print a file"),
    ("  touch <file>", "create an empty file"),
    ("  mkdir <folder>", "create a folder"),
    ("  echo <text> [> file]", "print or write text (>> appends)"),
    ("  cp <src> <dest>", "copy into a folder"),
    ("  mv <src> <dest>", "move into a folder, or rename"),
    ("  rm <path>", "move to the Recycle Bin"),
    ("  find <text>", "search file names"),
    ("  zip <name.zip> <paths…>", "compress files/folders"),
    ("  unzip <archive> [folder]", "extract .zip / .tar.gz / .tar.xz …"),
    ("  lsarchive <archive>", "list an archive's contents"),
    ("Desktop", ""),
    ("  open <file|app>", "open a file or app (try: open snake)"),
    ("  apps", "list installed apps"),
    ("  accent <color>", "change accent color (e.g. accent #f472b6)"),
    ("  wallpaper next", "cycle the wallpaper"),
    ("  lock", "lock the screen"),
    ("Fun & info", ""),
    ("  calc <expr>", "calculate (calc 2^10 + sqrt 16)"),
    ("  neofetch", "system summary"),
    ("  fortune / cowsay <text>", "wisdom"),
    ("  matrix", "you know what this does"),
    ("  date / whoami / uname", "info"),
    ("  history / clear / exit", "shell stuff"),
]


MAX_OUTPUT_LINES = 2000      # QML renders one delegate per line; keep it snappy
MAX_LINE_LENGTH = 4000
MAX_COMMAND_LENGTH = 8000


def _line(text: str = "", color: str = "") -> dict:
    return {"text": text if len(text) <= MAX_LINE_LENGTH else text[:MAX_LINE_LENGTH] + " …", "color": color}


def split_redirect(line: str):
    """Split ``cmd > file`` / ``cmd >> file`` on the first *unquoted* ``>``.

    Returns ``(command, target, mode)`` where mode is ``"w"``, ``"a"`` or ``None``.
    """
    quote = None
    i = 0
    while i < len(line):
        ch = line[i]
        if quote:
            if ch == "\\" and quote == '"':
                i += 2
                continue
            if ch == quote:
                quote = None
        elif ch in "'\"":
            quote = ch
        elif ch == ">":
            if line[i + 1:i + 2] == ">":
                return line[:i], line[i + 2:].strip(), "a"
            return line[:i], line[i + 1:].strip(), "w"
        i += 1
    return line, None, None


class ShellProvider(QObject):
    """Exposed to QML as ``Shell``."""

    def __init__(self, storage, prefs, system, parent=None):
        super().__init__(parent)
        self._storage = storage
        self._prefs = prefs
        self._system = system

    # ------------------------------------------------------------------- API
    @Slot(str, str, result="QVariantMap")
    def run(self, cwd: str, line: str) -> dict:
        self._cwd = normalize(cwd or "/")
        self._out: List[dict] = []
        self._actions: List[dict] = []
        self._clear = False
        self._dropped = 0
        line = (line or "").strip()
        if len(line) > MAX_COMMAND_LENGTH:
            self._err("glassh: command too long")
            line = ""
        if line:
            try:
                self._dispatch(line)
            except Exception as exc:  # a shell must never crash the OS
                log.exception("command failed: %s", line)
                self._err(f"glassh: {exc}")
        if len(self._out) > MAX_OUTPUT_LINES:
            hidden = len(self._out) - MAX_OUTPUT_LINES + self._dropped
            self._out = self._out[:MAX_OUTPUT_LINES]
            self._out.append(_line(f"… {hidden} more line(s) not shown (open the file in GlassPad instead)", "dim"))
        return {"lines": self._out, "cwd": self._cwd, "clear": self._clear, "actions": self._actions}

    @Slot(str, str, result="QVariantList")
    def complete(self, cwd: str, partial: str) -> list:
        """Tab completion for the last word."""
        cwd = normalize(cwd or "/")
        words = partial.split(" ")
        last = words[-1]
        if len(words) == 1:
            cmds = sorted(self._commands().keys())
            return [c for c in cmds if c.startswith(last)]
        if "/" in last:
            head, prefix = last.rsplit("/", 1)
            directory = self._abs(cwd, head or "/")
            head += "/"
        else:
            head, prefix, directory = "", last, cwd
        out = []
        for e in self._storage.list(directory):
            if e["name"].lower().startswith(prefix.lower()):
                out.append(head + e["name"] + ("/" if e["isDir"] else ""))
        return out

    # -------------------------------------------------------------- plumbing
    def _say(self, text="", color=""):
        chunks = str(text).split("\n")
        room = MAX_OUTPUT_LINES + 1 - len(self._out)
        if room < len(chunks):  # don't build huge lists we'd throw away anyway
            self._dropped += len(chunks) - max(0, room)
            chunks = chunks[:max(0, room)]
        self._out.extend(_line(c, color) for c in chunks)

    def _err(self, text):
        self._say(text, "err")

    @staticmethod
    def _abs(cwd: str, path: str) -> str:
        if not path or path == "~":
            return "/"
        if path.startswith("~/"):
            path = path[1:]
        return normalize(path if path.startswith("/") else join(cwd, path))

    def _commands(self):
        return {
            "help": self._help, "ls": self._ls, "dir": self._ls, "cd": self._cd, "pwd": self._pwd,
            "cat": self._cat, "type": self._cat, "touch": self._touch, "mkdir": self._mkdir,
            "echo": self._echo, "rm": self._rm, "del": self._rm, "cp": self._cp, "mv": self._mv,
            "find": self._find, "tree": self._tree, "open": self._open, "start": self._open,
            "apps": self._apps, "calc": self._calc_cmd, "neofetch": self._neofetch,
            "fortune": self._fortune, "cowsay": self._cowsay, "matrix": self._matrix,
            "date": self._date, "whoami": self._whoami, "uname": self._uname, "clear": self._clear_cmd,
            "cls": self._clear_cmd, "exit": self._exit, "accent": self._accent,
            "wallpaper": self._wallpaper, "lock": self._lock, "history": self._history,
            "sudo": self._sudo, "hello": self._hello,
            "zip": self._zip, "unzip": self._unzip, "extract": self._unzip, "lsarchive": self._lsarchive,
        }

    def _dispatch(self, line: str):
        redirect, mode = None, None
        if not line.lower().startswith("calc"):  # calc uses '>' nowhere, but keep math untouched
            line, redirect, mode = split_redirect(line)
        try:
            argv = shlex.split(line)
        except ValueError:
            argv = line.split()
        if not argv:
            self._err("glassh: missing command before '>'")
            return
        cmd, args = argv[0].lower(), argv[1:]
        handler = self._commands().get(cmd)
        if handler is None:
            if cmd in APP_ALIASES:
                self._actions.append({"type": "launch", "app": APP_ALIASES[cmd]})
                self._say(f"Launching {APP_ALIASES[cmd]}…", "dim")
                return
            self._err(f"glassh: command not found: {cmd}")
            self._say("Type 'help' to see what I can do.", "dim")
            return
        if redirect is not None:
            start = len(self._out)
            handler(args)
            produced = "\n".join(l["text"] for l in self._out[start:])
            del self._out[start:]
            self._write_redirect(redirect, produced, mode)
            return
        handler(args)

    def _write_redirect(self, target: str, text: str, mode: str):
        if not target:
            self._err("glassh: no file after '>'")
            return
        path = self._abs(self._cwd, target)
        if self._storage.isDir(path):
            self._err(f"glassh: {target}: is a folder")
            return
        existing = ""
        if mode == "a" and self._storage.exists(path):
            existing = self._storage.readText(path).get("text", "")
            if existing and not existing.endswith("\n"):
                existing += "\n"
        if not self._storage.writeText(path, existing + text + "\n"):
            self._err(f"glassh: cannot write {target}")

    # -------------------------------------------------------------- commands
    def _help(self, args):
        self._say("GlassShell — commands", "accent")
        for cmd, desc in HELP:
            if not desc:
                self._say(cmd, "warn")
            else:
                self._say(f"{cmd:<26}{desc}")

    def _ls(self, args):
        long = "-l" in args
        targets = [a for a in args if not a.startswith("-")] or ["."]
        path = self._abs(self._cwd, targets[0])
        if not self._storage.exists(path):
            self._err(f"ls: {targets[0]}: no such file or folder")
            return
        if not self._storage.isDir(path):
            self._say(path.rsplit("/", 1)[-1])
            return
        entries = self._storage.list(path)
        if not entries:
            self._say("(empty)", "dim")
            return
        if long:
            for e in entries:
                when = _dt.datetime.fromtimestamp(e["modified"] / 1000).strftime("%b %d %H:%M")
                size = "<DIR>" if e["isDir"] else _human(e["size"])
                self._say(f"{size:>9}  {when}  {e['name']}{'/' if e['isDir'] else ''}", "accent" if e["isDir"] else "")
        else:
            row = "   ".join((e["name"] + "/") if e["isDir"] else e["name"] for e in entries)
            self._say(row)

    def _cd(self, args):
        path = self._abs(self._cwd, args[0] if args else "~")
        if not self._storage.isDir(path):
            self._err(f"cd: {args[0] if args else '~'}: not a folder")
            return
        self._cwd = path

    def _pwd(self, args):
        self._say(self._cwd)

    def _cat(self, args):
        if not args:
            self._err("cat: which file?")
            return
        for a in args:
            path = self._abs(self._cwd, a)
            res = self._storage.readText(path)
            if res.get("ok"):
                self._say(res["text"].rstrip("\n") if res["text"] else "")
            else:
                self._err(f"cat: {a}: {res.get('error', 'cannot read')}")

    def _touch(self, args):
        for a in args or []:
            path = self._abs(self._cwd, a)
            if self._storage.exists(path):
                continue
            if not self._storage.isDir(parent_of(path)) or not self._storage.writeText(path, ""):
                self._err(f"touch: cannot create {a}")
        if not args:
            self._err("touch: which file?")

    def _mkdir(self, args):
        if not args:
            self._err("mkdir: which folder?")
        for a in args:
            path = self._abs(self._cwd, a)
            if self._storage.exists(path):
                self._err(f"mkdir: {a}: already exists")
            elif not self._storage.createFolder(parent_of(path), path.rsplit("/", 1)[-1]):
                self._err(f"mkdir: cannot create {a}")

    def _echo(self, args):
        self._say(" ".join(args))

    def _rm(self, args):
        paths = [a for a in args if not a.startswith("-")]
        if not paths:
            self._err("rm: what should I remove?")
            return
        for a in paths:
            path = self._abs(self._cwd, a)
            if not self._storage.exists(path):
                self._err(f"rm: {a}: no such file or folder")
            elif path == TRASH or path.startswith(TRASH + "/"):
                self._err("rm: use 'Empty Recycle Bin' from the Recycle Bin window")
            elif self._storage.trash([path]):
                self._say(f"{a} moved to the Recycle Bin", "dim")
            else:
                self._err(f"rm: {a}: protected or cannot be removed")

    def _cp(self, args):
        self._transfer(args, copy=True)

    def _mv(self, args):
        self._transfer(args, copy=False)

    def _transfer(self, args, copy: bool):
        name = "cp" if copy else "mv"
        if len(args) < 2:
            self._err(f"{name}: usage: {name} <source> <destination>")
            return
        src = self._abs(self._cwd, args[0])
        dest = self._abs(self._cwd, args[1])
        if not self._storage.exists(src):
            self._err(f"{name}: {args[0]}: no such file or folder")
            return
        if self._storage.isDir(dest):
            ok = self._storage.copyTo([src], dest) if copy else self._storage.move([src], dest)
            if not ok:
                self._err(f"{name}: could not {('copy' if copy else 'move')} {args[0]}")
            return
        # destination is a new name
        if parent_of(dest) == parent_of(src) and not copy:
            if not self._storage.rename(src, dest.rsplit("/", 1)[-1]):
                self._err(f"mv: cannot rename to {args[1]}")
            return
        self._err(f"{name}: {args[1]}: destination folder does not exist")

    def _find(self, args):
        if not args:
            self._err("find: what are you looking for?")
            return
        results = self._storage.search(" ".join(args), self._cwd)
        for r in results[:50]:
            self._say(r["path"] + ("/" if r["isDir"] else ""), "accent" if r["isDir"] else "")
        if not results:
            self._say("Nothing found.", "dim")
        elif len(results) > 50:
            self._say(f"… and {len(results) - 50} more", "dim")

    def _tree(self, args):
        root = self._abs(self._cwd, args[0] if args else ".")
        if not self._storage.isDir(root):
            self._err("tree: not a folder")
            return
        self._say(root, "accent")
        count = [0]

        def walk(path, prefix, depth):
            entries = self._storage.list(path)
            for i, e in enumerate(entries):
                if count[0] > 300:
                    return
                count[0] += 1
                last = i == len(entries) - 1
                self._say(f"{prefix}{'└── ' if last else '├── '}{e['name']}", "accent" if e["isDir"] else "")
                if e["isDir"] and depth < 4:
                    walk(e["path"], prefix + ("    " if last else "│   "), depth + 1)

        walk(root, "", 0)

    def _zip(self, args):
        if len(args) < 2:
            self._err("zip: usage: zip <name.zip> <file-or-folder>…")
            return
        name = args[0] if args[0].lower().endswith(".zip") else args[0] + ".zip"
        target = self._abs(self._cwd, name)
        dest_dir = self._storage.real_path(parent_of(target))
        sources = [self._storage.real_path(self._abs(self._cwd, a)) for a in args[1:]]
        missing = [a for a, r in zip(args[1:], sources) if r is None or not r.exists()]
        if missing:
            self._err(f"zip: {missing[0]}: no such file or folder")
            return
        if dest_dir is None or not dest_dir.is_dir() or self._storage.exists(target):
            self._err(f"zip: can't create {name} (exists or bad folder)")
            return
        n = _archives.compress(sources, dest_dir / target.rsplit("/", 1)[-1])
        self._storage.notifyChanged(parent_of(target))
        self._say(f"{name}: {n} file(s) compressed", "ok")

    def _unzip(self, args):
        if not args:
            self._err("unzip: usage: unzip <archive> [destination-folder]")
            return
        src = self._abs(self._cwd, args[0])
        dest = self._abs(self._cwd, args[1]) if len(args) > 1 else parent_of(src)
        real, real_dest = self._storage.real_path(src), self._storage.real_path(dest)
        if real is None or not real.is_file():
            self._err(f"unzip: {args[0]}: no such archive")
            return
        if real_dest is None or not real_dest.is_dir():
            self._err(f"unzip: {dest}: not a folder")
            return
        try:
            out = _archives.extract(real, real_dest, _archives.stem_of(real.name))
        except _archives.ArchiveError as exc:
            self._err(f"unzip: {exc}")
            return
        self._storage.notifyChanged(dest)
        self._say(f"extracted to {self._storage.to_virtual(out)}", "ok")

    def _lsarchive(self, args):
        if not args:
            self._err("lsarchive: which archive?")
            return
        real = self._storage.real_path(self._abs(self._cwd, args[0]))
        if real is None or not real.is_file():
            self._err(f"lsarchive: {args[0]}: no such archive")
            return
        try:
            info = _archives.list_archive(real, limit=300)
        except _archives.ArchiveError as exc:
            self._err(f"lsarchive: {exc}")
            return
        for e in info["entries"]:
            self._say(f"{('' if e['isDir'] else _human(e['size'])):>9}  {e['name']}{'/' if e['isDir'] else ''}", "accent" if e["isDir"] else "")
        self._say(f"{info['count']} entries, {_human(info['total'])} uncompressed", "dim")

    def _open(self, args):
        if not args:
            self._err("open: what should I open?")
            return
        target = " ".join(args)
        if target.lower() in APP_ALIASES:
            self._actions.append({"type": "launch", "app": APP_ALIASES[target.lower()]})
            return
        path = self._abs(self._cwd, target)
        if not self._storage.exists(path):
            self._err(f"open: {target}: no such file, folder or app")
            return
        self._actions.append({"type": "open", "path": path})

    def _apps(self, args):
        seen = []
        for alias, app in APP_ALIASES.items():
            if app not in seen:
                seen.append(app)
                self._say(f"  {alias:<12}→ {app}")

    def _calc_cmd(self, args):
        expr = " ".join(args)
        if not expr:
            self._err("calc: usage: calc 2 + 2")
            return
        try:
            self._say(_calc.format_number(_calc.evaluate(expr)), "ok")
        except _calc.CalcError as exc:
            self._err(f"calc: {exc}")

    def _neofetch(self, args):
        info = self._system.snapshot()
        logo = [
            "    ▄▄████████▄▄    ",
            "  ▄██▀▀      ▀▀██▄  ",
            " ██▀   ▄▄▄▄▄▄   ▀██ ",
            " ██   ██▀▀▀▀██   ██ ",
            " ██   ██▄▄▄▄██   ██ ",
            " ██▄   ▀▀▀▀▀▀   ▄██ ",
            "  ▀██▄▄      ▄▄██▀  ",
            "    ▀▀████████▀▀    ",
        ]
        user = self._prefs.userName.lower().replace(" ", "")
        facts = [
            (f"{user}@glassos", "accent"),
            ("─" * 22, "dim"),
            (f"OS: GlassOS {info['version']}", ""),
            (f"Host: {info['os']}", ""),
            (f"Python: {info['python']}  Qt: {info['qt']}", ""),
            (f"CPU: {info['cpuCores']} cores @ {info['cpuPercent']:.0f}%", ""),
            (f"Memory: {info['memUsed']:.1f} / {info['memTotal']:.1f} GB", ""),
            (f"Uptime: {info['uptime']}", ""),
        ]
        for i in range(max(len(logo), len(facts))):
            left = logo[i] if i < len(logo) else " " * 20
            text, _ = facts[i] if i < len(facts) else ("", "")
            self._out.append(_line(f"{left}  {text}", "accent" if i == 0 else ""))

    def _fortune(self, args):
        self._say(random.choice(FORTUNES), "warn")

    def _cowsay(self, args):
        text = " ".join(args) or random.choice(FORTUNES)
        text = text[:60]
        border = "─" * (len(text) + 2)
        self._say(f" ╭{border}╮\n │ {text} │\n ╰{border}╯\n        \\   ^__^\n         \\  (oo)\\_______\n"
                  f"            (__)\\       )\\/\\\n                ||----w |\n                ||     ||")

    def _matrix(self, args):
        self._actions.append({"type": "matrix"})
        self._say("Wake up, Neo…  (press any key to stop)", "ok")

    def _date(self, args):
        self._say(_dt.datetime.now().strftime("%A, %d %B %Y  %H:%M:%S"))

    def _whoami(self, args):
        self._say(self._prefs.userName)

    def _uname(self, args):
        self._say(f"GlassOS {self._system.snapshot()['version']} on {platform.system()} {platform.machine()}")

    def _clear_cmd(self, args):
        self._clear = True

    def _exit(self, args):
        self._actions.append({"type": "exit"})

    def _accent(self, args):
        presets = {"blue": "#4cc2ff", "purple": "#a78bfa", "pink": "#f472b6", "orange": "#fb923c",
                   "yellow": "#facc15", "green": "#34d399", "teal": "#2dd4bf", "red": "#f87171"}
        if not args:
            self._say("usage: accent <color>   e.g. accent pink, accent #ff8800", "dim")
            self._say("presets: " + ", ".join(presets))
            return
        color = presets.get(args[0].lower(), args[0])
        before = self._prefs.accent.name()
        self._prefs.setAccent(color)
        if self._prefs.accent.name() == before and color.lower() != before:
            self._err(f"accent: '{args[0]}' is not a color")
        else:
            self._say("Accent updated", "ok")

    def _wallpaper(self, args):
        walls = self._storage.wallpapers()
        if not walls:
            self._err("wallpaper: no wallpapers in /Pictures/Wallpapers")
            return
        paths = [w["path"] for w in walls]
        cur = self._prefs.wallpaper
        nxt = paths[(paths.index(cur) + 1) % len(paths)] if cur in paths else paths[0]
        self._prefs.setWallpaper(nxt)
        self._say(f"Wallpaper: {nxt}", "ok")

    def _lock(self, args):
        self._actions.append({"type": "lock"})

    def _history(self, args):
        self._actions.append({"type": "history"})

    def _sudo(self, args):
        self._say(f"{self._prefs.userName} is not in the sudoers file. This incident will be reported.", "warn")

    def _hello(self, args):
        self._say(f"Hey {self._prefs.userName}! Type 'help' to explore.", "accent")


def _human(size: int) -> str:
    for unit in ("B", "KB", "MB", "GB"):
        if size < 1024:
            return f"{size:.0f} {unit}" if unit == "B" else f"{size:.1f} {unit}"
        size /= 1024
    return f"{size:.1f} TB"
