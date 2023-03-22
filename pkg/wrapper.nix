{ lib
, symlinkJoin
, unwrapped
, python3
}:

let
  wrapper = { pythonPackages ? (_: [ ]), plugins ? (_: [ ]) }:
    let
      plugins' = plugins unwrapped.plugins;
      extraPythonPackages = builtins.concatLists (map (p: lib.optionals (p?propagatedBuildInputs) p.propagatedBuildInputs) plugins');
    in
    symlinkJoin {
      name = "${unwrapped.pname}-with-plugins-${unwrapped.version}";

      inherit unwrapped;
      paths = plugins';
      pythonPath = [ unwrapped ] ++ pythonPackages python3.pkgs ++ extraPythonPackages;

      nativeBuildInputs = [ python3.pkgs.wrapPython ];

      postBuild = ''
        mkdir -p $out/bin
        rm -f $out/nix-support/propagated-build-inputs
        rmdir $out/nix-support || true
        cp $unwrapped/bin/.mbc-wrapped $out/bin/mbc
        cp $unwrapped/bin/.maubot-wrapped $out/bin/maubot
        wrapPythonProgramsIn "$out/bin" "$pythonPath"
      '';

      passthru = {
        inherit unwrapped;
        withPythonPackages = filter: wrapper {
          pythonPackages = pkgs: pythonPackages pkgs ++ filter pkgs;
          inherit plugins;
        };
        withPlugins = filter: wrapper {
          plugins = pkgs: plugins pkgs ++ filter pkgs;
          inherit pythonPackages;
        };
      };
    };
in
wrapper
