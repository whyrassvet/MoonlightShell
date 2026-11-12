{
  description = "DarkShadow's Shell: a Hyprland and niri desktop with Quickshell";

  # no inputs: the module uses the nixpkgs of your own system, so nothing extra is downloaded or pinned
  outputs = { self, ... }: {
    nixosModules.default = import ./nix/module.nix;
    nixosModules.shadows-shell = self.nixosModules.default;
  };
}
