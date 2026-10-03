"""Check argument counts of QML -> Python slot calls against @Slot(...) signatures."""
import ast, glob, os, re, sys
root = sys.argv[1]
CTX = {"Storage": "StorageProvider", "Prefs": "Prefs", "System": "SystemProvider", "Shell": "ShellProvider",
       "Calc": "CalcProvider", "WeatherService": "WeatherProvider", "AdBlocker": "AdBlockerProvider",
       "Visualizer": "AudioVisualizer", "Web": "BrowserService", "Clipboard": "ClipboardService", "Thumbs": "ThumbnailService", "Extensions": "ExtensionService", "Syntax": "SyntaxService"}
sigs = {}
for f in glob.glob(os.path.join(root, "core", "*.py")):
    for cls in [n for n in ast.parse(open(f, encoding="utf-8").read()).body if isinstance(n, ast.ClassDef)]:
        for n in cls.body:
            if isinstance(n, ast.FunctionDef):
                for d in n.decorator_list:
                    if isinstance(d, ast.Call) and getattr(d.func, "id", "") == "Slot":
                        sigs[(cls.name, n.name)] = len(d.args)
def split_args(s):
    depth, cur, out, q = 0, "", [], None
    for ch in s:
        if q:
            cur += ch
            if ch == q: q = None
            continue
        if ch in "\"'`": q = ch
        if ch in "([{": depth += 1
        if ch in ")]}": depth -= 1
        if ch == "," and depth == 0: out.append(cur); cur = ""
        else: cur += ch
    if cur.strip(): out.append(cur)
    return out
problems = 0
for f in glob.glob(os.path.join(root, "qml", "**", "*.qml"), recursive=True):
    src = open(f, encoding="utf-8").read()
    for m in re.finditer(r"\b(" + "|".join(CTX) + r")\.(\w+)\(", src):
        start = m.end(); depth = 1; i = start
        while i < len(src) and depth:
            depth += {"(": 1, ")": -1}.get(src[i], 0); i += 1
        args = split_args(src[start:i - 1])
        key = (CTX[m.group(1)], m.group(2))
        if key in sigs and len(args) != sigs[key]:
            line = src[:m.start()].count("\n") + 1
            print(f"{os.path.relpath(f, root)}:{line}: {m.group(1)}.{m.group(2)} called with {len(args)} arg(s), slot takes {sigs[key]}")
            problems += 1
print(f"{problems} arity problem(s)")
