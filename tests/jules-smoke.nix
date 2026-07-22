##############################################################################
#
# Jules Smoke
#
# Purpose
# -------
# Verify that the Jules CLI package builds and is available in PATH.
#
##############################################################################

{ pkgs, sops-nix, home-manager }:

let
  julesVersion = "0.1.42";

  julesBinary = pkgs.stdenv.mkDerivation {
    pname = "jules-cli";
    version = julesVersion;
    src = pkgs.fetchurl {
      url = "https://storage.googleapis.com/jules-cli/v${julesVersion}/jules_external_v${julesVersion}_linux_amd64.tar.gz";
      hash = "sha256-c869LI+Jubsk703MuM15Q8y2npmzfeJnwvV5Mjen0QM=";
    };
    sourceRoot = ".";
    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      mkdir -p $out/libexec/jules
      cp jules $out/libexec/jules/jules
      chmod +x $out/libexec/jules/jules
      runHook postInstall
    '';
  };

  julesWrapped = pkgs.writeShellScriptBin "jules" ''
    export JULES_CONFIG_DIR="''${JULES_CONFIG_DIR:-$HOME/.config/jules}"
    exec ${julesBinary}/libexec/jules/jules "$@"
  '';
in
pkgs.testers.nixosTest {
  name = "jules-smoke";

  nodes.machine = { ... }: {
    imports = [
      sops-nix.nixosModules.sops
      home-manager.nixosModules.home-manager
    ];

    networking.hostName = "jules-smoke";
    services.xserver.enable = false;
    services.openssh.enable = false;
    system.stateVersion = "26.11";

    environment.systemPackages = [ julesWrapped ];

    sops.age.keyFile = pkgs.runCommand "dummy-sops-key" { } ''
      mkdir -p $out
      echo "AGE-SECRET-KEY-1TEST" > $out/key.txt
    '';
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Verify jules is in PATH
    machine.succeed("which jules")

    # Verify the wrapper script is executable
    machine.succeed("test -x $(which jules)")
  '';
}
