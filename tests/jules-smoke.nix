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
      hash = "sha256-1b2c021cy8n9diaydhj90s3jqxrkjwj9p3ff2hm7fm7j20wv99nd";
    };
    nativeBuildInputs = [ pkgs.nodejs ];
    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      mkdir -p $out/libexec/jules
      cp jules $out/libexec/jules/jules
      chmod +x $out/libexec/jules/jules
      cp run.cjs $out/libexec/jules/run.cjs
      runHook postInstall
    '';
    dontFixup = true;
  };

  julesWrapped = pkgs.writeShellScriptBin "jules" ''
    export JULES_CONFIG_DIR="''${JULES_CONFIG_DIR:-$HOME/.config/jules}"
    exec ${pkgs.nodejs}/bin/node ${julesBinary}/libexec/jules/run.cjs "$@"
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
