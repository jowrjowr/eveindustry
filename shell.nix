{ pkgs ? import <nixos-22.05> {} }:

with pkgs;

let
  inherit (lib) optional optionals;
  elixir = beam.packages.erlangR24.elixir_1_13;
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
  ]
  
  ++ optional stdenv.isLinux glibc
  ++ optional stdenv.isLinux glibcLocales
  ;

  # Fix GLIBC Locale
  LOCALE_ARCHIVE = lib.optionalString stdenv.isLinux
    "${pkgs.glibcLocales}/lib/locale/locale-archive";
  LANG = "en_US.UTF-8";

  # fix something with the elixir env i forget what

  ERL_INCLUDE_PATH="${erlangR23}/lib/erlang/usr/include";

}
