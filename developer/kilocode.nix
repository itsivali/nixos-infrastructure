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
# The upstream binary is a Bun 1.2 standalone executable (168 MB) with a
# non-standard ELF layout.  autoPatchelfHook corrupts the PHDR/INTERP
# segments when extending the interpreter path, causing a segfault.
# buildFHSEnv provides /lib64/ld-linux-x86-64.so.2 without modifying
# the binary — the same proven pattern used by antigravity.nix.
#
# Ownership
# ---------
# environment.systemPackages
#
##############################################################################

{ config, lib, pkgs, ... }:

let
  cfg = config.ivali.kilocode;

  version = "7.5.5";

  kilocode-base = pkgs.stdenv.mkDerivation {
    pname = "kilocode-cli-base";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/@kilocode/cli-linux-x64/-/cli-linux-x64-${version}.tgz";
      hash = "sha256-xmB10AcJvEP56v82XitjCNi8+HBqZtDleqNXMmFUBIw=";
    };

    dontBuild = true;
    dontPatchelf = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/kilocode
      cp -r bin/* $out/lib/kilocode/

      runHook postInstall
    '';

    meta = {
      description = "Kilo Code CLI";
      homepage = "https://github.com/Kilo-Org/kilocode";
      license = lib.licenses.mit;
      mainProgram = "kilo";
      platforms = [ "x86_64-linux" ];
    };
  };

  kilocode-fhs = pkgs.buildFHSEnv {
    name = "kilo";
    targetPkgs = pkgs: [
      kilocode-base
    ];
    runScript = "${kilocode-base}/lib/kilocode/kilo";
  };

in
{
  options.ivali.kilocode = {
    enable = lib.mkEnableOption "Kilo Code CLI";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      kilocode-fhs
    ];
  };
}
