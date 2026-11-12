-- DarkShadow's Shell: a setting or keybind this Hyprland does not know never stops the rest of the config.
-- Without this, one unknown option (a newer or older Hyprland, a distro build) ends the whole hyprland.lua and
-- Hyprland falls back to its emergency config: no keybinds but SUPER + Enter, no bar, no cursor theme.
-- What was skipped is written to ~/.cache/rice/hypr-errors.log (and shown once as a notification).
-- Loaded first from hyprland.lua: pcall(require, "rice-guard")
local home = os.getenv("HOME") or ""
local logp = home .. "/.cache/rice/hypr-errors.log"
local told = false

local function note(what, err)
  pcall(function()
    os.execute("mkdir -p '" .. home .. "/.cache/rice'")
    local f = io.open(logp, told and "a" or "w")
    if f then f:write(what .. ": " .. tostring(err) .. "\n"); f:close() end
  end)
  if not told then
    told = true
    pcall(function()
      os.execute("(sleep 6; notify-send -a \"DarkShadow's Shell\" 'Some Hyprland settings were skipped' " ..
                 "'Your Hyprland does not know them. The rest works. Details: ~/.cache/rice/hypr-errors.log') >/dev/null 2>&1 &")
    end)
  end
end

-- every setting call: run it, and if Hyprland refuses it, write it down and go on
for _, name in ipairs({ "config", "bind", "unbind", "env", "monitor", "animation", "curve", "window_rule", "layer_rule",
                        "workspace_rule", "device", "gesture", "permission", "exec_cmd", "plugin" }) do
  pcall(function()
    local f = hl[name]
    if type(f) ~= "function" then return end
    hl[name] = function(...)
      local ok, r = pcall(f, ...)
      if ok then return r end
      note("hl." .. name, r)
    end
  end)
end

-- a dispatcher this Hyprland does not have (hl.dsp.something) gives a harmless nil instead of an error
local function soft(t, path, depth)
  if depth > 2 then return end
  pcall(function()
    for k, v in pairs(t) do
      if type(v) == "table" then soft(v, path .. "." .. k, depth + 1) end
    end
    setmetatable(t, { __index = function(_, k) note(path .. "." .. tostring(k), "not in this Hyprland"); return nil end })
  end)
end
pcall(soft, hl.dsp, "hl.dsp", 0)

-- the lock screen: if it ever stops while the screen is locked, another one (hyprlock) may take the lock over
-- instead of leaving a red "locked" screen (rice-lock does that by itself)
hl.config({ misc = { allow_session_lock_restore = true } })
