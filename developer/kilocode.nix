##############################################################################
#
# Kilocode CLI
#
# Purpose
# -------
# System-wide installation of Kilocode CLI, a fork of OpenCode that supports
# 500+ AI models. Provides the `kilo` command for agentic development workflows.
# Built from npm tarball since the nixpkgs package has a broken build.
#
# Ownership
# ---------
# environment.systemPackages
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.kilocode;

  kilocode-cli = pkgs.stdenv.mkDerivation {
    pname = "kilocode-cli";
    version = "7.5.5";

    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/@kilocode/cli/-/cli-7.5.5.tgz";
      sha256 = "sha256-nIR1j3KxETxjAj9A0nMPDFnmnVssxlDXm+98vLd7nRM=";
    };

    nativeBuildInputs = [ pkgs.makeWrapper ];

    dontBuild = true;

    installPhase = ''
      mkdir -p $out/lib/node_modules/@kilocode/cli
      cp -r ./* $out/lib/node_modules/@kilocode/cli/

      mkdir -p $out/bin
      makeWrapper ${pkgs.nodejs}/bin/node $out/bin/kilo \
        --add-flags "$out/lib/node_modules/@kilocode/cli/index.js"
    '';
  };
in
{
  options.ivali.kilocode = {
    enable = lib.mkEnableOption "Kilocode CLI (fork of OpenCode)";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      kilocode-cli
    ];
  };
}
