{
  description = "Nix compatibility for Maubot";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, ... }:
    let
      forEachSystem = fn: nixpkgs.lib.genAttrs [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ]
        (system: fn (import nixpkgs {
          inherit system;
          overlays = [
            self.overlays.default
          ];
        }));
    in
    {
      nixosModules.default = import ./module;
      nixosModules.maubot = import ./module;
      overlays.default = final: prev: {
        maubot = prev.pythonPackages.toPythonApplication (final.callPackage ./pkg { });
        maubotPlugins = nixpkgs.lib.recurseIntoAttrs final.python3.pkgs.maubot.plugins;
        python3Packages = prev.python3Packages // {
          maubot = final.callPackage ./pkg { };
        };
        python3 = prev.python3 // {
          pkgs = prev.python3.pkgs // {
            maubot = final.callPackage ./pkg { };
          };
        };
      };
      checks.x86_64-linux = {
        inherit (self.packages.x86_64-linux.maubot) withAllPlugins;
      };
      formatter = forEachSystem (pkgs: pkgs.nixpkgs-fmt);
      packages = forEachSystem (pkgs: {
        maubot = pkgs.maubot;
        default = pkgs.maubot;
        maubot-lib = pkgs.python3Packages.maubot;
      });
      devShells = forEachSystem (pkgs: {
        # for plugins update script
        default =
          let py = pkgs.python3.withPackages (p: with p; [ gitpython requests types-requests ruamel-yaml toml ]);
          in pkgs.mkShell {
            nativeBuildInputs = [
              py
              pkgs.git
              pkgs.nurl
            ];
            MYPYPATH = "${py}/${py.sitePackages}";
          };
      });
    };
}
