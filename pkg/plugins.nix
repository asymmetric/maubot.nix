{ lib
, stdenvNoCC
, fetchFromGitHub
, maubot
, python3
}:

let
  buildMaubotPlugin = attrs@{ version, pname, ... }: stdenvNoCC.mkDerivation ({
    name = "${pname}-v${version}.mbp";
    nativeBuildInputs = [ maubot ];
    buildPhase = ''
      runHook preBuild

      mbc build

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      install -m 444 -T $name $out

      runHook postInstall
    '';

    dontFixup = true;
  } // attrs);

  buildOfficialPlugin = attrs@{ version, src, ... }: buildMaubotPlugin (attrs // {
    src = fetchFromGitHub ({
      owner = "maubot";
      rev = "v${version}";
    } // src);
    pname = "xyz.maubot.${src.repo}";
  });

  officialPlugins = builtins.mapAttrs (k: v: buildOfficialPlugin (v // {
    src = v.src // {
      repo = k;
    };
    meta = with lib; {
      homepage = "https://github.com/maubot/${k}";
      license = licenses.agpl3Plus;
    } // v.meta;
  })) {
    sed = {
      version = "1.1.0";
      src.sha256 = "sha256-raVUYEEuNHDFEE+b/yb8DyokFOrbVn0miul+2tJbR+s=";
      meta.description = "A maubot plugin to do sed-like replacements";
    };
    factorial = {
      version = "3.0.0";
      src.sha256 = "sha256-XHAwAloJZpFdY0kRrUjkEGJoryHK4PSQgBf2QH9C/6o=";
      meta.description = "A maubot plugin that calculates factorials";
    };
    media = {
      version = "1.0.0";
      src.sha256 = "sha256-00zESMN2WxKYPAQbpyvDpkyJIFkILLOP+m256k0Avzk=";
      meta.description = "A maubot plugin that posts MXC URIs of uploaded images";
      meta.license = lib.licenses.mit;
    };
    dice = {
      version = "1.1.0";
      src.sha256 = "sha256-xnqcxOXHhsHR9RjLaOa6QZOx87V6kLQJW+mRWF/S5eM=";
      meta.description = "A maubot plugin that rolls dice";
    };
    karma = {
      version = "1.0.1";
      src.sha256 = "sha256-7CK4NReLhU/d0FXTWj9eM7C5yL9nXkM+vpPExv4VPfE=";
      meta.description = "A maubot plugin to track the karma of users";
    };
    xkcd = {
      version = "1.2.0";
      src.sha256 = "sha256-dtst/QuIZrMjk5RdbXjTksCbGwf8HCBsECDWtp70W1U=";
      propagatedBuildInputs = with python3.pkgs; [ python-magic pillow ];
      meta.description = "A maubot plugin to view xkcd comics";
    };
    echo = {
      version = "1.4.0";
      src.sha256 = "sha256-/ajDs2vpWqejxDF7naXtKi1nYRs2lJpuc0R0dV7oVHI=";
      meta.description = "A simple maubot plugin that echoes pings and other stuff";
      meta.license = lib.licenses.mit;
    };
    rss = {
      version = "0.3.2";
      src.sha256 = "sha256-p/xJpJbzsOeQGcowvOhJSclPtmZyNyBaZBz+mexVqIY=";
      propagatedBuildInputs = with python3.pkgs; [ feedparser ];
      meta.description = "A RSS plugin for maubot";
    };
    reminder = {
      version = "0.2.2";
      src.sha256 = "sha256-BCyeWl5xPKvUGWkrnuGh498gKxfhfNZ7oBrsZzpKxkg=";
      propagatedBuildInputs = with python3.pkgs; [ python-dateutil pytz ];
      meta.description = "A maubot plugin to remind you about things";
    };
    translate = {
      version = "0.1.0";
      src.sha256 = "sha256-eaiTNjnBa0r2zeCzYZH/k04dGftBSGuGaDvwOGKKZDA=";
      meta.description = "A maubot plugin to translate words";
    };
    reactbot = {
      version = "2.2.0";
      src.sha256 = "sha256-eaiTNjnBa0r2zeCzYZH/k04dGftBSGuGaDvwOGKKZDA=";
      meta.description = "A maubot plugin that responds to messages that match predefined rules";
    };
    exec = {
      version = "0.1.0";
      src.rev = "475d0fe70dc30e1c14e29028694fd4ac38690932";
      src.sha256 = "sha256-bwy3eB7ULYTGeJXtTNFMfry9dWQmnTjcU6HWdRznWxc=";
      meta.description = "A maubot plugin to execute code";
    };
    commitstrip = {
      version = "1.0.0";
      src.rev = "28ab63c2725aa989a151f5659cb37a674b002a80";
      src.sha256 = "sha256-P5u4oDmsMj4r48JZIZ1Cg8cX11aimv9dGI+J0lJrY34=";
      meta.description = "A maubot plugin to view CommitStrips";
    };
    supportportal = {
      version = "0.1.0";
      src.sha256 = "sha256-9CmA9KfkOkzqTycAGE8jaZuDwS7IvFwWGUer3iR8ooM=";
      meta.description = "A maubot plugin to manage customer support on Matrix";
    };
    gitlab = {
      version = "0.2.1";
      src.sha256 = "sha256-lkHGR+uLnT3f7prWDAbJplwzwAyOfMCwf8B2LeiJzIo=";
      propagatedBuildInputs = with python3.pkgs; [ python-gitlab ];
      meta.description = "A GitLab client and webhook receiver for maubot";
    };
    github = {
      version = "0.1.2";
      src.sha256 = "sha256-Qc0KH8iGqMDa+1BXaB5fHtRIcsZRpTF2IufGMEXqV6Q=";
      meta.description = "A GitHub client and webhook receiver for maubot";
    };
    tex = {
      version = "0.1.0";
      src.rev = "a6617da41409b5fc5960dc8de06046bbac091318";
      src.sha256 = "sha256-6Iq/rOiMQiFtKvAYeYuF+2xXVcR7VIxQTejbpYBpy2A=";
      propagatedBuildInputs = with python3.pkgs; [ matplotlib pillow ];
      meta.description = "A maubot plugin to render LaTeX as SVG";
    };
    altalias = {
      version = "1.0.0";
      src.rev = "b07b7866c9647612bfe784700b37087855432028";
      src.sha256 = "sha256-+qW3CX2ae86jc5l/7poyLs2cQycLjft9l3rul9eYby4=";
      meta.description = "A maubot that lets users publish alternate aliases in rooms";
    };
    satwcomic = {
      version = "1.0.0";
      src.rev = "0241bce4807ce860578e2f4fde76bb043bcebe95";
      src.sha256 = "sha256-TyXrPUUQdLC0IXbpQquA9eegzDoBm1g2WaeQuqhYPco=";
      propagatedBuildInputs = with python3.pkgs; [ pyquery pillow ];
      meta.description = "A maubot plugin to view SatWComics";
    };
    songwhip = {
      version = "0.1.0";
      src.rev = "68d5226b19b983f7ef0e2452c3c1be93a8b5c23b";
      src.sha256 = "sha256-gA4anzN5Qifam+8fPDb7avo1kBZW4x81ckJB3b7Cia0=";
      meta.description = "A maubot plugin to post Songwhip links";
    };
    manhole = {
      version = "1.0.0";
      src.rev = "47f1f7501b5b353a0fa74bf5929cead559496174";
      src.sha256 = "sha256-F3Nrl6NOUmwDuBsCxIfopRnLU9rltdaCJL/OcNGzw1Q=";
      meta.description = "A maubot plugin that provides a Python shell to access the internals of maubot";
    };
  };

  self = officialPlugins // {
    inherit buildMaubotPlugin;
  };

in
self
