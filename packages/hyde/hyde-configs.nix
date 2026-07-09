{ pkgs, lib, src }:

pkgs.stdenv.mkDerivation {
  name = "hyde-configs";
  inherit src;

  nativeBuildInputs = with pkgs; [
    gnutar
    unzip
  ];

  buildPhase = ''
    # Remove large assets not needed for configs
    rm -rf Source/assets
    rm -f Source/arcs/*.tar.gz Source/arcs/*.vsix

    # Remove binaries that come from separate packages
    rm -f Configs/.local/bin/hydectl
    rm -f Configs/.local/bin/hyde-ipc
    rm -f Configs/.local/bin/hyq
    rm -f Configs/.local/lib/hyde/hyde-config
    rm -f Configs/.local/lib/hyde/hyq
    rm -f Configs/.local/lib/hyde/resetxdgportal.sh

    # Patch killall references for NixOS wrapped binaries
    find . -type f -print0 | xargs -0 sed -i 's/killall waybar/killall .waybar-wrapped/g'
    find . -type f -print0 | xargs -0 sed -i 's/killall dunst/killall .dunst-wrapped/g'
    find . -type f -print0 | xargs -0 sed -i 's/killall kitty/killall .kitty-wrapped/g'
    find . -type f -print0 | xargs -0 sed -i 's/killall -SIGUSR1 kitty/killall -SIGUSR1 .kitty-wrapped/g'

    # Follow symlinks in find commands
    find . -type f -executable -print0 | xargs -0 sed -i 's/find "/find -L "/g'
    find . -type f -name "*.sh" -print0 | xargs -0 sed -i 's/find "/find -L "/g'

    # Fix GTK4 theme switching
    sed -i '187,190d' Configs/.local/lib/hyde/theme.switch.sh 2>/dev/null || true

    # Fix rofi launch
    sed -i '5d' Configs/.local/lib/hyde/rofilaunch.sh 2>/dev/null || true
  '';

  installPhase = ''
    mkdir -p $out
    cp -r . $out
  '';

  meta = {
    description = "HyDE desktop environment configuration files";
    homepage = "https://github.com/HyDE-Project/HyDE";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
  };
}
