import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class NotificationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.env = dict(os.environ, HOME=str(self.home))

    def run_tool(self, name, *args):
        return subprocess.run([str(ROOT / "bin" / name), *args], env=self.env,
                              capture_output=True, text=True, check=True)

    def test_legacy_engine_does_not_break_dnd(self):
        cfg = self.home / ".config/rice/cc.json"
        cfg.parent.mkdir(parents=True)
        cfg.write_text(json.dumps({"engine": "swaync", "dnd": True, "shellOnce": True}))
        self.assertEqual(self.run_tool("rice-cc", "dnd", "state").stdout.strip(), "on")
        self.run_tool("rice-cc", "migrate")
        self.assertEqual(json.loads(cfg.read_text())["engine"], "shell")
        self.run_tool("rice-cc", "dnd", "off")
        self.assertFalse(json.loads(cfg.read_text())["dnd"])

    def test_notification_settings_and_blur(self):
        self.run_tool("rice-notify", "set", "timeout", "9")
        state = json.loads(self.run_tool("rice-notify", "state").stdout)
        self.assertEqual(state["timeout"], 9)
        lua = (self.home / ".config/hypr/rice-notify.lua").read_text()
        self.assertIn('namespace = "rice-notify-popup"', lua)
        self.assertNotIn("swaync", lua)
        self.assertFalse((self.home / ".config/swaync").exists())

    def test_installer_packages_do_not_include_alternative_daemon(self):
        output = subprocess.check_output(
            ["bash", "-c", 'source install/lib/distro.sh; printf "%s\\n" "${ARCH_PKGS[@]}" "${NEED_CMDS[@]}"'],
            cwd=ROOT, env=self.env, text=True)
        self.assertNotIn("swaync", output)


if __name__ == "__main__":
    unittest.main()
