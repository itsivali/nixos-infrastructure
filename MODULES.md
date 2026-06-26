# Module System

This repository uses a **zero-touch auto-import** pattern.
`configuration.nix` and `flake.nix` never need to be edited when adding new modules.

---

## How it works

```
configuration.nix                 ← stable registry of top-level domains
│
├── ./automation                  → automation/default.nix
│   ├── gitops-reconciler.nix     ← auto-discovered ✓
│   └── _common.nix               ← skipped (underscore prefix)
│
├── ./recovery                    → recovery/default.nix
│   ├── deployment-health.nix     ← auto-discovered ✓
│   └── rollback.nix              ← auto-discovered ✓
│
├── ./boot                        → boot/default.nix
│   └── (drop files here)
│
├── ./networking                  → networking/default.nix
│   ├── msmtp/                    ← auto-discovered sub-directory ✓
│   │   └── default.nix
│   └── (drop vpn.nix here)       ← auto-discovered ✓
│
├── ./security                    → security/default.nix
│   ├── firewall.nix              ← auto-discovered ✓
│   └── tailscale.nix             ← auto-discovered ✓
│
├── ./developer                   → developer/default.nix
│   └── (drop rust.nix here)
│
├── ./desktop                     → desktop/default.nix
│   └── gnome-lean.nix            ← auto-discovered ✓
│
├── ./observability               → observability/default.nix
│   └── (drop alertmanager.nix)
│
└── ./ci                          → ci/default.nix
    └── gitlab-runner.nix         ← auto-discovered ✓
```

The engine is `lib/auto-imports.nix` — a single Nix function used by every `default.nix`.

---

## Adding a module

### Within an existing domain

Drop a `.nix` file anywhere in an existing folder:

```bash
# Add a WireGuard VPN config
touch networking/vpn.nix
```

Edit it as a normal NixOS module. On the next `nixos-rebuild switch` it is imported automatically. No other file needs to change.

### New sub-directory within a domain

Create the directory with its own `default.nix`:

```
networking/
├── default.nix
├── msmtp/
│   └── default.nix    ← already exists
└── wireguard/
    └── default.nix    ← new sub-module, auto-discovered
```

The parent `default.nix` auto-discovers it because it has a `default.nix`.

### New top-level domain (rare)

1. Create the folder with a `default.nix`
2. Add **one line** to `configuration.nix`:

```nix
./my-new-domain
```

That is the only time `configuration.nix` ever changes.

---

## File naming conventions

| Prefix / name  | Behaviour              | Use for                              |
|----------------|------------------------|--------------------------------------|
| `default.nix`  | Entry point, not imported by auto-importer | Module barrel / config   |
| `foo.nix`      | Auto-imported as NixOS module | Services, settings, options |
| `_foo.nix`     | **Skipped** by auto-importer  | Shared data, constants, helpers |
| `_lib/` dir    | **Skipped** by auto-importer  | Private helper modules      |

### The `_` prefix convention

Files and directories starting with `_` are excluded from auto-import.
Use them for Nix values that are not NixOS modules:

```
automation/_common.nix      ← { hostName = "prague"; gitops = { ... }; }
security/_options.nix       ← shared option type definitions
```

Import them explicitly from the file that needs them:
```nix
let common = import ./_common.nix; in
```

---

## Module template

```nix
# domain/my-feature.nix
{ config, lib, pkgs, ... }:
{
  # No `imports` needed — this file IS the import.

  services.my-feature = {
    enable = true;
  };
}
```

For a sub-directory module:
```nix
# domain/sub-feature/default.nix
{ config, lib, pkgs, ... }:
{
  # Auto-import siblings inside this sub-directory.
  imports = import ../../lib/auto-imports.nix ./.;

  # Configuration here…
}
```

---

## Depth reference for `lib/auto-imports.nix`

| Module location               | Import path                       |
|-------------------------------|-----------------------------------|
| `boot/default.nix`            | `../lib/auto-imports.nix`         |
| `networking/default.nix`      | `../lib/auto-imports.nix`         |
| `networking/msmtp/default.nix`| `../../lib/auto-imports.nix`      |
| `networking/wireguard/default.nix` | `../../lib/auto-imports.nix` |
