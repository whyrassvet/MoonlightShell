-- keybinds that belong to DarkShadow's Shell (installed by install.sh, loaded from hyprland.lua)
local bin = os.getenv("HOME") .. "/.local/bin/"

-- wallpaper picker: unbind first so only ONE menu opens even if another config also binds SUPER + W
hl.unbind("SUPER + W")
-- the Wallpaper tab of the dashboard (or the old picker when the dashboard is off)
hl.bind("SUPER + W", hl.dsp.exec_cmd(bin .. "rice-dashboard wallpaper"))

-- volume, microphone and brightness: laptop Fn keys and headset +/- buttons
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd(bin .. "rice-media up"),          { locked = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd(bin .. "rice-media down"),        { locked = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd(bin .. "rice-media mute"),        { locked = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd(bin .. "rice-media mic"),         { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(bin .. "rice-media bright-up"),   { locked = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(bin .. "rice-media bright-down"), { locked = true })

-- screenshots and screen recording
hl.bind("Print",               hl.dsp.exec_cmd(bin .. "rice-hotcorner shot region"))
hl.bind("SHIFT + Print",       hl.dsp.exec_cmd(bin .. "rice-hotcorner shot full"))
hl.bind("SUPER + SHIFT + R",   hl.dsp.exec_cmd(bin .. "rice-hotcorner record region"))   -- press again to stop
hl.bind("SUPER + A",           hl.dsp.exec_cmd(bin .. "rice-dashboard open control"))   -- quick switches
-- widget editor on the desktop (Esc or Done to finish)
hl.bind("SUPER + ALT + W",     hl.dsp.exec_cmd(bin .. "desktop-set edit toggle"))
-- dashboard (also: point at the middle of the bar edge)
hl.bind("SUPER + ALT + D",     hl.dsp.exec_cmd(bin .. "rice-dashboard open"))
-- the game bar: CPU / GPU, capture, power mode, gaming mode, volume and brightness over your game
hl.bind("SUPER + G",           hl.dsp.exec_cmd(bin .. "rice-gamebar"))
-- the control center: switches, sliders, music and notifications
hl.bind("SUPER + N",           hl.dsp.exec_cmd(bin .. "rice-cc"))
-- the clipboard history (float / tile moved to SUPER + SHIFT + V)
pcall(hl.unbind, "SUPER + V")
hl.bind("SUPER + V",           hl.dsp.exec_cmd(bin .. "rice-clip toggle"))

-- the Task view (every workspace and its windows) and the window switcher (rice-taskview, TaskView.qml)
pcall(hl.bind, "SUPER + TAB",       hl.dsp.exec_cmd(bin .. "rice-taskview overview"))
pcall(hl.bind, "ALT + TAB",         hl.dsp.exec_cmd(bin .. "rice-taskview switch"))
pcall(hl.bind, "ALT + SHIFT + TAB", hl.dsp.exec_cmd(bin .. "rice-taskview back"))
-- letting go of ALT goes to the window picked in the switcher (written straight to the file: no program starts)
local taskfile = os.getenv("HOME") .. "/.cache/rice/taskview-open"
local commit = "sh -c 'printf \"%s commit\\n\" \"$(date +%s.%N)\" > " .. taskfile .. "'"
pcall(hl.bind, "ALT + ALT_L", hl.dsp.exec_cmd(commit), { release = true })
-- SUPER alone (pressed and let go) opens the Task view, when it is on (Settings > Desktop > Task view)
RiceTask = RiceTask or {}
function RiceTask.super(on)
    pcall(hl.unbind, "SUPER + SUPER_L")
    if on then pcall(hl.bind, "SUPER + SUPER_L", hl.dsp.exec_cmd(bin .. "rice-taskview overview"), { release = true }) end
end
do
    local f = io.open(os.getenv("HOME") .. "/.config/rice/taskview.json", "r")
    local s = f and f:read("*a") or ""
    if f then f:close() end
    if s:match('"super"%s*:%s*true') then RiceTask.super(true) end
end

-- a key bound with nothing held (a plain letter) can never be typed; anything that does that is taken off at
-- start (hypr-set keycheck lists them, ~/.cache/rice/keycheck.log says what was taken off)
pcall(hl.on, "hyprland.start", function() pcall(hl.exec_cmd, "sleep 5; " .. bin .. "hypr-set keycheck-fix >/dev/null 2>&1") end)
