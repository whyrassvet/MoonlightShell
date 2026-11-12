"""Teach hyprquickpaper/commands.sh about named color schemes and refresh hooks. Safe to run many times."""
import sys

p = sys.argv[1]
s = open(p).read()
changed = False
old = '''case "$(cat "$HOME/.config/rice/color-mode" 2>/dev/null)" in
  grey) sat=0; lum=50 ;;
  navy) sat=0; lum=0 ;;
esac

if awk "BEGIN{exit !($sat < 12)}"; then
'''
new = '''mode="$(cat "$HOME/.config/rice/color-mode" 2>/dev/null)"
scheme=""
case "$mode" in
  grey) sat=0; lum=50 ;;
  navy) sat=0; lum=0 ;;
  ""|auto) ;;
  *) scheme="$("$HOME/.local/bin/rice-colors" scheme "$mode" 2>/dev/null)" ;;
esac

if [ -n "$scheme" ]; then
  # named color scheme from Settings > Theme: "<matugen type> <seed> <workspace marker>"
  read -r stype seed ws <<<"$scheme"
  cmd=(matugen color hex "$seed" --type "$stype" -q)
elif awk "BEGIN{exit !($sat < 12)}"; then
'''
if "rice-colors\" scheme" not in s:
    if s.count(old) != 1:
        print("commands.sh differs from the expected text, schemes not added")
    else:
        s = s.replace(old, new)
        changed = True
hook = '"$HOME/.local/bin/rice-colors" refresh >/dev/null 2>&1 &'
if hook not in s:
    s = s.rstrip("\n") + "\n\n# recolor notifications and the lock screen (DarkShadow's Shell)\n" + hook + "\n"
    changed = True
if changed:
    open(p, "w").write(s)
    print("commands.sh updated")
else:
    print("commands.sh already up to date")
