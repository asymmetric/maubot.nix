{ lib
, stdenvNoCC
, symlinkJoin
, makeWrapper
, unwrapped
}:

pythonPackages:

stdenvNoCC.mkDerivation {
  name = "${unwrapped.pname}-with-plugins-${unwrapped.version}";
  pythonPath = pythonPackages ++ [ unwrapped ];
  inherit unwrapped;
  nativeBuildInputs = [ unwrapped.python.pkgs.wrapPython makeWrapper ];
  phases = [ "installPhase" ];

  passthru = {
    inherit unwrapped;
  };

  installPhase = ''
    mkdir -p "$out/bin"
    # not so unwrapped huh...
    cp $unwrapped/bin/.mbc-wrapped $out/bin/mbc
    cp $unwrapped/bin/.maubot-wrapped $out/bin/maubot
    wrapPythonProgramsIn "$out/bin" "$out $pythonPath"
  '';
}
