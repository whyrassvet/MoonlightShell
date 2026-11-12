-- Infinite Desktop is based on the idea of Sarods2D: https://github.com/sarodscommits/hyprland-infinitie-desktop-v2 (MIT)
-- DarkShadow's Shell: Infinite Desktop (Settings > Desktop > Infinite Desktop, or SUPER + F)
-- The windows of a workspace float on an endless canvas. While it is on:
--   CTRL + mouse wheel          zoom out / in around the pointer (the windows get smaller and come together)
--   SUPER + mouse wheel         move the canvas up / down      SUPER + SHIFT + wheel: left / right
--   SUPER + ALT + arrows        move the canvas
--   hold SUPER + ALT            move the mouse: the canvas moves with it, live (rice-canvasd reads the mouse)
--   SUPER + drag a window       against the edge of the screen it pushes the others away, so it goes on
--   (these two also work while it is off, on the floating windows of the workspace you are on)
--   SUPER + ALT + 0             back to 100 %
--   SUPER + CTRL + arrows       go to the next window that way: the canvas glides until it is in the middle
-- A new window does not land on top of the others: it gets its own place next to the one you were in, and the
-- canvas glides to it (the pointer follows), so there is always room.
-- Turning it off puts every window back where it was and tiles again the ones that were tiled.
-- Everything is guarded: if something is missing in this Hyprland, the rest of the config still loads.

local RI = {}
RiceInfinite = RI

local HOME = os.getenv("HOME") or ""
local STATE = HOME .. "/.config/rice/infinite.state"
local CONF = HOME .. "/.config/rice/infinite.conf"
local LAYOUT = HOME .. "/.config/rice/infinite-layout"

RI.on = false
RI.ws = nil
RI.z, RI.ox, RI.oy = 1.0, 0, 0
RI.world = {}      -- address -> { x, y, w, h } on the canvas (screen = offset + canvas * zoom)
RI.tiled = {}      -- address -> true: it was tiled before, tile it again when turned off
RI.cfg = { step = 0.12, min = 0.2, max = 1.0, pan = 180 }

local function run(d)
    if d then pcall(hl.dispatch, d) end
end

local function sel(w)
    local a = tostring(w.address or "")
    if a:sub(1, 2) ~= "0x" then a = "0x" .. a end
    return "address:" .. a
end

local bind_keys, unbind_keys

-- your keys (Settings > Desktop > Infinite Desktop > Keys): on / off, the keys you hold (with the mouse or the
-- arrows), the ones for going to the next window, and the one for zooming with the wheel
RI.keys = { key_toggle = "SUPER + F", mod_hold = "SUPER + ALT", mod_go = "SUPER + CTRL", mod_zoom = "CTRL" }

function RI.load_cfg()
    local f = io.open(CONF, "r")
    if not f then return end
    for line in f:lines() do
        local k, v = line:match("^%s*(%w+)%s*=%s*([%d%.]+)%s*$")
        if k and RI.cfg[k] ~= nil and tonumber(v) then RI.cfg[k] = tonumber(v) end
        local kk, kv = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
        if kk and RI.keys[kk] ~= nil and kv ~= "" then RI.keys[kk] = kv end
    end
    f:close()
end

local function save()
    local f = io.open(STATE, "w")
    if not f then return end
    f:write(string.format("on=%d\nws=%s\nz=%.5f\nox=%.2f\noy=%.2f\nsig=%s\n", RI.on and 1 or 0, tostring(RI.ws or ""), RI.z, RI.ox, RI.oy,
        os.getenv("HYPRLAND_INSTANCE_SIGNATURE") or ""))
    for a in pairs(RI.tiled) do f:write("tiled=" .. a .. "\n") end
    f:close()
end

local function active_ws()
    local ws = hl.get_active_workspace()
    return ws and ws.id or nil
end

-- the windows of the canvas workspace that can be moved
local function wins()
    local out = {}
    local ok, list = pcall(hl.get_windows)
    if not ok or type(list) ~= "table" then return out end
    for _, w in pairs(list) do
        local wsid = w.workspace and w.workspace.id
        if wsid ~= nil and wsid == RI.ws and w.mapped ~= false and not w.hidden and (tonumber(w.fullscreen) or 0) == 0
            and not w.pinned and w.at and w.size then
            out[#out + 1] = w
        end
    end
    return out
end

-- where a window is on the canvas. Its place always comes from where it is on the screen now (Hyprland gives the
-- place a window is going to), so a window you moved yourself never jumps back; its size is kept
local function canvas(w)
    local s = RI.world[w.address]
    local x, y = (w.at.x - RI.ox) / RI.z, (w.at.y - RI.oy) / RI.z
    if not s then
        s = { x = x, y = y, w = w.size.x / RI.z, h = w.size.y / RI.z }
        RI.world[w.address] = s
    elseif not (s.tx and math.abs(w.at.x - s.tx) <= 2 and math.abs(w.at.y - s.ty) <= 2) then
        -- (where we put it ourselves: keep the exact value, no rounding creeping in)
        s.x, s.y = x, y
    end
    return s
end

local function place(w, s, resize)
    s.tx, s.ty = math.floor(RI.ox + s.x * RI.z + 0.5), math.floor(RI.oy + s.y * RI.z + 0.5)
    if resize then
        run(hl.dsp.window.resize({ x = math.max(60, math.floor(s.w * RI.z + 0.5)), y = math.max(40, math.floor(s.h * RI.z + 0.5)), window = sel(w) }))
    end
    run(hl.dsp.window.move({ x = math.floor(RI.ox + s.x * RI.z + 0.5), y = math.floor(RI.oy + s.y * RI.z + 0.5), window = sel(w) }))
end

local function here()
    return RI.on and active_ws() == RI.ws
end

function RI.zoom_to(nz, cx, cy)
    if not here() then return end
    local list = wins()
    for _, w in ipairs(list) do canvas(w) end
    nz = math.max(RI.cfg.min, math.min(RI.cfg.max, nz))
    if math.abs(nz - RI.z) < 0.0005 then return end
    if not cx then
        local c = hl.get_cursor_pos()
        cx, cy = c.x, c.y
    end
    -- the point under the pointer stays under the pointer
    local wx, wy = (cx - RI.ox) / RI.z, (cy - RI.oy) / RI.z
    RI.z = nz
    RI.ox, RI.oy = cx - wx * nz, cy - wy * nz
    for _, w in ipairs(list) do place(w, RI.world[w.address], true) end
    save()
end

-- dir > 0: closer (bigger), dir < 0: farther away (smaller)
function RI.zoom(dir)
    local f = 1 + RI.cfg.step
    RI.zoom_to(dir > 0 and RI.z * f or RI.z / f)
end

-- live: many small moves in a row (SUPER + ALT + mouse); the place is written down once at the end (RI.save)
function RI.pan(dx, dy, live)
    if not here() then return end
    local list = wins()
    for _, w in ipairs(list) do canvas(w) end
    RI.ox, RI.oy = RI.ox + dx, RI.oy + dy
    for _, w in ipairs(list) do place(w, RI.world[w.address], false) end
    if not live then save() end
end

function RI.save()
    save()
end

-- the floating windows of the workspace you are on (for SUPER + ALT while Infinite Desktop is off)
local function floats_here()
    local out, ws = {}, active_ws()
    local ok, list = pcall(hl.get_windows)
    if not ok or type(list) ~= "table" or ws == nil then return out end
    for _, w in pairs(list) do
        if w.floating and w.workspace and w.workspace.id == ws and w.mapped ~= false and not w.hidden
            and (tonumber(w.fullscreen) or 0) == 0 and not w.pinned and w.at then
            out[#out + 1] = w
        end
    end
    return out
end

local function nudge(list, dx, dy, skip)
    for _, w in ipairs(list) do
        if w.address ~= skip then
            run(hl.dsp.window.move({ x = math.floor(w.at.x + dx), y = math.floor(w.at.y + dy), window = sel(w) }))
        end
    end
end

-- SUPER + ALT + mouse (rice-canvasd): the canvas, or with Infinite Desktop off the floating windows here
function RI.slide(dx, dy)
    if here() then RI.pan(dx, dy, true) else nudge(floats_here(), dx, dy) end
end

-- the middle of the usable part of the screen (logical pixels, without the bar)
local function middle()
    local m = hl.get_active_monitor()
    if not m then return 960, 540, 1920, 1080 end
    local sc = (tonumber(m.scale) or 1)
    if sc <= 0 then sc = 1 end
    local W, H = (m.width or 1920) / sc, (m.height or 1080) / sc
    local r = m.reserved or {}
    local l, t, rr, b = tonumber(r.left) or 0, tonumber(r.top) or 0, tonumber(r.right) or 0, tonumber(r.bottom) or 0
    return (m.x or 0) + l + (W - l - rr) / 2, (m.y or 0) + t + (H - t - b) / 2, W - l - rr, H - t - b
end

-- glide the canvas so that this canvas point is in the middle of the screen (Hyprland animates the moves)
local function center_on(cx, cy, list)
    local mx, my = middle()
    local nox, noy = mx - cx * RI.z, my - cy * RI.z
    if math.abs(nox - RI.ox) + math.abs(noy - RI.oy) < 1 then return end
    RI.ox, RI.oy = nox, noy
    for _, w in ipairs(list) do
        local s = RI.world[w.address]
        if s then place(w, s, false) end
    end
end

local function focus(w)
    run(hl.dsp.focus({ window = sel(w) }))
end

local function overlaps(a, list, skip)
    for addr, b in pairs(list) do
        if addr ~= skip and a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h then return true end
    end
    return false
end

-- a free place on the canvas next to the window you were in (to the right, then below, then left, then above)
local function room(from, w, h)
    local gap = 40
    if not from then
        local mx, my = middle()
        return (mx - RI.ox) / RI.z - w / 2, (my - RI.oy) / RI.z - h / 2
    end
    local tries = {
        function(k) return from.x + from.w + gap + k * (w + gap), from.y end,
        function(k) return from.x, from.y + from.h + gap + k * (h + gap) end,
        function(k) return from.x - w - gap - k * (w + gap), from.y end,
        function(k) return from.x, from.y - h - gap - k * (h + gap) end,
    }
    for k = 0, 12 do
        for _, f in ipairs(tries) do
            local x, y = f(k)
            if not overlaps({ x = x, y = y, w = w, h = h }, RI.world, nil) then return x, y end
        end
    end
    return from.x + from.w + gap, from.y
end

-- SUPER + CTRL + arrows: the nearest window that way, brought to the middle
function RI.go(dir)
    if not here() then return end
    local list = wins()
    local a = hl.get_active_window()
    local cx, cy
    if a and a.at and a.size and a.workspace and a.workspace.id == RI.ws then
        cx, cy = a.at.x + a.size.x / 2, a.at.y + a.size.y / 2
    else
        cx, cy = middle()
    end
    local best, bestd
    for _, w in ipairs(list) do
        if not (a and w.address == a.address) then
            local dx, dy = w.at.x + w.size.x / 2 - cx, w.at.y + w.size.y / 2 - cy
            local along, across
            if dir == "right" then along, across = dx, dy
            elseif dir == "left" then along, across = -dx, dy
            elseif dir == "down" then along, across = dy, dx
            else along, across = -dy, dx end
            if along > 1 then
                local d = along + 2 * math.abs(across)
                if not bestd or d < bestd then best, bestd = w, d end
            end
        end
    end
    if not best then return end
    -- the middle of that window goes to the middle of the screen: the whole canvas glides by that much
    local mx, my = middle()
    RI.pan(math.floor(mx - (best.at.x + best.size.x / 2) + 0.5), math.floor(my - (best.at.y + best.size.y / 2) + 0.5))
    focus(best)
end

-- a window that opened on the canvas: float it, give it its own room next to the last one, glide there
function RI.opened(w)
    if not (RI.on and w and w.workspace and w.workspace.id == RI.ws) then return end
    if not w.floating then
        -- it would have been tiled: it tiles again when Infinite Desktop is turned off
        RI.tiled[w.address] = true
        run(hl.dsp.window.float({ action = "set", window = sel(w) }))
    end
    local list = wins()
    local lastAddr = (RI.last ~= w.address) and RI.last or RI.prev
    local from = lastAddr and RI.world[lastAddr]
    for _, o in ipairs(list) do
        if o.address ~= w.address then canvas(o) end
    end
    if lastAddr and not RI.world[lastAddr] then from = nil end
    local _, _, W, H = middle()
    local nw = from and from.w or (W * 0.6) / RI.z
    local nh = from and from.h or (H * 0.7) / RI.z
    local x, y = room(from, nw, nh)
    RI.world[w.address] = { x = x, y = y, w = nw, h = nh }
    local fresh = {}
    for _, o in ipairs(wins()) do fresh[#fresh + 1] = o end
    for _, o in ipairs(fresh) do
        if o.address == w.address then place(o, RI.world[o.address], true) end
    end
    center_on(x + nw / 2, y + nh / 2, fresh)
    focus(w)
    if RI.last ~= w.address then RI.prev = RI.last end
    RI.last = w.address
    save()
end

-- SUPER + dragging a window against the edge of the screen: the other windows move away, so it can go on
function RI.edge_push(dx, dy)
    local a = hl.get_active_window()
    if not (a and a.at and a.floating) then return end
    -- only when the pointer is at the edge of the screen and the mouse goes on that way: the window you hold
    -- cannot go further, so the others come towards it
    local m = hl.get_active_monitor()
    local c = hl.get_cursor_pos()
    if not (m and c) then return end
    local sc = tonumber(m.scale) or 1
    if sc <= 0 then sc = 1 end
    local l, t = m.x or 0, m.y or 0
    local r, b = l + (m.width or 1920) / sc, t + (m.height or 1080) / sc
    local px, py = 0, 0
    if (dx < 0 and c.x <= l + 2) or (dx > 0 and c.x >= r - 3) then px = -dx end
    if (dy < 0 and c.y <= t + 2) or (dy > 0 and c.y >= b - 3) then py = -dy end
    if px == 0 and py == 0 then return end
    if not here() then
        nudge(floats_here(), px, py, a.address)
        return
    end
    local list = wins()
    for _, w in ipairs(list) do canvas(w) end
    RI.ox, RI.oy = RI.ox + px, RI.oy + py
    for _, w in ipairs(list) do
        if w.address ~= a.address then place(w, RI.world[w.address], false) end
    end
    -- the window you hold stays under the pointer: its place on the canvas moved
    local s = RI.world[a.address]
    if s then s.x, s.y = (a.at.x - RI.ox) / RI.z, (a.at.y - RI.oy) / RI.z; s.tx = nil end
end

-- rice-canvasd: SUPER + ALT + mouse and the push at the edge (it reads the mouse, Hyprland cannot tell it)
local function daemon(on)
    run(hl.dsp.exec_cmd(HOME .. "/.local/bin/rice-infinite " .. (on and "daemon" or "daemon-stop")))
end

local function notify(text)
    run(hl.dsp.exec_cmd("command -v notify-send >/dev/null && notify-send -t 1600 -a 'Infinite Desktop' 'Infinite Desktop' '" .. text .. "'"))
end

-- keys that only exist while it is on (CTRL + wheel goes back to your apps when it is off). Made from your keys
local KEYS = {}
local function k(mod, key) return mod .. " + " .. key end

bind_keys = function()
    local p = function() return RI.cfg.pan end
    local K = RI.keys
    local hold, go, zoom = K.mod_hold, K.mod_go, K.mod_zoom
    KEYS = { k(zoom, "mouse_down"), k(zoom, "mouse_up"), "SUPER + SHIFT + mouse_down", "SUPER + SHIFT + mouse_up",
        k(hold, "left"), k(hold, "right"), k(hold, "up"), k(hold, "down"), k(hold, "0"),
        k(go, "left"), k(go, "right"), k(go, "up"), k(go, "down") }
    pcall(hl.unbind, "SUPER + mouse_down")
    pcall(hl.unbind, "SUPER + mouse_up")
    pcall(hl.bind, k(zoom, "mouse_down"), function() RI.zoom(-1) end)
    pcall(hl.bind, k(zoom, "mouse_up"), function() RI.zoom(1) end)
    pcall(hl.bind, "SUPER + mouse_down", function() RI.pan(0, -p()) end)
    pcall(hl.bind, "SUPER + mouse_up", function() RI.pan(0, p()) end)
    pcall(hl.bind, "SUPER + SHIFT + mouse_down", function() RI.pan(-p(), 0) end)
    pcall(hl.bind, "SUPER + SHIFT + mouse_up", function() RI.pan(p(), 0) end)
    pcall(hl.bind, k(hold, "left"), function() RI.pan(p(), 0) end, { repeating = true })
    pcall(hl.bind, k(hold, "right"), function() RI.pan(-p(), 0) end, { repeating = true })
    pcall(hl.bind, k(hold, "up"), function() RI.pan(0, p()) end, { repeating = true })
    pcall(hl.bind, k(hold, "down"), function() RI.pan(0, -p()) end, { repeating = true })
    pcall(hl.bind, k(hold, "0"), function() RI.zoom_to(1.0) end)
    pcall(hl.bind, k(go, "left"), function() RI.go("left") end)
    pcall(hl.bind, k(go, "right"), function() RI.go("right") end)
    pcall(hl.bind, k(go, "up"), function() RI.go("up") end)
    pcall(hl.bind, k(go, "down"), function() RI.go("down") end)
end

unbind_keys = function()
    for _, key in ipairs(KEYS) do pcall(hl.unbind, key) end
    pcall(hl.unbind, "SUPER + mouse_down")
    pcall(hl.unbind, "SUPER + mouse_up")
    -- the normal SUPER + wheel: next / previous workspace
    pcall(hl.bind, "SUPER + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
    pcall(hl.bind, "SUPER + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
end

-- the on / off key (yours, SUPER + F by default)
local toggle_key = nil
local function bind_toggle()
    if toggle_key then pcall(hl.unbind, toggle_key) end
    toggle_key = RI.keys.key_toggle
    pcall(hl.bind, toggle_key, function() RI.toggle() end)
end

-- after Settings changed something
function RI.reload()
    if RI.on then for _, key in ipairs(KEYS) do pcall(hl.unbind, key) end end
    pcall(RI.load_cfg)
    pcall(bind_toggle)
    if RI.on then bind_keys() end
end

-- ---------- the canvas of each workspace is remembered (turn it off and on: everything is where you left it) ----------
RI.layouts = {}     -- workspace id -> { z, ox, oy, wins = { { a = address, c = class, x, y, w, h }, ... } }

local function clean(t)
    return (tostring(t or ""):gsub("[|\n]", " "))
end

local function write_layouts()
    local f = io.open(LAYOUT, "w")
    if not f then return end
    for ws, l in pairs(RI.layouts) do
        f:write(string.format("ws|%s|%.5f|%.2f|%.2f\n", tostring(ws), l.z, l.ox, l.oy))
        for _, e in ipairs(l.wins) do
            f:write(string.format("win|%s|%s|%s|%.2f|%.2f|%.2f|%.2f\n", tostring(ws), clean(e.a), clean(e.c), e.x, e.y, e.w, e.h))
        end
    end
    f:close()
end

local function read_layouts()
    local f = io.open(LAYOUT, "r")
    if not f then return end
    for line in f:lines() do
        local p = {}
        for v in (line .. "|"):gmatch("([^|]*)|") do p[#p + 1] = v end
        if p[1] == "ws" and #p >= 5 then
            local ws = tonumber(p[2]) or p[2]
            RI.layouts[ws] = { z = tonumber(p[3]) or 1, ox = tonumber(p[4]) or 0, oy = tonumber(p[5]) or 0, wins = {} }
        elseif p[1] == "win" and #p >= 8 then
            local l = RI.layouts[tonumber(p[2]) or p[2]]
            if l then
                l.wins[#l.wins + 1] = { a = p[3], c = p[4], x = tonumber(p[5]) or 0, y = tonumber(p[6]) or 0,
                    w = tonumber(p[7]) or 400, h = tonumber(p[8]) or 300 }
            end
        end
    end
    f:close()
end

local function class_of(w)
    return clean(w.class or w.initialClass or w.initial_class or "")
end

-- before turning off: where every window of this workspace is on the canvas
local function remember()
    if RI.ws == nil then return end
    local l = { z = RI.z, ox = RI.ox, oy = RI.oy, wins = {} }
    for _, w in ipairs(wins()) do
        local s = canvas(w)
        l.wins[#l.wins + 1] = { a = w.address, c = class_of(w), x = s.x, y = s.y, w = s.w, h = s.h }
    end
    if #l.wins > 0 then
        RI.layouts[RI.ws] = l
        write_layouts()
    end
end

-- after turning on: the windows go back to their places (the same window, or else one of the same app)
local function bring_back()
    local l = RI.layouts[RI.ws]
    if not l then return false end
    RI.z, RI.ox, RI.oy = l.z, l.ox, l.oy
    local used = {}
    local function find(w)
        for i, e in ipairs(l.wins) do
            if not used[i] and e.a == w.address then used[i] = true; return e end
        end
        local c = class_of(w)
        if c == "" then return nil end
        for i, e in ipairs(l.wins) do
            if not used[i] and e.c == c then used[i] = true; return e end
        end
        return nil
    end
    local list = wins()
    local fresh = {}
    for _, w in ipairs(list) do
        local e = find(w)
        if e then
            RI.world[w.address] = { x = e.x, y = e.y, w = e.w, h = e.h }
        else
            fresh[#fresh + 1] = w
        end
    end
    -- a window that was not there before keeps its place on the screen
    for _, w in ipairs(fresh) do
        local o = RI.world[w.address]
        if o then RI.world[w.address] = { x = (o.x - RI.ox) / RI.z, y = (o.y - RI.oy) / RI.z, w = o.w / RI.z, h = o.h / RI.z } end
    end
    for _, w in ipairs(list) do
        local s = RI.world[w.address]
        if s then place(w, s, true) end
    end
    return true
end

pcall(read_layouts)

function RI.set(on)
    on = on and true or false
    if on == RI.on then return end
    if on then
        RI.ws = active_ws()
        if RI.ws == nil then return end
        RI.z, RI.ox, RI.oy, RI.world, RI.tiled = 1.0, 0, 0, {}, {}
        local list = wins()
        for _, w in ipairs(list) do
            RI.world[w.address] = { x = w.at.x, y = w.at.y, w = w.size.x, h = w.size.y }
            if not w.floating then
                RI.tiled[w.address] = true
                run(hl.dsp.window.float({ action = "set", window = sel(w) }))
            end
        end
        RI.on = true
        -- this workspace had a canvas before: everything back where you left it
        if not bring_back() then
            -- floating gives a window another size: put each one back where it was
            for _, w in ipairs(wins()) do
                local s = RI.world[w.address]
                if s and RI.tiled[w.address] then place(w, s, true) end
            end
        end
        local a = hl.get_active_window()
        RI.last = a and a.address or nil
        bind_keys()
        daemon(true)
        notify("On: hold " .. RI.keys.mod_hold .. " and move the mouse, " .. RI.keys.mod_zoom .. " + wheel to zoom")
        -- SUPER + ALT + mouse cannot read the mouse yet: say what the one step is (nothing happening is the worst)
        run(hl.dsp.exec_cmd(HOME .. "/.local/bin/rice-canvasd --tell"))
    else
        if RI.ws ~= nil then
            pcall(remember)
            -- back to 100 % where everything started
            RI.z, RI.ox, RI.oy = 1.0, 0, 0
            for _, w in ipairs(wins()) do
                local s = RI.world[w.address]
                if s then place(w, s, true) end
                if RI.tiled[w.address] then run(hl.dsp.window.float({ action = "unset", window = sel(w) })) end
            end
        end
        RI.on = false
        unbind_keys()
        notify("Off: windows are back")
    end
    save()
end

function RI.toggle()
    RI.set(not RI.on)
end

-- after a config reload: carry on where it was
local function restore()
    local f = io.open(STATE, "r")
    if not f then return end
    local st = { tiled = {} }
    for line in f:lines() do
        local k, v = line:match("^(%w+)=(.*)$")
        if k == "tiled" then st.tiled[v] = true elseif k then st[k] = v end
    end
    f:close()
    -- only after a config reload of this same session, not on the next login
    local sig = os.getenv("HYPRLAND_INSTANCE_SIGNATURE") or ""
    if st.on ~= "1" or sig == "" or st.sig ~= sig then
        if st.on == "1" then RI.on = false; save() end
        return
    end
    RI.on = true
    RI.ws = tonumber(st.ws) or st.ws
    RI.z, RI.ox, RI.oy = tonumber(st.z) or 1.0, tonumber(st.ox) or 0, tonumber(st.oy) or 0
    RI.tiled = st.tiled
    RI.world = {}
    bind_keys()
    daemon(true)
end

pcall(RI.load_cfg)
pcall(restore)

pcall(bind_toggle)

-- rice-canvasd runs with Hyprland (only one at a time; it stops when Hyprland stops)
local CANVASD = HOME .. "/.local/bin/rice-infinite daemon"
pcall(hl.on, "hyprland.start", function() pcall(hl.exec_cmd, CANVASD) end)
if (os.getenv("HYPRLAND_INSTANCE_SIGNATURE") or "") ~= "" then pcall(hl.exec_cmd, CANVASD) end

-- a window that opens on the canvas floats too
pcall(hl.on, "window.open", function(w) pcall(RI.opened, w) end)
pcall(hl.on, "window.close", function(w) if w and RI.world[w.address] then RI.world[w.address] = nil end end)
-- the window you are in: new windows get their place next to it
pcall(hl.on, "window.active", function(w)
    if RI.on and w and w.address and w.workspace and w.workspace.id == RI.ws and w.address ~= RI.last then
        RI.prev = RI.last
        RI.last = w.address
    end
end)
