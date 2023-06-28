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
      # used for testing, I really ought to move it to checks...
      nixosConfigurations.test0 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          (import ./module)
          {
            system.stateVersion = "23.05";
            fileSystems."/" = { device = "none"; fsType = "tmpfs"; neededForBoot = false; options = [ "defaults" "size=2G" "mode=755" ]; };
            boot.loader.grub.device = "nodev";
          }
        ];
      };
      nixosConfigurations.test1 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          (import ./module)
          {
            system.stateVersion = "23.05";
            fileSystems."/" = { device = "none"; fsType = "tmpfs"; neededForBoot = false; options = [ "defaults" "size=2G" "mode=755" ]; };
            boot.loader.grub.device = "nodev";
            services.maubot.enable = true;
          }
        ];
      };
      nixosConfigurations.test2 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          (import ./module)
          ({ pkgs, ... }: {
            system.stateVersion = "23.05";
            fileSystems."/" = { device = "none"; fsType = "tmpfs"; neededForBoot = false; options = [ "defaults" "size=2G" "mode=755" ]; };
            boot.loader.grub.device = "nodev";
            services.maubot.enable = true;
            services.maubot.plugins = (pkgs.callPackage ./pkg { }).plugins.allOfficialPlugins;
            services.maubot.settings.database = "postgresql://maubot@localhost/maubot";
          })
        ];
      };
      formatter = forEachSystem (pkgs: pkgs.nixpkgs-fmt);
      packages = forEachSystem (pkgs: {
        maubot = pkgs.maubot;
        default = pkgs.maubot;
        maubot-lib = pkgs.python3Packages.maubot;
      });
      devShells = forEachSystem (pkgs: {
        flake =
          let py = pkgs.python3.withPackages (p: with p; [ gitpython requests types-requests ruamel-yaml toml ]);
          in pkgs.mkShell {
            propagatedBuildInputs = [ py ];
            MYPYPATH = "${py}/${py.sitePackages}";
          };
        default =
          let py = pkgs.python3.withPackages (p: [ pkgs.python3Packages.maubot ]);
          in pkgs.mkShell {
            propagatedBuildInputs = [ py ];
            MYPYPATH = "${py}/${py.sitePackages}";
          };
      });
    };
}
