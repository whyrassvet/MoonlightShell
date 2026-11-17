import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class AltSwitchTests(unittest.TestCase):
    # Alt must reach the app: games (Dota 2) draw their alt-overlays only on a real Alt keypress,
    # so the release bind that confirms the pick must not consume the press.
    def test_alt_release_bind_keeps_alt_for_apps(self):
        for path in (ROOT / "lua/rice-keys.lua", ROOT / "config/hypr/rice-keys.lua"):
            text = path.read_text()
            self.assertIn('"ALT + ALT_L"', text)
            self.assertIn("release = true, non_consuming = true", text)

    # Hyprland 0.57 runs `hyprctl dispatch` as Lua: the old hyprlang arguments fail with a parse error.
    def test_taskview_uses_lua_dispatchers(self):
        text = (ROOT / "bin/rice-taskview").read_text()
        for legacy in ("focuswindow", "closewindow", "movetoworkspacesilent"):
            self.assertNotIn(legacy, text)
        self.assertIn('hl.dsp.focus({ window = "address:%s" })', text)
        self.assertIn('hl.dsp.window.close({ window = "address:%s" })', text)
        self.assertIn('hl.dsp.window.move({ workspace = "%s", window = "address:%s", follow = false })', text)
        self.assertIn('hl.dsp.focus({ workspace = "%s" })', text)

    # The strip opens under the pointer: hovering a tile must not move the highlight.
    def test_switcher_ignores_hover(self):
        text = (ROOT / "quickshell/rice-desktop/TaskView.qml").read_text()
        self.assertNotIn("onEntered: tv.sel = index", text)
        self.assertIn("onClicked: { tv.sel = index; tv.commit() }", text)


if __name__ == "__main__":
    unittest.main()
