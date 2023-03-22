# maubot.nix

I plan to implement a NixOS module for maubot here and eventually merge
it to nixpkgs. Currently there's only code for building maubot itself
and plugins, and no code for configuring maubot.

It's pretty hard to declaratively configure maubot bots as it uses a
postgres table (well, I could try using maubot CLI if it supports
that...), so the plan is to only make the plugins and the config
declaratively configurable. The rest will be stateful as usual. Probably
not a bad thing considering that state contains Matrix tokens.

Config itself is expected to be mutable, however there's also an
immutable `--base-config` argument which will be used here.

As for plugin, multiple plugin load directories are supported in maubot
config, so there's no problem here.
