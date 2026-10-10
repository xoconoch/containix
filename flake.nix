{
  description = "containix - Declarative Docker/Podman Compose projects managed natively by systemd on NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    nixosModules = {
      containix = import ./modules/default.nix;
      default = self.nixosModules.containix;
    };

    # Legacy output for flakes compatibility
    nixosModule = self.nixosModules.default;
  };
}
