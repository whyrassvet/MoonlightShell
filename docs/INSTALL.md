# Installation

## Arch Linux (and CachyOS, EndeavourOS, Garuda)
```bash
git clone https://github.com/whyrassvet/MoonlightShell.git && cd MoonlightShell
./install.sh
```
The installer runs `sudo pacman -S --needed` for packages found in the repos and uses `paru` or `yay` for the rest (for example `quickshell`, `awww`). Without an AUR helper it prints the list for you to install.

CachyOS works the same way: its repositories are used and `paru`, which CachyOS ships, installs the AUR packages. Manjaro holds packages back, so its Hyprland can be older than 0.55 (the config needs 0.55); the installer tells you at the end.

## Backups and undo
Every file the installer replaces is copied to `~/.config/darkshadows-shell-backup-<time>/`. Undo with `./install.sh --restore`.

Other distribution families are not supported.
