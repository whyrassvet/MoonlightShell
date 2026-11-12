import os
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
