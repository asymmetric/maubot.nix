# maubot.nix

Instruction:

1. Install the NixOS module. For flake users, add this flake's
   `nixosModules.default` output to your system. For everyone else, use
   something like this:

   ```nix
   imports = [
     (import (builtins.fetchGit {
         url = "https://github.com/chayleaf/maubot.nix";
         rev = "commit hash"; # this line is optional, but recommended
     })).nixosModules.default
   ];
   ```
2. Set `services.maubot.enable` to `true`.
3. If you want to use PostgreSQL instead of SQLite, do this:

   ```nix
   services.maubot.settings.database = "postgresql://maubot@localhost/maubot";
   ```

   Or, if you have a user with a password set up already, do the above,
   but also add `database: postgresql://user:password@localhost/maubot`
   to `/var/lib/maubot/config.yaml`.
4. If you plan to expose your Maubot interface to the web, do something
   like this:
   ```nix
   services.nginx.virtualHosts."matrix.example.org".locations = {
     "/_matrix/maubot/" = {
       proxyPass = "http://127.0.0.1:${toString config.services.maubot.settings.server.port}";
       proxyWebsockets = true;
     };
   };
   services.maubot.settings.server.public_url = "matrix.example.org";
   # do the following only if you want to use something other than /_matrix/maubot...
   services.maubot.settings.server.ui_base_path = "/another/base/path";
   ```
5. Optionally, set `services.maubot.pythonPackages` to a list of python3
   packages to make available for Maubot plugins.
6. Optionally, set `services.maubot.plugins` to a list of Maubot
   plugins:
   ```nix
   services.maubot.plugins = with config.services.maubot.package.plugins; [
     xyz.maubot.reactbot
     # This will only change the default config! After you create a
     # plugin instance, the default config will be copied into that
     # instance's config in Maubot database, and base config changes
     # won't be reflected
     (xyz.maubot.rss.override {
       base_config = {
         update_interval = 60;
         max_backoff = 7200;
         spam_sleep = 2;
         command_prefix = "rss";
         admins = [ "@chayleaf:pavluk.org" ];
       };
     })
   ];
   # ...or...
   services.maubot.plugins = config.services.maubot.package.plugins.allOfficialPlugins;
   # ...or...
   services.maubot.plugins = with config.services.maubot.package.plugins; [
     (com.arachnitech.weather.override {
       # you can pass base_config as a string
       base_config = ''
         default_location: New York
         default_units: M
         default_language:
         show_link: true
         show_image: false
       '';
     })
   ] ++ allOfficialPlugins;
   ```
7. Start Maubot at least once before doing the following steps.
8. To create a user account for logging into Maubot web UI and
   configuring it, generate a password using the shell command
   `mkpasswd -R 12 -m bcrypt`, and edit `/var/lib/maubot/config.yaml`
   with the following:

   ```yaml
   admins:
       admin_username: $2b$12$g.oIStUeUCvI58ebYoVMtO/vb9QZJo81PsmVOomHiNCFbh0dJpZVa
   ```

   Where `admin_username` is your username, and `$2b...` is the bcrypted
   password.
9. Optional: if you want to be able to register new users with the
   Maubot CLI (`mbc`), and your homeserver is private, add you
   homeserver's registration key to `/var/lib/maubot/config.yaml`:

   ```yaml
   homeservers:
       matrix.example.org:
           url: https://matrix.example.org
           secret: your-very-secret-key
   ```
10. You're done! Open https://matrix.example.org/_matrix/maubot, log in
    and start using Maubot! If you want to use `mbc` CLI, use this
    flake's output `packages.${builtins.currentSystem}.maubot`. If you
    want to develop Maubot plugins and need the `maubot` Python module
    for IDE support, use
    `packages.${builtins.currentSystem}.maubot-lib` or run
    `nix develop` in this flake's root. You can also use this flake's
    output `overlays.default`, in that case you should use
    `python3Packages.maubot` instead of `maubot-lib`.
