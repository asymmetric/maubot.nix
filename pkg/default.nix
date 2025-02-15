{ lib
, fetchpatch
, python3
, runCommand
, callPackage
, encryptionSupport ? true
}:

let
  python = python3.override {
    packageOverrides = final: prev: {
      aiosqlite = prev.aiosqlite.overridePythonAttrs (old: rec {
        version = "0.18.0";
        src = old.src.override {
          rev = "refs/tags/v${version}";
          hash = "sha256-yPGSKqjOz1EY5/V0oKz2EiZ90q2O4TINoXdxHuB7Gqk=";
        };
        # FAILED aiosqlite/tests/smoke.py::SmokeTest::test_multiple_connections - sqlite3.OperationalError: database is locked
        # and this only happens when built on my server (perhaps because it runs slower there)
        # either way, disable this
        # This will be in the binary cache when upstreamed so this shouldn't make it into nixpkgs
        doCheck = false;
      });
      # <0.20
      mautrix = prev.mautrix.overridePythonAttrs (old: rec {
        version = "0.19.16";
        disabled = prev.pythonOlder "3.8";
        checkInputs = old.checkInputs ++ [ final.sqlalchemy ];
        SQLALCHEMY_SILENCE_UBER_WARNING = true;
        src = old.src.override {
          rev = "refs/tags/v${version}";
          hash = "sha256-aZlc4+J5Q+N9qEzGUMhsYguPdUy+E5I06wrjVyqvVDk=";
        };
      });
      # runtime error with new ruamel-yaml
      ruamel-yaml = prev.ruamel-yaml.overridePythonAttrs (prev: rec {
        version = "0.17.21";
        src = prev.src.override {
          version = version;
          hash = "sha256-i3zml6LyEnUqNcGsQURx3BbEJMlXO+SSa1b/P10jt68=";
        };
      });
      sqlalchemy = final.buildPythonPackage rec {
        pname = "SQLAlchemy";
        version = "1.3.24";

        src = final.fetchPypi {
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

  self = with python.pkgs; buildPythonPackage rec {
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
      in
      {
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
