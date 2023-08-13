{ lib
, fetchgit
, fetchFromGitHub
, fetchFromGitLab
, fetchFromGitea
, python3
, poetry
, buildMaubotPlugin
}:

let
  json = builtins.fromJSON (builtins.readFile ./generated.json);
in
lib.flip builtins.mapAttrs json (name: entry:
let
  inherit (entry) manifest;
  dependencies =
    (if manifest.dependencies or null == null then [ ] else builtins.filter (x: x != null) manifest.dependencies)
    ++ (if manifest.soft_dependencies or null == null then [ ] else builtins.filter (x: x != null) manifest.soft_dependencies);
  propagatedBuildInputs = builtins.filter (x: x != null) (map
    (name:
      let
        packageName = builtins.elemAt (builtins.match "([^~=<>]*).*" name) 0;
        lower = lib.toLower packageName;
        extraPackages = builtins.mapAttrs (_: file: python3.pkgs.callPackage file { }) {
          whispercpp = ./whispercpp.nix;
        };
        ignorePackages = {
          # too annoying to build as they vendor a lot of stuff, and it's optional for the local-stt plugin
          vosk = null;
          # not actually needed since it's always installed for maubot plugins
          maubot = null;
        };
      in
        ignorePackages.${packageName} or python3.pkgs.${packageName} or python3.pkgs.${lower} or extraPackages.${packageName} or (throw "Dependency ${packageName} not found!"))
    dependencies);
in
buildMaubotPlugin (entry.attrs // {
  inherit propagatedBuildInputs;
  pname = manifest.id;
  inherit (manifest) version;
  src =
    if entry?github then fetchFromGitHub entry.github
    else if entry?git then fetchgit entry.git
    else if entry?gitlab then fetchFromGitLab entry.gitlab
    else if entry?gitea then fetchFromGitea entry.gitea
    else throw "Invalid generated entry for ${manifest.id}: missing source";
  meta = entry.attrs.meta // {
    license =
      let
        spdx = entry.attrs.meta.license or manifest.license or "unfree";
        spdxLicenses = builtins.listToAttrs
          (map (x: lib.nameValuePair x.spdxId x) (builtins.filter (x: x?spdxId) (builtins.attrValues lib.licenses)));
      in
      spdxLicenses.${spdx};
  };
  passthru.isOfficial = entry.isOfficial or false;
} // lib.optionalAttrs (entry.isPoetry or false) {
  nativeBuildInputs = [
    poetry
    (python3.withPackages (p: with p; [ toml ruamel-yaml isort ]))
  ];
  preBuild = (if entry?attrs.preBuild then entry.attrs.preBuild + "\n" else "") + ''
    export HOME=$(mktemp -d)
    [[ ! -d scripts ]] || patchShebangs --build scripts
    make maubot.yaml
  '';
}))
