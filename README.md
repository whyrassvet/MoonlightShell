<p align="center">
  <img src="assets/banner-dark.svg" alt="Moonlight Shell" width="100%">
</p>

<p align="center">
  <b>🌙 A desktop that feels like yours. ✨</b><br>
  A customizable Quickshell desktop for Hyprland and niri.
</p>

<p align="center">
  Made by <a href="https://github.com/whyrassvet">rassvet</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Arch--based-1793D1?style=for-the-badge&logo=archlinux&logoColor=white&labelColor=11111b" alt="Arch-based Linux">
  <img src="https://img.shields.io/badge/Hyprland-0.55%2B-58E1FF?style=for-the-badge&logo=hyprland&logoColor=white&labelColor=11111b" alt="Hyprland 0.55 or newer">
  <img src="https://img.shields.io/badge/niri-Wayland-8B7BFF?style=for-the-badge&logo=wayland&logoColor=white&labelColor=11111b" alt="niri">
  <img src="https://img.shields.io/badge/Quickshell-QML-41CD52?style=for-the-badge&logo=qt&logoColor=white&labelColor=11111b" alt="Quickshell">
</p>
<p align="center">
  <a href="https://github.com/whyrassvet/MoonlightShell/releases"><img src="https://img.shields.io/badge/GitHub-Releases-8B7BFF?style=for-the-badge&labelColor=11111b&logo=github&logoColor=white" alt="Releases"></a>
  <a href="https://github.com/whyrassvet/MoonlightShell/commits/main"><img src="https://img.shields.io/github/last-commit/whyrassvet/MoonlightShell?style=for-the-badge&labelColor=11111b&logo=git&logoColor=white&color=4c566a&label=updated" alt="Last commit"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-2ea043?style=for-the-badge&labelColor=11111b&logo=opensourceinitiative&logoColor=white" alt="MIT license"></a>
</p>

<p align="center">
  <a href="#screenshots">Screenshots</a> · <a href="#install">Install</a> ·
  <a href="#make-it-yours">Customize</a> · <a href="#updates">Updates</a>
</p>

---

## 🌌 Screenshots

<p align="center">
  <img src="assets/screenshot-desktop.png" alt="Moonlight Shell desktop with widgets, bar and visualizer" width="100%"><br>
  <sub>The desktop: widgets, bar and audio visualizer</sub>
</p>
<p align="center">
  <img src="assets/screenshot-settings.png" alt="Moonlight Shell Settings" width="100%"><br>
  <sub>Settings · <code>SUPER + U</code></sub>
</p>
<p align="center">
  <img src="assets/screenshot-edit.png" alt="Moonlight Shell desktop edit mode" width="100%"><br>
  <sub>Edit mode · <code>SUPER + ALT + W</code></sub>
</p>

## 🚀 Install

Moonlight Shell supports **Arch-based distributions**, including Arch Linux, CachyOS and EndeavourOS. The installer supports Hyprland and niri; Hyprland requires version **0.55 or newer**.

> [!IMPORTANT]
> Review the installer and back up your existing configuration before installing. Run the installer as your normal user, not root. It installs packages and changes desktop configuration files.

```bash
sudo pacman -S --needed git base-devel
git clone https://github.com/whyrassvet/MoonlightShell.git
cd MoonlightShell
./install.sh
```

Choose Hyprland, niri or both in the installer. To preview the plan without installing, run `./install.sh --yes --dry-run`. After installation, log out and select your chosen session; open Settings with `SUPER + U`.

The installer saves replaced files in `~/.config/darkshadows-shell-backup-<timestamp>/`. See `./install.sh --help` for options, including `--no-packages`, `--wm=niri` and `--restore`.

## 🎨 Make it yours

Use the Settings app to personalize the bar, wallpaper, colors, animations and desktop widgets. Edit mode lets you arrange widgets and adjust the visualizer directly on the desktop.

| Shortcut | Action |
| --- | --- |
| `SUPER + U` | Open Settings |
| `SUPER + ALT + W` | Toggle desktop edit mode |
| `SUPER + W` | Open wallpapers |
| `SUPER + N` | Open the control center |
| `SUPER + F` | Toggle fullscreen |
| `SUPER + T` | Return a window to tiling |
| `SUPER + ALT + F` | Toggle Infinite Desktop |
| `Print` | Capture the focused monitor |

### ⚙️ Your Hyprland configuration

For your own Hyprland Lua settings and keybinds, edit `~/.config/hypr/hyprland-user.lua`. It is loaded last by the shell's Hyprland configuration and is not overwritten by the installer during updates. Existing `~/.config/hypr/user.lua` files are also loaded for compatibility. Settings controlled by the app are kept separately.

## 🔄 Updates

Check **Settings → Update Center** or run the installer from your Moonlight Shell checkout:

```bash
./install.sh --update
```

Updates use the [Moonlight Shell repository](https://github.com/whyrassvet/MoonlightShell). If Git cannot fast-forward, the update stops rather than resetting or stashing your local changes. Browse published versions on the [releases page](https://github.com/whyrassvet/MoonlightShell/releases).

## 💙 Credits

Moonlight Shell is based on [DarkShadowShell](https://github.com/shadowww-dev/DarkShadowShell) by shadowww-dev, with bug fixes and quality-of-life improvements developed for this fork. Thanks to the original author and everyone whose work contributed to the project.

Licensed under the [MIT License](LICENSE).
