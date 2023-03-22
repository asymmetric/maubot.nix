{ lib
, callPackage
, stdenvNoCC
, symlinkJoin
, makeWrapper
, unwrapped
}:

let
  wrapper = { pythonPackages ? [], plugins ? [] }:
    let
      extraPythonPackages = builtins.concatLists (map (p: if  p?propagatedBuildInputs then p.propagatedBuildInputs else []) plugins);
    in
      symlinkJoin {
        name = "${unwrapped.pname}-with-plugins-${unwrapped.version}";

        inherit unwrapped;
        paths = [ unwrapped ] ++ plugins;
        pythonPath = extraPythonPackages ++ pythonPackages;

        nativeBuildInputs = [ unwrapped.python.pkgs.wrapPython ];

        postBuild = ''
          rm $out/bin/* $out/bin/.*
          cp $unwrapped/bin/.mbc-wrapped $out/bin/mbc
          cp $unwrapped/bin/.maubot-wrapped $out/bin/maubot
          wrapPythonPrograms
        '';

        passthru = {
          inherit unwrapped;
          withPythonPackages = filter: wrapper {
            pythonPackages = filter unwrapped.python.pkgs ++ pythonPackages;
            inherit plugins;
          };
          withPlugins = filter: wrapper {
            plugins = filter unwrapped.plugins ++ plugins;
            inherit pythonPackages;
          };
        };
      };
in
  wrapper
