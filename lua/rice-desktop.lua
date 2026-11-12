-- starts the desktop widgets, dock, hot corner and welcome screen (DarkShadow's Shell)
hl.on("hyprland.start", function()
    -- without systemd (Void): PipeWire and the password prompt agent are started here
    hl.exec_cmd(os.getenv("HOME") .. "/.local/bin/rice-sys session")
    hl.exec_cmd(os.getenv("HOME") .. "/.local/bin/rice-desktop start")
    -- your cursor from Settings > Cursors (Bibata Modern Ice by default)
    hl.exec_cmd(os.getenv("HOME") .. "/.local/bin/rice-cursor restore")
end)

-- see-through, blurred Nautilus (like Overskride) and floating pop-up apps.
-- pcall: if your Hyprland does not know a key, it is skipped instead of breaking the config.
local function rule(r) pcall(hl.window_rule, r) end
rule({ name = "rice-nautilus-glass", match = { class = "org.gnome.Nautilus" }, opacity = "0.90 0.84" })
rule({ name = "rice-calendar-float", match = { class = "org.gnome.Calendar" }, float = true, center = true, size = "900 650" })

-- full-screen layers that animate themselves: no extra pop-in from Hyprland
pcall(hl.layer_rule, { name = "rice-welcome-noanim", match = { namespace = "rice-welcome" }, no_anim = true })
pcall(hl.layer_rule, { name = "rice-tour-dim-noanim", match = { namespace = "rice-tour-dim" }, no_anim = true })
