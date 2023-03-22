{
  description = "Nix compatibility for Maubot";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/master";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, flake-compat }: {
    nixosModules.default = import ./module;
    overlays.default = final: prev: {
      maubot = prev.callPackage ./pkg { };
      maubotPlugins = nixpkgs.lib.recurseIntoAttrs final.maubot.plugins;
    };
  } // (flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = (import nixpkgs {
        inherit system;
        # config.allowUnfree = true;
      }).extend self.overlays.default;
    in
    rec {
      formatter = pkgs.nixpkgs-fmt;
      packages.maubot = pkgs.maubot;
      packages.default = packages.maubot;
      devShells.default =
        let py = pkgs.python3.withPackages (p: with p; [ gitpython requests types-requests ruamel-yaml toml ]);
        in pkgs.mkShell {
          propagatedBuildInputs = [ py ];
          MYPYPATH = "${py}/${py.sitePackages}";
        };
    }));
}
