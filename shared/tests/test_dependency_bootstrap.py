"""Real HashLink subprocess tests; set HAXE, HL and LD_LIBRARY_PATH as needed.

Uses a harmless native dialog fixture instead of a game window.
No ImGui plugin is installed or loaded.
The exact bootstrap arguments come from each mod's compile.hxml.
"""
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
MODS = ["dps-meter", "minimap", "item-utilities", "more-settings", "fix-target-lock"]
HAXE = os.environ.get("HAXE", "haxe")
HL = os.environ.get("HL", "hl")


class BootstrapTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        cls.base = Path(cls.temp.name)
        cls.compiled = cls.base / "compiled"
        cls.compiled.mkdir()
        (cls.compiled / "Payload.hx").write_text('''
class Payload {
    static function __init__() { sys.io.File.saveContent("initialized", "yes"); }
    static function main() { sys.io.File.saveContent("started", "yes"); }
}
''')
        (cls.compiled / "StatProbe.hx").write_text('''
class StatProbe {
    static function main() {
        var path = Sys.args()[0];
        Sys.println("SIZE=" + sys.FileSystem.stat(path).size);
        var file = sys.io.File.read(path, true);
        Sys.println("READ=" + file.read(4).length);
        file.close();
    }
}
''')
        subprocess.run([HAXE, "-cp", ".", "-main", "StatProbe", "-hl", "stat-probe.hl"],
                       cwd=cls.compiled, check=True, capture_output=True)
        for mod in MODS:
            payload = cls.compiled / f"build/{mod}/implementation/{mod}.hl"
            subprocess.run([HAXE, "-cp", ".", "-main", "Payload", "-hl", str(payload)],
                           cwd=cls.compiled, check=True, capture_output=True)
            args = []
            section = (ROOT / mod / "compile.hxml").read_text().split("--next\n")[1]
            for line in section.splitlines():
                parts = shlex.split(line, comments=True)
                if not parts:
                    continue
                if parts[0] == "-cp":
                    parts[1] = str((ROOT / mod / parts[1]).resolve())
                args.extend(parts)
            subprocess.run([HAXE, *args], cwd=cls.compiled, check=True, capture_output=True)

        # The signature matches the real HashLink desktop dialog primitive.
        cls.libs = {}
        for lib, source in {
            "ui": r'''
#include <stdint.h>
#include <stdio.h>
static void text(const uint16_t *s) { while (*s) putchar((char)*s++); }
static int dialog(const uint16_t *title, const uint16_t *message, int flags) {
    printf("DIALOG[%d] ", flags); text(title); putchar('\n'); text(message); putchar('\n'); fflush(stdout); return 0;
}
void *hlp_ui_dialog(const char **signature) { *signature = "PBBi_i"; return (void*)dialog; }
''',
        }.items():
            source_path = cls.base / (lib + ".c")
            source_path.write_text(source)
            directory = cls.base / lib
            directory.mkdir()
            library = directory / (lib + "64.hdll")
            subprocess.run(["cc", "-shared", "-fPIC", str(source_path), "-o", str(library)], check=True)
            shutil.copy2(library, directory / (lib + ".hdll"))
            cls.libs[lib] = directory

        # Reproduce Windows _wstat's zero-length symlink metadata on Linux,
        # while actual file reads and HashLink module loading still follow links.
        stat_source = cls.base / "zero_symlink_stat.c"
        stat_source.write_text(r'''
#define _GNU_SOURCE
#include <dlfcn.h>
#include <sys/stat.h>
int stat(const char *path, struct stat *info) {
    static int (*real_stat)(const char *, struct stat *);
    if (!real_stat) real_stat = dlsym(RTLD_NEXT, "stat");
    int result = real_stat(path, info);
    struct stat link;
    if (result == 0 && lstat(path, &link) == 0 && S_ISLNK(link.st_mode))
        info->st_size = 0;
    return result;
}
''')
        cls.zero_symlink_stat = cls.base / "zero_symlink_stat.so"
        subprocess.run(["cc", "-shared", "-fPIC", str(stat_source), "-ldl", "-o",
                        str(cls.zero_symlink_stat)], check=True)

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def launch(self, mod, settings=True, alerts=True, ui=True, implementation="valid",
               linked=False, zero_link_size=False):
        with tempfile.TemporaryDirectory(dir=self.base) as directory:
            game = Path(directory)
            module = game / "hlx/mods" / mod
            shutil.copytree(self.compiled / "build" / mod, module)
            if settings:
                bms = game / "hlx/mods/better-mod-settings"
                bms.mkdir()
                shutil.copy2(module / "implementation" / (mod + ".hl"), bms / "better-mod-settings.hl")
            if alerts:
                update_alerts = game / "hlx/mods/mod-update-alerts"
                update_alerts.mkdir()
                binary = update_alerts / "mod-update-alerts.hl"
                shutil.copy2(module / "implementation" / (mod + ".hl"), binary)
                if alerts == "disabled":
                    binary.rename(binary.with_suffix(".hl.disabled"))
                elif alerts == "empty":
                    binary.write_bytes(b"")
                elif alerts == "truncated":
                    binary.write_bytes(b"HLB")
                elif alerts == "invalid":
                    binary.write_bytes(b"not bytecode")
                elif alerts == "broken":
                    binary.unlink()
                    binary.symlink_to("missing-target.hl")
            payload = module / "implementation" / (mod + ".hl")
            if implementation == "missing":
                payload.unlink()
            elif implementation == "mismatched":
                payload.write_bytes(payload.read_bytes() + b"different version")
            if linked:
                staging = game / "Vortex staging ü"
                staging.mkdir()
                for index, binary in enumerate((game / "hlx/mods").rglob("*.hl")):
                    if binary.is_symlink():
                        continue
                    target = staging / f"{index}-{binary.name}"
                    binary.rename(target)
                    binary.symlink_to(os.path.relpath(target, binary.parent))
            env = dict(os.environ)
            env["LD_LIBRARY_PATH"] = ":".join(
                ([str(self.libs["ui"])] if ui else [])
                + [env.get("LD_LIBRARY_PATH", "")])
            if zero_link_size:
                env["LD_PRELOAD"] = str(self.zero_symlink_stat)
                probe = subprocess.run([HL, str(self.compiled / "stat-probe.hl"),
                                        str(game / "hlx/mods/better-mod-settings/better-mod-settings.hl")],
                                       cwd=game, env=env, capture_output=True, text=True, timeout=15)
                self.assertEqual(probe.returncode, 0, probe.stdout + probe.stderr)
                self.assertIn("SIZE=0", probe.stdout)
                self.assertIn("READ=4", probe.stdout)
            result = subprocess.run([HL, str(module / (mod + ".hl"))], cwd=game, env=env,
                                    capture_output=True, text=True, timeout=15)
            ran = (game / "initialized").exists() or (game / "started").exists()
            return result.returncode, result.stdout + result.stderr, ran

    def test_all_five_stop_before_initializers_without_settings(self):
        for mod in MODS:
            with self.subTest(mod=mod):
                code, output, ran = self.launch(mod, settings=False)
                self.assertEqual(code, 1, output)
                self.assertIn("DIALOG[2] Farever mod dependency error", output)
                self.assertIn("- Better Mod Settings", output)
                self.assertFalse(ran)

    def test_all_five_load_matching_implementation_without_imgui(self):
        for mod in MODS:
            with self.subTest(mod=mod):
                code, output, ran = self.launch(mod)
                self.assertEqual(code, 0, output)
                self.assertNotIn("DIALOG", output)
                self.assertTrue(ran)

    def test_all_five_load_through_symlinks_with_zero_metadata_size(self):
        for mod in MODS:
            with self.subTest(mod=mod):
                code, output, ran = self.launch(mod, linked=True, zero_link_size=True)
                self.assertEqual(code, 0, output)
                self.assertNotIn("DIALOG", output)
                self.assertTrue(ran)

    def test_all_five_load_through_normal_symlinks(self):
        for mod in MODS:
            with self.subTest(mod=mod):
                code, output, ran = self.launch(mod, linked=True)
                self.assertEqual(code, 0, output)
                self.assertTrue(ran)

    def test_invalid_symlink_targets_still_stop_before_initializers(self):
        for state in ["empty", "truncated", "invalid", "broken"]:
            with self.subTest(state=state):
                code, output, ran = self.launch("dps-meter", alerts=state, linked=True)
                self.assertEqual(code, 1, output)
                self.assertIn("- Mod Update Alerts", output)
                self.assertNotIn("- Better Mod Settings", output)
                self.assertFalse(ran)

    def test_all_five_stop_without_update_alerts(self):
        for mod in MODS:
            for alerts in [False, "disabled", "empty"]:
                with self.subTest(mod=mod, alerts=alerts):
                    code, output, ran = self.launch(mod, alerts=alerts)
                    self.assertEqual(code, 1, output)
                    self.assertIn("DIALOG[2] Farever mod dependency error", output)
                    self.assertIn("- Mod Update Alerts", output)
                    self.assertIn("https://www.nexusmods.com/farever/mods/17", output)
                    self.assertNotIn("- Better Mod Settings", output)
                    self.assertNotIn("- Farever ImGui plugin", output)
                    self.assertFalse(ran)

    def test_reports_all_missing_dependencies(self):
        code, output, ran = self.launch("item-utilities", settings=False, alerts=False)
        self.assertEqual(code, 1, output)
        self.assertIn("- Better Mod Settings", output)
        self.assertIn("- Mod Update Alerts", output)
        self.assertNotIn("ImGui", output)
        self.assertFalse(ran)

    def test_missing_or_mixed_implementation_cannot_start(self):
        for state in ["missing", "mismatched"]:
            for linked in [False, True]:
                with self.subTest(state=state, linked=linked):
                    code, output, ran = self.launch("minimap", implementation=state, linked=linked)
                    self.assertEqual(code, 1, output)
                    self.assertIn("Reinstall or redeploy the complete mod archive", output)
                    self.assertFalse(ran)

    def test_missing_dialog_library_still_logs_and_exits(self):
        code, output, ran = self.launch("minimap", settings=False, ui=False)
        self.assertEqual(code, 1, output)
        self.assertIn("Missing critical dependencies", output)
        self.assertFalse(ran)


if __name__ == "__main__":
    unittest.main()
