import os
import json
from pathlib import Path
import runpy
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.repo = self.base / "repo"
        self.home = self.base / "home"
        self.home.mkdir()
        self.repo.mkdir()
        shutil.copy(ROOT / "install.sh", self.repo)
        shutil.copy(ROOT / "VERSION", self.repo)
        shutil.copytree(ROOT / "install", self.repo / "install")
        self.os_release = self.base / "os-release"
        self.os_release.write_text('ID=arch\nNAME="Test Arch"\n')
        self.env = dict(os.environ, HOME=str(self.home), USER="tester", OS_RELEASE=str(self.os_release),
                        NO_COLOR="1", SHADOWS_ALLOW_ROOT="1", TMPDIR=str(self.base),
                        GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=str(self.base / "gitconfig"))
        self.env.pop("HYPRLAND_INSTANCE_SIGNATURE", None)
        self.env.pop("NIRI_SOCKET", None)

    def git(self, *args):
        return subprocess.run(["git", "-C", str(self.repo), *args], env=self.env,
                              check=True, capture_output=True, text=True)

    def setup_git(self):
        self.git("init", "-b", "main")
        self.git("config", "user.name", "Test")
        self.git("config", "user.email", "test@example.invalid")
        self.git("add", ".")
        self.git("commit", "-m", "initial")
        self.git("remote", "add", "origin", "https://github.com/whyrassvet/MoonlightShell.git")
        self.git("update-ref", "refs/remotes/origin/main", "HEAD")
        self.git("branch", "--set-upstream-to=origin/main", "main")

    def install(self, *args):
        return subprocess.run(["bash", str(self.repo / "install.sh"), *args], env=self.env,
                              capture_output=True, text=True, timeout=30)

    def test_versions(self):
        module = runpy.run_path(str(ROOT / "bin/rice-update"))
        self.assertGreater(module["key"]("1.10"), module["key"]("1.9"))
        self.assertEqual(module["clean"]("invalid"), "")

    def test_launcher_default_and_legacy_duplicate(self):
        config = self.home / ".config/rice/keys.conf"
        config.parent.mkdir(parents=True)
        config.write_text("launcher2=SUPER + D\n")
        module = runpy.run_path(str(ROOT / "bin/rice-keymap"))
        module["read"].__globals__["CONF"] = str(config)
        self.assertEqual(module["DEFAULTS"]["launcher"], "SUPER + D")
        self.assertEqual(module["DEFAULTS"]["launcher2"], "ALT + Space")
        self.assertNotIn("launcher2", module["read"]())

    def test_non_arch_is_rejected(self):
        self.os_release.write_text('ID=fedora\nNAME=Fedora\n')
        result = self.install("--dry-run", "--yes")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Arch-based", result.stderr)
        self.assertEqual(list(self.home.iterdir()), [])

    def test_dry_run_preserves_home(self):
        self.setup_git()
        kept = self.home / ".cache/rice/kept-edits"
        kept.parent.mkdir(parents=True)
        kept.write_text("keep me\n")
        result = self.install("--update", "--dry-run", "--no-packages")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(kept.read_text(), "keep me\n")
        self.assertEqual(sorted(p.relative_to(self.home).as_posix() for p in self.home.rglob("*") if p.is_file()),
                         [".cache/rice/kept-edits"])

    def test_install_dry_run_preserves_home(self):
        result = self.install("--dry-run", "--yes", "--no-packages")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(list(self.home.iterdir()), [])

    def test_user_hypr_modules_created_without_overwriting(self):
        script = (ROOT / "install.sh").read_text()
        functions = script[script.index("make_user_lua() {"):script.index("# btop:")]
        command = functions + '\nDRY_RUN=0\nmake_user_lua\nmake_hyprland_user_lua\n'
        subprocess.run(["bash", "-e", "-c", command], env=self.env, check=True)
        hypr = self.home / ".config/hypr"
        for name in ("user.lua", "hyprland-user.lua"):
            (hypr / name).write_text("-- personal settings\n")
        subprocess.run(["bash", "-e", "-c", command], env=self.env, check=True)
        for name in ("user.lua", "hyprland-user.lua"):
            self.assertEqual((hypr / name).read_text(), "-- personal settings\n")

    def test_fixup_does_not_change_user_hypr_modules(self):
        hypr = self.home / ".config/hypr"
        hypr.mkdir(parents=True)
        for name in ("user.lua", "hyprland-user.lua"):
            (hypr / name).write_text("render_power = 42\n")
        subprocess.run(["python3", str(ROOT / "install/lib/fixup.py")], env=self.env, check=True,
                       capture_output=True, text=True)
        for name in ("user.lua", "hyprland-user.lua"):
            self.assertEqual((hypr / name).read_text(), "render_power = 42\n")

    def test_shipped_hypr_defaults_do_not_pin_a_monitor(self):
        for name in ("moonlight-defaults.lua", "rice-settings.lua"):
            content = (ROOT / "config/hypr" / name).read_text()
            self.assertNotIn("hl.monitor", content)
            self.assertNotIn("sensitivity", content)

    def test_default_widget_layout_is_not_tied_to_one_display(self):
        desktop = json.loads((ROOT / "settings/rice/desktop.json").read_text())
        for widget in desktop["widgets"].values():
            self.assertFalse({"x", "y", "w"} & widget.keys())
        self.assertTrue(desktop["widgets"]["visualizer"]["enabled"])

    def test_user_module_stays_last_when_wiring_hyprland(self):
        hypr = self.home / ".config/hypr"
        hypr.mkdir(parents=True)
        main = hypr / "hyprland.lua"
        main.write_text('require("hyprland-user")\n')
        (hypr / "hyprland-user.lua").write_text("-- personal settings\n")
        (hypr / "rice-gpu.lua").write_text("-- hardware support\n")
        script = (ROOT / "install.sh").read_text()
        function = script[script.index("wire_hypr() {"):script.index("patch_colors() {")]
        subprocess.run(["bash", "-e", "-c", function + "\nwire_hypr\nwire_hypr\n"], env=self.env, check=True)
        lines = main.read_text().splitlines()
        self.assertEqual(lines[-1], 'require("hyprland-user")')
        self.assertEqual(lines.count('require("hyprland-user")'), 1)
        self.assertIn('pcall(require, "rice-gpu")', lines)

    def test_wrong_remote_is_rejected(self):
        self.setup_git()
        self.git("remote", "set-url", "origin", "https://github.com/example/other.git")
        result = self.install("--update", "--dry-run")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("origin must point", result.stderr)

    def test_failed_pull_preserves_changes(self):
        self.setup_git()
        fakebin = self.base / "fakebin"
        fakebin.mkdir()
        git = fakebin / "git"
        git.write_text('#!/bin/sh\ncase " $* " in *" pull "*) exit 1 ;; esac\nexec "' +
                       shutil.which("git") + '" "$@"\n')
        git.chmod(0o755)
        self.env["PATH"] = str(fakebin) + os.pathsep + self.env["PATH"]
        changed = self.repo / "VERSION"
        changed.write_text("local change\n")
        untracked = self.repo / "local.txt"
        untracked.write_text("local file\n")
        before = self.git("rev-parse", "HEAD").stdout
        result = self.install("--update", "--no-packages")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("git pull --ff-only failed", result.stderr)
        self.assertEqual(changed.read_text(), "local change\n")
        self.assertEqual(untracked.read_text(), "local file\n")
        self.assertEqual(self.git("rev-parse", "HEAD").stdout, before)
        self.assertEqual(self.git("stash", "list").stdout, "")


if __name__ == "__main__":
    unittest.main()
