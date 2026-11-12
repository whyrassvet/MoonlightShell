-- DarkShadow's Shell: your own keys for the shell's actions (Settings > System > Keybinds, the pencil next to a key).
-- The keys you chose are in ~/.config/rice/keys.conf (id=KEYS); this file is loaded after the others, takes the
-- default key away from the action and gives it the one you chose. Missing pieces never stop the config.

local RK = {}
RiceKeys = RK

local HOME = os.getenv("HOME") or ""
local BIN = HOME .. "/.local/bin/"
local CONF = HOME .. "/.config/rice/keys.conf"

local function exec(cmd) return function() return hl.dsp.exec_cmd(cmd) end end

-- id -> default keys, what it does (a function that gives the dispatcher, so nothing is made before it is needed)
RK.actions = {
    terminal  = { "SUPER + Return",    exec(BIN .. "rice-term") },
    launcher  = { "SUPER + R",         exec(BIN .. "rice-launch") },
    launcher2 = { "ALT + Space",       exec(BIN .. "rice-launch") },
    settings  = { "SUPER + U",         exec(BIN .. "rice-settings") },
    wallpaper = { "SUPER + W",         exec(BIN .. "rice-dashboard wallpaper") },
    quick     = { "SUPER + A",         exec(BIN .. "rice-dashboard open control") },
    cc        = { "SUPER + N",         exec(BIN .. "rice-cc") },
    gamebar   = { "SUPER + G",         exec(BIN .. "rice-gamebar") },
    dashboard = { "SUPER + ALT + D",   exec(BIN .. "rice-dashboard open") },
    lock      = { "SUPER + L",         exec(BIN .. "rice-lock now") },
    close     = { "SUPER + Q",         function() return hl.dsp.window.close() end },
    float     = { "SUPER + SHIFT + V", function() return hl.dsp.window.float({ action = "toggle" }) end },
    clipboard = { "SUPER + V",         exec(BIN .. "rice-clip toggle") },
    shot      = { "Print",             exec(BIN .. "rice-hotcorner shot region") },
    shotfull  = { "SHIFT + Print",     exec(BIN .. "rice-hotcorner shot full") },
    record    = { "SUPER + SHIFT + R", exec(BIN .. "rice-hotcorner record region") },
    widgets   = { "SUPER + ALT + W",   exec(BIN .. "desktop-set edit toggle") },
    taskview  = { "SUPER + TAB",       exec(BIN .. "rice-taskview overview") },
    switcher  = { "ALT + TAB",         exec(BIN .. "rice-taskview switch") },
    infinite  = { "SUPER + F",         function() return function() if RiceInfinite then RiceInfinite.toggle() end end end },
}

RK.cur = RK.cur or {}   -- id -> the keys it has now (when not the default)

local function read()
    local out = {}
    local f = io.open(CONF, "r")
    if not f then return out end
    for line in f:lines() do
        local id, keys = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
        if id and RK.actions[id] and keys ~= "" then out[id] = keys end
    end
    f:close()
    return out
end

-- give every action the key it should have now
function RK.apply()
    local want = read()
    for id, a in pairs(RK.actions) do
        local now = RK.cur[id] or a[1]
        local new = want[id] or a[1]
        if now ~= new then
            pcall(hl.unbind, now)
            local ok, d = pcall(a[2])
            if ok and d then pcall(hl.bind, new, d) end
            -- back to the default: the default key was taken away above when it was changed, give it back
            RK.cur[id] = (new ~= a[1]) and new or nil
        end
    end
end

pcall(RK.apply)
