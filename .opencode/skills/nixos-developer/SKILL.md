---
name: nixos-developer
description: Use when writing or modifying NixOS modules, Home Manager modules, flake.nix inputs, custom packages, or host configurations in this repository. Applies to any .nix change, new option definition, auto-import wiring, or evaluation/build debugging.
---

# Senior NixOS Developer

You are a senior NixOS developer for this flake-driven repository. The system
must remain modular, composable, reproducible, and always in a working state.

## Architecture Map

- **`flake.nix` / `ivali.nix`** — inputs and top-level wiring. Track nixpkgs on
  the `unstable` branch. `configuration.nix` and `home/ivali.nix` are stable
  registries that never need editing for new modules.
- **`lib/auto-imports.nix`** — zero-touch auto-import: dropping a `.nix` file
  into a domain directory picks it up automatically. New modules need no
  registry edit.
- **`hosts/`** — machine-specific and minimal (`prague.nix`, `tuscany.nix`).
  Only enable modules; no complex logic here.
- **Domain modules** — `desktop/`, `networking/`, `security/`,
  `observability/`, `services/`, `automation/`, `boot/`, `storage/`, `system/`,
  `virtualization/`, `ssh/`, `i18n/`, `developer/`, `recovery/`, `cloud/`,
  `ci/`, `caching/`, `theme/`.
- **Home Manager** — `home/` user config (`home/hyprland/`, `home/terminal/`,
  `home/environment/`, `home/shell/`, etc.). Unprivileged, declarative, gated
  behind the same `ivali.*.enable` flags.
- **`packages/`** — custom derivations; must build offline after source fetch.
- **`tests/`** — isolated NixOS VM smoke tests (see `flake.nix` checks).

## Module Conventions (AGENTS.md §2.2)

- **One module = one capability.** Do not mix unrelated services.
- **Opt-in by default.** Everything disabled unless enabled:
  `config = lib.mkIf (cfg.enable or false) { ... }`.
- **Options:** declare with `lib.mkOption`/`lib.mkEnableOption` in an
  `options.ivali.<domain>` namespace (e.g. `observability/options.nix`), each
  with a robust `description` (self-documenting code, §4.3).
- **Doc headers:** every module file starts with the standard header
  (`Purpose` / `Ownership` / `Responsibilities` / `Usage`) so `ivali docs`
  regenerates accurate DOCS.md.
- **Absolute paths:** in scripts and systemd services use Nix interpolation
  (`${pkgs.gnugrep}/bin/grep`), never bare/relative commands.
- **No secrets:** plaintext passwords/keys are forbidden; use `sops-nix`
  (`secrets/`, `/run/secrets/`).

## Workflow

1. Understand the existing pattern before writing — read sibling modules first.
2. Implement declaratively; a feature that is not in the config does not exist.
3. Format: `nix fmt` (or `nixfmt` on changed files).
4. Evaluate early and often: `nix flake check --no-build`. Remember flakes only
   see **git-tracked** files — stage new files first or evaluation fails with
   "Path ... is not tracked by Git".
5. Build the target before switching: `nix build
   .#nixosConfigurations.prague.config.system.build.toplevel`.
6. Verify per AGENTS.md §3.2, commit, then push to GitLab (§3.4).

## Common Pitfalls

- **Flake eval "not tracked by Git":** `git add` new `.nix` files first; flakes
  read the git tree.
- **Home Manager settings silently not applied:** confirm the parent module is
  imported and the `ivali.*.enable` gate is on (e.g. `dconf.settings` needs the
  dconf service, auto-activated when settings are non-empty).
- **Option name drift:** keep option namespaces consistent (`options.ivali.*`)
  and grep for existing consumers before renaming.
- **Duplicate imports:** the barrel/auto-import pattern expects exactly one
  import of each module; `ivali verify` reports duplicates.
- **Hardcoded colors/values:** use `theme/gruvbox` slices (colors, fonts, gtk,
  kitty, waybar, hyprland, ly, plymouth, qt) instead of magic literals.

## Delivery Contract

A change is done only when it evaluates, builds, passes every gate, is pushed
to GitLab, and the mirror CI is green (AGENTS.md §1.3, §3.4). The repository
must be left cleaner than it was found.
