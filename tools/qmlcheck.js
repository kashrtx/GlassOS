#!/usr/bin/env node
// QML static checker for GlassOS.
//  * parses QML object structure (objects, ids, properties, functions, signals, bindings)
//  * syntax-checks every JS snippet with the TypeScript parser
//  * resolves every free identifier (JS scope, ids, properties, delegate roles, globals)
//  * checks member access on Python context objects against the real Python API
//  * checks member access / property assignment on local QML components against their API
const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");
const ts = require(path.join(execSync("npm root -g").toString().trim(), "typescript"));

const projectRoot = process.argv[2];
const qmlRoot = path.join(projectRoot, "qml");

// ------------------------------------------------------------------ lexer
function lex(src) {
  const toks = [];
  let i = 0, line = 1;
  const push = (t, v, s, e) => toks.push({ t, v, s, e, line });
  while (i < src.length) {
    const c = src[i];
    if (c === "\n") { push("nl", "\n", i, i + 1); line++; i++; continue; }
    if (/\s/.test(c)) { i++; continue; }
    if (c === "/" && src[i + 1] === "/") { while (i < src.length && src[i] !== "\n") i++; continue; }
    if (c === "/" && src[i + 1] === "*") { const j = src.indexOf("*/", i + 2); for (let k = i; k < j; k++) if (src[k] === "\n") line++; i = j + 2; continue; }
    if (c === '"' || c === "'" || c === "`") {
      const s = i; i++;
      while (i < src.length && src[i] !== c) { if (src[i] === "\\") i++; if (src[i] === "\n") line++; i++; }
      i++; push("str", src.slice(s, i), s, i); continue;
    }
    if (/[A-Za-z_$]/.test(c)) { const s = i; while (i < src.length && /[\w$]/.test(src[i])) i++; push("id", src.slice(s, i), s, i); continue; }
    if (/[0-9]/.test(c)) { const s = i; while (i < src.length && /[\w.]/.test(src[i])) i++; push("num", src.slice(s, i), s, i); continue; }
    // regex literal (only after an operator-ish token)
    if (c === "/") {
      const prev = toks.length ? toks[toks.length - 1] : null;
      if (!prev || (prev.t === "p" && "(,=:[!&|?{};+-*%<>~^".includes(prev.v.slice(-1))) || (prev.t === "id" && prev.v === "return")) {
        const s = i; i++;
        let inClass = false;
        while (i < src.length && (src[i] !== "/" || inClass) && src[i] !== "\n") { if (src[i] === "\\") i++; else if (src[i] === "[") inClass = true; else if (src[i] === "]") inClass = false; i++; }
        i++; while (/[a-z]/.test(src[i])) i++;
        push("str", src.slice(s, i), s, i); continue;
      }
    }
    const three = src.substr(i, 3), two = src.substr(i, 2);
    const ops3 = ["===", "!==", "...", ">>>", "**="], ops2 = ["==", "!=", "<=", ">=", "&&", "||", "=>", "++", "--", "+=", "-=", "*=", "/=", "?.", "??", "**", "<<", ">>"];
    if (ops3.includes(three)) { push("p", three, i, i + 3); i += 3; continue; }
    if (ops2.includes(two)) { push("p", two, i, i + 2); i += 2; continue; }
    push("p", c, i, i + 1); i++;
  }
  push("eof", "", src.length, src.length);
  return toks;
}

// ----------------------------------------------------------------- parser
function parseQml(file) {
  const src = fs.readFileSync(file, "utf8");
  const toks = lex(src);
  let p = 0;
  const errors = [];
  const peek = (k = 0) => { let q = p, n = 0; while (true) { const t = toks[q]; if (t.t !== "nl") { if (n === k) return t; n++; } q++; } };
  const next = () => { while (toks[p].t === "nl") p++; return toks[p++]; };
  const skipNl = () => { while (toks[p].t === "nl" || (toks[p].t === "p" && toks[p].v === ";")) p++; };
  const err = (msg, t) => errors.push({ file, line: (t || toks[p]).line, msg });

  const imports = [];
  let pragmaSingleton = false;
  skipNl();
  while (toks[p].t === "id" && (toks[p].v === "import" || toks[p].v === "pragma")) {
    const kw = toks[p].v; let s = toks[p].s; while (toks[p].t !== "nl" && toks[p].t !== "eof") p++;
    const text = src.slice(s, toks[p].s).trim();
    if (kw === "import") imports.push(text); else if (/Singleton/.test(text)) pragmaSingleton = true;
    skipNl();
  }

  function readDotted() {
    let t = next(); let name = t.v; const line = t.line;
    while (toks[p].t === "p" && toks[p].v === "." && toks[p + 1].t === "id") { p++; name += "." + toks[p].v; p++; }
    return { name, line };
  }

  function matchClose(open, close) { // p at opening token; returns index after close
    let depth = 0;
    for (; p < toks.length; p++) {
      const t = toks[p];
      if (t.t === "p" && t.v === open) depth++;
      else if (t.t === "p" && t.v === close) { depth--; if (depth === 0) { p++; return; } }
      if (t.t === "eof") { err(`unbalanced ${open}`); return; }
    }
  }

  const CONT_END = new Set(["+", "-", "*", "/", "%", "&&", "||", "?", ":", ",", "=", "==", "===", "!=", "!==", "<", ">", "<=", ">=", "=>", ".", "(", "[", "!", "??", "?.", "+=", "-=", "&", "|"]);
  const CONT_START = new Set(["?", ":", ".", "&&", "||", "+", "*", "/", "%", "===", "!==", "==", "!=", "??", "?."]);

  function readExpr() { // returns {code, line, start}
    const startTok = toks[p];
    while (toks[p].t === "nl") p++;
    const s = toks[p].s, line = toks[p].line;
    let depth = 0, last = null;
    for (; ; p++) {
      const t = toks[p];
      if (t.t === "eof") break;
      if (t.t === "p" && "([{".includes(t.v)) depth++;
      if (t.t === "p" && ")]}".includes(t.v)) { if (depth === 0) break; depth--; }
      if (depth === 0 && t.t === "p" && t.v === ";") break;
      if (depth === 0 && t.t === "nl") {
        let q = p; while (toks[q].t === "nl") q++;
        const nt = toks[q];
        const contEnd = last && last.t === "p" && CONT_END.has(last.v);
        const contStart = nt.t === "p" && CONT_START.has(nt.v);
        if (!contEnd && !contStart) break;
        continue;
      }
      if (t.t !== "nl") last = t;
    }
    const e = last ? last.e : s;
    return { code: src.slice(s, e), line, start: s };
  }

  function parseObject(type, line, parentObj, onProp) {
    const obj = { type, line, id: null, props: {}, funcs: {}, signals: {}, bindings: [], children: [], parent: parentObj, on: onProp || null, isGroup: false, file };
    const t = next(); if (t.v !== "{") { err(`expected '{' after ${type}`, t); return obj; }
    parseBody(obj);
    return obj;
  }

  function parseBody(obj) {
    while (true) {
      skipNl();
      const t = toks[p];
      if (t.t === "eof") { err("unexpected end of file (missing '}')"); return; }
      if (t.t === "p" && t.v === "}") { p++; return; }
      if (t.t !== "id") { err(`unexpected token '${t.v}' in object body`, t); p++; continue; }
      const kw = t.v;
      if (kw === "id" && peek(1).v === ":") { next(); next(); obj.id = next().v; continue; }
      if (["property", "readonly", "default", "required"].includes(kw) && (kw === "property" || ["property", "readonly", "default", "required"].includes(peek(1).v))) {
        while (["readonly", "default", "required"].includes(toks[p].v)) next();
        if (next().v !== "property") { err("expected 'property'"); continue; }
        let ptype = next().v;
        if (toks[p].v === "<") { p++; ptype += "<" + next().v + ">"; p++; }
        const nameTok = next();
        obj.props[nameTok.v] = { type: ptype, line: nameTok.line };
        if (toks[p].t === "p" && toks[p].v === ":") { p++; parseValue(obj, nameTok.v, nameTok.line, ptype === "alias"); }
        continue;
      }
      if (kw === "signal") { next(); const n = next(); const params = []; if (toks[p].v === "(") { const s = p; matchClose("(", ")"); for (let q = s; q < p; q++) if (toks[q].t === "id") params.push(toks[q].v); }
        obj.signals[n.v] = params.filter((x, i) => i % 2 === 1 || params.length === 1); continue; }
      if (kw === "function") {
        const s = toks[p].s, fl = toks[p].line; next(); const n = next();
        matchClose("(", ")"); while (toks[p].t === "nl") p++;
        if (toks[p].v === ":") { p++; next(); } // type annotation
        while (toks[p].t === "nl") p++;
        matchClose("{", "}");
        obj.funcs[n.v] = { line: fl };
        obj.bindings.push({ name: n.v, code: src.slice(s, toks[p - 1].e), line: fl, kind: "function" });
        continue;
      }
      if (kw === "enum") { next(); next(); matchClose("{", "}"); continue; }
      const d = readDotted();
      const nt = toks[p];
      if (nt.t === "p" && nt.v === "{") {
        if (/^[A-Z]/.test(d.name.split(".").pop())) obj.children.push(parseObject(d.name, d.line, obj));
        else { const g = parseObject(d.name, d.line, obj); g.isGroup = true; obj.children.push(g); }
        continue;
      }
      if (nt.t === "id" && nt.v === "on") { p++; const target = readDotted(); obj.children.push(parseObject(d.name, d.line, obj, target.name)); continue; }
      if (nt.t === "p" && nt.v === ":") { p++; parseValue(obj, d.name, d.line, false); continue; }
      err(`cannot parse member '${d.name}' (next token '${nt.v}')`, nt);
      p++;
    }
  }

  function parseValue(obj, name, line, isAlias) {
    while (toks[p].t === "nl") p++;
    const t = toks[p];
    if (t.t === "id" && /^[A-Z]/.test(t.v)) {
      // Type { ... }  or Type.Enum expression
      let q = p + 1; while (toks[q].t === "p" && toks[q].v === "." && toks[q + 1].t === "id") q += 2;
      while (toks[q].t === "nl") q++;
      if (toks[q].t === "p" && toks[q].v === "{") {
        const d = readDotted();
        const child = parseObject(d.name, d.line, obj); child.assignedTo = name; obj.children.push(child); return;
      }
    }
    if (t.t === "p" && t.v === "[") {
      // list of objects?
      let q = p + 1; while (toks[q].t === "nl") q++;
      if (toks[q].t === "id" && /^[A-Z]/.test(toks[q].v)) {
        let r = q + 1; while (toks[r].t === "p" && toks[r].v === "." ) r += 2; while (toks[r].t === "nl") r++;
        if (toks[r].v === "{") {
          p++;
          while (true) { skipNl(); if (toks[p].v === "]") { p++; break; } if (toks[p].v === ",") { p++; continue; }
            const d = readDotted(); const child = parseObject(d.name, d.line, obj); child.assignedTo = name; obj.children.push(child); }
          return;
        }
      }
    }
    const ex = readExpr();
    obj.bindings.push({ name, code: ex.code, line: ex.line, kind: isAlias ? "alias" : (/^(on[A-Z]|.*\.on[A-Z])/.test(name) ? "handler" : "expr") });
  }

  skipNl();
  let root = null;
  if (toks[p].t === "id") { const d = readDotted(); root = parseObject(d.name, d.line, null); }
  else err("no root object");
  return { file, imports, root, errors, pragmaSingleton, src };
}

// ------------------------------------------------------ knowledge tables
const JS_GLOBALS = new Set(("Math JSON Date Number String Array Object Boolean RegExp Error TypeError parseInt parseFloat isNaN isFinite " +
  "console undefined NaN Infinity encodeURIComponent decodeURIComponent encodeURI escape Promise Map Set Symbol Qt qsTr print " +
  "arguments this gc Intl").split(" "));
const QML_TYPES = new Set(("Item Rectangle Text Image AnimatedImage MouseArea Row Column Grid Flow Repeater ListView GridView PathView Flickable Loader " +
  "Component Timer Behavior NumberAnimation ColorAnimation RotationAnimation ParallelAnimation SequentialAnimation PauseAnimation " +
  "ScriptAction PropertyAction PropertyAnimation SmoothedAnimation SpringAnimation Gradient GradientStop FocusScope TextInput TextEdit Canvas " +
  "ShaderEffectSource ShaderEffect Scale Rotation Translate Connections Shortcut QtObject ListModel ListElement Keys Window ApplicationWindow " +
  "Popup ToolTip TextField TextArea ScrollView ScrollBar ScrollIndicator Slider Switch Button AbstractButton Menu MenuItem MenuSeparator " +
  "ComboBox BusyIndicator Label Control Overlay Pane Frame Dialog RowLayout ColumnLayout GridLayout Layout StackLayout StackView SwipeView " +
  "WebEngineView WebEngineProfile WebEngine WebEngineDownloadRequest WebEngineNewWindowRequest WebEngineLoadingInfo WebEngineView " +
  "DragHandler TapHandler HoverHandler WheelHandler PinchHandler PointHandler Binding Instantiator Easing Font Screen Drag DropArea " +
  "Accessible LayoutMirroring EnterKey Positioner ViewTransition Transition State StateGroup PropertyChanges AnchorChanges ItemGrabResult " +
  "IntValidator DoubleValidator RegularExpressionValidator Locale TextMetrics FontMetrics FileDialog Path PathLine PathArc Shape ShapePath " +
  "XAnimator YAnimator OpacityAnimator ScaleAnimator RotationAnimator Animation Matrix4x4 SystemPalette Palette PointerDevice " +
  "QtQuick ButtonGroup CheckBox RadioButton ProgressBar SpinBox Tumbler ToolButton TabBar TabButton StandardKey Qt Component FolderDialog MessageDialog ColorDialog FontDialog DragEvent MediaPlayer AudioOutput VideoOutput MediaMetaData WebEngineScript MultiEffect GraphicsInfo").split(" "));
const CONTEXT = { Storage: "StorageProvider", Prefs: "Prefs", System: "SystemProvider", Shell: "ShellProvider", Calc: "CalcProvider",
  WeatherService: "WeatherProvider", AdBlocker: "AdBlockerProvider", HasWebEngine: null, LaunchArgs: null,
  HasMultimedia: null, Visualizer: "AudioVisualizer", Web: "BrowserService", BrowserProfile: null, Clipboard: "ClipboardService", Thumbs: "ThumbnailService", Extensions: "ExtensionService", Syntax: "SyntaxService" };
const CONVENTIONS = { hostWindow: "GlassWindow", wm: "Main", win: "GlassWindow", w: "GlassWindow" };
// Generous list of built-in property / signal-param names. Unknown lowercase names
// not in this list are reported so they can be reviewed.
const BUILTIN = new Set(`x y z width height implicitWidth implicitHeight parent visible enabled opacity anchors text color font
 radius border gradient source fillMode clip focus activeFocus scale rotation transform transformOrigin state states transitions
 children data resources childrenRect antialiasing smooth layer containsMouse pressed hoverEnabled acceptedButtons cursorShape
 mouseX mouseY drag propagateComposedEvents preventStealing pressedButtons spacing padding leftPadding rightPadding topPadding bottomPadding
 model delegate count currentIndex currentItem contentX contentY contentWidth contentHeight contentItem flickableDirection boundsBehavior
 orientation interactive moving dragging flicking atYBeginning atYEnd atXBeginning atXEnd verticalVelocity cacheBuffer section header footer
 highlight highlightFollowsCurrentItem keyNavigationEnabled snapMode cellWidth cellHeight flow layoutDirection columns rows
 running repeat interval triggeredOnStart duration from to easing loops paused target property properties value alwaysRunToEnd
 status progress item active asynchronous sourceComponent sourceSize paintedWidth paintedHeight mirror cache autoTransform
 horizontalAlignment verticalAlignment wrapMode elide maximumLineCount lineCount textFormat lineHeight style styleColor
 selectByMouse selectedText selectionStart selectionEnd cursorPosition cursorVisible readOnly echoMode inputMask validator
 maximumLength acceptableInput placeholderText placeholderTextColor length canUndo canRedo persistentSelection selectionColor selectedTextColor
 textDocument tabStopDistance cursorRectangle inputMethodHints overwriteMode renderType baseUrl
 modal dim closePolicy opened margins leftMargin rightMargin topMargin bottomMargin background enter exit popupType
 delay timeout from stepSize snapMode live position visualPosition availableWidth availableHeight handle checked checkable
 down hovered icon display autoRepeat flat highlighted
 sequence sequences context autoRepeat
 url title loading loadProgress canGoBack canGoForward zoomFactor profile settings icon backgroundColor
 index modelData model mouse wheel event close request loadRequest download key modifiers accepted button buttons angleDelta pixelDelta
 inverted point eventPoint
 objectName wm hostWindow
 contentData background palette locale
 baselineOffset fill centerIn left right top bottom horizontalCenter verticalCenter baseline
 policy size minimumSize stepSize
 tapCount gesturePolicy grabPermissions acceptedModifiers longPressThreshold
 restoreMode when delayed
 textEdited accepted editingFinished
 targetProperty
 gc
 positionViewAtIndex
 sourceItem hideSource recursive mipmap format textureSize
 frameCount currentFrame playing
 window screen
 implicitBackgroundWidth implicitContentWidth
 effectiveHorizontalAlignment
 contentHeight
 ignoreUnknownSignals
 xScale yScale origin angle axis
 minimumValue maximumValue
 lineWidth
 available
 dragThreshold
 contentWidth
 bottomInset topInset leftInset rightInset
 inputMethodComposing preeditText
 visibility flags minimumWidth minimumHeight active activeFocusItem
 pixelSize pointSize family bold italic weight letterSpacing wordSpacing capitalization underline strikeout hintingPreference
 renderTarget contextType canvasSize canvasWindow available
 originX originY selectedFiles selectedFile selectedFolder currentFolder fileMode nameFilters acceptLabel maskEnabled maskSource maskThresholdMin maskSpreadAtMin textDocument windowCloseRequested recentlyAudible recommendedState lifecycleState inspectedView devToolsView reloadAndBypassCache isFinished isPaused downloadFileName downloadDirectory receivedBytes totalBytes playbackState mediaStatus duration position seekable hasVideo hasAudio playbackRate metaData loops audioOutput videoOutput stringValue play setPosition errorString volume muted hovered
 getContext requestPaint forceActiveFocus selectAll deselect select copy paste cut undo redo clear insert remove
 positionAt positionToRectangle open close toggle start stop restart increase decrease positionViewAtEnd
 positionViewAtBeginning incrementCurrentIndex decrementCurrentIndex indexAt itemAt append setProperty get move reload
 goBack goForward runJavaScript triggerWebAction findText returnToBounds flick cancelFlick forceLayout accept cancel
 pause resume complete setSource containsDrag audioMuted ensureVisible nextItemInFocusChain lineHeightMode mapToItem mapFromItem mapToGlobal
`.split(/\s+/).filter(Boolean));

const BUILTIN_SIGNALS = new Set("clicked doubleClicked pressAndHold toggled moved closed opened aboutToShow aboutToHide accepted rejected editingFinished textEdited activated triggered finished started stopped loaded canceled released pressed entered exited wheel positionChanged".split(" "));
function pythonApi() {
  const out = {};
  const py = `
import ast, json, glob, os
res = {}
for f in glob.glob(os.path.join(${JSON.stringify(projectRoot)}, "core", "*.py")):
    tree = ast.parse(open(f, encoding="utf-8").read())
    for cls in [n for n in tree.body if isinstance(n, ast.ClassDef)]:
        api = {"slots": [], "props": [], "signals": [], "writable": []}
        for n in cls.body:
            if isinstance(n, ast.Assign) and isinstance(n.value, ast.Call) and getattr(n.value.func, "id", "") == "Signal":
                api["signals"] += [t.id for t in n.targets if isinstance(t, ast.Name)]
            if isinstance(n, ast.FunctionDef):
                for d in n.decorator_list:
                    fn = d.func if isinstance(d, ast.Call) else d
                    name = getattr(fn, "id", None) or getattr(fn, "attr", None)
                    if name == "Slot": api["slots"].append(n.name)
                    if name == "Property": api["props"].append(n.name)
                    if name == "setter": api["writable"].append(n.name)
        res[cls.name] = api
print(json.dumps(res))`;
  return JSON.parse(execSync("python3 -", { input: py }).toString());
}

// --------------------------------------------------------------- analysis
function collectFiles(dir) {
  let out = [];
  for (const f of fs.readdirSync(dir)) {
    const full = path.join(dir, f);
    if (fs.statSync(full).isDirectory()) out = out.concat(collectFiles(full));
    else if (f.endsWith(".qml")) out.push(full);
  }
  return out;
}

const files = collectFiles(qmlRoot);
const parsed = {};
for (const f of files) parsed[f] = parseQml(f);
const PY = pythonApi();

// component registry: name -> parsed file (by file basename); apps/components/ui directories
const components = {};
for (const f of files) components[path.basename(f, ".qml")] = parsed[f];

function walk(obj, fn) { fn(obj); for (const c of obj.children) walk(c, fn); }
const BOUNDARY_PROPS = new Set(["delegate", "header", "footer", "highlight", "sourceComponent"]);
function isBoundary(o) {
  return !!o.parent && (o.parent.type === "Component" || BOUNDARY_PROPS.has(o.assignedTo) ||
    ((o.parent.type === "Repeater" || o.parent.type === "Instantiator") && !o.assignedTo));
}
function boundaryChain(o) { const out = []; for (let c = o; c; c = c.parent) if (isBoundary(c)) out.push(c); return out; }
function boundaryOf(o) { for (let c = o; c; c = c.parent) if (isBoundary(c)) return c; return null; }

function apiOf(compName, seen = new Set()) {
  const pf = components[compName];
  if (!pf || !pf.root || seen.has(compName)) return null;
  seen.add(compName);
  const r = pf.root;
  const api = new Set([...Object.keys(r.props), ...Object.keys(r.funcs), ...Object.keys(r.signals)]);
  for (const s of Object.keys(r.signals)) api.add("on" + s[0].toUpperCase() + s.slice(1));
  for (const pr of Object.keys(r.props)) api.add("on" + pr[0].toUpperCase() + pr.slice(1) + "Changed");
  const base = apiOf(r.type, seen);
  if (base) for (const b of base) api.add(b);
  return api;
}

function propTypeOf(compName, prop) {
  const pf = components[compName];
  if (!pf || !pf.root) return null;
  const pr = pf.root.props[prop];
  if (pr && components[pr.type]) return pr.type;
  if (CONVENTIONS[prop]) return CONVENTIONS[prop];
  return null;
}

const problems = [];
const report = (file, line, msg) => problems.push(`${path.relative(projectRoot, file)}:${line}: ${msg}`);

// A context property (setContextProperty) is SHADOWED inside any file that can see a
// QML type of the same name (its own directory is imported implicitly). QML resolves the
// type first, so `Name.method()` silently calls nothing. This broke AeroBrowser once.
for (const f of files) {
  const dirTypes = new Set(files.filter(g => path.dirname(g) === path.dirname(f)).map(g => path.basename(g, ".qml")));
  const src = fs.readFileSync(f, "utf8");
  for (const name of Object.keys(CONTEXT)) {
    if (!dirTypes.has(name)) continue;
    const re = new RegExp("\\b" + name + "\\.[a-z]");
    const m = src.match(re);
    if (m) report(f, src.slice(0, m.index).split("\n").length, `context property '${name}' is shadowed by ${name}.qml in this folder (QML resolves the type first) - rename one of them`);
  }
}
for (const f of files) {
  const pf = parsed[f];
  for (const e of pf.errors) report(e.file, e.line, "PARSE: " + e.msg);
  if (!pf.root) continue;
  // ids in file
  const ids = {};
  walk(pf.root, o => { if (o.id) { if (ids[o.id]) report(f, o.line, `duplicate id '${o.id}'`); ids[o.id] = o; } });
  // (1) the same property/handler assigned twice in one object: QML refuses to load the file
  walk(pf.root, o => {
    const seen = {};
    for (const b of o.bindings || []) {
      if (b.kind === "alias") continue;
      if (seen[b.name]) report(f, b.line, `'${b.name}' is set more than once in this ${o.type} (first on line ${seen[b.name]}) - QML won't load this file`);
      else seen[b.name] = b.line;
    }
  });
  // (2) a Layout child sized from a sibling in the same layout: the sizes feed back
  //     into each other and the layout never settles (polish loop, freezes)
  walk(pf.root, o => {
    if (!/^(RowLayout|ColumnLayout|GridLayout)$/.test(o.type)) return;
    const kids = (o.children || []).filter(c => !c.isGroup);
    const sibIds = kids.map(c => c.id).filter(Boolean);
    for (const c of kids) {
      const sizeBindings = (c.bindings || []).filter(b => /^(Layout\.(preferred|minimum|maximum)(Width|Height)|width|height)$/.test(b.name));
      for (const g of (c.children || []).filter(x => x.isGroup && x.type === "Layout")) for (const b of g.bindings || []) sizeBindings.push({ name: "Layout." + b.name, code: b.code, line: b.line });
      for (const b of sizeBindings) for (const sid of sibIds) {
        if (sid === c.id) continue;
        if (new RegExp("\\b" + sid + "\\.(width|height|implicitWidth|implicitHeight)\\b").test(b.code))
          report(f, b.line, `${b.name} reads sibling '${sid}' inside the same ${o.type}: layout feedback loop (polish loop / freeze)`);
      }
    }
  });
  // ListModel roles / append keys / setProperty role names in file
  const roles = new Set();
  for (const m of pf.src.matchAll(/\.(?:append|insert|set)\(\s*(?:[\w.]+\s*,\s*)?\{([^}]*)\}/g)) for (const k of m[1].matchAll(/([A-Za-z_]\w*)\s*:/g)) roles.add(k[1]);
  for (const m of pf.src.matchAll(/setProperty\([^,]+,\s*"(\w+)"/g)) roles.add(m[1]);
  walk(pf.root, o => { if (o.type === "ListElement") for (const b of o.bindings) roles.add(b.name); });
  const singletonNames = new Set(["UI"]);
  for (const imp of pf.imports) { const m = imp.match(/\bas\s+(\w+)\s*$/); if (m) singletonNames.add(m[1]); }

  // per object checks
  const RESERVED = new Set("x y z width height state states visible enabled opacity scale rotation clip focus children data parent anchors transform smooth antialiasing activeFocus implicitWidth implicitHeight transitions layer objectName".split(" "));
  // QML refuses methods/properties named like JS globals ("Illegal method name")
  const ILLEGAL = new Set("print gc qsTr Qt console Math JSON Date Array Object String Number Boolean RegExp Error parseInt parseFloat isNaN isFinite eval escape unescape encodeURIComponent decodeURIComponent encodeURI decodeURI Symbol Map Set Promise Proxy Reflect undefined NaN Infinity".split(" "));
  const LAYOUTS = new Set(["RowLayout", "ColumnLayout", "GridLayout"]);
  walk(pf.root, obj => {
    for (const fn of Object.keys(obj.funcs)) if (ILLEGAL.has(fn)) report(f, obj.funcs[fn].line, `illegal method name '${fn}' (shadows a JS global)`);
    for (const pn of Object.keys(obj.props)) if (/^[A-Z]/.test(pn)) report(f, obj.props[pn].line, `property '${pn}' must start with a lowercase letter`);
    for (const pn of Object.keys(obj.props)) if (ILLEGAL.has(pn)) report(f, obj.props[pn].line, `illegal property name '${pn}' (shadows a JS global)`);
    // A layout inherits fillWidth/fillHeight from its children unless told otherwise.
    if (LAYOUTS.has(obj.type) && obj.parent && LAYOUTS.has(obj.parent.type)) {
      for (const axis of ["fillHeight", "fillWidth"]) {
        const explicit = obj.bindings.some(b => b.name === "Layout." + axis);
        const kids = obj.children.flatMap(c => (c.type === "Repeater" || c.type === "Instantiator") ? c.children : [c]);
        const childFills = kids.some(c => c.bindings.some(b => b.name === "Layout." + axis && b.code.trim() === "true"));
        const parentAxisMatters = (axis === "fillHeight" && obj.parent.type === "ColumnLayout") || (axis === "fillWidth" && obj.parent.type === "RowLayout");
        if (!explicit && childFills && parentAxisMatters)
          report(f, obj.line, `${obj.type} implicitly inherits Layout.${axis} from a child - set Layout.${axis} explicitly`);
      }
    }
    for (const b of obj.bindings) if ((b.name === "sequence" || b.name === "sequences") && /StandardKey\./.test(b.code))
      report(f, b.line, `StandardKey may map to several key combos on some platforms - use explicit strings`);
    for (const pn of Object.keys(obj.props)) if (RESERVED.has(pn)) report(f, obj.props[pn].line, `property '${pn}' shadows a built-in Item property`);
    // type existence
    if (!obj.isGroup) {
      const tn = obj.type.split(".").pop();
      if (!QML_TYPES.has(tn) && !components[tn]) report(f, obj.line, `unknown type '${obj.type}'`);
    }
    // property assignments on local components
    const compApi = !obj.isGroup ? apiOf(obj.type.split(".").pop()) : null;
    if (compApi) {
      for (const b of obj.bindings) {
        if (b.kind === "function") continue;
        const head = b.name.split(".")[0];
        if (b.name.includes(".") && /^[A-Z]/.test(head)) continue; // attached property e.g. Layout.fillWidth
        if (!compApi.has(head) && !BUILTIN.has(head) && !Object.keys(obj.props).includes(head) && !/^on[A-Z]/.test(head))
          report(f, b.line, `'${obj.type}' has no property '${head}'`);
        if (/^on[A-Z]/.test(head) && !compApi.has(head) && !BUILTIN.has(lcSig(head)) && !BUILTIN_SIGNALS.has(lcSig(head)) && !BUILTIN.has(lcProp(head)) && !obj.props[lcProp(head)])
          report(f, b.line, `'${obj.type}' has no signal for handler '${head}'`);
      }
      for (const c of obj.children) if (c.isGroup && !compApi.has(c.type.split(".")[0]) && !BUILTIN.has(c.type.split(".")[0]) && !/^[A-Z]/.test(c.type))
        report(f, c.line, `'${obj.type}' has no grouped property '${c.type}'`);
    }

    // determine scope chain names
    const scopeNames = new Set();
    const addObjNames = o => {
      for (const k of Object.keys(o.props)) scopeNames.add(k);
      for (const k of Object.keys(o.funcs)) scopeNames.add(k);
      for (const k of Object.keys(o.signals)) scopeNames.add(k);
      const ca = !o.isGroup ? apiOf(o.type.split(".").pop()) : null;
      if (ca) for (const k of ca) scopeNames.add(k);
    };
    addObjNames(obj);
    // walk up to component root: file root or nearest object whose parent is a Component / delegate assignment
    let inDelegate = false;
    let cur = obj;
    while (cur) {
      if (cur.parent && (cur.parent.type === "Component" || cur.assignedTo === "delegate" || cur.parent.type === "Repeater" || cur.parent.type === "Instantiator")) {
        inDelegate = inDelegate || cur.assignedTo === "delegate" || cur.parent.type === "Repeater" || cur.parent.type === "Instantiator";
        addObjNames(cur);
      }
      if (cur.parent && cur.parent.isGroup) addObjNames(cur.parent);
      if (!cur.parent) addObjNames(cur);
      cur = cur.parent;
    }
    // handler parameters: signals declared on the object type
    const sigParams = new Set();
    for (const b of obj.bindings) if (b.kind === "handler") {
      const sig = lcSig(b.name.split(".").pop());
      const comp = components[obj.type.split(".").pop()];
      if (comp && comp.root.signals[sig]) for (const prm of comp.root.signals[sig]) sigParams.add(prm);
      // Connections: handler params come from function declarations (fine)
    }

    for (const b of obj.bindings) {
      if (b.kind === "alias") continue;
      let wrapped;
      if (b.kind === "function") wrapped = b.code;
      else if (b.code.trim().startsWith("{")) wrapped = "function __b__() " + b.code;
      else if (b.kind === "handler" && /^(function\b|\([^)]*\)\s*=>|\w+\s*=>)/.test(b.code.trim())) wrapped = "var __h__ = (\n" + b.code + "\n)";
      else if (b.kind === "handler") wrapped = "function __h__() {\n" + b.code + "\n}";
      else wrapped = "function __b__() { return (\n" + b.code + "\n) }";
      const sf = ts.createSourceFile("x.js", wrapped, ts.ScriptTarget.ES2020, true, ts.ScriptKind.JS);
      for (const d of sf.parseDiagnostics) {
        const pos = sf.getLineAndCharacterOfPosition(d.start);
        report(f, b.line + pos.line - (b.kind === "function" ? 0 : 1), `JS syntax: ${ts.flattenDiagnosticMessageText(d.messageText, " ")} in '${b.name}'`);
      }
      checkIdentifiers(sf, b, obj, { f, ids, roles, scopeNames, sigParams, inDelegate, singletonNames, pf });
    }
  });
}

function lcSig(handler) { const s = handler.replace(/^on/, ""); return s[0].toLowerCase() + s.slice(1); }
function lcProp(handler) { const s = lcSig(handler); return s.endsWith("Changed") ? s.slice(0, -7) : s; }

function checkIdentifiers(sf, b, obj, ctx) {
  // scopes
  const scopes = [];
  function declaredIn(fnNode) {
    const names = new Set();
    function visit(n) {
      if (n !== fnNode && (ts.isFunctionDeclaration(n) || ts.isFunctionExpression(n) || ts.isArrowFunction(n))) {
        if (ts.isFunctionDeclaration(n) && n.name) names.add(n.name.text);
        return;
      }
      if (ts.isVariableDeclaration(n)) bindNames(n.name, names);
      if (ts.isCatchClause(n) && n.variableDeclaration) bindNames(n.variableDeclaration.name, names);
      if (ts.isFunctionDeclaration(n) && n.name && n !== fnNode) names.add(n.name.text);
      ts.forEachChild(n, visit);
    }
    if (fnNode.parameters) for (const prm of fnNode.parameters) bindNames(prm.name, names);
    if (fnNode.name && ts.isFunctionExpression(fnNode)) names.add(fnNode.name.text);
    if (fnNode.body) visit(fnNode.body);
    return names;
  }
  function bindNames(nameNode, set) {
    if (ts.isIdentifier(nameNode)) set.add(nameNode.text);
    else if (nameNode.elements) for (const el of nameNode.elements) if (el.name) bindNames(el.name, set);
  }
  const isDeclared = name => scopes.some(s => s.has(name));

  function exprType(node) {
    if (ts.isIdentifier(node)) {
      const n = node.text;
      if (isDeclared(n)) return CONVENTIONS[n] ? { comp: CONVENTIONS[n] } : null;
      if (CONTEXT.hasOwnProperty(n)) return CONTEXT[n] ? { py: CONTEXT[n] } : null;
      if (n === "UI") return { comp: "UI" };
      if (ctx.ids[n]) { const t = ctx.ids[n].type.split(".").pop(); return components[t] ? { comp: t, idObj: ctx.ids[n] } : null; }
      if (CONVENTIONS[n]) return { comp: CONVENTIONS[n] };
      return null;
    }
    if (ts.isPropertyAccessExpression(node)) {
      const bt = exprType(node.expression);
      if (bt && bt.comp) { const t = propTypeOf(bt.comp, node.name.text); return t ? { comp: t } : null; }
    }
    return null;
  }

  function visit(n) {
    const isFn = ts.isFunctionDeclaration(n) || ts.isFunctionExpression(n) || ts.isArrowFunction(n);
    if (isFn) scopes.push(declaredIn(n));
    if (ts.isPropertyAccessExpression(n)) {
      const bt = exprType(n.expression);
      const member = n.name.text;
      if (bt && bt.py) {
        const api = PY[bt.py];
        if (api && ![...api.slots, ...api.props, ...api.signals].includes(member))
          report(ctx.f, b.line, `${n.expression.getText()}.${member}: not a Slot/Property/Signal of Python class ${bt.py}`);
      } else if (bt && bt.comp) {
        const api = apiOf(bt.comp);
        let extra = new Set();
        if (bt.idObj) { for (const k of Object.keys(bt.idObj.props)) extra.add(k); for (const k of Object.keys(bt.idObj.funcs)) extra.add(k); for (const k of Object.keys(bt.idObj.signals)) extra.add(k); }
        if (api && !api.has(member) && !BUILTIN.has(member) && !extra.has(member) && !["destroy", "forceActiveFocus", "mapToItem", "mapFromItem", "connect", "disconnect", "toString", "contains", "childAt", "grabToImage"].includes(member))
          report(ctx.f, b.line, `'${n.expression.getText()}' (${bt.comp}) has no member '${member}'`);
      }
    }
    if (ts.isIdentifier(n)) checkFree(n);
    ts.forEachChild(n, visit);
    if (isFn) scopes.pop();
  }

  function checkFree(id) {
    const p = id.parent;
    if (ts.isPropertyAccessExpression(p) && p.name === id) return;
    if ((ts.isPropertyAssignment(p) || ts.isMethodDeclaration(p) || ts.isPropertyDeclaration(p)) && p.name === id) return;
    if ((ts.isFunctionDeclaration(p) || ts.isFunctionExpression(p)) && p.name === id) return;
    if (ts.isVariableDeclaration(p) && p.name === id) return;
    if (ts.isParameter(p) && p.name === id) return;
    if (ts.isBindingElement(p)) return;
    if (ts.isLabeledStatement(p) || ts.isBreakStatement(p) || ts.isContinueStatement(p)) return;
    if (ts.isCatchClause(p)) return;
    const name = id.text;
    if (["__b__", "__h__"].includes(name) || isDeclared(name)) return;
    if (JS_GLOBALS.has(name) || CONTEXT.hasOwnProperty(name) || ctx.singletonNames.has(name)) return;
    if (/^[A-Z]/.test(name)) { if (!QML_TYPES.has(name) && !components[name]) report(ctx.f, b.line, `unknown global/type '${name}' in '${b.name}'`); return; }
    if (ctx.ids[name]) {
      const owner = boundaryOf(ctx.ids[name]);
      if (owner && !boundaryChain(obj).includes(owner))
        report(ctx.f, b.line, `id '${name}' is defined inside a delegate/Component and is not visible here`);
      return;
    }
    if (ctx.scopeNames.has(name) || ctx.sigParams.has(name)) return;
    if (ctx.inDelegate && (ctx.roles.has(name) || ["index", "modelData", "model"].includes(name))) return;
    if (BUILTIN.has(name)) return;
    if (name === "setTimeout" || name === "setInterval") { report(ctx.f, b.line, `'${name}' does not exist in QML`); return; }
    report(ctx.f, b.line, `unresolved identifier '${name}' in '${b.name}'`);
  }
  visit(sf);
}

// singleton qmldir sanity
for (const dir of ["ui", "components"]) {
  const qd = path.join(qmlRoot, dir, "qmldir");
  if (fs.existsSync(qd)) for (const line of fs.readFileSync(qd, "utf8").split("\n")) {
    const m = line.trim().split(/\s+/); if (m.length >= 3 && m[m.length - 1].endsWith(".qml") && !fs.existsSync(path.join(qmlRoot, dir, m[m.length - 1]))) report(qd, 1, `qmldir references missing ${m[m.length - 1]}`);
  }
}

console.log(problems.length ? problems.join("\n") : "✔ no problems found");
console.log(`\n${files.length} QML files, ${problems.length} problem(s)`);
process.exit(problems.length ? 1 : 0);
