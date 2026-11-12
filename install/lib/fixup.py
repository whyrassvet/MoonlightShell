"""Make a copied Hyprland config work on this computer.

- require("x") lines whose x.lua does not exist here are commented out (instead of breaking the config)
- values that newer Hyprland versions reject are clamped (shadow render_power 1..4)
- V3.17: the Hyprland autostart starts the DarkShadow bar (rice-bar start: Waybar only if you switched it off) and
  ALT + Space opens the DarkShadow Launcher (rice-launch: Rofi if you chose Rofi). A copy of the file is kept next to it
Prints one line per change. Safe to run many times.
"""
import json
import os
import re
import sys

home = os.path.expanduser("~")
hypr = home + "/.config/hypr"
changes = []


def fix_requires(path):
    try:
        s = open(path).read()
    except OSError:
        return
    def repl(m):
        indent, name = m.group(1), m.group(2)
        base = os.path.join(hypr, *name.split("."))
        if os.path.exists(base + ".lua") or os.path.exists(os.path.join(base, "init.lua")):
            return m.group(0)
        changes.append("%s: module '%s' is not on this computer, turned it off" % (os.path.basename(path), name))
        return "%s-- [DarkShadow's Shell] missing on this computer: %s" % (indent, m.group(0).strip())
    n = re.sub(r'^([ \t]*)require\(\s*"([^"]+)"\s*\)[^\n]*$', repl, s, flags=re.M)
    if n != s:
        open(path, "w").write(n)


def clamp_lua(path):
    try:
        s = open(path).read()
    except OSError:
        return
    def repl(m):
        v = int(m.group(2))
        nv = max(1, min(4, v))
        if nv != v:
            changes.append("%s: shadow render_power %d -> %d (allowed 1..4)" % (os.path.basename(path), v, nv))
        return m.group(1) + str(nv)
    n = re.sub(r'(render_power"?\]?\s*[=,:]\s*)(\d+)', repl, s)
    if n != s:
        open(path, "w").write(n)


def clamp_json(path):
    try:
        j = json.load(open(path))
    except Exception:
        return
    hit = False
    def walk(o):
        nonlocal hit
        if isinstance(o, dict):
            for k, v in o.items():
                if "render_power" in k and isinstance(v, (int, float)) and not 1 <= v <= 4:
                    o[k] = max(1, min(4, int(v)))
                    hit = True
                else:
                    walk(v)
    walk(j)
    if hit:
        json.dump(j, open(path, "w"))
        changes.append("%s: shadow render_power clamped to 1..4" % os.path.basename(path))


def migrate_main(path):
    try:
        s = open(path).read()
    except OSError:
        return
    n = s
    if "rice-bar start" not in n:
        n = re.sub(r'hl\.exec_cmd\(\s*"waybar"\s*\)', 'hl.exec_cmd("$HOME/.local/bin/rice-bar start")', n)
    # V3.24: swaync starts through rice-notifyd, which leaves it off when the shell shows notifications itself
    if "rice-notifyd" not in n:
        n = re.sub(r'hl\.exec_cmd\(\s*"swaync"\s*\)', 'hl.exec_cmd("$HOME/.local/bin/rice-notifyd")', n)
    if "rice-launch" not in n:
        n = re.sub(r'(hl\.bind\(\s*"ALT \+ Space"\s*,\s*hl\.dsp\.exec_cmd\()\s*"[^"]*rofi[^"]*"(\s*\))',
                   r'\1"$HOME/.local/bin/rice-launch"\2', n)
    # V3.19: the volume keys go through rice-volume, so the shell can show how loud it is
    for old, new in (("pamixer -i 5", "up"), ("pamixer -d 5", "down"), ("swayosd-client --output-volume raise", "up"),
                     ("swayosd-client --output-volume lower", "down"), ("swayosd-client --output-volume mute-toggle", "mute")):
        n = n.replace('hl.dsp.exec_cmd("%s")' % old, 'hl.dsp.exec_cmd("$HOME/.local/bin/rice-volume %s")' % new)
    if "XF86AudioRaiseVolume" not in n:
        n = n.rstrip("\n") + """

-- volume keys of laptops, keyboards and headphones (added by DarkShadow's Shell V3.19)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("$HOME/.local/bin/rice-volume up"),   { locked = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("$HOME/.local/bin/rice-volume down"), { locked = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("$HOME/.local/bin/rice-volume mute"), { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("$HOME/.local/bin/rice-volume mic"),  { locked = true })
"""
    # V3.45: SUPER + L and friends lock with the shell's lock screen (rice-lock now; hyprlock is its fallback)
    n = n.replace('hl.dsp.exec_cmd("hyprlock")', 'hl.dsp.exec_cmd("$HOME/.local/bin/rice-lock now")')
    # V3.43: settings this Hyprland does not know are skipped instead of stopping the whole config (rice-guard.lua)
    if "rice-guard" not in n and os.path.exists(os.path.join(hypr, "rice-guard.lua")):
        n = '-- DarkShadow\'s Shell: settings this Hyprland does not know are skipped instead of stopping the config\npcall(require, "rice-guard")\n\n' + n
    # V3.22: outer gaps 5 by default (only when it still has the old default 12; Settings > Hyprland changes it)
    n = re.sub(r'^(\s*gaps_out\s*=\s*)12(\s*,)', r'\g<1>5\2', n, count=1, flags=re.M)
    if n != s:
        bak = path + ".bak-bar"
        if not os.path.exists(bak):
            open(bak, "w").write(s)
        open(path, "w").write(n)
        changes.append("hyprland.lua: bar, launcher and volume keys of DarkShadow's Shell (copy: hyprland.lua.bak-bar)")


if os.path.isdir(hypr):
    for f in sorted(os.listdir(hypr)):
        if f.endswith(".lua"):
            clamp_lua(os.path.join(hypr, f))
    fix_requires(os.path.join(hypr, "hyprland.lua"))
    migrate_main(os.path.join(hypr, "hyprland.lua"))
    for extra in ("hyprland-gui.lua",):
        pth = os.path.join(hypr, extra)
        try:
            t = open(pth).read()
            t2 = t.replace('hl.dsp.exec_cmd("hyprlock")', 'hl.dsp.exec_cmd("$HOME/.local/bin/rice-lock now")')
            if t2 != t:
                open(pth, "w").write(t2)
                changes.append(extra + ": SUPER + L uses the new lock screen")
        except OSError:
            pass
clamp_json(home + "/.config/rice/hypr.json")

for c in changes:
    print(c)
if not changes:
    print("nothing to fix")
sys.exit(0)
