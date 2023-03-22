{ lib
, fetchpatch
, python3
, runCommand
, callPackage
, encryptionSupport ? true
}:

let
  python = python3.override {
    packageOverrides = self: super: {
      sqlalchemy = super.buildPythonPackage rec {
        pname = "SQLAlchemy";
        version = "1.3.24";

        src = super.fetchPypi {
          inherit pname version;
          sha256 = "sha256-67t3fL+TEjWbiXv4G6ANrg9ctp+6KhgmXcwYpvXvdRk=";
        };

        postInstall = ''
          sed -e 's:--max-worker-restart=5::g' -i setup.cfg
        '';

        doCheck = false;
      };
    };
  };

  self = with python.pkgs; buildPythonApplication rec {
    pname = "maubot";
    version = "0.4.1";
    disabled = pythonOlder "3.8";

    src = fetchPypi {
      inherit pname version;
      sha256 = "sha256-Ro2PPgF8818F8JewPZ3AlbfWFNNHKTZkQq+1zpm3kk4=";
    };

    patches = [
      # add entry point
      (fetchpatch {
        url = "https://patch-diff.githubusercontent.com/raw/maubot/maubot/pull/146.patch";
        sha256 = "0yn5357z346qzy5v5g124mgiah1xsi9yyfq42zg028c8paiw8s8x";
      })
      ./allow-building-plugins-from-nix-store.patch
    ];

    propagatedBuildInputs = [
      # requirements.txt
      mautrix
      aiohttp
      yarl
      sqlalchemy
      asyncpg
      aiosqlite
      CommonMark
      ruamel-yaml
      attrs
      bcrypt
      packaging
      click
      colorama
      questionary
      jinja2
    ]
    # optional-requirements.txt
    ++ lib.optionals encryptionSupport [
      python-olm
      pycryptodome
      unpaddedbase64
    ];

    postInstall = ''
      rm $out/example-config.yaml
    '';

    # Setuptools is trying to do python -m maubot test
    dontUseSetuptoolsCheck = true;

    pythonImportsCheck = [
      "maubot"
    ];

    meta = with lib; {
      description = "A plugin-based Matrix bot system written in Python";
      homepage = "https://maubot.xyz/";
      changelog = "https://github.com/maubot/maubot/blob/v${version}/CHANGELOG.md";
      license = licenses.agpl3Plus;
      maintainers = with maintainers; [ chayleaf ];
    };

    passthru =
      let
        wrapper = callPackage ./wrapper.nix {
          unwrapped = self;
          python3 = python;
        };
      in {
        tests = {
          simple = runCommand "${pname}-tests" { } ''
            ${self}/bin/mbc --help > $out
          '';
        };

        plugins = callPackage ./plugins {
          maubot = self;
          python3 = python;
        };

        withPythonPackages = pythonPackages: wrapper { inherit pythonPackages; };

        # This adds the plugins to lib/maubot-plugins
        withPlugins = plugins: wrapper { inherit plugins; };

        withAllPlugins = self.withPlugins (p: p.allPlugins);

        withAllOfficialPlugins = self.withPlugins (p: p.officialPlugins);
      };
  };

in
self
