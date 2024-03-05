{
  outputs = {self}: {
    nixosModules = {
      default = self.nixosModules.patchwork;
      patchwork = import ./nixos.nix;
    };

    homeModules = {
      default = self.homeModules.patchwork;
      patchwork = import ./home.nix;
    };
  };
}
