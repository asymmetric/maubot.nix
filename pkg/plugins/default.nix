{ lib
, stdenvNoCC
, callPackage
, maubot
, python3
, formats
}:

let
  # pname: plugin id (example: xyz.maubot.echo)
  # version: plugin version
  # other attributes are passed directly to stdenv.mkDerivation (you at least need src)
  buildMaubotPlugin = attrs@{ version, pname, base_config ? null, ... }:
    stdenvNoCC.mkDerivation (builtins.removeAttrs attrs [ "base_config" ] // {
      pluginName = "${pname}-v${version}.mbp";
      nativeBuildInputs = attrs.nativeBuildInputs or [] ++ [ maubot ];
      buildPhase = ''
        runHook preBuild

        mbc build

        runHook postBuild
      '';

      postPatch = lib.optionalString (base_config != null) ''
        [ -e base-config.yaml ] || (echo "base-config.yaml doesn't exist, can't override it" && exit 1)
        cp "${if builtins.isPath base_config || lib.isDerivation base_config then base_config
          else if builtins.isString base_config then builtins.toFile "base-config.yaml" base_config
          else (formats.yaml { }).generate "base-config.yaml" base_config}" base-config.yaml
      '' + attrs.postPatch or "";

      installPhase = ''
        runHook preInstall

        mkdir -p $out/lib/maubot-plugins
        install -m 444 $pluginName $out/lib/maubot-plugins

        runHook postInstall
      '';
    });

  generated = callPackage ./generated.nix {
    inherit python3;
  };

  # args can be a string (specify the description), an attrset (specify meta),
  # or an attrset with meta key (specify meta and other attrs)
  #
  # meta.changelogFile is a special attr to specify path to changelog file in relation to repo root
  generatedPlugin = name: args:
    let
      entry = generated.${name};
      meta =
        if builtins.isString args then {
          description = args;
        }
        else if args?meta then args.meta
        else args;
      extraAttrs = if args?meta then args else { };
    in
    # only make base_config overridable for now
    lib.makeOverridable ({ base_config ? null }: buildMaubotPlugin (builtins.removeAttrs entry [ "genPassthru" ] // extraAttrs // {
      meta = entry.meta // lib.optionalAttrs (meta?changelogFile) {
        changelog = "${entry.genPassthru.repoBase}/${meta.changelogFile}";
      } // (builtins.removeAttrs meta [ "changelogFile" ]);
    })) {};

  generatedPlugins = prefix: builtins.mapAttrs (k: generatedPlugin "${prefix}.${k}");

  plugins = {
    bzh.abolivier = generatedPlugins "bzh.abolivier" {
      autoreply = "Maubot plugin for an auto-reply bot";
    };
    casavant = {
      jeff = generatedPlugins "casavant.jeff" {
        trumptweet = "A plugin for maubot that generates tweets from Trump";
      };
      tom = generatedPlugins "casavant.tom" {
        giphy = "Generates a gif given a search term, a plugin for maubot for Matrix";
        poll = "A plugin for maubot that creates a poll in a riot room and allows users to vote";
        reddit = "A simple maubot that corrects users when they enter a subreddit without including the entire link";
      };
    };
    coffee.maubot = generatedPlugins "coffee.maubot" {
      choose = "Maubot plugin to choose an option randomly";
      urlpreview = "A bot that responds to links with a link preview embed, using Matrix API to fetch meta tag";
    };
    com = {
      arachnitech = generatedPlugins "com.arachnitech" {
        weather = {
          description = "This is a maubot plugin that uses wttr.in to get a simple representation of the weather";
          changelogFile = "CHANGELOG.md";
        };
      };
      dvdgsng.maubot = generatedPlugins "com.dvdgsng.maubot" {
        urban = "A maubot to fetch definitions from Urban Dictionary. Returns a specified or random entry.";
      };
      valentinriess = generatedPlugins "com.valentinriess" {
        hasswebhook = "A maubot to get Homeassistant-notifications in your favorite Matrix room";
        mensa = "A maubot bot for the canteen at Otto-von-Guericke-Universität Magdeburg";
      };
    };
    de = {
      hyteck = generatedPlugins "de.hyteck" {
        alertbot = {
          description = "A bot that receives a webhook and forwards alerts to a Matrix room";
          changelogFile = "CHANGELOG.md";
        };
      };
      yoxcu = generatedPlugins "de.yoxcu" {
        token = "A maubot to manage your synapse user registration tokens";
      };
    };
    lomion = generatedPlugins "lomion" {
      tmdb = {
        description = "A maubot to get information about movies from TheMovieDB.org";
        # changelog on releases page is more complete, so don't use release-note.md
        # changelogFile = "release-note.md";
      };
    };
    me = {
      edwardsdean.maubot = generatedPlugins "me.edwardsdean.maubot" {
        metric = "A maubot plugin that will reply to a message with imperial units with the fixed metric units";
      };
      gogel.maubot = generatedPlugins "me.gogel.maubot" {
        socialmediadownload = "Maubot plugin that downloads content from various social media websites given a link";
        wolframalpha = "Maubot plugin to search on Wolfram Alpha";
        youtubepreview = "Maubot plugin that responds to a YouTube link with the video title and thumbnail";
      };
      jasonrobinson = generatedPlugins "me.jasonrobinson" {
        pocket = {
          description = "A maubot plugin that integrates with Pocket";
          changelogFile = "CHANGELOG.md";
        };
      };
    };
    org = {
      casavant.jeff = generatedPlugins "org.casavant.jeff" {
        twilio = "Maubot plugin to bridge SMS in with Twilio";
      };
      jobmachine = generatedPlugins "org.jobmachine" {
        createspaceroom = "Maubot plugin to create a Matrix room and include it as part of a Matrix space";
        invitebot = "Maubot plugin for generating invite tokens via matrix-registration";
        join = "Maubot plugin to allow specific users to get a bot to join another room";
        kickbot = "Maubot plugin that tracks the last message timestamp of a user across any room that the bot is in, and generates a simple report";
        reddit = "Maubot plugin that fetches a random post (image or link) from a given subreddit)";
        tickerbot = "Maubot plugin to return basic financial data about stocks and cryptocurrencies";
        welcome = "Maubot plugin to send a greeting to people when they join rooms";
      };
    };
    pl.rom4nik.maubot = generatedPlugins "pl.rom4nik.maubot" {
      alternatingcaps = "A simple maubot plugin that repeats previous message in room using aLtErNaTiNg cApS";
    };
    xyz.maubot = generatedPlugins "xyz.maubot" {
      altalias = "A maubot that lets users publish alternate aliases in rooms";
      commitstrip = "A maubot plugin to view CommitStrips";
      dice = "A maubot plugin that rolls dice";
      echo = "A simple maubot plugin that echoes pings and other stuff";
      exec = "A maubot plugin to execute code";
      factorial = "A maubot plugin that calculates factorials";
      github = "A GitHub client and webhook receiver for maubot";
      gitlab = "A GitLab client and webhook receiver for maubot";
      karma = "A maubot plugin to track the karma of users";
      manhole = "A maubot plugin that provides a Python shell to access the internals of maubot";
      media = "A maubot plugin that posts MXC URIs of uploaded images";
      reactbot = "A maubot plugin that responds to messages that match predefined rules";
      reminder = "A maubot plugin to remind you about things";
      rss = "A RSS plugin for maubot";
      satwcomic = "A maubot plugin to view SatWComics";
      sed = "A maubot plugin to do sed-like replacements";
      songwhip = "A maubot plugin to post Songwhip links";
      supportportal = "A maubot plugin to manage customer support on Matrix";
      tex = "A maubot plugin to render LaTeX as SVG";
      translate = "A maubot plugin to translate words";
      xkcd = "A maubot plugin to view xkcd comics";

      # unofficial plugins using the same namespace...
      pingcheck = "Maubot plugin to track ping times against echo bot for Icinga passive checks";
      redactbot = "A maubot that responds to files being posted and redacts/warns all but a set of whitelisted mime types";
    };
  };

  allDerivations = attrs: builtins.concatLists
    (lib.mapAttrsToList
      (k: v: if lib.isDerivation v then [ v ] else allDerivations v)
      attrs);

  recursiveRecurse = builtins.mapAttrs
    (k: v: if lib.isDerivation v then v else lib.recurseIntoAttrs (recursiveRecurse v));

in
recursiveRecurse plugins // {
  inherit buildMaubotPlugin;

  allOfficialPlugins =
    builtins.filter
      (x: with plugins.xyz.maubot; x != pingcheck && x != redactbot)
      (builtins.attrValues plugins.xyz.maubot);

  allPlugins = allDerivations plugins;
}
