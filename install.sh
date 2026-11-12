#!/usr/bin/env bash
# DarkShadow's Shell installer.
# Works for any user (everything uses $HOME / $USER). Arch-based distros get their packages
# installed; NixOS gets the module to add; everything else gets a list of what to install.
set -Euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RICE_VERSION="$(tr -d ' \r\n' <"$ROOT/VERSION" 2>/dev/null || true)"; RICE_VERSION="${RICE_VERSION#[vV]}"; RICE_VERSION="${RICE_VERSION:-2.02}"
HAVE_VERSION="$(tr -d ' \r\n' 2>/dev/null <"$HOME/.config/rice/version" || true)"; HAVE_VERSION="${HAVE_VERSION#[vV]}"
# shellcheck source=install/lib/ui.sh
. "$ROOT/install/lib/ui.sh"
# shellcheck source=install/lib/distro.sh
. "$ROOT/install/lib/distro.sh"

ASSUME_YES=0; DRY_RUN=0; MODE=install; SKIP_PKGS=0; PULLED=0; TAKE_SETTINGS_ARG=0; WM_ARG=""; AUR_ARG=""; HELPER_ARG=""; DOCTOR=0
usage() {
  cat <<U
DarkShadow's Shell installer V$RICE_VERSION

Usage: ./install.sh [options]
  -y, --yes          install everything, no questions
  -n, --dry-run      show what would happen, change nothing
      --no-packages  skip the package step
      --update       get the newest version and update apps, scripts and packages (keeps your configs)
      --use-saved-settings  take the settings saved in this copy (settings/) even where you changed yours
      --wm=hyprland|niri|both   the window manager to set up (default: Hyprland; both: pick one at login)
      --helper=yay|paru   Arch: the AUR helper to use (or build yay); default: the one you have, paru first
      --doctor       check cursor theme, AUR helper and session, print a report to paste and repair the cursor
      --aur          Arch: get yay and every AUR package (without it: only when the shell needs one)
      --no-aur       Arch: never build yay; AUR packages are skipped (the cursor and fonts come from GitHub)
      --no-input-group  do not join the input group (Infinite Desktop: SUPER + ALT + mouse then stays off)
      --restore      put back the files from the newest backup
  -h, --help         this help
U
}
for a in "$@"; do
  case "$a" in
    -y|--yes) ASSUME_YES=1 ;;
    -n|--dry-run) DRY_RUN=1 ;;
    --no-packages) SKIP_PKGS=1 ;;
    --restore) MODE=restore ;;
    --update) MODE=update ;;
    --pulled) MODE=update; PULLED=1 ;;
    --use-saved-settings) TAKE_SETTINGS_ARG=1 ;;
    --wm=hyprland|--wm=niri|--wm=both) WM_ARG="${a#--wm=}" ;;
    --aur) AUR_ARG=yes ;;
    --no-aur) AUR_ARG=no ;;
    --helper=yay|--helper=paru) HELPER_ARG="${a#--helper=}" ;;
    --doctor) DOCTOR=1 ;;
    --no-input-group) NO_INPUT=1 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown option: $a"; usage; exit 2 ;;
  esac
done

if [ "$(id -u)" = 0 ] && [ -z "${SHADOWS_ALLOW_ROOT:-}" ]; then
  fail "Run this as your normal user, not root. It installs into your home folder and asks for sudo when needed."
  exit 1
fi

# running as root on purpose (SHADOWS_ALLOW_ROOT: a container, a VM): there is nothing to ask sudo for
if [ "$(id -u)" = 0 ]; then
  sudo() { while [ "${1:-}" = -n ] || [ "${1:-}" = -v ] || [ "${1:-}" = -E ]; do [ "$1" = -v ] && return 0; shift; done; "$@"; }
fi
# find, sort and friends: a minimal system image can lack them
for c in find sort tar; do
  command -v "$c" >/dev/null 2>&1 && continue
  command -v "$c" >/dev/null 2>&1 || [ "$DRY_RUN" = 1 ] || { fail "$c is missing. Install findutils, coreutils and tar, then run ./install.sh again."; exit 1; }
  break
done

STAMP="$(date +%Y%m%d-%H%M%S)"
BK="$HOME/.config/darkshadows-shell-backup-$STAMP"
LOG="${TMPDIR:-/tmp}/darkshadows-shell-install-$STAMP.log"
: >"$LOG"
IN_HYPR=0; [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v hyprctl >/dev/null 2>&1 && IN_HYPR=1
IN_NIRI=0; [ -n "${NIRI_SOCKET:-}" ] && command -v niri >/dev/null 2>&1 && IN_NIRI=1
BIN="$HOME/.local/bin"
SUDO_PID=""
cleanup() { [ -n "$SUDO_PID" ] && kill "$SUDO_PID" 2>/dev/null; rm -f "${PKG_SPLIT:-}"; show_cursor; }
trap cleanup EXIT

# ------------------------------------------------------------------ helpers
# ver_newer A B: true when version A is newer than B ("2.1" == "2.10" > "2.02")
ver_newer() {
  python3 - "$1" "$2" <<'PY' 2>/dev/null
import sys
def k(v):
    a, _, b = v.strip().lstrip("vV").partition(".")
    try:
        return (int(a or 0), float("0." + (b or "0")))
    except ValueError:
        return (0, 0.0)
sys.exit(0 if k(sys.argv[1]) > k(sys.argv[2]) else 1)
PY
}
# ---- your own edits survive updates (V4.32) ----
# The installer remembers what it wrote (~/.config/rice/installed.sums). A Quickshell file (.qml, .js) you changed
# since then is kept as it is on an update: the new version lands next to it as FILE.rice-update and the summary
# lists it. Before there was a list, the version the repo had before this update (git) tells if it was changed.
SUMS="$HOME/.config/rice/installed.sums"
KEPTF="$HOME/.cache/rice/kept-edits"
PREV_REV=""
sum_of() { sha256sum 2>/dev/null | cut -c1-64; }
rec_sum() { # rec_sum DST: what is in DST now is ours
  [ "$DRY_RUN" = 1 ] && return 0
  case "$1" in "$HOME"/.config/quickshell/*.qml|"$HOME"/.config/quickshell/*.js) ;; *) return 0 ;; esac
  mkdir -p "$(dirname "$SUMS")"
  printf '%s  %s\n' "$(sum_of <"$1")" "${1#"$HOME"/}" >>"$SUMS"
}
user_edited() { # user_edited SRC DST: true when you changed DST after the installer wrote it
  local src="$1" dst="$2" rel cur rec old
  [ "${RICE_OVERWRITE:-0}" = 1 ] && return 1
  case "$dst" in "$HOME"/.config/quickshell/*.qml|"$HOME"/.config/quickshell/*.js) ;; *) return 1 ;; esac
  rel="${dst#"$HOME"/}"
  cur="$(sum_of <"$dst")"
  rec="$(grep -F "  $rel" "$SUMS" 2>/dev/null | awk -v r="$rel" '$2 == r { s = $1 } END { print s }')"
  if [ -n "$rec" ]; then [ "$cur" != "$rec" ]; return; fi
  [ -n "$PREV_REV" ] || return 1
  git -C "$ROOT" cat-file -e "$PREV_REV:${src#"$ROOT"/}" 2>/dev/null || return 1      # not in that version
  old="$(git -C "$ROOT" show "$PREV_REV:${src#"$ROOT"/}" 2>/dev/null | sed -e "s|@HOME@|$HOME|g" -e "s|@USER@|$USER|g" | sum_of)"
  [ -n "$old" ] && [ "$cur" != "$old" ]
}
keep_edit() { # keep_edit SRC DST: your file stays, the new one goes next to it
  put "$1" "$2.rice-update"
  mkdir -p "$(dirname "$KEPTF")"; printf '%s\n' "${2#"$HOME"/}" >>"$KEPTF"
}

# put SRC DST: copy one file, fill in @HOME@/@USER@, back up what it replaces
put() {
  local src="$1" dst="$2" rel
  [ "$DRY_RUN" = 1 ] && return 0
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    rel="${dst#"$HOME"/}"
    mkdir -p "$BK/$(dirname "$rel")"
    cp -aL "$dst" "$BK/$rel" 2>/dev/null || true
    [ -L "$dst" ] && rm -f "$dst"
  fi
  mkdir -p "$(dirname "$dst")"
  if grep -qI . "$src" 2>/dev/null; then
    sed -e "s|@HOME@|$HOME|g" -e "s|@USER@|$USER|g" "$src" >"$dst"
  else
    cp -f "$src" "$dst"
  fi
  [ -x "$src" ] && chmod +x "$dst"
  return 0
}
copy_tree() { # copy_tree SRC_DIR DST_DIR
  local src="$1" dst="$2" f rel
  local -a new_files=() kept_files=()
  [ -d "$src" ] || return 0
  # files that are new on this computer go first (a changed file may need them, and Quickshell reloads as soon as
  # something changes), then the changed ones, and shell.qml goes last
  while IFS= read -r -d '' f; do
    rel="${f#"$src"/}"
    if [ -e "$dst/$rel" ] || [ -L "$dst/$rel" ]; then kept_files+=("$f"); else new_files+=("$f"); fi
  done < <(find -L "$src" -type f ! -name '*.bak*' ! -name '.gitkeep' ! -name shell.qml -print0)
  for f in "${new_files[@]}"; do put "$f" "$dst/${f#"$src"/}"; rec_sum "$dst/${f#"$src"/}"; done
  # the changed ones are written next to their old selves first and then swapped in all at once, so a running
  # Quickshell never reloads with half of the new files (a new Bar.qml with an old DynIsland.qml); files that
  # did not change are not touched at all
  local d rel2
  local -a staged=()
  for f in "${kept_files[@]}"; do
    d="$dst/${f#"$src"/}"
    if [ "$DRY_RUN" = 1 ]; then continue; fi
    put "$f" "$d.rice-new"
    if cmp -s "$d.rice-new" "$d"; then rm -f "$d.rice-new" "$d.rice-update"; rec_sum "$d"; continue; fi
    if user_edited "$f" "$d"; then rm -f "$d.rice-new"; keep_edit "$f" "$d"; continue; fi
    rel2="${d#"$HOME"/}"
    mkdir -p "$BK/$(dirname "$rel2")"
    cp -aL "$d" "$BK/$rel2" 2>/dev/null || true
    [ -L "$d" ] && rm -f "$d"
    staged+=("$d")
  done
  for d in "${staged[@]}"; do mv -f "$d.rice-new" "$d"; rm -f "$d.rice-update"; rec_sum "$d"; done
  # shell.qml last, swapped in whole as well (Quickshell must never read it half written)
  if [ -f "$src/shell.qml" ] && [ "$DRY_RUN" != 1 ]; then
    d="$dst/shell.qml"
    if [ -e "$d" ]; then
      put "$src/shell.qml" "$d.rice-new"
      if cmp -s "$d.rice-new" "$d"; then rm -f "$d.rice-new"; rec_sum "$d"
      elif user_edited "$src/shell.qml" "$d"; then rm -f "$d.rice-new"; keep_edit "$src/shell.qml" "$d"
      else
        rel2="${d#"$HOME"/}"; mkdir -p "$BK/$(dirname "$rel2")"; cp -aL "$d" "$BK/$rel2" 2>/dev/null || true
        [ -L "$d" ] && rm -f "$d"
        mv -f "$d.rice-new" "$d"; rec_sum "$d"
      fi
    else
      put "$src/shell.qml" "$d"; rec_sum "$d"
    fi
  fi
  return 0
}
missing_cmds() {
  local c out=()
  for c in "${NEED_CMDS[@]}"; do command -v "$c" >/dev/null 2>&1 || out+=("$c"); done
  echo "${out[*]:-}"
}
# run a tool with a time limit so one stuck program can never freeze the installer
t() { timeout "${T:-25}" "$@"; }
# start something in the background, detached from the installer
detach() { setsid -f "$@" >/dev/null 2>&1 </dev/null || true; }
config_dirs() { local d; for d in "$ROOT"/config/*/; do [ -d "$d" ] && basename "$d"; done; }
pretty_dir() {
  case "$1" in
    hypr) echo "Hyprland" ;; waybar) echo "Waybar" ;; swaync) echo "Notifications (swaync)" ;;
    rofi) echo "Rofi" ;; matugen) echo "Matugen colors" ;; kitty) echo "Kitty terminal" ;;
    fastfetch) echo "Fastfetch" ;; btop) echo "btop theme (transparent)" ;; fish) echo "Fish shell" ;; waybar-presets) echo "Waybar presets" ;; *) echo "$1" ;;
  esac
}

# ------------------------------------------------------------------ window manager: Hyprland, niri or both
# what runs now, or what is installed, or what was set up before
wm_guess() {
  if [ "$IN_NIRI" = 1 ]; then echo niri; return; fi
  if [ "$IN_HYPR" = 1 ]; then
    if command -v niri >/dev/null 2>&1 && grep -qs "generated by rice-niri" "$HOME/.config/niri/config.kdl"; then echo both; else echo hyprland; fi
    return
  fi
  local saved; saved="$(cat "$HOME/.config/rice/wm" 2>/dev/null)"
  case "$saved" in hyprland|niri|both) echo "$saved"; return ;; esac
  if command -v niri >/dev/null 2>&1 && ! command -v Hyprland >/dev/null 2>&1; then echo niri; return; fi
  echo hyprland
}
has_hypr() { [ "$WM" = hyprland ] || [ "$WM" = both ]; }
has_niri() { [ "$WM" = niri ] || [ "$WM" = both ]; }
wm_name() { case "$WM" in niri) echo "niri" ;; both) echo "Hyprland and niri" ;; *) echo "Hyprland" ;; esac; }
# the packages for that choice: niri's are added; niri alone leaves Hyprland itself (and its portal) out
wm_packages() {
  local p keep=()
  if has_niri; then
    ARCH_PKGS+=("${PKG_NIRI[@]}"); FEDORA_PKGS+=("${FPKG_NIRI[@]}"); FEDORA_COPRS+=("$FEDORA_NIRI_COPR")
    NEED_CMDS+=(niri xwayland-satellite)
  fi
  if ! has_hypr; then
    for p in "${ARCH_PKGS[@]}"; do case "$p" in hyprland|xdg-desktop-portal-hyprland) ;; *) keep+=("$p") ;; esac; done
    ARCH_PKGS=("${keep[@]}"); keep=()
    for p in "${FEDORA_PKGS[@]}"; do case "$p" in hyprland|xdg-desktop-portal-hyprland) ;; *) keep+=("$p") ;; esac; done
    FEDORA_PKGS=("${keep[@]}"); keep=()
    for p in "${NEED_CMDS[@]}"; do [ "$p" = Hyprland ] || keep+=("$p"); done
    NEED_CMDS=("${keep[@]}")
  fi
}
remember_wm() { mkdir -p "$HOME/.config/rice"; echo "$WM" >"$HOME/.config/rice/wm"; }

# ------------------------------------------------------------------ steps
sudo_keepalive() {
  [ "$DRY_RUN" = 1 ] && return 0
  info "Some steps need administrator rights (sudo)."
  sudo -v || { fail "sudo failed, skipping packages"; return 1; }
  ( while true; do sudo -n true 2>/dev/null; sleep 50; done ) &
  SUDO_PID=$!
}

PKG_SPLIT="$(mktemp)"
pkg_check() { # writes "repo NAME" / "aur NAME" lines for every package in ARCH_PKGS
  local p
  : >"$PKG_SPLIT"
  for p in "${ARCH_PKGS[@]}"; do
    if pacman -Si "$p" >/dev/null 2>&1; then echo "repo $p"; else echo "aur $p"; fi >>"$PKG_SPLIT"
  done
}
pkg_load() {
  REPO_PKGS=(); AUR_PKGS=()
  local kind p
  while read -r kind p; do
    if [ "$kind" = repo ]; then REPO_PKGS+=("$p"); else AUR_PKGS+=("$p"); fi
  done <"$PKG_SPLIT"
}

# fedora_check: writes the names of the FEDORA_PKGS your repositories have (one per line)
fedora_check() {
  local names=() p
  for p in "${FEDORA_PKGS[@]}"; do IFS='|' read -r -a alts <<<"$p"; names+=("${alts[@]}"); done
  dnf repoquery -q --qf '%{name}\n' "${names[@]}" 2>/dev/null | sort -u >"$PKG_SPLIT"
  return 0
}
# fedora_pick "a|b": the first name your repositories have (nothing when none)
fedora_pick() {
  local a
  IFS='|' read -r -a alts <<<"$1"
  for a in "${alts[@]}"; do grep -qx "$a" "$PKG_SPLIT" 2>/dev/null && { echo "$a"; return 0; }; done
  return 0
}

# matugen from its GitHub releases (Fedora 43 and older have no package): ~/.local/bin/matugen
matugen_download() {
  local arch url d
  arch="$(uname -m)"
  url="$(curl -fsSL --max-time 20 https://api.github.com/repos/InioX/matugen/releases/latest 2>/dev/null |
         grep -oE '"browser_download_url": *"[^"]+"' | grep -oE 'https://[^"]+' |
         grep -iE "${arch}.*\.tar\.gz$" | head -1)"
  [ -n "$url" ] || return 1
  d="$(mktemp -d)"
  if curl -fsSL --max-time 120 -o "$d/m.tar.gz" "$url" && tar -xzf "$d/m.tar.gz" -C "$d" 2>/dev/null; then
    local bin; bin="$(find "$d" -type f -name matugen | head -1)"
    if [ -n "$bin" ]; then mkdir -p "$HOME/.local/bin"; install -m 755 "$bin" "$HOME/.local/bin/matugen"; rm -rf "$d"; return 0; fi
  fi
  rm -rf "$d"
  return 1
}

# the installed Hyprland is older than the Lua config needs: prints its version, nothing when it is fine or missing
hypr_too_old() {
  command -v Hyprland >/dev/null 2>&1 || return 0
  local v maj min
  v="$(timeout 10 Hyprland --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)"
  [ -n "$v" ] || return 0
  maj="${v%%.*}"; min="${v#*.}"
  if [ "$maj" -lt "$HYPR_MIN_MAJOR" ] || { [ "$maj" -eq "$HYPR_MIN_MAJOR" ] && [ "$min" -lt "$HYPR_MIN_MINOR" ]; }; then echo "$v"; fi
  return 0
}

# what is special about this flavour of the family (shown once at the start)
flavor_notes() {
  case "$DISTRO_FLAVOR" in
    cachyos)     note "CachyOS: its own repositories are used, and paru (which CachyOS ships) installs the AUR packages." ;;
    endeavouros) note "EndeavourOS: plain Arch with yay or paru, everything is installed from the Arch repositories and the AUR." ;;
    garuda)      note "Garuda: Arch based, paru is used for the AUR packages." ;;
    manjaro)     warn "Manjaro holds packages back for weeks. Hyprland may be older than 0.55 (the Lua config needs 0.55): CachyOS or EndeavourOS work better." ;;
    nobara)      note "Nobara: Fedora based, the Fedora steps below are used." ;;
  esac
}

aur_helper() {
  if [ -n "$HELPER_ARG" ]; then command -v "$HELPER_ARG" >/dev/null 2>&1 && echo "$HELPER_ARG"; return 0; fi
  command -v paru >/dev/null 2>&1 && { echo paru; return; }; command -v yay >/dev/null 2>&1 && echo yay; return 0
}
# paru from the AUR the same way yay is built
install_paru() {
  local d rc
  d="$(mktemp -d)"
  sudo pacman -S --needed --noconfirm git base-devel rust &&
  timeout 120 git clone --depth 1 https://aur.archlinux.org/paru-bin.git "$d/paru-bin" &&
  (cd "$d/paru-bin" && makepkg -si --noconfirm --needed)
  rc=$?
  rm -rf "$d"
  return $rc
}

install_yay() {
  local d
  d="$(mktemp -d)"
  sudo pacman -S --needed --noconfirm git base-devel &&
  timeout 120 git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$d/yay-bin" &&
  (cd "$d/yay-bin" && makepkg -si --noconfirm --needed)
  local rc=$?
  rm -rf "$d"
  return $rc
}

step_packages() {
  case "$FAMILY" in
    arch)
      sudo_keepalive || return 0
      if [ "$DRY_RUN" = 1 ]; then
        info "would install ${#ARCH_PKGS[@]} packages: ${ARCH_PKGS[*]}"; return 0
      fi
      task "Updating your system first (Arch needs this before new packages)" sudo pacman -Syu --noconfirm
      task "Checking where each package comes from" pkg_check
      pkg_load
      note "${#REPO_PKGS[@]} from the official repositories, ${#AUR_PKGS[@]} from the AUR"
      if ! task "Installing ${#REPO_PKGS[@]} packages: desktop, shell, tools and fonts" \
           sudo pacman -S --needed --noconfirm "${REPO_PKGS[@]}"; then
        # one package (a conflict, a typo upstream) must not stop all the others
        warn "Installing them together failed, trying one by one"
        local p failed=()
        for p in "${REPO_PKGS[@]}"; do
          pacman -Qi "$p" >/dev/null 2>&1 && continue
          task "  $p" sudo pacman -S --needed --noconfirm "$p" || failed+=("$p")
        done
        [ "${#failed[@]}" -gt 0 ] && warn "Could not install: ${failed[*]} (see $LOG)"
      fi
      if [ "${#AUR_PKGS[@]}" -gt 0 ]; then
        local helper; helper="$(aur_helper)"
        # yay is optional and nothing asks about it: paru or yay are used when you have one; otherwise yay is
        # built only when the shell itself needs an AUR package (the cursor and the fonts have other ways in),
        # or when you ask for it (--aur). --no-aur: never.
        if [ -z "$helper" ]; then
          local p need=()
          for p in "${AUR_PKGS[@]}"; do
            case " ${AUR_NEEDED[*]} " in *" $p "*) need+=("$p") ;; esac
          done
          if [ "$AUR_ARG" = yes ] || [ -n "$HELPER_ARG" ] || { [ "$AUR_ARG" != no ] && [ "${#need[@]}" -gt 0 ]; }; then
            local want="${HELPER_ARG:-yay}"
            [ "${#need[@]}" -gt 0 ] && note "The shell needs these from the AUR: ${need[*]}, so $want is set up for them"
            info "Building $want (AUR helper). Its output is shown below."
            if "install_$want"; then ok "$want is installed"; helper=$want; else fail "$want could not be built"; fi
          else
            note "No AUR helper: skipping ${AUR_PKGS[*]} (not needed; ./install.sh --aur gets them)"
            AUR_PKGS=()
          fi
        fi
        if [ -n "$helper" ]; then
          local extra=(--needed --noconfirm --sudoloop)
          [ "$helper" = paru ] && extra+=(--skipreview)
          info "Installing ${#AUR_PKGS[@]} AUR packages with $helper: ${AUR_PKGS[*]}"
          note "AUR packages are built on your computer; their output is shown so nothing waits invisibly."
          if "$helper" -S "${extra[@]}" "${AUR_PKGS[@]}"; then ok "AUR packages installed"
          else warn "Some AUR packages failed. Try later: $helper -S ${AUR_PKGS[*]}"; fi
        elif [ "${#AUR_PKGS[@]}" -gt 0 ]; then
          warn "Skipped AUR packages. Install them later: ${AUR_PKGS[*]}"
        fi
      fi
      # power modes in the notification center (not when TLP or auto-cpufreq already manage power)
      if pacman -Qi power-profiles-daemon >/dev/null 2>&1 && ! pacman -Qi tlp >/dev/null 2>&1 && ! pacman -Qi auto-cpufreq >/dev/null 2>&1; then
        task "Turning on power modes (power-profiles-daemon)" sudo systemctl enable --now power-profiles-daemon.service
      fi
      if pacman -Qi bluez >/dev/null 2>&1; then
        task "Turning on the Bluetooth service" sudo systemctl enable --now bluetooth.service
      fi
      ;;
    fedora)
      if [ "$FEDORA_ATOMIC" = 1 ]; then
        warn "$DISTRO_NAME is an atomic (image based) Fedora: packages are layered with rpm-ostree."
        note "Run these, reboot, then ./install.sh again:"
        local c; for c in "${FEDORA_COPRS[@]}"; do note "  sudo wget -P /etc/yum.repos.d/ https://copr.fedorainfracloud.org/coprs/$c/repo/fedora-\$(rpm -E %fedora)/${c%%/*}-${c##*/}-fedora-\$(rpm -E %fedora).repo"; done
        local first=() p; for p in "${FEDORA_PKGS[@]}"; do first+=("${p%%|*}"); done
        note "  rpm-ostree install ${first[*]}"
        return 0
      fi
      sudo_keepalive || return 0
      if [ "$DRY_RUN" = 1 ]; then
        info "would enable COPR ${FEDORA_COPRS[*]} and install ${#FEDORA_PKGS[@]} packages: ${FEDORA_PKGS[*]//|/ or }"; return 0
      fi
      task "COPR support for dnf" sudo dnf install -y 'dnf-command(copr)'
      local c
      for c in "${FEDORA_COPRS[@]}"; do task "Enabling COPR $c" sudo dnf copr enable -y "$c"; done
      task "Checking which packages your Fedora has" fedora_check
      local have=() absent=() p n
      for p in "${FEDORA_PKGS[@]}"; do
        n="$(fedora_pick "$p")"
        if [ -n "$n" ]; then have+=("$n"); else absent+=("${p//|/ or }"); fi
      done
      # repoquery did not work at all: just try everything (first names)
      if [ "${#have[@]}" = 0 ]; then have=(); for p in "${FEDORA_PKGS[@]}"; do have+=("${p%%|*}"); done; absent=(); fi
      note "${#have[@]} packages to install${absent[0]:+, not in your repositories: ${absent[*]}}"
      if ! task "Installing ${#have[@]} packages: desktop, shell, tools and fonts" sudo dnf install -y --skip-unavailable "${have[@]}"; then
        warn "Installing them together failed, trying one by one"
        local failed=()
        for p in "${have[@]}"; do
          rpm -q "$p" >/dev/null 2>&1 && continue
          task "  $p" sudo dnf install -y "$p" || failed+=("$p")
        done
        [ "${#failed[@]}" -gt 0 ] && warn "Could not install: ${failed[*]} (see $LOG)"
      fi
      if ! command -v matugen >/dev/null 2>&1; then
        if task "matugen (theme colors) from its GitHub releases" matugen_download; then ok "matugen is in ~/.local/bin"
        else warn "matugen could not be installed: colors from the wallpaper will not change (cargo install matugen works too)"; fi
      fi
      # power modes, unless TLP or auto-cpufreq already manage power
      if rpm -q power-profiles-daemon >/dev/null 2>&1 && ! rpm -q tlp >/dev/null 2>&1 && ! rpm -q auto-cpufreq >/dev/null 2>&1; then
        task "Turning on power modes (power-profiles-daemon)" sudo systemctl enable --now power-profiles-daemon.service
      fi
      rpm -q bluez >/dev/null 2>&1 && task "Turning on the Bluetooth service" sudo systemctl enable --now bluetooth.service
      ;;
    nixos)
      info "NixOS installs packages from your system configuration, not from this script."
      note "Add this line to /etc/nixos/configuration.nix:"
      printf '\n        %simports = [ %s/nix/module.nix ];%s\n\n' "$CW" "$ROOT" "$C0"
      note "or with flakes:  inputs.darkshadows-shell.url = \"github:shadowww-dev/DarkShadowShell\";"
      note "then run:  sudo nixos-rebuild switch"
      note "Infinite Desktop (SUPER + ALT + mouse) also needs, next to the module import:  programs.shadows-shell.user = \"$USER\";"
      ;;
    *)
      warn "$DISTRO_NAME is not supported for automatic packages."
      note "Install these with your package manager, then run ./install.sh again:"
      note "${NEED_CMDS[*]}"
      ;;
  esac
}

set_look() {
  local theme=Bibata-Modern-Ice icons=Papirus-Dark gtk=adw-gtk3-dark f
  [ -d /usr/share/themes/adw-gtk3-dark ] || gtk=Adwaita-dark
  mkdir -p "$HOME/.icons/default" "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"
  printf '[Icon Theme]\nName=Default\nInherits=%s\n' "$theme" >"$HOME/.icons/default/index.theme"
  for f in "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"; do
    [ -f "$f" ] && cp -n "$f" "$f.bak-darkshadows" 2>/dev/null
    printf '[Settings]\ngtk-application-prefer-dark-theme=1\ngtk-theme-name=%s\ngtk-icon-theme-name=%s\ngtk-cursor-theme-name=%s\ngtk-cursor-theme-size=24\ngtk-font-name=Inter 11\n' \
      "$gtk" "$icons" "$theme" >"$f"
  done
  if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark || true
    gsettings set org.gnome.desktop.interface gtk-theme "$gtk" || true
    gsettings set org.gnome.desktop.interface icon-theme "$icons" || true
    gsettings set org.gnome.desktop.interface cursor-theme "$theme" || true
    gsettings set org.gnome.desktop.interface cursor-size 24 || true
  fi
  # Bibata is not packaged everywhere (Fedora): download it for this user when it is missing
  if [ ! -d "/usr/share/icons/$theme" ] && [ ! -d "$HOME/.local/share/icons/$theme" ] && [ ! -d "$HOME/.icons/$theme" ]; then
    mkdir -p "$HOME/.local/share/icons"
    curl -fsSL -m 120 "https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/$theme.tar.xz" |
      tar -xJ -C "$HOME/.local/share/icons" 2>/dev/null || echo "could not download the $theme cursor"
  fi
  # a theme folder that has no cursors inside (a broken package) is no theme: rice-cursor gets a working one
  [ -f "$HOME/.config/rice/cursor.json" ] || { mkdir -p "$HOME/.config/rice"; echo '{"theme": "Bibata-Modern-Ice", "size": 24}' >"$HOME/.config/rice/cursor.json"; }
  [ -x "$ROOT/bin/rice-cursor" ] && T=120 t "$ROOT/bin/rice-cursor" restore
  # Nautilus opens folders
  command -v xdg-mime >/dev/null 2>&1 && [ -f /usr/share/applications/org.gnome.Nautilus.desktop ] &&
    xdg-mime default org.gnome.Nautilus.desktop inode/directory
  return 0
}
put_wallpapers() {
  local dir f n=0
  dir="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")/Wallpapers"
  [ "$dir" = "/Wallpapers" ] && dir="$HOME/Pictures/Wallpapers"
  mkdir -p "$dir"
  # wallpapers we replaced: remove the old ones (only a file that is exactly the old picture, never yours)
  if [ -f "$ROOT/install/retired-wallpapers.txt" ]; then
    local sum name
    while read -r sum name; do
      case "$sum" in ''|'#'*) continue ;; esac
      [ -f "$dir/$name" ] && [ "$(md5sum "$dir/$name" | cut -d' ' -f1)" = "$sum" ] && rm -f "$dir/$name" && echo "removed the old wallpaper $name"
    done <"$ROOT/install/retired-wallpapers.txt"
  fi
  for f in "$ROOT"/wallpapers/*; do
    [ -f "$f" ] || continue
    [ -e "$dir/$(basename "$f")" ] || { cp "$f" "$dir/"; n=$((n + 1)); }
  done
  # first start (or the wallpaper you had is gone): one of ours, the black hole when it is there
  f="$(cat "$HOME/.cache/hyprquickpaper-current" 2>/dev/null)"
  if [ -z "$f" ] || [ ! -f "$f" ]; then
    mkdir -p "$HOME/.cache"
    f="$dir/space-black-hole.jpg"
    [ -f "$f" ] || f="$(find "$dir" -maxdepth 1 -type f \( -name '*.jpg' -o -name '*.png' \) | sort | head -n1)"
    [ -n "$f" ] && echo "$f" >"$HOME/.cache/hyprquickpaper-current"
  fi
  # in a running desktop with no wallpaper yet: put it on now, with its colors (at the next login rice-walls
  # start does the same)
  if [ -n "${WAYLAND_DISPLAY:-}" ] && [ -x "$HOME/.local/bin/rice-walls" ]; then
    setsid -f "$HOME/.local/bin/rice-walls" start >/dev/null 2>&1 </dev/null
  fi
  echo "$n new wallpapers in $dir"
}
quiet_fish() {
  mkdir -p "$HOME/.config/fish/conf.d"
  printf '# DarkShadow'"'"'s Shell: no "Welcome to fish" message\nset -g fish_greeting\n' >"$HOME/.config/fish/conf.d/darkshadows.fish"
}
step_fonts() {
  task "Fonts: Google Sans Flex & Code, Inter, Rubik, Nerd Font icons, clock fonts" timeout 400 "$ROOT/bin/rice-fonts"
  command -v fc-cache >/dev/null 2>&1 && task "Refreshing the font cache" timeout 120 fc-cache -f
  task "Google Sans Flex as the interface font" t "$ROOT/bin/font-set" migrate
  task "Dark theme for apps, Papirus icons, Bibata cursor" set_look
  if fc-list 2>/dev/null | grep -qi "JetBrainsMono Nerd"; then ok "JetBrains Mono Nerd Font (icons) is installed"
  else warn "JetBrains Mono Nerd Font is missing: icons will show as boxes"; fi
}

# ~/.config/hypr/user.lua: your own Hyprland settings, loaded last; no update ever writes over it
make_user_lua() {
  local f="$HOME/.config/hypr/user.lua"
  [ "$DRY_RUN" = 1 ] || [ -e "$f" ] && return 0
  mkdir -p "$HOME/.config/hypr"
  cat >"$f" <<'LUA'
-- Your own Hyprland settings. DarkShadow's Shell never changes this file (updates leave it alone).
-- It is loaded last, so whatever you set here wins over the shell's config. Put your changes here instead of
-- hyprland.lua (an update brings a new hyprland.lua; your old one is in ~/.config/darkshadows-shell-backup-*).
-- Docs: https://wiki.hypr.land
--
-- Examples:
-- hl.bind("SUPER + B", hl.dsp.exec_cmd("firefox"))
-- hl.config({ input = { repeat_delay = 300, repeat_rate = 40 } })
-- hl.config({ general = { gaps_in = 4, gaps_out = 8 } })
-- hl.on("hyprland.start", function() hl.exec_cmd("discord") end)
LUA
}

# btop: the transparent theme is used unless you picked a theme of your own
set_btop() {
  [ "$DRY_RUN" = 1 ] && return 0
  command -v btop >/dev/null 2>&1 || return 0
  local f="$HOME/.config/btop/btop.conf" th cur
  th=darkshadow; [ -f "$HOME/.config/btop/themes/matugen.theme" ] && th=matugen
  mkdir -p "$HOME/.config/btop"
  [ -f "$f" ] || printf 'color_theme = "Default"\ntheme_background = True\n' >"$f"
  cur="$(sed -n 's/^color_theme *= *"\(.*\)".*/\1/p' "$f" | head -1)"
  case "$cur" in
    ""|Default|TTY|darkshadow|matugen)
      grep -q '^color_theme' "$f" && sed -i "s|^color_theme *=.*|color_theme = \"$th\"|" "$f" || echo "color_theme = \"$th\"" >>"$f"
      grep -q '^theme_background' "$f" && sed -i 's|^theme_background *=.*|theme_background = False|' "$f" || echo "theme_background = False" >>"$f" ;;
  esac
}

step_configs() {
  local d n
  n="$(config_dirs | wc -l)"
  if [ "$n" = 0 ]; then warn "This copy has no config files (config/ is empty)"; return 0; fi
  # the keyboard layout you use now is kept (an update used to put it back to US)
  has_hypr && task "Keeping your keyboard layout" python3 "$ROOT/bin/hypr-set" kbd-remember
  for d in $(config_dirs); do
    task "$(pretty_dir "$d")  ->  ~/.config/$d" copy_tree "$ROOT/config/$d" "$HOME/.config/$d"
  done
  # your Settings for Hyprland (layout, gaps, keys ...) are written again over the file the update brought
  has_hypr && task "Your Hyprland settings" python3 "$ROOT/bin/hypr-set" regen
  has_hypr && make_user_lua
  task "btop: transparent theme" set_btop
  task "Hyprland add-ons (keybinds, gaming mode)" copy_lua
  [ -d "$ROOT/wallpapers" ] && task "Wallpapers  ->  ~/Pictures/Wallpapers" put_wallpapers
  task "Fish: no welcome message" quiet_fish
  if [ -d "$ROOT/config/fish" ] && command -v fish >/dev/null 2>&1 && [ "$(basename "${SHELL:-}")" != fish ]; then
    if [ "$ASSUME_YES" != 1 ] && confirm "Make fish your default shell? (the configs are made for it)"; then
      # chsh asks for your password, so it runs in the open (not behind a spinner)
      if [ "$DRY_RUN" = 1 ] || chsh -s "$(command -v fish)"; then ok "Default shell is now fish (from your next login)"
      else warn "Could not change the shell. Run later: chsh -s $(command -v fish)"; fi
    fi
  fi
}
copy_lua() { local f; for f in "$ROOT"/lua/*.lua; do [ -f "$f" ] && put "$f" "$HOME/.config/hypr/$(basename "$f")"; done; return 0; }

# ------------------------------------------------------------------ your saved settings
# settings/ holds what you chose in Settings on the computer that ran ./sync.sh: the Waybar look
# (ui.json), dashboard, widgets, hot corner, notifications, lock screen, rofi, fonts, cursor, effects.
# A file is put in place when you do not have it yet, or when you did not change it since the
# installer put it there last time. Files you changed on this computer are kept, unless you said
# "use the saved settings" (then yours are backed up first, like every other file).
SET_STATE="$HOME/.config/rice/.settings-applied"
TAKE_SETTINGS=0
settings_dst() {
  local rel="${1#"$ROOT/settings/"}"
  case "$rel" in
    rice/*) echo "$HOME/.config/rice/${rel#rice/}" ;;
    waybar/*) echo "$HOME/.config/waybar/${rel#waybar/}" ;;
  esac
}
settings_sum() { sed -e "s|@HOME@|$HOME|g" -e "s|@USER@|$USER|g" "$1" | sha256sum | cut -c1-16; }
have_settings() { [ -n "$(find "$ROOT/settings" -type f ! -name '.gitkeep' 2>/dev/null | head -n1)" ]; }
apply_settings() { # apply_settings RES: puts the saved settings in place, writes what it did to RES
  local res="$1" f rel dst new have last key
  : >"$res"
  mkdir -p "$SET_STATE"
  while IFS= read -r -d '' f; do
    rel="${f#"$ROOT/settings/"}"; dst="$(settings_dst "$f")"
    [ -n "$dst" ] || continue
    key="$SET_STATE/${rel//\//_}"
    new="$(settings_sum "$f")"
    last="$(cat "$key" 2>/dev/null || true)"
    if [ -f "$dst" ]; then
      have="$(sha256sum <"$dst" | cut -c1-16)"
      if [ "$have" = "$new" ]; then echo "$new" >"$key"; continue; fi
      if [ "$have" != "$last" ] && [ "$TAKE_SETTINGS" != 1 ]; then echo "kept $rel" >>"$res"; continue; fi
    fi
    put "$f" "$dst"
    echo "$new" >"$key"
    echo "set $rel" >>"$res"
  done < <(find "$ROOT/settings" -type f ! -name '.gitkeep' -print0 2>/dev/null)
  # the widget editor never comes back open
  [ -f "$HOME/.config/rice/desktop.json" ] && python3 - "$HOME/.config/rice/desktop.json" <<'PY' 2>/dev/null
import json, sys
p = sys.argv[1]
c = json.load(open(p))
if c.get("editing"):
    c["editing"] = False
    json.dump(c, open(p, "w"))
PY
  return 0
}
step_settings() {
  local sf; sf="$(mktemp)"
  task "Your saved settings: bar, widgets, lock screen..." apply_settings "$sf"
  local n_set n_kept
  n_set="$(grep -c '^set ' "$sf" 2>/dev/null || true)"; n_kept="$(grep -c '^kept ' "$sf" 2>/dev/null || true)"
  [ "${n_set:-0}" -gt 0 ] && note "$n_set settings files updated"
  if [ "${n_kept:-0}" -gt 0 ]; then
    note "Kept your own (changed on this computer): $(sed -n 's/^kept //p' "$sf" | xargs -n1 basename | tr '\n' ' ')"
    note "To take the saved ones too:  ./install.sh --update --use-saved-settings"
  fi
  if [ "${n_set:-0}" -gt 0 ] && [ "$DRY_RUN" != 1 ]; then
    [ -f "$HOME/.config/waybar/config.jsonc" ] && task "Waybar: your look" t "$BIN/waybar-set" reapply
    [ -x "$BIN/rice-cursor" ] && task "Cursor" t "$BIN/rice-cursor" restore
  fi
  rm -f "$sf"
}

step_apps() {
  local d n
  n="$(find "$ROOT/bin" -maxdepth 1 -type f | wc -l)"
  task "Helper scripts ($n)  ->  ~/.local/bin" copy_bins
  [ -d "$ROOT/sounds" ] && task "Notification sounds  ->  ~/.local/share/rice/sounds" copy_tree "$ROOT/sounds" "$HOME/.local/share/rice/sounds"
  [ -f "$ROOT/assets/icon.png" ] && task "App icon  ->  ~/.local/share/rice/icon.png" put "$ROOT/assets/icon.png" "$HOME/.local/share/rice/icon.png"
  for d in "$ROOT"/quickshell/*/; do
    [ -d "$d" ] || continue
    d="$(basename "$d")"
    case "$d" in
      rice-settings) n="Settings app" ;; rice-desktop) n="Desktop widgets and dock" ;;
      rice-welcome) n="Welcome screen" ;; hyprquickpaper) n="Wallpaper picker" ;; *) n="$d" ;;
    esac
    task "$n  ->  ~/.config/quickshell/$d" copy_tree "$ROOT/quickshell/$d" "$HOME/.config/quickshell/$d"
  done
  # V3.38: the dashboard is gone (the bar's island took its place); its old files leave the config too
  local old
  for old in Dashboard DashAbout DashControl DashGrid DashHome DashPerf DashTasks DashWalls DCard DRing DSlide WallPreview; do
    rm -f "$HOME/.config/quickshell/rice-desktop/$old.qml"
  done
  rm -f "$HOME/.config/quickshell/rice-settings/DashboardPage.qml" "$HOME/.config/quickshell/rice-settings/DashMini.qml"
  if ! printf '%s' ":$PATH:" | grep -q ":$HOME/.local/bin:"; then
    warn "\$HOME/.local/bin is not in your PATH. Add it in your shell config (fish: fish_add_path \$HOME/.local/bin)"
  fi
}
copy_bins() { local f; for f in "$ROOT"/bin/*; do [ -f "$f" ] && put "$f" "$BIN/$(basename "$f")"; done; return 0; }

# NVIDIA alone: Hyprland draws the cursor itself (a hardware cursor is often invisible there). Nothing else is set:
# V3.43 also set LIBVA_DRIVER_NAME=nvidia, __GLX_VENDOR_LIBRARY_NAME=nvidia and NVD_BACKEND=direct, and those broke
# video in Chromium, Brave and Discord (sound but a black picture, GIFs that never play), above all on laptops
# with Intel or AMD graphics next to the NVIDIA card. This file is written again on every update without them.
write_gpu() {
  local f="$HOME/.config/hypr/rice-gpu.lua" gpus nv=0 other=0
  # the old file set the video variables: take them out of the session's services now (apps started by
  # Hyprland keep them until you log out once; the summary says so)
  if grep -qs 'LIBVA_DRIVER_NAME' "$f"; then
    systemctl --user unset-environment LIBVA_DRIVER_NAME __GLX_VENDOR_LIBRARY_NAME NVD_BACKEND 2>/dev/null || true
    mkdir -p "$HOME/.cache/rice"; : >"$HOME/.cache/rice/gpu-env-fixed"
  fi
  gpus="$(lspci 2>/dev/null | grep -iE 'vga|3d|display' || true)"
  if [ -e /proc/driver/nvidia/version ] || printf '%s\n' "$gpus" | grep -qi nvidia; then nv=1; fi
  if printf '%s\n' "$gpus" | grep -vi nvidia | grep -qiE 'intel|amd|ati |advanced micro|radeon'; then other=1; fi
  # which card drives the connected screens: a desktop PC with the screen on the NVIDIA card and the CPU's
  # graphics turned on as well needs the software cursor too (without it: no cursor at all)
  local c b drv nvscreen=0
  for c in /sys/class/drm/card[0-9]*-*; do
    [ "$(cat "$c/status" 2>/dev/null)" = connected ] || continue
    b="${c##*/}"
    drv="$(basename "$(readlink -f "/sys/class/drm/${b%%-*}/device/driver" 2>/dev/null)" 2>/dev/null)"
    case "$drv" in nvidia*) nvscreen=1 ;; esac
  done
  # a software cursor only when NVIDIA drives a screen. A laptop with Intel or AMD graphics next to the NVIDIA
  # card (a hybrid laptop) draws the desktop on those: a software cursor there only costs smoothness (the
  # desktop felt like 60 Hz on a 144 Hz screen)
  if [ "$nv" = 1 ] && { [ "$other" = 0 ] || [ "$nvscreen" = 1 ]; }; then
    mkdir -p "$HOME/.config/hypr"
    cat >"$f" <<'LUA'
-- written by DarkShadow's Shell for NVIDIA graphics (install.sh)
-- the cursor is drawn in software: with a hardware cursor it can be invisible on NVIDIA
hl.config({ cursor = { no_hardware_cursors = true } })
LUA
    echo "NVIDIA drives the screen: software cursor"
  elif [ "$nv" = 1 ]; then
    rm -f "$f"; echo "hybrid graphics (NVIDIA + Intel/AMD): nothing to change"
  else
    rm -f "$f"; echo "no NVIDIA card"
  fi
}
# power modes (Performance / Balanced / Power saver in the island, the control center and Home): power-profiles-daemon.
# Packages only come with a full install; this also runs on updates, so it is there for everyone. Not when TLP,
# auto-cpufreq or tuned (Fedora's tuned-ppd gives the same thing) already manage power.
# Infinite Desktop: SUPER + ALT + mouse reads the mouse and the keyboard directly (rice-canvasd), which needs the
# input group. NixOS keeps groups in its configuration: it gets the line to add instead.
ensure_input_group() {
  [ "$DRY_RUN" = 1 ] && return 0
  if id -nG "$USER" 2>/dev/null | tr ' ' '\n' | grep -qx input; then echo "input group: yes"; return 0; fi
  if [ "${NO_INPUT:-0}" = 1 ]; then echo "input group: skipped (--no-input-group)"; return 0; fi
  if [ "$FAMILY" = nixos ]; then
    echo "NixOS: add \"input\" to users.users.$USER.extraGroups in /etc/nixos/configuration.nix, then sudo nixos-rebuild switch"
    return 0
  fi
  getent group input >/dev/null 2>&1 || { echo "no input group on this system"; return 0; }
  # the installer asked for your password already; when that ran out, sudo asks once more
  if sudo ${RICE_GUI:+-n} usermod -aG input "$USER"; then
    echo "input group: joined (log out and back in once, then SUPER + ALT + mouse works)"
  else
    echo "input group: not joined (Settings > Desktop > Infinite Desktop > Allow)"
  fi
}

ensure_power_modes() {
  [ "$DRY_RUN" = 1 ] && return 0
  local other=0
  for p in tlp auto-cpufreq; do command -v "$p" >/dev/null 2>&1 && other=1; done
  if [ "$other" = 1 ]; then echo "TLP or auto-cpufreq manage power: left alone"; return 0; fi
  if ! command -v powerprofilesctl >/dev/null 2>&1; then
    case "$FAMILY" in
      arch)   sudo -n true 2>/dev/null || { echo "power-profiles-daemon: needs sudo, skipped"; return 0; }
              sudo -n pacman -S --needed --noconfirm power-profiles-daemon || return 0 ;;
      fedora) sudo -n true 2>/dev/null || { echo "power-profiles-daemon: needs sudo, skipped"; return 0; }
              rpm -q tuned-ppd >/dev/null 2>&1 || sudo -n dnf install -y power-profiles-daemon || return 0 ;;
      *) echo "power-profiles-daemon: install it with your package manager"; return 0 ;;
    esac
  fi
  if systemctl list-unit-files power-profiles-daemon.service >/dev/null 2>&1 &&
     ! systemctl is-enabled power-profiles-daemon.service >/dev/null 2>&1; then
    sudo -n systemctl enable --now power-profiles-daemon.service || true
  fi
  echo "power modes: on"
}
wire_hypr() {
  local lua="$HOME/.config/hypr/hyprland.lua" m
  [ -f "$lua" ] || return 0
  # settings this Hyprland does not know are skipped instead of stopping the whole config
  if [ -f "$HOME/.config/hypr/rice-guard.lua" ] && ! grep -q 'rice-guard' "$lua"; then
    printf '%s\n%s\n\n' "-- DarkShadow's Shell: settings this Hyprland does not know are skipped instead of stopping the config" 'pcall(require, "rice-guard")' | cat - "$lua" >"$lua.rice-new" && mv -f "$lua.rice-new" "$lua"
  fi
  if [ -f "$HOME/.config/hypr/rice-gpu.lua" ] && ! grep -q 'rice-gpu' "$lua"; then printf '\npcall(require, "rice-gpu")\n' >>"$lua"; fi
  # Settings > Desktop > Infinite Desktop (SUPER + F)
  if [ -f "$HOME/.config/hypr/rice-infinite.lua" ] && ! grep -q 'rice-infinite' "$lua"; then printf '\npcall(require, "rice-infinite")\n' >>"$lua"; fi
  # your own keys for the shell's actions (Settings > System > Keybinds): loaded after everything else
  if [ -f "$HOME/.config/hypr/rice-keymap.lua" ] && ! grep -q 'rice-keymap' "$lua"; then printf '\npcall(require, "rice-keymap")\n' >>"$lua"; fi
  for m in rice-settings rice-desktop rice-keys; do
    if [ -f "$HOME/.config/hypr/$m.lua" ] && ! grep -q "^[[:space:]]*require(\"$m\")" "$lua"; then
      printf '\nrequire("%s")\n' "$m" >>"$lua"
    fi
  done
  return 0
}
patch_colors() {
  local c="$HOME/.config/quickshell/hyprquickpaper/commands.sh"
  [ -f "$c" ] || { echo "no hyprquickpaper, skipped"; return 0; }
  python3 "$ROOT/install/patches/colors-commands.py" "$c"
}
fixup() { python3 "$ROOT/install/lib/fixup.py" >"$1"; }
# extra cursor themes from GitHub into ~/.local/share/icons (skips the ones you have; offline is fine)
cursor_packs() { t "$BIN/rice-cursor" get all --missing >"$1" 2>&1; }
remember_repo() { mkdir -p "$HOME/.config/rice"; echo "$ROOT" >"$HOME/.config/rice/repo"; }
remember_version() { mkdir -p "$HOME/.config/rice"; echo "$RICE_VERSION" >"$HOME/.config/rice/version"; }
first_backup() { mkdir -p "$HOME/.config/rice" "$HOME/.cache/rice"; [ -f "$HOME/.config/rice/.first-backup" ] || echo "$BK" >"$HOME/.config/rice/.first-backup"; }

# old backups pile up with every update (a slow, big ~/.config): keep the first one and the newest two
prune_backups() {
  [ "$DRY_RUN" = 1 ] && return 0
  local first old d
  first="$(cat "$HOME/.config/rice/.first-backup" 2>/dev/null)"
  old="$(find "$HOME/.config" -maxdepth 1 -type d \( -name 'darkshadows-shell-backup-*' -o -name 'shadows-shell-backup-*' \) 2>/dev/null | sort | head -n -2)"
  [ -n "$old" ] || return 0
  while IFS= read -r d; do
    [ "$d" = "$first" ] && continue
    rm -rf "$d"
  done <<<"$old"
  return 0
}
# the quiet version of those tasks, for updates
refresh_look() {
  [ -f "$HOME/.config/waybar/config.jsonc" ] && t "$BIN/waybar-set" distro-icon on
  [ -x "$BIN/desktop-set" ] && t "$BIN/desktop-set" state
  [ -x "$BIN/rice-cc" ] && t "$BIN/rice-cc" migrate
  t "$BIN/rice-notify" apply
  command -v hyprlock >/dev/null 2>&1 && t "$BIN/rice-lock" apply
  t "$BIN/rice-rofi" apply
  [ -x "$BIN/rice-bar" ] && t bash -c "\"$BIN/rice-bar\" migrate && \"$BIN/rice-bar\" start"
  t "$BIN/rice-hotcorner" apply
  [ -x "$BIN/desktop-set" ] && t "$BIN/desktop-set" dock-blur
  [ -x "$BIN/rice-dashboard" ] && t "$BIN/rice-dashboard" blur
  return 0
}
step_finish() {
  local T=25
  task "Remembering your backup folder" first_backup
  task "Removing old backups (keeps the first and the newest two)" prune_backups
  task "Remembering where this copy lives (for updates)" remember_repo
  task "Version V$RICE_VERSION" remember_version
  { [ "$FAMILY" = arch ] || [ "$FAMILY" = fedora ]; } && task "Power modes (power-profiles-daemon)" ensure_power_modes
  task "Window manager: $(wm_name)" remember_wm
  task "Graphics card (NVIDIA cursor)" write_gpu
  task "Loading the shell's modules in Hyprland" wire_hypr
  task "Infinite Desktop: SUPER + ALT + mouse (input group)" ensure_input_group
  local fx; fx="$(mktemp)"
  task "Fitting the config to this computer" fixup "$fx"
  grep -v '^nothing to fix$' "$fx" 2>/dev/null | while IFS= read -r line; do note "$line"; done
  rm -f "$fx"
  [ "${WANT[4]:-0}" = 1 ] && have_settings && step_settings
  if [ "$MODE" = update ]; then
    # an update re-applies your settings quietly: one line instead of ten
    task "Refreshing your settings (bar, dock, blur, notifications, lock screen)" refresh_look
  else
    [ -f "$HOME/.config/waybar/config.jsonc" ] && task "Waybar: ${DISTRO_NAME} logo" t "$BIN/waybar-set" distro-icon on
    [ -x "$BIN/desktop-set" ] && task "Desktop widgets settings" t "$BIN/desktop-set" state
    [ -x "$BIN/rice-cc" ] && task "Notifications shown by the shell (Google-style pop-ups and control center)" t "$BIN/rice-cc" migrate
    task "Notifications style and blur" t "$BIN/rice-notify" apply
    command -v hyprlock >/dev/null 2>&1 && task "Lock screen and idle timers" t "$BIN/rice-lock" apply
    task "Launcher and bar blur" t "$BIN/rice-rofi" apply
    [ -x "$BIN/rice-bar" ] && task "DarkShadow bar (Waybar stays off)" t bash -c "\"$BIN/rice-bar\" migrate && \"$BIN/rice-bar\" start"
    task "Panel settings" t "$BIN/rice-hotcorner" apply
    [ -x "$BIN/desktop-set" ] && task "Dock and widget blur" t "$BIN/desktop-set" dock-blur
    [ -x "$BIN/rice-dashboard" ] && task "Panel blur" t "$BIN/rice-dashboard" blur
  fi
  task "Theme colors for the wallpaper picker" patch_colors
  # last: it must stay the last module Hyprland loads
  [ -x "$BIN/rice-effects" ] && task "Blur, transparency and gaming mode" t "$BIN/rice-effects" apply --no-reload
  [ -x "$BIN/rice-fonts" ] && T=400 task "Fonts: Google Sans Flex & Code, Material Symbols, Nerd Font icons (skips what you have)" t "$BIN/rice-fonts"
  [ -x "$BIN/font-set" ] && task "Google Sans Flex as the interface font" t "$BIN/font-set" migrate
  [ -x "$BIN/rice-look" ] && task "Look & Feel: your shell, terminal and fastfetch" t "$BIN/rice-look" apply
  if [ -x "$BIN/rice-cursor" ]; then
    local cf; cf="$(mktemp)"
    T=240 task "Cursor packs: Rose Pine (Hyprcursor), Catppuccin, Phinger" cursor_packs "$cf"
    grep -v 'already here' "$cf" 2>/dev/null | while IFS= read -r line; do note "$line"; done
    rm -f "$cf"
  fi
  # niri: its config from your settings (after the cursor, blur and gaming mode above, which it reads)
  if has_niri || grep -qs "generated by rice-niri" "$HOME/.config/niri/config.kdl"; then
    if command -v niri >/dev/null 2>&1 || [ "$DRY_RUN" = 1 ]; then
      task "niri: keys, borders, corners, animations and blur" t "$BIN/rice-niri" apply
    else
      task "niri config (written again for your niri when it first starts)" t "$BIN/rice-niri" apply
    fi
  fi
  # Settings > Security > Shell files: the files are watched from here on (after every install and update)
  if [ "$IN_HYPR" = 1 ] && [ "$DRY_RUN" != 1 ]; then
    task "Reloading Hyprland" t hyprctl reload
    task "Restarting the bar and the desktop widgets" restart_shell
  elif [ "$IN_NIRI" = 1 ] && [ "$DRY_RUN" != 1 ]; then
    # niri loads its new config by itself
    task "Restarting the bar and the desktop widgets" restart_shell
  else
    note "$(wm_name) is not running here, so nothing was reloaded. Everything starts on your next login."
  fi
}
restart_shell() {
  if [ -x "$BIN/rice-bar" ] && "$BIN/rice-bar" enabled 2>/dev/null; then
    "$BIN/rice-bar" start
  else
    pkill -x waybar 2>/dev/null; pkill -x .waybar-wrapped 2>/dev/null; sleep 0.3
    command -v waybar >/dev/null 2>&1 && detach waybar
  fi
  [ -x "$BIN/rice-desktop" ] && T=10 t "$BIN/rice-desktop" restart
  return 0
}

do_restore() {
  local last
  last="$(find "$HOME/.config" -maxdepth 1 -type d \( -name 'darkshadows-shell-backup-*' -o -name 'shadows-shell-backup-*' \) 2>/dev/null | sort | tail -n1 || true)"
  [ -n "$last" ] || { fail "No backup found."; exit 1; }
  title "Restore"
  kv "Backup" "$last"
  confirm "Put these files back over your current ones?" || { warn "Cancelled."; exit 0; }
  [ "$DRY_RUN" = 1 ] || cp -a "$last"/. "$HOME"/
  ok "Restored. Files that did not exist before the install were left in place."
  exit 0
}

# ------------------------------------------------------------------ main
banner
title "Your system"
kv "User" "$USER  ($HOME)"
kv "System" "$DISTRO_NAME"
flavor_notes
if [ "$IN_HYPR" = 1 ]; then kv "Session" "Hyprland is running (changes apply right away)"
elif [ "$IN_NIRI" = 1 ]; then kv "Session" "niri is running (changes apply right away)"
else kv "Session" "no Hyprland or niri running here (changes apply at next login)"; fi
if [ "$FAMILY" = arch ]; then h="$(aur_helper)"; kv "AUR" "${h:-no yay or paru yet (one can be installed for you: --helper=yay or --helper=paru)}"; fi
[ "$DRY_RUN" = 1 ] && warn "Dry run: nothing will be changed."
if [ "$DOCTOR" = 1 ]; then
  title "Check"
  kv "Hyprland" "$(command -v Hyprland || echo not found)"; kv "niri" "$(command -v niri || echo not found)"
  for h in paru yay; do kv "$h" "$(command -v $h || echo not installed)"; done
  [ -n "$HELPER_ARG" ] && kv "Chosen helper" "$HELPER_ARG"
  if [ -x "$ROOT/bin/rice-cursor" ]; then "$ROOT/bin/rice-cursor" doctor; elif command -v rice-cursor >/dev/null 2>&1; then rice-cursor doctor; fi
  exit 0
fi
[ "$MODE" = restore ] && do_restore

if [ "$MODE" = update ]; then
  title "Update"
  if [ "$PULLED" = 1 ]; then ok "Got the newest version"
  elif [ -d "$ROOT/.git" ] && command -v git >/dev/null 2>&1; then
    old="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo ?)"
    export RICE_PREV_REV="${RICE_PREV_REV:-$(git -C "$ROOT" rev-parse HEAD 2>/dev/null)}"
    if [ "$DRY_RUN" = 1 ]; then info "would run: git pull"
    elif { u="$(git -C "$ROOT" remote get-url origin 2>/dev/null)"; case "$u" in *shadowww-dev/shadows-shell*) git -C "$ROOT" remote set-url origin https://github.com/shadowww-dev/DarkShadowShell.git ;; esac
           GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=never git -c credential.helper= -C "$ROOT" pull --ff-only >>"$LOG" 2>&1; }; then
      new="$(git -C "$ROOT" rev-parse --short HEAD)"
      if [ "$old" != "$new" ]; then
        # new files from GitHub, maybe a new installer too: start the new one
        exec "$ROOT/install.sh" --update --pulled "$@"
      fi
    else
      # the pull did not go (files changed in the repo, or its history went another way). It used to carry on with
      # the old files and say it was done, so the version never moved (Settings > Update Center looked like it
      # updated and nothing changed). Now: what you changed is kept (a stash and a branch), and the repo is set to
      # GitHub's newest version
      info "git pull did not go through; keeping your changes aside and taking GitHub's version"
      gq() { GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=never git -c credential.helper= -C "$ROOT" "$@" >>"$LOG" 2>&1; }
      up="$(git -C "$ROOT" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || echo origin/main)"
      if gq fetch origin; then
        stamp="$(date +%Y%m%d-%H%M%S)"
        gq branch "rice-before-update-$stamp" HEAD || true
        gq stash push -u -m "rice: your changes before the update of $stamp" || true
        if gq reset --hard "$up"; then
          ok "Took the newest version (your old state: branch rice-before-update-$stamp, and git stash list)"
          exec "$ROOT/install.sh" --update --pulled "$@"
        fi
      fi
      if [ -n "${RICE_GUI:-}" ]; then
        fail "Could not get the newest version from GitHub (offline?). Nothing was changed."
        exit 1
      fi
      warn "Could not get the newest version from GitHub (offline?). Continuing with the files you have."
    fi
  fi
fi

# the version you have, as the repo had it (its tag, or the commit before the pull): your edits are told apart from it
if [ "$MODE" = update ] && [ -d "$ROOT/.git" ] && command -v git >/dev/null 2>&1; then
  PREV_REV="$(git -C "$ROOT" rev-parse -q --verify "v${HAVE_VERSION:-0}^{commit}" 2>/dev/null || true)"
  [ -n "$PREV_REV" ] || PREV_REV="${RICE_PREV_REV:-}"
fi
rm -f "$KEPTF"

if [ "$MODE" = update ]; then
  if ver_newer "$RICE_VERSION" "${HAVE_VERSION:-2.01}"; then
    ok "Update V$RICE_VERSION  (you have V${HAVE_VERSION:-2.01})"
  else
    ok "You already have the newest version: V$RICE_VERSION"
  fi
fi

if [ "$MODE" = update ]; then
  WANT=(1 0 0 1 1)
  [ "$SKIP_PKGS" = 1 ] && WANT[0]=0
  [ "$FAMILY" = arch ] || [ "$FAMILY" = fedora ] || WANT[0]=0
  # an update asks nothing: your configs and settings stay as they are (--use-saved-settings takes the saved ones)
  MENU_CHOICE=99
else
if [ -n "$HAVE_VERSION" ]; then
  if ver_newer "$RICE_VERSION" "$HAVE_VERSION"; then UPD_HINT="V$HAVE_VERSION  ->  V$RICE_VERSION, keeps your configs"
  else UPD_HINT="you have V$HAVE_VERSION, gets the newest from GitHub"; fi
else UPD_HINT="get the newest version, keeps your configs"; fi
menu_select "What would you like to do?" \
  "Install everything|recommended" \
  "Update|$UPD_HINT" \
  "Choose what to install|" \
  "Restore my previous files|from the last backup" \
  "Quit|"
case "$MENU_CHOICE" in 1) exec "$ROOT/install.sh" --update "$@" ;; 3) do_restore ;; 4) exit 0 ;; esac
WANT=(1 1 1 1 1)
[ "$SKIP_PKGS" = 1 ] && WANT[0]=0
TAKE_SETTINGS=1     # a fresh install takes the saved settings (yours are backed up)
fi
[ "$TAKE_SETTINGS_ARG" = 1 ] && TAKE_SETTINGS=1
# Hyprland by default (what runs now, or what was set up before, is kept); --wm=niri or --wm=both for others
WM="${WM_ARG:-$(wm_guess)}"
wm_packages
if [ "$MENU_CHOICE" = 2 ]; then
  menu_multi "Choose what to install" \
    "Packages|$(wm_name), Quickshell, Waybar, tools|${WANT[0]}" \
    "Fonts|Inter, Rubik, Nerd Font icons and clock fonts|1" \
    "Config files|Hyprland, bar, notifications, launcher|1" \
    "Apps and scripts|Settings app, widgets, dock|1" \
    "Your settings|bar, widgets, lock screen (settings/)|1"
  WANT=("${MENU_SEL[@]}")
fi

if [ "$MODE" != update ]; then
title "Plan"
info "Window manager: $(wm_name)"
[ "${WANT[0]}" = 1 ] && info "Install packages for $DISTRO_NAME"
[ "${WANT[1]}" = 1 ] && info "Install fonts"
[ "${WANT[2]}" = 1 ] && info "Copy config files into ~/.config"
[ "${WANT[3]}" = 1 ] && info "Install the Settings app, widgets and helper scripts"
[ "${WANT[4]:-0}" = 1 ] && have_settings && info "Use your saved settings (bar, widgets, lock screen...)"
info "Finish setup (theme, lock screen, notifications)"
note "Files that get replaced are saved in ${BK/#$HOME/~}"
confirm "Start?" || { warn "Cancelled."; exit 0; }
fi

STEP_TOTAL=$(( WANT[0] + WANT[1] + WANT[2] + WANT[3] + 1 ))
n=0
if [ "${WANT[0]}" = 1 ]; then n=$((n + 1)); step "$n" "Packages" "Everything the desktop needs, from your package manager"; step_packages; fi
if [ "${WANT[1]}" = 1 ]; then n=$((n + 1)); step "$n" "Fonts" "So text and icons look right"; step_fonts; fi
if [ "${WANT[2]}" = 1 ]; then n=$((n + 1)); step "$n" "Config files" "Your old files are backed up first"; step_configs; fi
if [ "${WANT[3]}" = 1 ]; then n=$((n + 1)); step "$n" "Apps and scripts" "Settings app, desktop widgets and the commands behind them"; step_apps
  [ "${WANT[2]}" = 1 ] || task "Hyprland add-ons (keybinds)" copy_lua
fi
n=$((n + 1)); if [ "$MODE" = update ]; then step "$n" "Finishing" "Refreshing and cleaning up"; else step "$n" "Finishing" "Theme, lock screen and notifications"; fi; step_finish

# ------------------------------------------------------------------ summary
miss="$(missing_cmds)"
printf '\n'
hr
if [ "$DRY_RUN" = 1 ]; then
  printf '  %s%sDry run finished.%s Nothing was changed.\n' "$CB" "$CW" "$C0"
else
  if [ "$MODE" = update ] && ver_newer "$RICE_VERSION" "${HAVE_VERSION:-2.01}"; then
    printf '  %s%sDarkShadow'"'"'s Shell updated to V%s%s  (was V%s)\n' "$CB" "$CW" "$RICE_VERSION" "$C0" "${HAVE_VERSION:-2.01}"
  elif [ "$MODE" = update ]; then printf '  %s%sDarkShadow'"'"'s Shell V%s%s  newest version, refreshed\n' "$CB" "$CW" "$RICE_VERSION" "$C0"
  else printf '  %s%sDarkShadow'"'"'s Shell V%s is installed.%s\n' "$CB" "$CW" "$RICE_VERSION" "$C0"; fi
fi
hr
if [ -n "$miss" ]; then warn "Still missing: $miss"; else ok "All needed programs are installed"; fi
if [ -s "$KEPTF" ] && [ "$DRY_RUN" != 1 ]; then
  warn "You changed these files, so they were kept as they are (the new versions are next to them, .rice-update):"
  sed 's/^/        ~\//' "$KEPTF" | head -20
  note "If something looks broken, take the new one:  mv FILE.rice-update FILE   (or update with RICE_OVERWRITE=1)"
fi
if [ -f "$HOME/.cache/rice/gpu-env-fixed" ] && [ "$DRY_RUN" != 1 ]; then
  warn "Log out and back in once: videos in Brave, Chrome and Discord (and GIFs) play again after that."
  note "An older version set NVIDIA video variables that broke them; they are gone now."
  command -v notify-send >/dev/null 2>&1 && notify-send -a "DarkShadow's Shell" "Log out and back in once" "Videos and GIFs in Brave, Chrome and Discord play again after that."
  rm -f "$HOME/.cache/rice/gpu-env-fixed"
fi
old_hypr="$(hypr_too_old)"
if has_hypr && [ -n "$old_hypr" ] && [ "$DRY_RUN" != 1 ]; then
  warn "Hyprland $old_hypr is older than 0.55. The config is written in Lua and needs 0.55 or newer."
  case "$FAMILY" in
    arch)   note "Update it: sudo pacman -Syu hyprland (Manjaro: the new version can take a while to arrive)" ;;
    fedora) note "Update it: sudo dnf upgrade --refresh hyprland (the nett00n/hyprland COPR carries the newest)" ;;
  esac
fi
if [ "$IN_HYPR" = 1 ] && [ "$DRY_RUN" != 1 ]; then
  errs="$(t hyprctl configerrors 2>/dev/null | grep -v '^\s*$' | head -5 || true)"
  if [ -n "$errs" ]; then warn "Hyprland reports config errors:"; printf '%s\n' "$errs" | sed 's/^/        /'; fi
fi
if has_niri && [ "$IN_NIRI" = 1 ] && [ "$DRY_RUN" != 1 ]; then
  nerr="$(t niri validate 2>&1 | grep -iE 'error|fail' | head -3 || true)"
  if [ -n "$nerr" ]; then warn "niri reports config errors:"; printf '%s\n' "$nerr" | sed 's/^/        /'; fi
fi
if [ "$MODE" != update ]; then
title "Next"
if [ "$IN_HYPR" = 1 ] || [ "$IN_NIRI" = 1 ]; then info "Press SUPER + U to open Settings"
else
  case "$WM" in
    niri) info "Log out and pick niri on the login screen (or type niri-session on a TTY)" ;;
    both) info "Log out and pick Hyprland or niri on the login screen (TTY: Hyprland or niri-session)" ;;
    *)    info "Log out and pick Hyprland on the login screen (or type Hyprland on a TTY)" ;;
  esac
  info "Then press SUPER + U to open Settings"
fi
has_niri && info "niri: SUPER + Tab or the top-left corner shows the overview, SUPER + Shift + / lists the keys"
[ -d "$BK" ] && info "Undo everything:  ./install.sh --restore"
fi
note "Full log: $LOG"
printf '\n'
# the welcome intro (once): night falls, the moon draws itself in, then Settings opens with a short tour.
# After a new install it plays at the next login (Hyprland starts it), so offer a reboot.
# After an update inside Hyprland it plays right away, if it has not been seen yet.
intro_pending=0
[ -x "$BIN/rice-welcome" ] && [ ! -f "$HOME/.config/rice/welcome-seen" ] && [ ! -f "$HOME/.config/rice/welcome-off" ] && intro_pending=1
if [ "$DRY_RUN" != 1 ]; then
  if [ "$MODE" = update ]; then
    if [ "$intro_pending" = 1 ] && { [ "$IN_HYPR" = 1 ] || [ "$IN_NIRI" = 1 ]; }; then info "Starting the welcome intro..."; detach "$BIN/rice-welcome" start 1; fi
  else
    [ "$intro_pending" = 1 ] && info "The welcome intro and a short tour of Settings start when you log in."
    if [ "$ASSUME_YES" != 1 ] && [ "$IS_TTY" = 1 ] && confirm_no "Reboot now?"; then
      info "Rebooting..."
      sleep 1
      "$ROOT/bin/rice-sys" reboot || warn "Could not reboot. Reboot yourself to finish."
    else
      note "Reboot (or log out and back in) when you are ready."
    fi
  fi
fi
