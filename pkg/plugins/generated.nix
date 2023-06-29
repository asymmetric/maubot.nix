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
  propagatedBuildInputs = map
    (name:
      let
        packageName = builtins.elemAt (builtins.match "([^~=<>]*).*" name) 0;
        lower = lib.toLower packageName;
      in
        python3.pkgs.${packageName} or python3.pkgs.${lower} or (throw "Dependency ${packageName} not found!"))
    dependencies;
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
    [[ ! -d scripts ]] || patchShebangs --host scripts
    make maubot.yaml
  '';
}))
