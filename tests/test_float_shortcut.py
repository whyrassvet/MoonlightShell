import runpy
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class FloatShortcutTests(unittest.TestCase):
    def test_defaults_match(self):
        keymap = runpy.run_path(str(ROOT / "bin/rice-keymap"))
        niri = runpy.run_path(str(ROOT / "bin/rice-niri"))
        self.assertEqual(keymap["DEFAULTS"]["float"], "SUPER + T")
        self.assertEqual(niri["ACTION_KEYS"]["float"], "Mod+T")
        binds = niri["default_binds"](niri["F"]((99, 0)), "terminal", "files")
        self.assertEqual([b[2] for b in binds if b[0] == "Mod+T"], ["toggle-window-floating;"])
        self.assertIn(("Mod+Shift+T", 'hotkey-overlay-title="Tabs in this column"',
                       "toggle-column-tabbed-display;"), binds)

    def test_hypr_binds_toggle_once(self):
        for path in (ROOT / "lua/rice-keys.lua", ROOT / "config/hypr/rice-keys.lua"):
            text = path.read_text()
            self.assertIn('hl.unbind("SUPER + T")', text)
            self.assertIn('hl.bind("SUPER + T", hl.dsp.window.float({ action = "toggle" }))', text)
        self.assertIn('float     = { "SUPER + T"', (ROOT / "lua/rice-keymap.lua").read_text())


if __name__ == "__main__":
    unittest.main()
