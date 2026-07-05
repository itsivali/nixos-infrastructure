# Desktop Control Extension — Nix Packaging

## How It Works

The extension is packaged by `desktop/desktop-control.nix` and installed as a system-wide NixOS package.

## Build Process

```nix
pkgs.stdenv.mkDerivation {
  name = "gnome-shell-extension-desktop-control";
  src = ./gnome-shell-extensions/desktop-control;
  installPhase = ''
    mkdir -p $out/share/gnome-shell/extensions/${extUuid}
    cp *.js *.json $out/share/gnome-shell/extensions/${extUuid}/
  '';
};
```

Key points:
- `src` points to the extension source directory
- `cp *.js *.json` copies ALL JavaScript modules automatically
- No hardcoded file list — adding a new `.js` module requires zero Nix changes
- Output goes to the standard GNOME Shell extension path

## Installation Path

The extension is installed to:
```
/run/current-system/sw/share/gnome-shell/extensions/desktop-control@prague.ivali/
```

## Activation Gate

The extension is only installed when `config.fleet.bot.enable` is true:

```nix
config = lib.mkIf config.fleet.bot.enable {
  environment.systemPackages = [ desktopControlExtension ];
};
```

This is controlled by `hosts/hosts.nix` → `features.bot = true`.

## Enablement

The extension is enabled via dconf in `home/environment/extensions.nix`:

```nix
dconf.settings = {
  "org/gnome/shell" = {
    enabled-extensions = [ "desktop-control@prague.ivali" ];
  };
};
```

Packaging (NixOS) and enablement (Home Manager) are separate concerns.

## Adding a New Module

1. Create `newmodule.js` in `desktop/gnome-shell-extensions/desktop-control/`
2. Import it in `extension.js` or `desktop.js`
3. Rebuild: `sudo nixos-rebuild switch --flake .#prague`

The `cp *.js` glob in the Nix derivation automatically picks up the new file.

## Reproducibility

- Nix ensures deterministic builds
- Source is pinned in the flake registry
- No network access during build
- Output is immutable in the Nix store
