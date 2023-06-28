{ lib
, config
, pkgs
, ...
}:

let
  cfg = config.services.maubot;
  format = pkgs.formats.yaml { };
  preFinalPackage =
    if cfg.plugins == []
    then cfg.package
    else cfg.package.withPlugins (_: cfg.plugins);
  finalPackage =
    if cfg.pythonPackages == []
    then preFinalPackage
    else preFinalPackage.withPythonPackages (_: cfg.pythonPackages);
  finalSettings = cfg.settings // {
    plugin_directories = cfg.settings.plugin_directories // {
      trash =
        if cfg.settings.plugin_directories.trash == null
        then "delete"
        else cfg.settings.plugin_directories.trash;
      load = [ "${finalPackage}/lib/maubot-plugins" ] ++ cfg.settings.plugin_directories.load;
    };
    server = cfg.settings.server // {
      override_resource_path =
        if builtins.isNull cfg.settings.server.override_resource_path
        then false
        else cfg.settings.server.override_resource_path;
      unshared_secret = "generate";
    };
  };
  configFile = format.generate "config.yaml" finalSettings;
  isPostgresql = db: builtins.isString db && lib.hasPrefix "postgresql://" db;
  isLocalPostgresDB = db: isPostgresql db && (builtins.any (x: lib.hasInfix x db) [
    "@127.0.0.1/"
    "@::1/"
    "@localhost/"
  ]);
  parseLocalPostgresDB = db:
    let
      noSchema = lib.removePrefix "postgresql://" db;
      username = builtins.head (lib.splitString "@" noSchema);
      database = lib.last (lib.splitString "/" noSchema);
    in
      if lib.hasInfix ":" username then null else {
        inherit database username;
      };

  localPostgresDBs = builtins.filter isLocalPostgresDB [
    cfg.settings.database
    cfg.settings.crypto_database
    cfg.settings.plugin_databases.postgres
  ];

  parsedLocalPostgresDBs = builtins.filter (x: x != null) (map parseLocalPostgresDB localPostgresDBs);

  hasLocalPostgresDB = localPostgresDBs != [ ];
in
{
  imports = [
    # (lib.mkRemovedOptionModule [ "server" "unshared_secret" ] "Pass this value via extraConfigFile instead")
  ];
  options.services.maubot = with lib; {
    enable = mkEnableOption (mdDoc "maubot");
    package = mkOption {
      type = types.package;
      default = pkgs.pythonPackages.toPythonApplication (pkgs.callPackage ../pkg { });
      defaultText = literalExpression "pkgs.maubot";
      description = mdDoc ''
        The maubot package to use.
      '';
    };
    plugins = mkOption {
      type = types.listOf types.package;
      default = [ ];
      example = literalExpression ''
        with config.services.maubot.package.plugins; [
          xyz.maubot.reactbot
          xyz.maubot.rss
        ];
      '';
      description = mdDoc ''
        List of additional maubot plugins to make available.
      '';
    };
    pythonPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      example = literalExpression ''
        with pkgs.python3Packages; [
          aiohttp
        ];
      '';
      description = mdDoc ''
        List of additional Python packages to make available for maubot.
      '';
    };
    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/maubot";
      description = mdDoc ''
        The directory where maubot stores its stateful data.
      '';
    };
    extraConfigFile = mkOption {
      type = types.str;
      default = "./config.yaml";
      defaultText = literalExpression ''"''${config.services.maubot.dataDir}/config.yaml"'';
      description = mdDoc ''
        A file for storing secrets. You can pass homeserver registration keys here.
        If it already exists, **it must contain `server.unshared_secret`** which is used for signing API keys.
        If `extraConfigFileWritable` is not set to true, **maubot user must have write access to this file**.
      '';
    };
    extraConfigFileWritable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''
        Whether maubot should write updated config into `extraConfigFile`. **This will make your Nix module settings have no effect, as extraConfigFile takes precedence over NixOS settings!** It is recommended to keep this off, or enable this for a short time only. Make sure to remove extra config from your file after settings.
      '';
    };
    settings = mkOption {
      default = { };
      description = mdDoc ''
        YAML settings for maubot. See the
        [example configuration](https://github.com/maubot/maubot/blob/v${cfg.package.version}/maubot/example-config.yaml)
        for more info.

        Secrets should be passed in by using `extraConfigFile`.
      '';
      type = with types; submodule {
        options = {
          database = mkOption {
            type = str;
            default = "sqlite:///maubot.db";
            example = "postgresql://username:password@hostname/dbname";
            description = mdDoc ''
              The full URI to the database. SQLite and Postgres are fully supported.
              Other DBMSes supported by SQLAlchemy may or may not work.
            '';
          };
          crypto_database = mkOption {
            type = str;
            default = "default";
            example = "postgresql://username:password@hostname/dbname";
            description = mdDoc ''
              Separate database URL for the crypto database. By default, the regular database is also used for crypto.
            '';
          };
          database_opts = mkOption {
            type = types.attrs;
            default = { };
            description = mdDoc ''
              Additional arguments for asyncpg.create_pool() or sqlite3.connect()
            '';
          };
          plugin_directories = mkOption {
            default = { };
            type = submodule {
              options = {
                upload = mkOption {
                  type = types.str;
                  default = "./plugins";
                  defaultText = literalExpression ''"''${config.services.maubot.dataDir}/plugins"'';
                  description = mdDoc ''
                    The directory where uploaded new plugins should be stored.
                  '';
                };
                load = mkOption {
                  type = types.listOf types.str;
                  default = [ "./plugins" ];
                  defaultText = literalExpression ''[ "''${config.services.maubot.dataDir}/plugins" ]'';
                  description = mdDoc ''
                    The directories from which plugins should be loaded. Duplicate plugin IDs will be moved to the trash.
                  '';
                };
                trash = mkOption {
                  type = types.str;
                  default = "./trash";
                  defaultText = literalExpression ''"''${config.services.maubot.dataDir}/trash"'';
                  description = mdDoc ''
                    The directory where old plugin versions and conflicting plugins should be moved. Set to null to delete files immediately.
                  '';
                };
              };
            };
          };
          plugin_databases = mkOption {
            default = { };
            type = submodule {
              options = {
                sqlite = mkOption {
                  type = types.str;
                  default = "./plugins";
                  defaultText = literalExpression ''"''${config.services.maubot.dataDir}/plugins"'';
                  description = mdDoc ''
                    The directory where SQLite plugin databases should be stored.
                  '';
                };
                postgres = mkOption {
                  type = types.nullOr types.str;
                  default = if isPostgresql cfg.settings.database then "default" else null;
                  defaultText = literalExpression ''if isPostgresql config.services.maubot.settings.database then "default" else null'';
                  description = mdDoc ''
                    The connection URL for plugin database. See [example config](https://github.com/maubot/maubot/blob/master/maubot/example-config.yaml) for exact format.
                  '';
                };
                postgres_max_conns_per_plugin = mkOption {
                  type = types.nullOr types.int;
                  default = 3;
                  description = mdDoc ''
                    Maximum number of connections per plugin instance.
                  '';
                };
                postgres_opts = mkOption {
                  type = types.attrs;
                  default = { };
                  description = mdDoc ''
                    Overrides for the default database_opts when using a non-default postgres connection URL.
                  '';
                };
              };
            };
          };
          server = mkOption {
            default =  { };
            type = submodule {
              options = {
                hostname = mkOption {
                  type = types.str;
                  default = "127.0.0.1";
                  description = mdDoc ''
                    The IP to listen on
                  '';
                };
                port = mkOption {
                  type = types.int;
                  default = 29316;
                  description = mdDoc ''
                    The port to listen on
                  '';
                };
                public_url = mkOption {
                  type = types.str;
                  default = "http://localhost:${toString cfg.settings.server.port}";
                  defaultText = literalExpression ''"http://localhost:${config.services.maubot.settings.server.port}"'';
                  description = mdDoc ''
                    Public base URL where the server is visible.
                  '';
                };
                ui_base_path = mkOption {
                  type = types.str;
                  default = "/_matrix/maubot";
                  description = mdDoc ''
                    The base path for the UI.
                  '';
                };
                plugin_base_path = mkOption {
                  type = types.str;
                  default = "${config.services.maubot.settings.server.ui_base_path}/plugin/";
                  defaultText = literalExpression ''
                    "''${config.services.maubot.settings.server.ui_base_path}/plugin/"
                  '';
                  description = mdDoc ''
                    The base path for plugin endpoints. The instance ID will be appended directly.
                  '';
                };
                override_resource_path = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = mdDoc ''
                    Override path from where to load UI resources.
                  '';
                };
              };
            };
          };
          homeservers = mkOption {
            type = types.attrsOf (types.submodule {
              options = {
                url = mkOption {
                  type = types.str;
                  description = mdDoc ''
                    Client-server API URL
                  '';
                };
              };
            });
            default = {
              "matrix.org" = {
                url = "https://matrix-client.matrix.org";
              };
            };
            description = mdDoc ''
              Known homeservers. This is required for the `mbc auth` command and also allows more convenient access from the management UI.
              If you want to specify registration secrets, pass this via extraConfigFile instead.
            '';
          };
          admins = mkOption {
            type = types.attrsOf types.str;
            default = { root = ""; };
            description = mdDoc ''
              List of administrator users. Plaintext passwords will be bcrypted on startup. Set empty password
              to prevent normal login. Root is a special user that can't have a password and will always exist.
            '';
          };
          api_features = mkOption {
            type = types.attrsOf bool;
            default = {
              login = true;
              plugin = true;
              plugin_upload = true;
              instance = true;
              instance_database = true;
              client = true;
              client_proxy = true;
              client_auth = true;
              dev_open = true;
              log = true;
            };
            description = mdDoc ''
              API feature switches.
            '';
          };
          logging = mkOption {
            type = types.attrs;
            description = mdDoc ''
              Python logging configuration. See [section 16.7.2 of the Python
              documentation](https://docs.python.org/3.6/library/logging.config.html#configuration-dictionary-schema)
              for more info.
            '';
            default = {
              version = 1;
              formatters = {
                colored = {
                  "()" = "maubot.lib.color_log.ColorFormatter";
                  format = "[%(asctime)s] [%(levelname)s@%(name)s] %(message)s";
                };
                normal = {
                  format = "[%(asctime)s] [%(levelname)s@%(name)s] %(message)s";
                };
              };
              handlers = {
                file = {
                  class = "logging.handlers.RotatingFileHandler";
                  formatter = "normal";
                  filename = "./maubot.log";
                  maxBytes = 10485760;
                  backupCount = 10;
                };
                console = {
                  class = "logging.StreamHandler";
                  formatter = "colored";
                };
              };
              loggers = {
                maubot = {
                  level = "DEBUG";
                };
                mau = {
                  level = "DEBUG";
                };
                aiohttp = {
                  level = "INFO";
                };
              };
              root = {
                level = "DEBUG";
                handlers = ["file" "console"];
              };
            };
          };
        };
      };
    };
  };
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = hasLocalPostgresDB -> config.services.postgresql.enable;
        message = ''
          Cannot deploy maubot with a configuration for a local postgresql database and a missing postgresql service.
        '';
      }
    ];
    services.postgresql = lib.mkIf hasLocalPostgresDB {
      enable = true;
      ensureDatabases = map (x: x.database) parsedLocalPostgresDBs;
      ensureUsers = map ({ username, database }: {
        name = username;
        ensurePermissions."DATABASE \"${database}\"" = "ALL PRIVILEGES";
      }) parsedLocalPostgresDBs;
    };
    users.users.maubot = {
      group = "maubot";
      home = cfg.dataDir;
      createHome = true;
      isSystemUser = true;
      # uid = 350; # config.ids.uids.maubot;
    };
    users.groups.maubot = {
      # gid = 350; # config.ids.gids.maubot;
    };
    system.userActivationScripts.maubotInit = {
      text = ''
        if [[ "$(whoami)" == maubot ]]; then
          pushd ~
          if [ ! -f "${cfg.extraConfigFile}" ]; then
            echo "server:" > "${cfg.extraConfigFile}"
            echo "    unshared_secret: $(head -c40 /dev/random | base32 | awk '{print tolower($0)}')" > "${cfg.extraConfigFile}"
          fi
          popd
        fi
      '';
    };
    systemd.services.maubot = {
      description = "maubot - a plugin-based Matrix bot system written in Python";
      after = [ "network.target" ] ++ lib.optional hasLocalPostgresDB "postgresql.service";
      # reasoning: all plugins get disabled if maubot starts before synapse
      requires = lib.optional config.services.matrix-synapse.enable "matrix-synapse.service";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        User = "maubot";
        Group = "maubot";
        WorkingDirectory = cfg.dataDir;
      };
      script = "${finalPackage}/bin/maubot --base-config ${configFile} --config ${cfg.extraConfigFile}" + lib.optionalString (!cfg.extraConfigFileWritable) " --no-update";
    };
    # TODO touch extraConfigFile?
  };
}
