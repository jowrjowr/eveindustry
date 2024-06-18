{ pkgs ? import <nixos-unstable> {} }:

with pkgs;

let
  inherit (lib) optional optionals;
in

mkShell {
  buildInputs = [
    ps
    elixir_1_17
    coreutils
    which
    git
    nix-prefetch-git
    zlib
    jq
  ]
  
  ++ optional stdenv.isLinux glibc
  ++ optional stdenv.isLinux glibcLocales
  ;

  # Fix GLIBC Locale
  LOCALE_ARCHIVE = lib.optionalString stdenv.isLinux
    "${pkgs.glibcLocales}/lib/locale/locale-archive";
  LANG = "en_US.UTF-8";

}
