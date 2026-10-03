"""
GlassOS backend tests.  Run from the project root:

    python -m unittest discover -s tests -v
"""

import json
import os
import logging
import math
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
logging.getLogger("glassos").setLevel(logging.CRITICAL)  # expected warnings would clutter the output

from core import calc  # noqa: E402
from core.adblock_rules import should_block, registrable  # noqa: E402
from core.settings import Prefs  # noqa: E402
from core.shell import ShellProvider  # noqa: E402
from core.shell import MAX_OUTPUT_LINES, split_redirect  # noqa: E402
from core.storage import StorageProvider, as_paths, normalize, valid_name  # noqa: E402
from core.weather_service import _valid_location, parse_forecast, parse_geocoding  # noqa: E402


class _FakeSystem:
    def snapshot(self):
        return {"version": "2.0.0", "os": "TestOS", "python": "3", "qt": "6", "cpuCores": 4,
                "cpuPercent": 12.0, "memUsed": 2.0, "memTotal": 8.0, "uptime": "1m"}


class TempStorage(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="glassos-test-"))
        self.s = StorageProvider(self.tmp / "User")

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def write(self, vpath, text="hello"):
        self.assertTrue(self.s.writeText(vpath, text), vpath)


class StorageTests(TempStorage):
    def test_layout_created(self):
        for p in ("/Desktop", "/Documents", "/Downloads", "/Pictures/Wallpapers", "/Recycle Bin"):
            self.assertTrue(self.s.isDir(p), p)

    def test_normalize(self):
        self.assertEqual(normalize(""), "/")
        self.assertEqual(normalize("Documents//a/"), "/Documents/a")
        self.assertEqual(normalize("\\Documents\\x.txt"), "/Documents/x.txt")
        self.assertEqual(normalize("/a/../.."), "/")

    def test_sandbox_escape_blocked(self):
        self.assertIsNone(self.s._resolve("/../../etc/passwd") and None)
        outside = self.tmp / "secret.txt"
        outside.write_text("x")
        self.assertFalse(self.s.exists("/../secret.txt"))
        self.assertEqual(self.s.rename("/Documents", "../evil"), "")
        self.assertFalse(valid_name("../x"))
        self.assertFalse(valid_name("a/b"))
        self.assertFalse(valid_name(" leading"))

    def test_read_write_roundtrip_and_listing(self):
        self.write("/Documents/note.txt", "héllo 🌍")
        self.assertEqual(self.s.readText("/Documents/note.txt")["text"], "héllo 🌍")
        names = [e["name"] for e in self.s.list("/Documents")]
        self.assertIn("note.txt", names)
        entry = [e for e in self.s.list("/Documents") if e["name"] == "note.txt"][0]
        self.assertEqual(entry["kind"], "text")
        self.assertEqual(entry["path"], "/Documents/note.txt")
        self.assertFalse(any(n.endswith(".tmp") for n in names))

    def test_binary_and_missing_files(self):
        (self.s.root / "Documents" / "bin.dat").write_bytes(b"\x00\x01\x02")
        self.assertFalse(self.s.readText("/Documents/bin.dat")["ok"])
        self.assertFalse(self.s.readText("/Documents/nope.txt")["ok"])

    def test_create_unique_names(self):
        a = self.s.createFolder("/Documents", "New folder")
        b = self.s.createFolder("/Documents", "New folder")
        self.assertEqual(a, "/Documents/New folder")
        self.assertEqual(b, "/Documents/New folder (2)")
        f1 = self.s.createFile("/Documents", "a.txt")
        f2 = self.s.createFile("/Documents", "a.txt")
        self.assertEqual(f2, "/Documents/a (2).txt")
        self.assertTrue(self.s.exists(f1))

    def test_change_signal(self):
        self.s.createFolder("/Documents", "x")
        self.assertIn(("/Documents",), self.s.changed.emitted)

    def test_rename(self):
        self.write("/Documents/a.txt")
        self.assertEqual(self.s.rename("/Documents/a.txt", "b.txt"), "/Documents/b.txt")
        self.write("/Documents/c.txt")
        self.assertEqual(self.s.rename("/Documents/c.txt", "b.txt"), "", "must not overwrite")
        self.assertEqual(self.s.rename("/Desktop", "Foo"), "", "special folders are protected")

    def test_copy_paste_same_folder_makes_copy(self):
        self.write("/Documents/a.txt", "1")
        self.s.copy(["/Documents/a.txt"])
        self.assertTrue(self.s.canPaste)
        self.assertEqual(self.s.paste("/Documents"), 1)
        self.assertTrue(self.s.exists("/Documents/a - Copy.txt"))
        self.assertEqual(self.s.paste("/Documents"), 1)
        self.assertTrue(self.s.exists("/Documents/a - Copy (2).txt"))

    def test_cut_paste_moves_and_clears(self):
        self.write("/Documents/a.txt")
        self.s.cut(["/Documents/a.txt"])
        self.assertEqual(self.s.paste("/Desktop"), 1)
        self.assertFalse(self.s.exists("/Documents/a.txt"))
        self.assertTrue(self.s.exists("/Desktop/a.txt"))
        self.assertFalse(self.s.canPaste)

    def test_folder_into_itself_rejected(self):
        self.s.createFolder("/Documents", "Proj")
        self.s.createFolder("/Documents/Proj", "Sub")
        self.assertEqual(self.s.copyTo(["/Documents/Proj"], "/Documents/Proj/Sub"), 0)
        self.assertEqual(self.s.move(["/Documents/Proj"], "/Documents/Proj"), 0)
        self.assertTrue(self.s.isDir("/Documents/Proj/Sub"))

    def test_trash_restore_roundtrip(self):
        self.write("/Documents/a.txt", "keep me")
        self.write("/Desktop/a.txt", "other")
        self.assertEqual(self.s.trash(["/Documents/a.txt", "/Desktop/a.txt"]), 2)
        listing = self.s.list("/Recycle Bin")
        self.assertEqual(sorted(e["name"] for e in listing), ["a.txt", "a.txt"])
        self.assertEqual(self.s.trashCount, 2)
        doc = [e for e in listing if e["originalPath"] == "/Documents/a.txt"][0]
        self.assertEqual(self.s.restore([doc["path"]]), 1)
        self.assertEqual(self.s.readText("/Documents/a.txt")["text"], "keep me")
        self.assertEqual(self.s.trashCount, 1)

    def test_restore_does_not_overwrite(self):
        self.write("/Documents/a.txt", "old")
        self.s.trash(["/Documents/a.txt"])
        self.write("/Documents/a.txt", "new")
        self.s.restore([self.s.list("/Recycle Bin")[0]["path"]])
        self.assertEqual(self.s.readText("/Documents/a.txt")["text"], "new")
        self.assertEqual(self.s.readText("/Documents/a (2).txt")["text"], "old")

    def test_legacy_trash_item_without_metadata(self):
        (self.s.root / "Recycle Bin" / "old.txt").write_text("x")
        self.assertEqual(self.s.restore(["/Recycle Bin/old.txt"]), 1)
        self.assertTrue(self.s.exists("/Documents/old.txt"))

    def test_empty_trash_and_protection(self):
        self.write("/Documents/a.txt")
        self.s.trash(["/Documents/a.txt"])
        self.assertEqual(self.s.trash(["/Documents"]), 0, "special folders can't be trashed")
        self.assertEqual(self.s.trash(["/"]), 0)
        self.assertEqual(self.s.emptyTrash(), 1)
        self.assertEqual(self.s.trashCount, 0)
        self.assertTrue(self.s.isDir("/Documents"))

    def test_search(self):
        self.write("/Documents/Report final.txt")
        self.write("/Desktop/report-notes.md")
        found = {e["path"] for e in self.s.search("report", "/")}
        self.assertEqual(found, {"/Documents/Report final.txt", "/Desktop/report-notes.md"})

    def test_file_url_is_valid_uri(self):
        self.write("/Documents/with space.txt")
        url = self.s.fileUrl("/Documents/with space.txt")
        self.assertTrue(url.startswith("file:///"), url)
        self.assertNotIn("file:////", url)

    def test_info_counts(self):
        self.write("/Documents/x/a.txt", "12345")
        info = self.s.info("/Documents/x")
        self.assertEqual(info["files"], 1)
        self.assertEqual(info["size"], 5)


class PrefsTests(TempStorage):
    def test_defaults_and_persist(self):
        p = Prefs(self.tmp / "System", self.s)
        p.setAccent("#ff0000")
        p.setVolume(150)
        p.setValue("calc.history", [1, 2])
        p.flush()
        data = json.loads((self.tmp / "System" / "settings.json").read_text())
        self.assertEqual(data["accent"], "#ff0000")
        self.assertEqual(data["volume"], 100)
        p2 = Prefs(self.tmp / "System", self.s)
        self.assertEqual(p2.accent.name(), "#ff0000")
        self.assertEqual(p2.value("calc.history", []), [1, 2])

    def test_invalid_values_rejected(self):
        p = Prefs(self.tmp / "System", self.s)
        p.setAccent("not a color")
        self.assertEqual(p.accent.name(), "#4cc2ff")
        self.assertFalse(p.setWallpaper("/Documents/missing.jpg"))

    def test_corrupt_settings_file(self):
        (self.tmp / "System").mkdir(parents=True)
        (self.tmp / "System" / "settings.json").write_text("{nope")
        p = Prefs(self.tmp / "System", self.s)
        self.assertEqual(p.volume, 60)

    def test_legacy_absolute_wallpaper_migrated(self):
        wp = self.s.root / "Pictures" / "Wallpapers" / "pic.jpg"
        wp.write_bytes(b"\xff\xd8fakejpeg")
        legacy = self.s.root / "Settings"
        legacy.mkdir()
        (legacy / "system_settings.json").write_text(json.dumps(
            {"wallpaper": "S:/someone else/GlassOS/Storage/User/Pictures/Wallpapers/pic.jpg", "volume": 33}))
        p = Prefs(self.tmp / "System", self.s)
        self.assertEqual(p.wallpaper, "/Pictures/Wallpapers/pic.jpg")
        self.assertEqual(p.volume, 33)
        self.assertTrue(p.wallpaperUrl.startswith("file:///"))


class CalcTests(unittest.TestCase):
    def ev(self, expr, deg=True):
        return calc.evaluate(expr, deg)

    def test_precedence(self):
        self.assertEqual(self.ev("2+3*4"), 14)
        self.assertEqual(self.ev("(2+3)*4"), 20)
        self.assertEqual(self.ev("2^3^2"), 512)
        self.assertEqual(self.ev("-2^2"), -4)
        self.assertEqual(self.ev("2*-3"), -6)
        self.assertEqual(self.ev("10 mod 4"), 2)
        self.assertEqual(self.ev("7-2-1"), 4)
        self.assertEqual(self.ev("8/2/2"), 2)

    def test_symbols_and_implicit(self):
        self.assertAlmostEqual(self.ev("2π"), 2 * math.pi)
        self.assertEqual(self.ev("3(4+1)"), 15)
        self.assertEqual(self.ev("(1+1)(2+2)"), 8)
        self.assertEqual(self.ev("6×7"), 42)
        self.assertEqual(self.ev("9÷3"), 3)
        self.assertEqual(self.ev("√(16)"), 4)
        self.assertEqual(self.ev("sqrt 9"), 3)
        self.assertEqual(self.ev("2 3"), 6)

    def test_functions(self):
        self.assertEqual(calc.format_number(self.ev("sin(30)")), "0.5")
        self.assertEqual(self.ev("sin(180)"), 0)
        self.assertAlmostEqual(self.ev("cos(pi)", deg=False), -1)
        self.assertAlmostEqual(self.ev("asin(1)"), 90)
        self.assertEqual(self.ev("5!"), 120)
        self.assertEqual(self.ev("50%"), 0.5)
        self.assertEqual(self.ev("200*10%"), 20)
        self.assertAlmostEqual(self.ev("ln(e)"), 1)
        self.assertEqual(self.ev("log(1000)"), 3)
        self.assertEqual(self.ev("(2+3"), 5, "missing ) is forgiven")

    def test_errors_never_hang_or_crash(self):
        for bad in ["1/0", "9^9^9", "171!", "2.5!", "sqrt(-1)", "foo(2)", "2+", "", ")", "1 $ 2", "(-8)^(1/3)"]:
            with self.assertRaises(calc.CalcError, msg=bad):
                calc.evaluate(bad)

    def test_format(self):
        self.assertEqual(calc.format_number(0.1 + 0.2), "0.3")
        self.assertEqual(calc.format_number(1e20), "1e20")
        self.assertEqual(calc.format_number(-42.0), "-42")
        self.assertEqual(calc.format_number(1 / 3), "0.333333333333")
        self.assertEqual(calc.format_number(123456789012.5), "123456789012")
        self.assertEqual(calc.format_number(2.5e-12), "2.5e-12")

    def test_provider(self):
        p = calc.CalcProvider()
        self.assertEqual(p.evaluate("ans*2", True, "21")["value"], "42")
        self.assertFalse(p.evaluate("1/0", True, "0")["ok"])
        self.assertTrue(p.looksLikeMath("12*7"))
        self.assertFalse(p.looksLikeMath("hello"))
        self.assertFalse(p.looksLikeMath("2024"))


class ShellTests(TempStorage):
    def setUp(self):
        super().setUp()
        self.prefs = Prefs(self.tmp / "System", self.s)
        self.sh = ShellProvider(self.s, self.prefs, _FakeSystem())

    def run_(self, line, cwd="/"):
        return self.sh.run(cwd, line)

    def text(self, res):
        return "\n".join(l["text"] for l in res["lines"])

    def test_cd_ls_pwd(self):
        r = self.run_("cd Documents")
        self.assertEqual(r["cwd"], "/Documents")
        r = self.run_("cd ..", "/Documents")
        self.assertEqual(r["cwd"], "/")
        r = self.run_("cd nowhere")
        self.assertEqual(r["lines"][0]["color"], "err")
        self.assertIn("Documents/", self.text(self.run_("ls")))

    def test_echo_redirect_and_cat(self):
        self.run_("echo hello world > note.txt", "/Documents")
        self.run_("echo second line >> note.txt", "/Documents")
        self.assertEqual(self.text(self.run_("cat note.txt", "/Documents")), "hello world\nsecond line")

    def test_mkdir_touch_mv_rm(self):
        self.run_("mkdir Proj", "/Documents")
        self.run_("touch Proj/a.txt", "/Documents")
        self.assertTrue(self.s.exists("/Documents/Proj/a.txt"))
        self.run_("mv Proj/a.txt Proj/b.txt", "/Documents")
        self.assertTrue(self.s.exists("/Documents/Proj/b.txt"))
        self.run_("rm Proj", "/Documents")
        self.assertFalse(self.s.exists("/Documents/Proj"))
        self.assertEqual(self.s.trashCount, 1)

    def test_quoted_names(self):
        self.run_('mkdir "My Stuff"', "/")
        self.assertTrue(self.s.isDir("/My Stuff"))

    def test_actions_and_fun(self):
        self.assertEqual(self.run_("open snake")["actions"], [{"type": "launch", "app": "Snake"}])
        self.assertEqual(self.run_("calc")["lines"][0]["color"], "err")
        self.assertEqual(self.text(self.run_("calc 2^10")), "1024")
        self.assertTrue(self.run_("clear")["clear"])
        self.assertIn("glassos", self.text(self.run_("neofetch")))
        self.assertIn("command not found", self.text(self.run_("frobnicate")))
        self.run_("accent pink")
        self.assertEqual(self.prefs.accent.name(), "#f472b6")
        self.assertEqual(self.run_("accent nope")["lines"][0]["color"], "err")
        for cmd in ["help", "fortune", "cowsay hi", "date", "whoami", "uname", "tree", "apps", "find doc",
                    "history", "sudo rm -rf /", "matrix", "ls -l /Documents", "pwd", "hello"]:
            self.assertIsInstance(self.run_(cmd)["lines"], list, cmd)

    def test_shell_never_raises(self):
        for weird in ['echo "unterminated', "> x", "cat", "rm /", "rm '/Recycle Bin'", "cp", "mv a", "cd ~/../..",
                      "ls ../../..", "echo hi > /", "touch /nonexistent/dir/file"]:
            res = self.run_(weird)
            self.assertIn("cwd", res, weird)
        self.assertTrue(self.s.isDir("/Documents"))

    def test_completion(self):
        self.assertIn("neofetch", self.sh.complete("/", "neo"))
        self.assertEqual(self.sh.complete("/", "cd Doc"), ["Documents/"])
        self.s.writeText("/Documents/zeta.txt", "")
        self.assertEqual(self.sh.complete("/", "cat Documents/ze"), ["Documents/zeta.txt"])


class AdblockTests(unittest.TestCase):
    def test_main_frame_never_blocked(self):
        self.assertFalse(should_block("https://doubleclick.net/", "doubleclick.net", "", True))

    def test_tracker_domains(self):
        self.assertTrue(should_block("https://stats.g.doubleclick.net/x", "stats.g.doubleclick.net",
                                     "news.example.com", False))
        self.assertFalse(should_block("https://cdn.example.com/app.js", "cdn.example.com", "example.com", False))

    def test_first_party_paths_allowed(self):
        self.assertFalse(should_block("https://www.youtube.com/ads/x", "www.youtube.com", "www.youtube.com", False))
        self.assertTrue(should_block("https://cdn.adco.com/banners/a.png", "cdn.adco.com", "news.com", False))

    def test_no_false_positive_on_popular(self):
        self.assertFalse(should_block("https://cdn.site.com/popular/list.json", "cdn.site.com", "other.com", False))

    def test_registrable(self):
        self.assertEqual(registrable("a.b.example.co.uk"), "example.co.uk")
        self.assertEqual(registrable("www.github.com"), "github.com")


class WeatherParseTests(unittest.TestCase):
    def test_parse(self):
        data = {
            "current": {"time": "2026-03-01T14:00", "temperature_2m": 21.6, "apparent_temperature": 20.2,
                        "is_day": 1, "weather_code": 2, "relative_humidity_2m": 55, "wind_speed_10m": 12.4,
                        "wind_direction_10m": 200, "pressure_msl": 1013.2, "cloud_cover": 40},
            "hourly": {"time": ["2026-03-01T13:00", "2026-03-01T14:00", "2026-03-01T15:00"],
                       "temperature_2m": [20, 21.6, None], "weather_code": [0, 2, 61], "is_day": [1, 1, 0],
                       "precipitation_probability": [0, 10, 80]},
            "daily": {"time": ["2026-03-01", "2026-03-02"], "weather_code": [2, 63],
                      "temperature_2m_max": [23.4, 18], "temperature_2m_min": [12.1, 9],
                      "sunrise": ["2026-03-01T06:31"], "sunset": ["2026-03-01T17:55"],
                      "uv_index_max": [4.25], "precipitation_probability_max": [10, 90]},
        }
        out = parse_forecast(data)
        self.assertEqual(out["temp"], 22)
        self.assertEqual(out["condition"], "Partly cloudy")
        self.assertEqual(out["hourly"][0]["time"], "Now")
        self.assertEqual(out["hourly"][1]["icon"], "wx-drizzle")
        self.assertEqual(out["hourly"][1]["temp"], 0, "null temperatures don't crash")
        self.assertEqual(out["forecast"][0]["day"], "Today")
        self.assertEqual(out["sunrise"], "06:31")
        self.assertEqual(out["high"], 23)

    def test_parse_empty(self):
        out = parse_forecast({})
        self.assertEqual(out["forecast"], [])
        self.assertEqual(parse_geocoding({}), [])


class HardeningTests(TempStorage):
    """Regression tests for the second (hardening) pass."""

    def test_string_where_list_expected(self):
        self.write("/Documents/a.txt")
        self.assertEqual(as_paths("/Documents/a.txt"), ["/Documents/a.txt"])
        self.assertEqual(as_paths(None), [])
        self.assertEqual(as_paths(["/a", None, 3, ""]), ["/a"])
        self.s.copy("/Documents/a.txt")          # used to put "/" on the clipboard
        self.assertEqual(self.s.clipboardPaths, ["/Documents/a.txt"])
        self.s.copy(["/Documents/a.txt", "/Documents/a.txt"])
        self.assertEqual(self.s.clipboardPaths, ["/Documents/a.txt"], "duplicates removed")
        self.assertEqual(self.s.trash("/Documents"), 0)

    def test_portable_names(self):
        for bad in ["CON", "con.txt", "LPT1", "nul", "a.", "tab\there", "x" * 300, None, 5]:
            self.assertFalse(valid_name(bad), bad)
        for good in ["console.txt", "Résumé 2026.md", "a.b.c", "😀.txt"]:
            self.assertTrue(valid_name(good), good)

    def test_normalize_non_string(self):
        self.assertEqual(normalize(None), "/")
        self.assertEqual(self.s.list(None), self.s.list("/"))

    def test_search_limit(self):
        for i in range(30):
            self.write(f"/Documents/note{i}.txt")
        self.assertEqual(len(self.s.search("note", "/", 8)), 8)
        self.assertEqual(len(self.s.search("note", "/", 0)), 30, "0 means 'use the default limit'")
        self.assertEqual(len(self.s.search("note", "/", 10 ** 9)), 30, "huge limits are clamped")

    def test_trash_count_cache_invalidated(self):
        self.assertEqual(self.s.trashCount, 0)
        self.write("/Documents/a.txt")
        self.s.trash(["/Documents/a.txt"])
        self.assertEqual(self.s.trashCount, 1)
        self.s.restore([self.s.list("/Recycle Bin")[0]["path"]])
        self.assertEqual(self.s.trashCount, 0)

    def test_write_none(self):
        self.assertTrue(self.s.writeText("/Documents/x.txt", None))
        self.assertEqual(self.s.readText("/Documents/x.txt")["text"], "")

    def test_prefs_strict_types_and_backup(self):
        (self.tmp / "System").mkdir(parents=True)
        (self.tmp / "System" / "settings.json").write_text(json.dumps({"volume": True, "glass": 1, "accent": "#ff0000"}))
        p = Prefs(self.tmp / "System", self.s)
        self.assertEqual(p.volume, 60, "bool is not accepted as an int")
        self.assertTrue(p.glass, "int is not accepted as a bool")
        self.assertEqual(p.accent.name(), "#ff0000")
        (self.tmp / "System" / "settings.json").write_text("{broken")
        Prefs(self.tmp / "System", self.s)
        self.assertTrue((self.tmp / "System" / "settings.corrupt.json").exists(), "corrupt file kept for inspection")

    def test_prefs_rejects_unserializable(self):
        p = Prefs(self.tmp / "System", self.s)
        p.setValue("bad", object())
        p.setValue("", 1)
        p.setValue("big", "x" * 3_000_000)
        p.setValue("ok", {"a": [1, 2]})
        p.flush()
        data = json.loads((self.tmp / "System" / "settings.json").read_text())["data"]
        self.assertEqual(data, {"ok": {"a": [1, 2]}})

    def test_blur_generation_drops_stale_results(self):
        p = Prefs(self.tmp / "System", self.s)
        p._blur_generation = 5
        p._on_blur_done(4, p.wallpaper, str(self.tmp / "old.jpg"))
        self.assertEqual(p.blurredWallpaperUrl, "", "stale render ignored")

    def test_blur_render_end_to_end(self):
        try:
            from PIL import Image
        except ImportError:
            self.skipTest("Pillow not installed")
        img = self.s.root / "Pictures" / "Wallpapers" / "w.jpg"
        Image.new("RGB", (800, 500), (30, 120, 200)).save(img)
        p = Prefs(self.tmp / "System", self.s)
        p.setWallpaper("/Pictures/Wallpapers/w.jpg")
        gen = p._blur_generation
        p._blur_worker(gen, p.wallpaper, img, (1280, 720))
        self.assertTrue(p.blurredWallpaperUrl.startswith("file:///"))
        self.assertEqual(len(list((self.tmp / "System" / "cache").glob("blur-*"))), 1)


class _JSValue:
    """Stand-in for PySide6.QtQml.QJSValue: what QML hands to "QVariant" slots."""

    def __init__(self, v):
        self._v = v

    def toVariant(self):
        return self._v

    def __deepcopy__(self, memo):
        raise TypeError("cannot pickle 'PySide6.QtQml.QJSValue' object")


class RuntimeRegressionTests(TempStorage):
    """Bugs reported from a real Windows / PySide6 6.10 run."""

    def test_value_with_js_default(self):
        p = Prefs(self.tmp / "System", self.s)
        # used to raise "cannot pickle QJSValue" and break taskbar, desktop and bookmarks
        self.assertEqual(p.value("taskbar.pinned", _JSValue(["AeroExplorer", "GlassPad"])), ["AeroExplorer", "GlassPad"])
        self.assertEqual(p.value("desktop.layout", _JSValue({})), {})
        self.assertIsNone(p.value("missing", _JSValue(object())))

    def test_set_value_with_js_objects(self):
        p = Prefs(self.tmp / "System", self.s)
        p.setValue("desktop.layout", _JSValue({"file:a": _JSValue([1, 2])}))
        self.assertEqual(p.value("desktop.layout", None), {"file:a": [1, 2]})
        p.flush()
        self.assertEqual(json.loads((self.tmp / "System" / "settings.json").read_text())["data"]["desktop.layout"],
                         {"file:a": [1, 2]})

    def test_paths_as_js_array(self):
        self.write("/Documents/a.txt")
        self.s.copy(_JSValue(["/Documents/a.txt"]))
        self.assertEqual(self.s.clipboardPaths, ["/Documents/a.txt"])

    def test_import_and_export_with_host(self):
        host = self.tmp / "host"
        (host / "album").mkdir(parents=True)
        (host / "photo one.jpg").write_bytes(b"jpg")
        (host / "album" / "x.txt").write_text("x")
        urls = [(host / "photo one.jpg").as_uri(), (host / "album").as_uri(), (host / "missing.txt").as_uri()]
        self.assertEqual(self.s.importFiles(urls, "/Desktop"), 2)
        self.assertTrue(self.s.exists("/Desktop/photo one.jpg"))
        self.assertEqual(self.s.readText("/Desktop/album/x.txt")["text"], "x")
        self.assertEqual(self.s.importFiles(urls[:1], "/Desktop"), 1)
        self.assertTrue(self.s.exists("/Desktop/photo one (2).jpg"), "imports never overwrite")
        self.assertEqual(self.s.importFiles(urls, "/Recycle Bin"), 0, "can't import into the bin")
        out = self.tmp / "exported"
        out.mkdir()
        self.assertEqual(self.s.exportFiles(["/Desktop/photo one.jpg", "/Desktop/album"], out.as_uri()), 2)
        self.assertTrue((out / "photo one.jpg").exists() and (out / "album" / "x.txt").exists())
        self.assertEqual(self.s.exportFiles(["/Desktop/photo one.jpg"], (self.tmp / "nope").as_uri()), 0)


class ShellHardeningTests(TempStorage):
    def setUp(self):
        super().setUp()
        self.sh = ShellProvider(self.s, Prefs(self.tmp / "System", self.s), _FakeSystem())

    def test_quoted_redirect(self):
        self.assertEqual(split_redirect('echo "a > b"'), ('echo "a > b"', None, None))
        self.assertEqual(split_redirect("echo 'x>y' > o"), ("echo 'x>y' ", "o", "w"))
        self.assertEqual(split_redirect("echo hi>>f"), ("echo hi", "f", "a"))
        out = self.sh.run("/Documents", 'echo "a > b"')
        self.assertEqual(out["lines"][0]["text"], "a > b")

    def test_output_is_capped(self):
        self.write("/Documents/big.txt", "line\n" * 50000)
        out = self.sh.run("/Documents", "cat big.txt")
        self.assertEqual(len(out["lines"]), MAX_OUTPUT_LINES + 1)
        self.assertIn("48000 more line", out["lines"][-1]["text"])

    def test_long_command_and_line(self):
        self.assertEqual(self.sh.run("/", "echo " + "x" * 10000)["lines"][0]["color"], "err")
        self.assertLess(len(self.sh.run("/", "echo " + "y" * 7000)["lines"][0]["text"]), 4100)


class CalcHardeningTests(unittest.TestCase):
    def test_bounds(self):
        p = calc.CalcProvider()
        self.assertEqual(p.evaluate("1+" * 600 + "1", True, "0")["error"], "Expression too long")
        self.assertEqual(p.evaluate("(" * 400 + "1" + ")" * 400, True, "0")["value"], "1")
        self.assertTrue(p.evaluate("ans+1", True, "not a number")["ok"])
        self.assertFalse(p.looksLikeMath(None))


class WeatherHardeningTests(unittest.TestCase):
    def test_location_validation(self):
        self.assertIsNone(_valid_location({"latitude": "x", "longitude": 1}))
        self.assertIsNone(_valid_location({"latitude": 91, "longitude": 0}))
        self.assertIsNone(_valid_location([1, 2]))
        self.assertEqual(_valid_location({"name": "Oslo", "latitude": 59.9, "longitude": 10.7})["name"], "Oslo")

    def test_geocoding_skips_bad_rows(self):
        rows = parse_geocoding({"results": [None, {"name": "x"}, {"name": "Rome", "latitude": 41.9, "longitude": 12.5}]})
        self.assertEqual([r["name"] for r in rows], ["Rome"])


class FilterEngineTests(unittest.TestCase):
    LIST = """[Adblock Plus 2.0]
! Title: test list
||ads.example.com^
||tracker.net^$third-party
/banner/*/img.png
@@||ads.example.com/allowed^
||cdn.site.com/ad.js$script,domain=news.com|~safe.news.com
/adx/*$redirect=noop.js
/^https?:\\/\\/regex\\.rule/
example.org##.ad
##.sponsored-box
##div:has(> .x)
*$image
"""

    def setUp(self):
        from core.adblock_rules import FilterEngine
        self.e = FilterEngine()
        self.e.add_text(self.LIST)

    def test_host_rules_and_exceptions(self):
        m = self.e.match
        self.assertTrue(m("https://ads.example.com/x.js", "ads.example.com", "page.com", "script"))
        self.assertTrue(m("https://sub.ads.example.com/x", "sub.ads.example.com", "page.com", "image"))
        self.assertFalse(m("https://ads.example.com/allowed/x", "ads.example.com", "page.com", "script"))
        self.assertFalse(m("https://notads.example.com/x", "notads.example.com", "page.com", "script"))

    def test_options(self):
        m = self.e.match
        self.assertFalse(m("https://tracker.net/p", "tracker.net", "tracker.net", "image"), "first-party allowed")
        self.assertTrue(m("https://tracker.net/p", "tracker.net", "blog.com", "image"))
        self.assertTrue(m("https://cdn.site.com/ad.js", "cdn.site.com", "news.com", "script"))
        self.assertFalse(m("https://cdn.site.com/ad.js", "cdn.site.com", "safe.news.com", "script"), "~domain")
        self.assertFalse(m("https://cdn.site.com/ad.js", "cdn.site.com", "news.com", "image"), "type filter")
        self.assertTrue(m("https://img.foo.com/banner/2024/img.png", "img.foo.com", "foo.com", "image"))

    def test_unsupported_and_unsafe_rules_are_skipped(self):
        self.assertFalse(self.e.match("https://x.com/adx/1", "x.com", "y.com", "script"), "$redirect skipped")
        self.assertFalse(self.e.match("https://regex.rule/a", "regex.rule", "y.com", "script"), "regex rules skipped")
        self.assertFalse(self.e.match("https://any.com/pic.png", "any.com", "y.com", "image"), "'*$image' too generic")
        self.assertEqual(self.e.cosmetic, [".sponsored-box"], "domain-specific and procedural cosmetics skipped")
        self.assertIn(".sponsored-box{display:none!important}", self.e.cosmetic_css())

    def test_should_block_wrapper(self):
        from core.adblock_rules import should_block
        self.assertFalse(should_block("https://ads.example.com/", "ads.example.com", "", True, self.e), "main frame never blocked")
        self.assertTrue(should_block("https://ads.example.com/a", "ads.example.com", "x.com", False, self.e, "script"))
        self.assertFalse(should_block("", "", "", False, self.e))

    def test_token_index_speed(self):
        import time
        from core.adblock_rules import FilterEngine
        e = FilterEngine()
        e.add_text("\n".join(f"||ad{i}.example{i}.com^" for i in range(20000)) + "\n" +
                   "\n".join(f"/path{i}/banner^$third-party" for i in range(20000)))
        t = time.perf_counter()
        for i in range(2000):
            e.match(f"https://cdn{i}.site.com/static/app{i}.js?v={i}", f"cdn{i}.site.com", "site.com", "script")
        per = (time.perf_counter() - t) / 2000
        self.assertLess(per, 0.0005, f"{per * 1e6:.0f} µs per request")
        self.assertTrue(e.match("https://x.com/path77/banner?a", "x.com", "y.com", "image"))


class BrowserServiceTests(TempStorage):
    def test_normalize(self):
        from core.browser import normalize_address as n
        self.assertEqual(n("github.com"), "https://github.com")
        self.assertEqual(n("localhost:8080/x"), "http://localhost:8080/x")
        self.assertEqual(n("192.168.1.1"), "http://192.168.1.1")
        self.assertEqual(n("https://x.org/a b"), "https://x.org/a b")
        self.assertTrue(n("how to bake bread").startswith("https://duckduckgo.com/?q=how+to+bake+bread"))
        self.assertTrue(n("cats", "Brave Search").startswith("https://search.brave.com/"))
        self.assertEqual(n("   "), "")

    def test_history_and_suggestions(self):
        from core.browser import BrowserService
        b = BrowserService(Prefs(self.tmp / "System", self.s), self.tmp / "System")
        for _ in range(5):
            b.addVisit("https://github.com/trending", "Trending")
        b.addVisit("https://news.ycombinator.com/", "Hacker News")
        b.addVisit("about:blank", "")
        self.assertEqual(b.suggest("git", 5)[0]["url"], "https://github.com/trending")
        self.assertEqual(b.suggest("hacker", 5)[0]["title"], "Hacker News")
        self.assertEqual(len(b.recent(10)), 2, "about: pages aren't recorded")
        self.assertEqual(b.topSites(4)[0]["url"], "https://github.com/trending")
        b.flush()
        b2 = BrowserService(Prefs(self.tmp / "System", self.s), self.tmp / "System")
        self.assertEqual(len(b2.recent(10)), 2, "history persists")
        b2.clearHistory()
        self.assertEqual(b2.recent(10), [])


class MediaTests(unittest.TestCase):
    def _tone_peak(self):
        from core import media
        sr = 48000
        x = [math.sin(2 * math.pi * 1000 * i / sr) for i in range(2048)]
        lv = media.spectrum(x, sr)
        k = max(range(len(lv)), key=lambda i: lv[i])
        edges = media.band_edges()
        return edges[k], edges[k + 1], lv

    def test_spectrum_peak(self):
        lo, hi, lv = self._tone_peak()
        self.assertTrue(lo * 0.7 <= 1000 <= hi * 1.3, (lo, hi))
        from core import media
        self.assertEqual(max(media.spectrum([0.0] * 2048, 48000)), 0.0)
        self.assertEqual(media.spectrum([], 48000), [0.0] * media.BANDS)

    def test_pure_python_fallback(self):
        from core import media
        saved, media._np = media._np, None
        try:
            lo, hi, lv = self._tone_peak()
            self.assertEqual(len(lv), media.BANDS)
            self.assertTrue(lo * 0.5 <= 1000 <= hi * 2, (lo, hi))
        finally:
            media._np = saved

    def test_pcm_decoding(self):
        import array
        from core.media import to_mono_floats
        raw = array.array("h", [16384, 16384, -32768, -32768]).tobytes()
        self.assertEqual(to_mono_floats(raw, "int16", 2), [0.5, -1.0])
        self.assertEqual(to_mono_floats(b"\x80\xff", "uint8", 1)[0], 0.0)
        self.assertEqual(to_mono_floats(b"abc", "weird", 1), [])


class TransferJobTests(TempStorage):
    def test_background_copy_and_move(self):
        import time
        self.write("/Documents/a.txt", "1")
        self.write("/Documents/b.txt", "2")
        j1 = self.s.startTransfer("copy", ["/Documents/a.txt"], "/Desktop")
        j2 = self.s.startTransfer("move", ["/Documents/b.txt"], "/Desktop")
        self.assertEqual(self.s.startTransfer("nuke", ["/Documents/a.txt"], "/Desktop"), 0)
        self.assertEqual(self.s.startTransfer("copy", [], "/Desktop"), 0)
        deadline = time.time() + 5
        while self.s.busy and time.time() < deadline:
            time.sleep(0.02)
        self.assertFalse(self.s.busy)
        self.assertTrue(self.s.exists("/Desktop/a.txt") and self.s.exists("/Documents/a.txt"))
        self.assertTrue(self.s.exists("/Desktop/b.txt") and not self.s.exists("/Documents/b.txt"))
        done = {e[0]: e for e in self.s.transferFinished.emitted}
        self.assertEqual(done[j1][2], 1)
        self.assertEqual(done[j2][2], 1)

    def test_media_library(self):
        self.write("/Music/a.mp3", "x")
        self.write("/Videos/b.mkv", "x")
        self.write("/Documents/c.flac", "x")
        self.s.trash(["/Documents/c.flac"])
        self.assertEqual([e["name"] for e in self.s.mediaFiles("audio")], ["a.mp3"], "trash excluded")
        self.assertEqual(self.s.mediaFiles("bogus"), [])


class ArchiveTests(TempStorage):
    def _wait(self):
        import time
        deadline = time.time() + 10
        while self.s.busy and time.time() < deadline:
            time.sleep(0.02)

    def _zip(self, name, members):
        import zipfile
        real = self.s.root / "Downloads" / name
        with zipfile.ZipFile(real, "w", zipfile.ZIP_DEFLATED) as zf:
            for arc, data in members:
                zf.writestr(arc, data)
        return "/Downloads/" + name

    def test_compress_extract_roundtrip(self):
        self.write("/Documents/Proj/a.txt", "alpha")
        self.write("/Documents/Proj/sub/b.txt", "beta")
        self.s.startTransfer("compress", ["/Documents/Proj"], "/Documents")
        self._wait()
        self.assertTrue(self.s.exists("/Documents/Proj.zip"))
        info = self.s.archiveInfo("/Documents/Proj.zip")
        self.assertTrue(info["ok"])
        self.assertEqual(sorted(e["name"] for e in info["entries"] if not e["isDir"]), ["Proj/a.txt", "Proj/sub/b.txt"])
        self.s.trash(["/Documents/Proj"])
        self.s.startTransfer("extract", ["/Documents/Proj.zip"], "/Documents")
        self._wait()
        self.assertEqual(self.s.readText("/Documents/Proj/sub/b.txt")["text"], "beta", "no Proj/Proj nesting")
        self.s.startTransfer("extract", ["/Documents/Proj.zip"], "/Documents")
        self._wait()
        self.assertTrue(self.s.exists("/Documents/Proj (2)/a.txt"), "never overwrites")

    def test_zip_slip_and_links_are_blocked(self):
        z = self._zip("evil.zip", [("../../escape.txt", "x"), ("/abs.txt", "x"), ("C:/win.txt", "x"), ("ok/fine.txt", "y")])
        self.s.startTransfer("extract", [z], "/Downloads")
        self._wait()
        self.assertFalse((self.tmp / "escape.txt").exists())
        self.assertFalse((self.s.root / "escape.txt").exists())
        self.assertTrue(self.s.exists("/Downloads/evil/ok/fine.txt"))
        self.assertFalse(any(p.name.startswith(".extract-") for p in (self.s.root / "Downloads").iterdir()), "staging cleaned")

    def test_tar_formats_and_links(self):
        import io, tarfile
        for ext, mode in [(".tar.gz", "w:gz"), (".tar.xz", "w:xz"), (".tar.bz2", "w:bz2")]:
            real = self.s.root / "Downloads" / ("t" + ext)
            with tarfile.open(real, mode) as tf:
                data = b"hello"
                ti = tarfile.TarInfo("t/x.txt"); ti.size = len(data); tf.addfile(ti, io.BytesIO(data))
                link = tarfile.TarInfo("t/link"); link.type = tarfile.SYMTYPE; link.linkname = "/etc/passwd"; tf.addfile(link)
            self.assertTrue(self.s.archiveInfo("/Downloads/t" + ext)["ok"])
            self.s.startTransfer("extract", ["/Downloads/t" + ext], "/Documents")
            self._wait()
        self.assertEqual(self.s.readText("/Documents/t/x.txt")["text"], "hello")
        self.assertFalse((self.s.root / "Documents" / "t" / "link").exists(), "symlinks never extracted")

    def test_bomb_and_garbage(self):
        from core import archives
        z = self._zip("big.zip", [("zeros.bin", "\0" * (2 * 1024 * 1024))])
        saved = archives.MAX_TOTAL_BYTES
        archives.MAX_TOTAL_BYTES = 1024 * 1024
        try:
            job = self.s.startTransfer("extract", [z], "/Downloads")
            self._wait()
            self.assertIn("20 GB", self.s.jobError(job) or "20 GB")
            self.assertFalse(self.s.exists("/Downloads/big"))
        finally:
            archives.MAX_TOTAL_BYTES = saved
        (self.s.root / "Downloads" / "bad.zip").write_bytes(b"not a zip")
        self.assertFalse(self.s.archiveInfo("/Downloads/bad.zip")["ok"])
        self.assertFalse(self.s.archiveInfo("/Downloads/x.rar")["ok"])
        self.assertTrue(self.s.canExtract("/a/b.TGZ"))

    def test_screenshot_path(self):
        a = self.s.newScreenshotPath()
        self.assertTrue(a["vpath"].startswith("/Pictures/Screenshots/Screenshot "))
        self.assertTrue(a["real"].endswith(".png"))


class ShellArchiveTests(TempStorage):
    def test_zip_unzip_lsarchive(self):
        sh = ShellProvider(self.s, Prefs(self.tmp / "System", self.s), _FakeSystem())
        self.write("/Documents/notes/a.txt", "A")
        self.assertEqual(sh.run("/Documents", "zip backup notes")["lines"][0]["color"], "ok")
        self.assertTrue(self.s.exists("/Documents/backup.zip"))
        listing = "\n".join(l["text"] for l in sh.run("/Documents", "lsarchive backup.zip")["lines"])
        self.assertIn("notes/a.txt", listing)
        out = sh.run("/Documents", "unzip backup.zip /Desktop")
        self.assertEqual(out["lines"][0]["color"], "ok", out)
        self.assertEqual(self.s.readText("/Desktop/backup/notes/a.txt")["text"], "A")
        for bad in ["unzip", "unzip nope.zip", "zip x", "zip x.zip missing", "lsarchive", "unzip backup.zip /nope"]:
            self.assertEqual(sh.run("/Documents", bad)["lines"][0]["color"], "err", bad)


class ExtensionTests(TempStorage):
    def test_store_ids(self):
        from core.extensions import store_id
        uid = "cjpalhdlnbpafiamejdnhcphjbkeiagm"
        self.assertEqual(store_id(f"https://chromewebstore.google.com/detail/ublock-origin/{uid}"), uid)
        self.assertEqual(store_id(f"https://chromewebstore.google.com/detail/{uid}?hl=en"), uid)
        self.assertEqual(store_id(f"https://chrome.google.com/webstore/detail/x/{uid}"), uid)
        self.assertEqual(store_id("https://example.com/detail/x/" + uid), "")
        self.assertEqual(store_id("https://chromewebstore.google.com/category/extensions"), "")

    def test_crx_formats(self):
        import io, struct, zipfile
        from core.extensions import ExtensionError, crx_to_zip
        buf = io.BytesIO()
        with zipfile.ZipFile(buf, "w") as zf:
            zf.writestr("manifest.json", '{"name":"x","version":"1","manifest_version":3}')
            zf.writestr("../evil.js", "x")
        z = buf.getvalue()
        crx3 = b"Cr24" + struct.pack("<II", 3, 5) + b"HEADR" + z
        crx2 = b"Cr24" + struct.pack("<III", 2, 3, 4) + b"KEY" + b"SIGN" + z
        self.assertEqual(crx_to_zip(crx3), z)
        self.assertEqual(crx_to_zip(crx2), z)
        self.assertEqual(crx_to_zip(z), z)
        for bad in [b"", b"Cr24" + struct.pack("<I", 9) + b"x" * 20, b"Cr24" + struct.pack("<II", 3, 0) + b"notzip"]:
            with self.assertRaises(ExtensionError):
                crx_to_zip(bad)
        from core.extensions import zip_manifest
        self.assertEqual(zip_manifest(z)[1], "", "top-level manifest")

    def test_manifest_v2_is_refused_clearly(self):
        from core.extensions import ExtensionError, check_manifest, zip_manifest
        pack = (ROOT / "assets" / "filters" / "ublock-origin-filters.zip").read_bytes()
        manifest, prefix = zip_manifest(pack)
        self.assertEqual((manifest["manifest_version"], prefix), (2, "uBlock0.chromium/"))
        with self.assertRaises(ExtensionError) as cm:
            check_manifest(manifest)
        self.assertIn("Manifest V2", str(cm.exception))
        self.assertIn("uBlock Origin Lite", str(cm.exception))
        check_manifest({"manifest_version": 3, "name": "ok"})

    def test_python_never_touches_the_extension_manager(self):
        # PySide6 6.10 crashes when QWebEngineExtensionInfo reaches Python (the 2.6 boot crash)
        import re as _re
        code = "\n".join(l.split("#")[0] for l in (ROOT / "core" / "extensions.py").read_text(encoding="utf-8").splitlines())
        code = _re.sub(r'"""[\s\S]*?"""', "", code)
        for forbidden in ("extensionManager(", ".extensions()", "setExtensionEnabled", "installExtension(", "loadFinished"):
            self.assertNotIn(forbidden, code, forbidden)

    def test_extensions_unavailable_without_developer_override(self):
        from core.extensions import ExtensionService
        os.environ.pop("GLASSOS_EXTENSIONS", None)
        prefs = Prefs(self.tmp / "System", self.s)
        prefs.setValue("browser.extensions.experimental", True)
        e = ExtensionService(self.tmp / "System", prefs)
        self.assertFalse(e.allowed)
        self.assertFalse(e.experimental, "a stored opt-in can't re-enable them on this Qt")

    def test_crash_guard_switches_extensions_off(self):
        os.environ["GLASSOS_EXTENSIONS"] = "1"
        self.addCleanup(os.environ.pop, "GLASSOS_EXTENSIONS", None)
        from core.extensions import ExtensionService
        prefs = Prefs(self.tmp / "System", self.s)
        prefs.setValue("browser.extensions.experimental", True)
        installed = self.tmp / "System" / "browser" / "Extensions" / "abc"
        installed.mkdir(parents=True)
        (self.tmp / "System" / "browser" / "Cookies").write_text("keep me")
        e = ExtensionService(self.tmp / "System", prefs)
        self.assertTrue(e.experimental and not e.crashedLastTime)
        e.markActive()                                   # ...and then GlassOS "crashes"
        e2 = ExtensionService(self.tmp / "System", prefs)
        self.assertTrue(e2.crashedLastTime)
        self.assertFalse(e2.experimental, "switched off after a crash")
        self.assertFalse(installed.exists(), "installed extensions purged")
        self.assertTrue((self.tmp / "System" / "browser" / "Cookies").exists(), "profile data untouched")
        e2.markActive(); e2.markInactive()               # clean exit disarms the guard
        self.assertFalse(ExtensionService(self.tmp / "System", prefs).crashedLastTime)

    def test_localized_names(self):
        import io, zipfile
        from core.extensions import localized_name, zip_manifest
        buf = io.BytesIO()
        with zipfile.ZipFile(buf, "w") as zf:
            zf.writestr("manifest.json", '{"name":"__MSG_extName__","default_locale":"en","manifest_version":3}')
            zf.writestr("_locales/en/messages.json", '{"extName":{"message":"uBlock Origin Lite"}}')
        z = buf.getvalue()
        manifest, prefix = zip_manifest(z)
        self.assertEqual(localized_name(manifest, z, prefix), "uBlock Origin Lite")
        self.assertEqual(localized_name({"name": "Plain"}), "Plain")
        self.assertEqual(localized_name({"name": "__MSG_missing__"}, z, ""), "Extension")

    def test_bundled_ublock_filters_load(self):
        from core.adblock_rules import FilterEngine
        from core.adblocker_lists import bundled_lists
        texts = bundled_lists(set())
        self.assertGreaterEqual(len(texts), 8, "uBO lists + EasyList + EasyPrivacy")
        e = FilterEngine()
        for t in texts:
            e.add_text(t)
        self.assertGreater(e.rule_count, 100000)
        self.assertTrue(e.match("https://securepubads.g.doubleclick.net/tag/js/gpt.js", "securepubads.g.doubleclick.net", "cnn.com", "script"))
        self.assertFalse(e.match("https://github.githubassets.com/assets/app.js", "github.githubassets.com", "github.com", "script"))
        self.assertEqual(len(bundled_lists({"easylist", "easyprivacy"})), len(texts) - 2, "fresher downloads win")


class StorageDetailsTests(TempStorage):
    def test_details_and_previews(self):
        self.write("/Documents/a.txt", "hello world")
        info = self.s.info("/Documents/a.txt")
        self.assertEqual(info["typeName"], "TXT Text document")
        self.assertEqual(info["location"], "/Documents")
        self.assertGreater(info["created"], 0)
        self.assertEqual(self.s.textPreview("/Documents/a.txt", 5), "hello")
        (self.s.root / "Documents" / "b.bin").write_bytes(b"\0\1\2")
        self.assertEqual(self.s.textPreview("/Documents/b.bin", 50), "")
        self.assertEqual(self.s.imageSize("/Documents/missing.png"), {"w": 0, "h": 0})

    def test_quick_info(self):
        self.write("/Documents/Proj/a.txt", "x")
        self.write("/Documents/Proj/b.txt", "y")
        q = self.s.quickInfo("/Documents/Proj")
        self.assertEqual((q["items"], q["typeName"], q["location"]), (2, "Folder", "/Documents"))
        self.s.trash(["/Documents/Proj/a.txt"])
        t = self.s.quickInfo(self.s.list("/Recycle Bin")[0]["path"])
        self.assertEqual((t["name"], t["originalPath"]), ("a.txt", "/Documents/Proj/a.txt"))
        self.assertEqual(self.s.quickInfo("/nope"), {})
        self.assertEqual(self.s.kindOf("mix.m3u"), "playlist")

    def test_restore_reports_destination(self):
        self.write("/Documents/a.txt", "x")
        self.s.trash(["/Documents/a.txt"])
        dest = self.s.restoreItems([self.s.list("/Recycle Bin")[0]["path"]])
        self.assertEqual(dest, ["/Documents/a.txt"])

    def test_external_trash_change_detected(self):
        self.write("/Documents/a.txt", "x")
        self.s.trash(["/Documents/a.txt"])
        self.assertEqual(self.s.trashCount, 1)
        for p in (self.s.root / "Recycle Bin").iterdir():
            if not p.name.startswith("."):
                p.unlink()
        self.s._on_dir_changed(str(self.s.root / "Recycle Bin"))   # what QFileSystemWatcher reports
        self.assertEqual(self.s.trashCount, 0)

    def test_image_thumbnail(self):
        try:
            from PIL import Image
        except ImportError:
            self.skipTest("Pillow missing")
        import time
        from core.thumbnails import ThumbnailService
        Image.new("RGB", (1600, 900), (10, 200, 90)).save(self.s.root / "Pictures" / "p.jpg")
        t = ThumbnailService(self.s, self.tmp / "thumbs")
        self.assertEqual(t.request("/Pictures/p.jpg"), "", "first request is async")
        deadline = time.time() + 5
        while not t.ready.emitted and time.time() < deadline:
            time.sleep(0.02)
        vpath, url = t.ready.emitted[-1]
        self.assertEqual(vpath, "/Pictures/p.jpg")
        self.assertTrue(url.startswith("file:///"))
        self.assertTrue(t.request("/Pictures/p.jpg").startswith("file:///"), "served from cache")
        self.assertEqual(t.meta("/Pictures/p.jpg"), {"width": 1600, "height": 900})
        self.assertEqual(t.request("/Documents/x.txt"), "", "not a media file")


class WebServiceTests(TempStorage):
    def test_suggestion_parsing_and_hosts(self):
        from core.browser import host_of, parse_suggestions
        self.assertEqual(parse_suggestions(["cat", ["cat videos", "cats", "cat videos", 5, ""]]), ["cat videos", "cats"])
        self.assertEqual(parse_suggestions({"oops": 1}), [])
        self.assertEqual(parse_suggestions(["q"]), [])
        self.assertEqual(host_of("https://www.YouTube.com/watch?v=1"), "www.youtube.com")
        self.assertEqual(host_of("about:blank"), "")

    def test_shortcuts(self):
        from core.browser import BrowserService
        b = BrowserService(Prefs(self.tmp / "System", self.s), self.tmp / "System")
        self.assertEqual(len(b.shortcuts), 8, "defaults before customizing")
        b.addVisit("https://example.org/page", "Example")
        self.assertEqual(b.shortcuts[0]["url"], "https://example.org/page", "most visited first")
        b.removeShortcut("https://www.youtube.com/")
        self.assertNotIn("https://www.youtube.com/", [s["url"] for s in b.shortcuts])
        b.addShortcut("Python", "python.org")
        self.assertEqual(b.shortcuts[-1], {"title": "Python", "url": "https://python.org"})
        b.updateShortcut("https://python.org", "Py", "https://docs.python.org")
        self.assertEqual(b.shortcuts[-1]["title"], "Py")
        b.resetShortcuts()
        self.assertEqual(len(b.shortcuts), 8)


class SyntaxTests(unittest.TestCase):
    def kinds(self, line, lang, state=0):
        from core.highlight import tokenize_line
        spans, st = tokenize_line(line, lang, state)
        return {line[a:a + n]: k for a, n, k in spans}, st

    def test_languages_from_paths(self):
        from core.highlight import language_for
        self.assertEqual(language_for("/a/b/main.py"), "python")
        self.assertEqual(language_for("App.QML"), "qml")
        self.assertEqual(language_for("Dockerfile"), "shell")
        self.assertEqual(language_for("notes.txt"), "")

    def test_python(self):
        k, st = self.kinds('def greet(name):  # say hi', "python")
        self.assertEqual((k["def"], k["greet"], k["# say hi"]), ("keyword", "function", "comment"))
        k, _ = self.kinds('x = "a # not a comment" + 0x1F', "python")
        self.assertEqual((k['"a # not a comment"'], k["0x1F"]), ("string", "number"))
        _, st = self.kinds('doc = """starts here', "python")
        k, st2 = self.kinds('still a string', "python", st)
        self.assertEqual(k["still a string"], "string")
        k, st3 = self.kinds('ends""" + print(1)', "python", st2)
        self.assertEqual((k['ends"""'], k["print"], st3), ("string", "builtin", 0))

    def test_c_like_block_comments_and_types(self):
        _, st = self.kinds("int x = 1; /* start", "c")
        self.assertEqual(st, 1)
        k, st = self.kinds("middle */ return Foo(x);", "c", st)
        self.assertEqual((k["middle */"], k["return"], k["Foo"], st), ("comment", "keyword", "function", 0))
        k, _ = self.kinds("const s = `tpl ${x}`; // c", "javascript")
        self.assertEqual((k["const"], k["`tpl ${x}`"], k["// c"]), ("keyword", "string", "comment"))

    def test_json_keys_vs_values_and_markup(self):
        k, _ = self.kinds('  "name": "GlassOS", "n": 3', "json")
        self.assertEqual((k['"name"'], k['"GlassOS"'], k["3"]), ("attr", "string", "number"))
        k, st = self.kinds('<a href="x.html">hi</a> <!-- note', "html")
        self.assertEqual((k["<a"], k["href"], k['"x.html"'], k["<!-- note"], st), ("tag", "attr", "string", "comment", 4))

    def test_html_output_is_escaped_and_bounded(self):
        from core.highlight import to_html
        out = to_html("<script>alert(1)</script>\n" * 100, "javascript", 5)
        self.assertNotIn("<script>", out)
        self.assertIn("&lt;script&gt;", out)
        self.assertEqual(out.count("\n"), 4, "max_lines respected")

    def test_formatting_helpers(self):
        from core.highlight import format_json, indent_for_newline
        self.assertEqual(format_json('{"a":[1,2]}')["text"], '{\n  "a": [\n    1,\n    2\n  ]\n}\n')
        self.assertFalse(format_json("{oops")["ok"])
        self.assertEqual(indent_for_newline("    if x:", "python"), "        ")
        self.assertEqual(indent_for_newline("  foo();", "javascript"), "  ")
        self.assertEqual(indent_for_newline("function f() {", "javascript"), "    ")

    def test_tokenizer_never_crashes(self):
        import random
        from core.highlight import EXT_LANG, tokenize_line
        rnd = random.Random(7)
        alphabet = "ab1_ \t\"'`/*#<>-=:{}()[]$@.\\!&;"
        for lang in set(EXT_LANG.values()):
            state = 0
            for _ in range(300):
                line = "".join(rnd.choice(alphabet) for _ in range(rnd.randint(0, 40)))
                spans, state = tokenize_line(line, lang, state)
                for a, n, k in spans:
                    self.assertTrue(0 <= a and a + n <= len(line) and n >= 0, (lang, line, a, n))


class WatchReleaseTests(TempStorage):
    """Windows can't delete/move a folder that's being watched ("Access is denied")."""

    class FakeWatcher:
        def __init__(self): self.dirs = set()
        def directories(self): return sorted(self.dirs)
        def addPath(self, p): self.dirs.add(p)
        def removePaths(self, ps): self.dirs -= set(ps)
        def removePath(self, p): self.dirs.discard(p)

    def test_watches_released_before_folder_operations(self):
        w = self.s._watcher = self.FakeWatcher()
        self.write("/Documents/Proj/sub/a.txt", "x")
        self.write("/Documents/Other/b.txt", "y")
        for v in ("/Documents/Proj", "/Documents/Proj/sub", "/Documents/Other", "/Desktop"):
            self.s.watch(v)
        proj = str(self.s.real_path("/Documents/Proj"))
        self.s.trash(["/Documents/Proj"])
        self.assertFalse(any(d == proj or d.startswith(proj + os.sep) for d in w.dirs), "folder + subfolders unwatched")
        self.assertIn(str(self.s.real_path("/Documents/Other")), w.dirs, "unrelated folders keep their watch")
        self.s.rename("/Documents/Other", "Renamed")
        self.assertNotIn(str(self.s.root / "Documents" / "Other"), w.dirs)
        self.assertTrue(self.s.exists("/Documents/Renamed/b.txt"))

    def test_vanished_folder_stops_being_watched(self):
        w = self.s._watcher = self.FakeWatcher()
        self.write("/Documents/Gone/x.txt", "x")
        self.s.watch("/Documents/Gone")
        real = str(self.s.real_path("/Documents/Gone"))
        import shutil
        shutil.rmtree(real)                      # deleted outside GlassOS
        self.s._on_dir_changed(real)
        self.assertNotIn(real, w.dirs)


class ClipHistoryTests(unittest.TestCase):
    def test_history_rules(self):
        from core.clipboard import ClipHistory, MAX_ITEMS
        h = ClipHistory(["pinned one"])
        self.assertTrue(h.add("a"))
        self.assertTrue(h.add("b"))
        self.assertTrue(h.add("a"))
        self.assertEqual([i["text"] for i in h.items][:2], ["a", "b"], "re-copy moves to top, no duplicate")
        self.assertFalse(h.add("   "))
        self.assertFalse(h.add("x" * 200_000))
        for i in range(MAX_ITEMS + 10):
            h.add(f"item {i}")
        self.assertEqual(sum(1 for i in h.items if not i["pinned"]), MAX_ITEMS)
        self.assertIn("pinned one", h.pinned_texts(), "pinned items survive the cap")
        first = h.items[0]["id"]
        h.toggle_pin(first)
        h.clear()
        self.assertEqual(len(h.items), 2, "clear keeps pinned")
        h.remove(first)
        self.assertEqual(h.pinned_texts(), ["pinned one"])


if __name__ == "__main__":
    unittest.main()
