# shellcheck shell=bash
# shellcheck disable=SC2034
# Distro detection + what to install.

DISTRO_ID=linux; DISTRO_NAME=Linux; DISTRO_LIKE=
OS_RELEASE="${OS_RELEASE:-/etc/os-release}"
if [ -r "$OS_RELEASE" ]; then
  # shellcheck disable=SC1090,SC1091
  . "$OS_RELEASE"
  DISTRO_ID="${ID:-linux}"; DISTRO_NAME="${NAME:-Linux}"; DISTRO_LIKE="${ID_LIKE:-}"
fi
FAMILY=other
case " $DISTRO_ID $DISTRO_LIKE " in
  *" nixos "*) FAMILY=nixos ;;
  *" arch "*|*" archlinux "*|*" cachyos "*|*" endeavouros "*|*" manjaro "*|*" garuda "*) FAMILY=arch ;;
  *" fedora "*|*" nobara "*|*" ultramarine "*) FAMILY=fedora ;;
esac
# the flavour inside a family, for messages (CachyOS, EndeavourOS, Manjaro, Nobara, Bazzite ...)
DISTRO_FLAVOR="$DISTRO_ID"
case "$FAMILY" in arch|fedora) : ;; *) DISTRO_FLAVOR="$FAMILY" ;; esac
# the Hyprland config is Lua, which needs Hyprland 0.55 or newer
HYPR_MIN_MAJOR=0; HYPR_MIN_MINOR=55
# Fedora Atomic (Bazzite, Silverblue, Kinoite...): packages are layered with rpm-ostree, not dnf
FEDORA_ATOMIC=0
if [ "$FAMILY" = fedora ] && [ -e "${OSTREE_BOOTED:-/run/ostree-booted}" ]; then FEDORA_ATOMIC=1; fi

# Arch packages, grouped so the installer can explain what it is doing.
PKG_DESKTOP=(hyprland hyprlock hypridle xdg-desktop-portal-hyprland xdg-desktop-portal-gtk hyprpolkitagent qt5-wayland qt6-wayland)
PKG_SHELL=(quickshell qt6-multimedia waybar swaync awww cava kitty fish fastfetch nautilus matugen)
PKG_TOOLS=(wf-recorder grim slurp wl-clipboard cliphist wtype libnotify xdg-user-dirs jq curl python playerctl brightnessctl pamixer
           imagemagick ffmpeg mpvpaper zenity networkmanager bluez bluez-utils pipewire pipewire-pulse wireplumber
           btop cmatrix peaclock pavucontrol gnome-calendar hyprsunset upower power-profiles-daemon)
PKG_FONTS=(ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols noto-fonts noto-fonts-emoji inter-font)
# adwaita-cursors: a cursor from the repositories, so there is always one (Bibata is in the AUR; without an
# AUR helper it is downloaded from GitHub)
PKG_LOOK=(papirus-icon-theme gnome-themes-extra adw-gtk-theme adwaita-cursors bibata-cursor-theme-bin)
ARCH_PKGS=("${PKG_DESKTOP[@]}" "${PKG_SHELL[@]}" "${PKG_TOOLS[@]}" "${PKG_FONTS[@]}" "${PKG_LOOK[@]}")
# AUR packages the shell cannot work without (on Arch versions that do not have them in the repositories):
# yay is built for these by itself (mpvpaper: live wallpapers). The others (the Bibata cursor, peaclock ...) are skipped without an AUR helper:
# the installer downloads the cursor from GitHub instead.
AUR_NEEDED=(quickshell awww matugen niri xwayland-satellite mpvpaper)

# programs the desktop needs at runtime (shown at the end if something is missing)
NEED_CMDS=(Hyprland hyprlock hypridle waybar qs swaync-client awww matugen cava jq python3 grim slurp wl-copy wf-recorder notify-send)

# niri: the scrollable-tiling window manager. The shell runs on it as on Hyprland (install.sh asks which one:
# Hyprland, niri or both). xwayland-satellite runs X11 apps there; the GNOME portal gives screen sharing.
# hyprlock, hypridle and hyprpolkitagent stay: the lock screen, the idle timers and password prompts use them on niri too.
# gammastep is the night light there (hyprsunset needs Hyprland).
PKG_NIRI=(niri xwayland-satellite xdg-desktop-portal-gnome gammastep)
FPKG_NIRI=(niri xwayland-satellite xdg-desktop-portal-gnome gammastep)
# the newest niri for Fedora (blur needs niri 26.04): the COPR of niri's author, next to Fedora's own package
FEDORA_NIRI_COPR=yalter/niri

# Fedora packages (dnf). Hyprland, its tools and Quickshell come from the nett00n/hyprland COPR (the newest
# Hyprland, needed for the Lua config); awww from scottames/awww. Nerd Font icons and the Bibata cursor are not
# in Fedora: rice-fonts and the installer download them.
# "a|b": the first of these names your Fedora has (package names that changed between Fedora releases).
# Quickshell: errornointernet/quickshell is the COPR the Quickshell docs point to (nett00n/hyprland has it too).
# matugen is in Fedora 44 and newer; on older ones the installer downloads it from its GitHub releases.
FEDORA_COPRS=(nett00n/hyprland errornointernet/quickshell scottames/awww)
FPKG_DESKTOP=(hyprland hyprlock hypridle hyprsunset hyprpolkitagent xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
              qt5-qtwayland qt6-qtwayland)
FPKG_SHELL=(quickshell qt6-qtmultimedia waybar SwayNotificationCenter awww cava kitty fish fastfetch nautilus matugen)
FPKG_TOOLS=(wf-recorder grim slurp wl-clipboard cliphist wtype libnotify xdg-user-dirs jq curl python3 playerctl brightnessctl pamixer
            ImageMagick "ffmpeg-free|ffmpeg" mpvpaper zenity NetworkManager bluez pipewire pipewire-pulseaudio wireplumber
            btop cmatrix pavucontrol gnome-calendar upower power-profiles-daemon tar xz unzip)
FPKG_FONTS=(rsms-inter-fonts google-noto-sans-fonts google-noto-emoji-fonts)
FPKG_LOOK=(papirus-icon-theme adw-gtk3-theme adwaita-cursor-theme)
FEDORA_PKGS=("${FPKG_DESKTOP[@]}" "${FPKG_SHELL[@]}" "${FPKG_TOOLS[@]}" "${FPKG_FONTS[@]}" "${FPKG_LOOK[@]}")

