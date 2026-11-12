# NixOS module: installs everything DarkShadow's Shell needs.
# Dotfiles and apps are still installed per user with ./install.sh (pick "Tools", "Apps", "Dotfiles").
#
#   imports = [ /path/to/shadows-shell/nix/module.nix ];      (or the flake: inputs.shadows-shell.nixosModules.default)
#   programs.shadows-shell.user = "shadow";                   your user: joins the "input" group (SUPER + ALT + mouse)
#
# Options (all optional): enable (true), user (null), niri (true), extras (true: live wallpapers, video previews).
# A package your nixpkgs does not have is skipped instead of stopping the rebuild (awww falls back to swww).
{ config, lib, pkgs, options, ... }:
let
  cfg = config.programs.shadows-shell;
  # the packages that exist in this nixpkgs (older or newer ones rename or drop some)
  have = names: lib.filter (p: p != null) (map (n: lib.attrByPath (lib.splitString "." n) null pkgs) names);
  wallpaperDaemon = if pkgs ? awww then [ pkgs.awww ] else have [ "swww" ];
in
{
  options.programs.shadows-shell = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install what DarkShadow's Shell needs (Hyprland, Quickshell, the tools and fonts).";
    };
    user = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "shadow";
      description = "Your user name. It joins the input group, so Infinite Desktop (SUPER + ALT + mouse) can read the mouse.";
    };
    niri = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Also install niri (the shell runs on it too; pick it on the login screen).";
    };
    extras = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Live wallpapers (mpvpaper) and video previews (ffmpeg).";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      programs.hyprland.enable = lib.mkDefault true;

      environment.systemPackages = wallpaperDaemon ++ have [
        "waybar" "swaynotificationcenter" "hyprlock" "hypridle" "hyprsunset" "hyprpolkitagent"
        "quickshell" "matugen" "imagemagick" "kitty" "fish" "fastfetch"
        "cava" "curl" "jq" "python3" "playerctl" "brightnessctl" "pamixer" "zenity"
        "wf-recorder" "grim" "slurp" "wl-clipboard" "libnotify" "xdg-user-dirs"
        "pavucontrol" "gnome-calendar" "upower" "nautilus" "btop" "cmatrix" "peaclock"
        "papirus-icon-theme" "bibata-cursors"
      ] ++ lib.optionals cfg.extras (have [ "ffmpeg" "mpvpaper" ]);

      fonts.packages = have [ "nerd-fonts.jetbrains-mono" "nerd-fonts.symbols-only" "inter" "rubik" ];

      services.pipewire = {
        enable = lib.mkDefault true;
        pulse.enable = lib.mkDefault true;
      };

      # battery and device charge for the Battery widget
      services.upower.enable = lib.mkDefault true;

      # power modes in the notification center (Power saver, Balanced, Performance).
      # Turned off automatically when you use TLP or auto-cpufreq, which do the same job.
      services.power-profiles-daemon.enable = lib.mkDefault (
        !(config.services.tlp.enable or false) && !(config.services.auto-cpufreq.enable or false));

      xdg.portal.enable = lib.mkDefault true;

      # the lock screen (the shell's own and hyprlock) checks your password with this PAM service
      security.pam.services.hyprlock = { };
    }

    # Infinite Desktop reads the mouse and the keyboard (SUPER + ALT + mouse): your user in the input group
    (lib.mkIf (cfg.user != null) {
      users.users.${cfg.user}.extraGroups = [ "input" ];
    })

    # niri: programs.niri brings niri, its session, the GNOME portal (screen sharing) and polkit;
    # xwayland-satellite runs X11 apps, gammastep is the night light there
    (lib.optionalAttrs (options ? programs && options.programs ? niri) {
      programs.niri.enable = lib.mkDefault cfg.niri;
    })
    (lib.mkIf cfg.niri {
      environment.systemPackages = have [ "xwayland-satellite" "gammastep" ];
    })
  ]);
}
