{ pkgs ? import <nixos-unstable> {} }:

with pkgs;

let
  inherit (lib) optional optionals;
  elixir = beam.packages.erlangR23.elixir_1_11;
in

mkShell {
  buildInputs = [
    ps
    elixir
    coreutils
    which
    git
    nix-prefetch-git
    zlib
    jq
    nodejs
  ];

  # Fix GLIBC Locale
  LOCALE_ARCHIVE = stdenv.lib.optionalString stdenv.isLinux
    "${pkgs.glibcLocales}/lib/locale/locale-archive";
  LANG = "en_US.UTF-8";

  # fix something with the elixir env i forget what

  ERL_INCLUDE_PATH="${erlangR23}/lib/erlang/usr/include";

}