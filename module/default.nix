{ lib
, config
, pkgs
, ...
}:

let
  cfg = config.services.maubot;
  format = pkgs.formats.yaml { };
  finalPackage =
    if cfg.plugins == [] then cfg.package
    else cfg.package.withPlugins cfg.plugins;
  finalSettings = {
    inherit (cfg.settings) database crypto_database database_opts plugin_databases;
    plugin_directories = cfg.settings.plugin_directories // {
      trash = if cfg.settings.plugin_directories.trash == null then "delete" else cfg.settings.plugin_directories.trash;
    } // (lib.optionalAttrs (builtins.length cfg.plugins != 0) {
      load = [ "${finalPackage}/lib/maubot-plugins" ] ++ cfg.settings.plugin_directories.load;
    });
    server = cfg.settings.server // {
      override_resource_path = if cfg.settings.server.override_resource_path == null then false else cfg.settings.server.override_resource_path;
      unshared_secret = "generate";
    };
  };
  configFile = format.generate "config.yaml" finalSettings;
  pluginsEnv = cfg.package.python.buildEnv.override {
    extraLibs = cfg.plugins;
  };
  isPostgresql = db: builtins.isString db && lib.hasPrefix "postgresql://" db;
  isLocalPostgresDB = db: isPostgresql db && (builtins.any (lib.flip lib.hasInfix db) [
    "@127.0.0.1/"
    "@::1/"
    "@localhost/"
  ]);
  hasLocalPostgresDB =
    isLocalPostgresDB cfg.settings.database
    || isLocalPostgresDB cfg.settings.crypto_database
    || builtins.any (db: isLocalPostgresDB db.postgres) cfg.settings.plugin_databases;
in
{
  imports = [
    (lib.mkRemovedOptionModule [ "services" "maubot" "settings" "server" "unshared_secret" ] "Pass this value via extraConfigFile instead")
  ];
  options = {
    services.maubot = {
      enable = lib.mkEnableOption (lib.mdDoc "maubot");
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.maubot;
        defaultText = lib.literalExpression "pkgs.maubot";
        description = lib.mdDoc ''
          Overridable attribute of the maubot package to use.
        '';
      };
      plugins = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        example = lib.literalExpression ''
          with config.services.maubot.package.plugins; [
            reactbot
            rss
          ];
        '';
        description = lib.mdDoc ''
          List of additional maubot plugins to make available.
        '';
      };
      dataDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/maubot";
        description = lib.mdDoc ''
          The directory where maubot stores its stateful data.
        '';
      };
      settings = lib.mkOption {
        default = { };
        description = lib.mdDoc ''
          The primary synapse configuration. See the
          [example configuration](https://github.com/maubot/maubot/blob/v${cfg.package.version}/maubot/example-config.yaml)
          for possible values.

          Secrets should be passed in by using the `configFilePath` option.
        '';
        type = with lib.types; submodule {
          options = {
            database = mkOption {
              type = types.str;
              default = "sqlite:///maubot.db";
              example = "postgresql://username:password@hostname/dbname";
              description = lib.mdDoc ''
                The full URI to the database. SQLite and Postgres are fully supported.
                Other DBMSes supported by SQLAlchemy may or may not work.
              '';
            };
            crypto_database = mkOption {
              type = types.str;
              default = "default";
              example = "postgresql://username:password@hostname/dbname";
              description = lib.mdDoc ''
                Separate database URL for the crypto database. By default, the regular database is also used for crypto.
              '';
            };
            database_opts = mkOption {
              type = types.attrs;
              default = { };
              description = lib.mdDoc ''
                Additional arguments for asyncpg.create_pool() or sqlite3.connect()
              '';
            };
            plugin_directories = mkOption {
              default = { };
              description = lib.mdDoc ''
                # Configuration for storing plugin .mbp files
              '';
              type = submodule {
                upload = mkOption {
                  type = types.str;
                  default = "./plugins";
                  description = lib.mdDoc ''
                    The directory where uploaded new plugins should be stored.
                  '';
                };
                load = mkOption {
                  type = types.listOf types.str;
                  default = [ "./plugins" ];
                  description = lib.mdDoc ''
                    The directories from which plugins should be loaded. Duplicate plugin IDs will be moved to the trash.
                  '';
                };
                trash = mkOption {
                  type = types.str;
                  default = "./trash";
                  description = lib.mdDoc ''
                    The directory where old plugin versions and conflicting plugins should be moved. Set to null to delete files immediately.
                  '';
                };
              };
            };
            plugin_databases = mkOption {
              type = submodule {
                sqlite = mkOption {
                  type = types.str;
                  default = "./plugins";
                  description = lib.mdDoc ''
                    The directory where SQLite plugin databases should be stored.
                  '';
                };
                postgres = mkOption {
                  type = types.optional types.str;
                  default = if isPostgresql cfg.settings.database then "default" else null;
                  defaultText = literalExpression ''if isPostgresql cfg.settings.database then "default" else null'';
                  description = lib.mdDoc ''
                    The connection URL for plugin database. See [example config](https://github.com/maubot/maubot/blob/master/maubot/example-config.yaml) for exact format.
                  '';
                };
                postgres_max_conns_per_plugin = mkOption {
                  type = types.optional types.int;
                  default = 3;
                  description = lib.mdDoc ''
                    Maximum number of connections per plugin instance.
                  '';
                };
                postgres_opts = mkOption {
                  type = types.attrs;
                  default = { };
                  description = lib.mdDoc ''
                    Overrides for the default database_opts when using a non-default postgres connection URL.
                  '';
                };
              };
            };
            server = mkOption {
              type = submodule {
                hostname = mkOption {
                  type = types.str;
                  description = lib.mdDoc ''
                    The IP to listen on
                  '';
                };
                port = mkOption {
                  type = types.int;
                  description = lib.mdDoc ''
                    The port to listen on
                  '';
                };
                public_url = mkOption {
                  type = types.str;
                  description = lib.mdDoc ''
                    Public base URL where the server is visible.
                  '';
                };
                ui_base_path = mkOption {
                  type = types.str;
                  default = "/_matrix/maubot";
                  description = lib.mdDoc ''
                    The base path for the UI.
                  '';
                };
                plugin_base_path = mkOption {
                  type = types.str;
                  default = "/_matrix/maubot/plugin/";
                  description = lib.mdDoc ''
                    The base path for plugin endpoints. The instance ID will be appended directly.
                  '';
                };
                override_resource_path = mkOption {
                  type = types.optional types.str;
                  default = null;
                  description = lib.mdDoc ''
                    Override path from where to load UI resources.
                  '';
                };
              };
            };
            homeservers = mkOption {
              type = types.attrsOf (types.submodule {
                url = mkOption {
                  type = types.str;
                  description = lib.mdDoc ''
                    Client-server API URL
                  '';
                };
              });
              default = {
                "matrix.org" = {
                  url = "https://matrix-client.matrix.org";
                };
              };
              description = lib.mdDoc ''
                Known homeservers. This is required for the `mbc auth` command and also allows more convenient access from the management UI.
                If you want to specify registration secrets, pass this via extraConfigFile instead.
              '';
            };
            admins = mkOption {
              type = types.attrsOf types.str;
              default = { root = ""; };
              description = lib.mdDoc ''
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
              description = lib.mdDoc ''
                API feature switches.
              '';
            };
            logging = mkOption {
              type = types.attrs;
              description = lib.mdDoc ''
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
  };
  config = {
    assertions = [
      {
        assertion = hasLocalPostgresDB -> config.services.postgresql.enable;
        message = ''
          Cannot deploy maubot with a configuration for a local postgresql database and a missing postgresql service.
        '';
      }
      {
        assertion = builtins.all (x: !(x?secret) || x.secret == null) (builtins.attrValues cfg.homeservers);
        message = ''
          Pass cfg.homeservers secrets via extraConfigFile instead!
        '';
      }
    ];
    users.users.maubot = {
      group = "maubot";
      home = cfg.dataDir;
      createHome = true;
      uid = config.ids.uids.maubot;
    };
    users.groups.maubot = {
      gid = config.ids.gids.maubot;
    };
    systemd.services.maubot = {
      # TODO
    };
  };
}
