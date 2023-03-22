{ lib
, fetchFromGitHub
, python3
}:

let
  json = builtins.fromJSON (builtins.readFile ./generated.json);
in
  builtins.listToAttrs (map (entry:
  let
    manifest = entry.manifest;
    dependencies =
      (lib.optionals (manifest?dependencies) manifest.dependencies)
      ++ (lib.optionals (manifest?soft_dependencies) manifest.soft_dependencies);
    propagatedBuildInputs = map (name:
      let
        inherit (builtins) hasAttr getAttr;
        packageName = builtins.elemAt (builtins.match "([^=<>]*).*" name) 0;
        lower = lib.toLower packageName;
      in
        if hasAttr packageName python3.pkgs then getAttr packageName python3.pkgs
        else if hasAttr lower python3.pkgs then getAttr lower python3.pkgs
        else throw "Dependency ${packageName} not found!"
    ) dependencies;
  in
  {
    name = manifest.id;
    value = lib.optionalAttrs (entry?attrs) entry.attrs // {
      inherit propagatedBuildInputs;
      pname = manifest.id;
      inherit (manifest) version;
      meta = {
        license =
          let
            spdx = manifest.license;
          in with lib.licenses;
            if spdx == "AGPL-3.0-or-later" then agpl3Plus
            else if spdx == "MIT" then mit
            else throw "Unknown license ID: ${spdx}";
      } // (lib.optionalAttrs (entry?github) {
        homepage = "https://github.com/${entry.github.owner}/${entry.github.repo}";
      });
      src =
        if entry?github then fetchFromGitHub entry.github
        else throw "Invalid generated entry for ${manifest.id}: missing source";
    };
  }) json)
