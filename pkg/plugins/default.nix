{ lib
, stdenvNoCC
, callPackage
, fetchFromGitHub
, maubot
, python3
}:

let
  buildMaubotPlugin = attrs@{ version, pname, ... }: stdenvNoCC.mkDerivation ({
    pluginName = "${pname}-v${version}.mbp";
    nativeBuildInputs = [ maubot ];
    buildPhase = ''
      runHook preBuild

      mbc build

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/maubot-plugins
      install -m 444 $pluginName $out/lib/maubot-plugins

      runHook postInstall
    '';
  } // attrs);

  generated = callPackage ./generated.nix {
    inherit python3;
  };

  generatedPlugin = name: meta:
    let
      entry = generated.${name};
    in buildMaubotPlugin (entry // {
      meta = entry.meta // meta;
    });

  self = {
    sed = generatedPlugin "xyz.maubot.sed" {
      description = "A maubot plugin to do sed-like replacements";
    };
    factorial = generatedPlugin "xyz.maubot.factorial" {
      description = "A maubot plugin that calculates factorials";
    };
    media = generatedPlugin "xyz.maubot.media" {
      description = "A maubot plugin that posts MXC URIs of uploaded images";
    };
    dice = generatedPlugin "xyz.maubot.media" {
      description = "A maubot plugin that rolls dice";
    };
    karma = generatedPlugin "xyz.maubot.karma" {
      description = "A maubot plugin to track the karma of users";
    };
    xkcd = generatedPlugin "xyz.maubot.xkcd" {
      description = "A maubot plugin to view xkcd comics";
    };
    echo = generatedPlugin "xyz.maubot.echo" {
      description = "A simple maubot plugin that echoes pings and other stuff";
    };
    rss = generatedPlugin "xyz.maubot.rss" {
      description = "A RSS plugin for maubot";
    };
    reminder = generatedPlugin "xyz.maubot.reminder" {
      description = "A maubot plugin to remind you about things";
    };
    translate = generatedPlugin "xyz.maubot.translate" {
      description = "A maubot plugin to translate words";
    };
    reactbot = generatedPlugin "xyz.maubot.reactbot" {
      description = "A maubot plugin that responds to messages that match predefined rules";
    };
    exec = generatedPlugin "xyz.maubot.exec" {
      description = "A maubot plugin to execute code";
    };
    commitstrip = generatedPlugin "xyz.maubot.commitstrip" {
      description = "A maubot plugin to view CommitStrips";
    };
    supportportal = generatedPlugin "xyz.maubot.supportportal" {
      description = "A maubot plugin to manage customer support on Matrix";
    };
    gitlab = generatedPlugin "xyz.maubot.gitlab" {
      description = "A GitLab client and webhook receiver for maubot";
    };
    github = generatedPlugin "xyz.maubot.github" {
      description = "A GitHub client and webhook receiver for maubot";
    };
    tex = generatedPlugin "xyz.maubot.tex" {
      description = "A maubot plugin to render LaTeX as SVG";
    };
    altalias = generatedPlugin "xyz.maubot.altalias" {
      description = "A maubot that lets users publish alternate aliases in rooms";
    };
    satwcomic = generatedPlugin "xyz.maubot.satwcomic" {
      description = "A maubot plugin to view SatWComics";
    };
    songwhip = generatedPlugin "xyz.maubot.songwhip" {
      description = "A maubot plugin to post Songwhip links";
    };
    manhole = generatedPlugin "xyz.maubot.manhole" {
      description = "A maubot plugin that provides a Python shell to access the internals of maubot";
    };
  };

in
  self // {
    inherit buildMaubotPlugin;
    allPlugins = lib.mapAttrsToList (k: v: v) self;
  }
