{ lib
, fetchgit
, fetchFromGitHub
, fetchFromGitLab
, fetchFromGitea
, python3
, poetry
}:

let
  # generated.json is a list of
  # manifest: parsed maubot.yaml
  # github/gitlab/gitea: what to pass to fetchFrom...
  # attrs: what is passed to buildMaubotPlugin
  # attrs.genPassthru: internal attrs for precisely configuring the derivation
  # ...genPassthru.isPoetry: use a custom poetry-based builder if true
  # ...genPassthru.repoBase: a base url to link to files from the repo for humans to see

  json = builtins.fromJSON (builtins.readFile ./generated.json);
in
builtins.listToAttrs (map
  (entry:
  let
    manifest = entry.manifest;
    dependencies =
      (lib.optionals (manifest?dependencies) manifest.dependencies)
      ++ (lib.optionals (manifest?soft_dependencies) manifest.soft_dependencies);
    propagatedBuildInputs = map
      (name:
        let
          inherit (builtins) hasAttr getAttr;
          packageName = builtins.elemAt (builtins.match "([^~=<>]*).*" name) 0;
          lower = lib.toLower packageName;
        in
        if hasAttr packageName python3.pkgs then getAttr packageName python3.pkgs
        else if hasAttr lower python3.pkgs then getAttr lower python3.pkgs
        else throw "Dependency ${packageName} not found!"
      )
      dependencies;
  in
  {
    name = manifest.id;
    value = entry.attrs // {
      inherit propagatedBuildInputs;
      pname = manifest.id;
      inherit (manifest) version;
      meta = {
        license =
          let
            spdx = manifest.license or "unfree";
            licenses = with lib.licenses; {
              inherit unfree;
              "AGPL 3.0" = agpl3Only;
            };
            spdxLicenses = builtins.listToAttrs (map (x: lib.nameValuePair x.spdxId x) (builtins.filter (x: x?spdxId) (builtins.attrValues lib.licenses)));
          in licenses.${spdx} or spdxLicenses.${spdx};
      }
      // (if entry?github then {
        homepage = "https://github.com/${entry.github.owner}/${entry.github.repo}";
      } // (lib.optionalAttrs (lib.hasInfix "." entry.github.rev) rec {
        # include /releases page in metadata if this is a version tag
        downloadPage = "https://github.com/${entry.github.owner}/${entry.github.repo}/releases";
        # default changelog link to releases page (can be overridden in default.nix)
        changelog = downloadPage;
      }) else if entry?gitlab then {
        homepage =
          let domain = if entry.gitlab?domain then entry.gitlab.domain else "gitlab.com";
          in "https://${domain}/${entry.gitlab.owner}/${entry.gitlab.repo}";
      } else if entry?gitea then {
        homepage = "https://${entry.gitea.domain}/${entry.gitea.owner}/${entry.gitea.repo}";
      } // (lib.optionalAttrs (lib.hasInfix "." entry.gitea.rev) rec {
        downloadPage = "https://${entry.gitea.domain}/${entry.gitea.owner}/${entry.gitea.repo}/releases";
        changelog = downloadPage;
      }) else { });
      src =
        if entry?github then fetchFromGitHub entry.github
        else if entry?git then fetchgit entry.git
        else if entry?gitlab then fetchFromGitLab entry.gitlab
        else if entry?gitea then fetchFromGitea entry.gitea
        else throw "Invalid generated entry for ${manifest.id}: missing source";
    }
    // lib.optionalAttrs (entry.attrs.genPassthru.isPoetry or false) {
      nativeBuildInputs = [
        poetry
        (python3.withPackages (p: with p; [ toml ruamel-yaml isort ]))
      ];
      preBuild = (if entry?attrs.preBuild then entry.attrs.preBuild + "\n" else "") + ''
        export HOME=$(mktemp -d)
        [[ ! -d scripts ]] || patchShebangs --host scripts
        make maubot.yaml
      '';
    };
  })
  json)
