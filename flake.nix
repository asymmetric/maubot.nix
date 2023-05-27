{
  description = "Nix compatibility for Maubot";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, ... }: {
    nixosModules.default = import ./module;
    nixosModules.maubot = import ./module;
    overlays.default = final: prev: {
      maubot = prev.toPythonApplication (prev.callPackage ./pkg { });
      maubotPlugins = nixpkgs.lib.recurseIntoAttrs final.python3.pkgs.maubot.plugins;
      python3Packages = prev.python3Packages // {
        maubot = prev.callPackage ./pkg { };
      };
      python3 = prev.python3 // {
        pkgs = prev.python3.pkgs // {
          maubot = prev.callPackage ./pkg { };
        };
      };
    };
    nixosConfigurations.test1 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux"; modules = [ (import ./module) {
        system.stateVersion = "23.05";
        fileSystems."/" = { device = "none"; fsType = "tmpfs"; neededForBoot = false; options = [ "defaults" "size=2G" "mode=755" ]; };
        boot.loader.grub.device = "nodev";
      } ];
    };
    nixosConfigurations.test2 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux"; modules = [ (import ./module) {
        system.stateVersion = "23.05";
        fileSystems."/" = { device = "none"; fsType = "tmpfs"; neededForBoot = false; options = [ "defaults" "size=2G" "mode=755" ]; };
        boot.loader.grub.device = "nodev";
        services.maubot.enable = true;
      } ];
    };
    nixosConfigurations.test3 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux"; modules = [ (import ./module) ({ pkgs, ... }: {
        system.stateVersion = "23.05";
        fileSystems."/" = { device = "none"; fsType = "tmpfs"; neededForBoot = false; options = [ "defaults" "size=2G" "mode=755" ]; };
        boot.loader.grub.device = "nodev";
        services.maubot.enable = true;
        services.maubot.plugins = (pkgs.callPackage ./pkg { }).plugins.officialPlugins;
      }) ];
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
      packages.python3Packages.maubot = pkgs.python3Packages.maubot;
      devShells.default =
        let py = pkgs.python3.withPackages (p: with p; [ gitpython requests types-requests ruamel-yaml toml ]);
        in pkgs.mkShell {
          propagatedBuildInputs = [ py ];
          MYPYPATH = "${py}/${py.sitePackages}";
        };
    }));
}
