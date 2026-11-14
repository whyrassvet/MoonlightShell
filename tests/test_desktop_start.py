import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class DesktopStartTests(unittest.TestCase):
    def test_parallel_ensure_starts_one_shell(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            fakebin = home / "fakebin"
            fakebin.mkdir()
            shell = home / ".config/quickshell/rice-desktop/shell.qml"
            shell.parent.mkdir(parents=True)
            shell.touch()
            desktop_set = home / ".local/bin/desktop-set"
            desktop_set.parent.mkdir(parents=True)
            desktop_set.write_text("#!/bin/sh\nexit 0\n")
            desktop_set.chmod(0o755)
            for name, script in {
                "pgrep": 'test -f "$HOME/running"',
                "setsid": 'echo launch >> "$HOME/launches"; (sleep 0.1; touch "$HOME/running") >/dev/null 2>&1 &',
            }.items():
                path = fakebin / name
                path.write_text("#!/bin/sh\n" + script + "\n")
                path.chmod(0o755)
            env = dict(os.environ, HOME=tmp, PATH=f"{fakebin}:{os.environ['PATH']}")
            processes = [subprocess.Popen([str(ROOT / "bin/rice-desktop"), "ensure"], env=env)
                         for _ in range(8)]
            for process in processes:
                self.assertEqual(process.wait(timeout=10), 0)
            self.assertEqual((home / "launches").read_text().splitlines(), ["launch"])


if __name__ == "__main__":
    unittest.main()
