{ lib
, symlinkJoin
, unwrapped
, python3
}:

let
  wrapper = { pythonPackages ? (_: []), plugins ? (_: []) }:
    let
      plugins' = plugins unwrapped.plugins;
      extraPythonPackages = builtins.concatLists (map (p: lib.optionals (p?propagatedBuildInputs) p.propagatedBuildInputs) plugins');
    in
      symlinkJoin {
        name = "${unwrapped.pname}-with-plugins-${unwrapped.version}";

        inherit unwrapped;
        paths = [ unwrapped ] ++ plugins';
        pythonPath = extraPythonPackages ++ pythonPackages python3.pkgs;

        nativeBuildInputs = [ python3.pkgs.wrapPython ];

        postBuild = ''
          rm $out/bin/* $out/bin/.*
          cp $unwrapped/bin/.mbc-wrapped $out/bin/mbc
          cp $unwrapped/bin/.maubot-wrapped $out/bin/maubot
          wrapPythonPrograms
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
