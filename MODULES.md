# NixOS Module Architecture

This repository uses a **zero-touch, convention-driven NixOS module system** built around a single shared auto-import mechanism.

The goal is to make adding capabilities predictable:

> **Add the module → place it in the correct domain → the architecture discovers it → tests validate it → CI enforces it.**

A developer or AI agent should not need to modify `flake.nix` or `configuration.nix` every time a capability is added.

The module system is intentionally designed to support a large NixOS infrastructure repository without turning the top-level configuration into a constantly changing import registry.

---

# 1. Core Principles

The module system follows these principles:

1. **Domains own capabilities.**
2. **Hosts compose domains.**
3. **`default.nix` files are domain/subdomain entry points.**
4. **Ordinary `.nix` modules are automatically discovered.**
5. **Files beginning with `_` are private and excluded from discovery.**
6. **Auto-discovery is convention, not permission to violate architecture.**
7. **A module must still obey architecture dependency rules.**
8. **No module may silently create cross-domain coupling.**
9. **Configuration ownership must remain explicit.**
10. **Every meaningful behavior change must be tested.**
11. **The module system must remain deterministic.**
12. **The auto-importer itself is infrastructure and must be treated as a critical component.**

The important distinction is:

> **Auto-import answers “how is this module discovered?”
> Architecture answers “is this module allowed to exist here?”**

Auto-discovery does **not** bypass architecture enforcement.

---

# 2. Repository Composition Model

The repository follows this conceptual hierarchy:

```text
Host
  │
  ├── Domain
  │     │
  │     ├── Subdomain
  │     │      │
  │     │      └── Module
  │     │
  │     └── Module
  │
  └── Shared infrastructure
```

For example:

```text
prague
│
├── boot
├── hardware
├── networking
├── security
├── desktop
├── developer
├── observability
├── automation
├── recovery
├── storage
├── services
├── virtualization
├── system
├── ssh
├── ci
├── cloud
└── i18n
```

The host should primarily **compose capabilities**.

It should not become a dumping ground for implementation details.

The preferred architectural relationship is:

```text
HOST
 │
 ├── BOOT
 ├── HARDWARE
 ├── NETWORKING
 ├── SECURITY
 ├── DESKTOP
 ├── OBSERVABILITY
 ├── AUTOMATION
 ├── RECOVERY
 ├── STORAGE
 ├── SERVICES
 ├── VIRTUALIZATION
 └── SYSTEM
```

Not:

```text
domain → host-specific implementation → unrelated domain
```

---

# 3. The Auto-Import Engine

The central mechanism is:

```text
lib/auto-imports.nix
```

This is the repository's shared module-discovery function.

Every domain or subdomain `default.nix` that participates in automatic discovery should use the same implementation.

Conceptually:

```text
domain/default.nix
        │
        ▼
lib/auto-imports.nix
        │
        ├── module-a.nix
        ├── module-b.nix
        ├── module-c.nix
        └── subdomain/default.nix
```

The repository must have **one canonical auto-import implementation**.

Do not create competing implementations such as:

```text
lib/auto-imports.nix
lib/import-modules.nix
lib/module-loader.nix
lib/discover.nix
```

unless architecture explicitly requires them.

Multiple discovery mechanisms create ambiguity and make the repository harder to reason about.

---

# 4. Current Module Layout

The repository is organized into capability domains.

A representative structure is:

```text
.
├── automation/
│   ├── default.nix
│   ├── gitops-reconciler.nix
│   └── ...
│
├── boot/
│   ├── default.nix
│   ├── kernel.nix
│   ├── loader.nix
│   ├── sysctl.nix
│   ├── tpm.nix
│   └── zram.nix
│
├── hardware/
│   ├── default.nix
│   └── ...
│
├── networking/
│   ├── default.nix
│   ├── networkmanager.nix
│   ├── time.nix
│   └── ...
│
├── security/
│   ├── default.nix
│   ├── apparmor.nix
│   ├── fail2ban.nix
│   ├── firewall.nix
│   ├── hardening.nix
│   ├── packages.nix
│   ├── sops.nix
│   ├── sudo.nix
│   ├── tailscale.nix
│   └── ...
│
├── desktop/
│   ├── default.nix
│   ├── common/
│   │   ├── default.nix
│   │   ├── audio.nix
│   │   ├── gpu.nix
│   │   └── portals.nix
│   │
│   ├── kde/
│   │   ├── default.nix
│   │   ├── session.nix
│   │   ├── plasma.nix
│   │   ├── applications.nix
│   │   ├── theme.nix
│   │   ├── input.nix
│   │   ├── power.nix
│   │   └── ...
│   │
│   └── login/
│       └── ...
│
├── developer/
│   ├── default.nix
│   ├── languages.nix
│   ├── shell.nix
│   └── ...
│
├── observability/
│   ├── default.nix
│   ├── alloy.nix
│   ├── falco.nix
│   ├── grafana.nix
│   ├── journald.nix
│   ├── loki.nix
│   ├── options.nix
│   ├── otel.nix
│   ├── packages.nix
│   ├── prometheus.nix
│   └── ...
│
├── ci/
│   ├── default.nix
│   └── gitlab-runner.nix
│
├── ssh/
│   ├── default.nix
│   └── client.nix
│
├── services/
│   ├── default.nix
│   ├── msmtp/
│   │   └── default.nix
│   ├── nginx/
│   │   └── default.nix
│   └── postgres/
│       └── default.nix
│
├── storage/
│   ├── default.nix
│   └── ...
│
├── system/
│   ├── default.nix
│   ├── nix.nix
│   ├── state.nix
│   ├── users.nix
│   └── ...
│
├── virtualization/
│   ├── default.nix
│   └── docker.nix
│
├── cloud/
│   ├── default.nix
│   ├── aws/
│   │   └── default.nix
│   ├── digitalocean/
│   │   └── default.nix
│   └── hetzner/
│       └── default.nix
│
└── i18n/
    ├── default.nix
    └── locale.nix
```

This is a **structural model**, not permission to create arbitrary domains.

The authoritative domain list is defined by the repository architecture manifests.

---

# 5. Domain Ownership

Every module belongs to a domain.

Examples:

| Domain           | Responsibility                                                |
| ---------------- | ------------------------------------------------------------- |
| `boot`           | Kernel, bootloader, initrd, early boot                        |
| `hardware`       | Hardware-specific configuration                               |
| `networking`     | NetworkManager, routing, DNS, time, network interfaces        |
| `security`       | Firewall, AppArmor, SOPS, sudo, hardening, Tailscale security |
| `desktop`        | KDE Plasma and desktop integration                            |
| `developer`      | Development tools and language environments                   |
| `observability`  | Metrics, logs, tracing, telemetry                             |
| `automation`     | GitOps, reconciliation, automation                            |
| `recovery`       | Health, rollback, recovery mechanisms                         |
| `storage`        | Filesystems, mounts, storage policies                         |
| `services`       | Long-running application services                             |
| `virtualization` | Containers and virtualization                                 |
| `system`         | Core operating-system configuration                           |
| `ssh`            | SSH client/server configuration                               |
| `ci`             | CI runner and CI infrastructure                               |
| `cloud`          | Cloud-provider integration                                    |
| `i18n`           | Locale and internationalization                               |

A module must be placed according to **what it owns**, not merely what package it configures.

For example:

```text
security/tailscale.nix
```

is appropriate when the module primarily establishes Tailscale security/network policy.

A generic application package should not automatically be placed under `security/` merely because the application has security implications.

---

# 6. Hosts Are Compositions

Host configuration should remain intentionally thin.

A host should answer:

> “Which capabilities does this machine have?”

rather than:

> “How does every capability work?”

Conceptually:

```nix
{
  imports = [
    ./boot
    ./hardware
    ./networking
    ./security
    ./desktop
    ./developer
    ./observability
    ./automation
    ./recovery
    ./storage
    ./system
  ];
}
```

The host should not repeatedly enumerate every leaf module:

```nix
./security/firewall.nix
./security/sudo.nix
./security/apparmor.nix
./security/fail2ban.nix
./security/sops.nix
```

That defeats the purpose of domain-level composition.

---

# 7. Adding a Module

## 7.1 Existing domain

To add a capability to an existing domain:

```bash
touch networking/vpn.nix
```

Then implement the module normally:

```nix
{ config, lib, pkgs, ... }:

{
  # Module configuration
}
```

If the domain's `default.nix` uses the canonical auto-importer, the new module becomes part of the domain automatically.

No modification to:

```text
flake.nix
```

is required.

No modification to:

```text
configuration.nix
```

is required.

No manual import should be added to another file merely to make discovery work.

---

# 8. Adding a Subdomain

Use a subdirectory when a capability becomes sufficiently large or cohesive to deserve its own namespace.

Example:

```text
services/
├── default.nix
├── postgres/
│   └── default.nix
└── redis/
    └── default.nix
```

A subdomain must have:

```text
default.nix
```

which acts as its entry point.

Example:

```nix
{ ... }:

{
  imports = import ../../lib/auto-imports.nix ./.;

  # Subdomain-level configuration
}
```

The subdomain can then contain:

```text
postgres/
├── default.nix
├── configuration.nix
├── backup.nix
├── monitoring.nix
└── security.nix
```

provided each discovered file is actually a valid NixOS module.

---

# 9. Adding a New Top-Level Domain

Top-level domains are intentionally rare.

Do not create a new domain simply because a module does not fit neatly into an existing directory.

Before creating one:

1. Inspect the architecture manifest.
2. Determine whether an existing domain owns the capability.
3. Check dependency direction.
4. Check configuration ownership.
5. Check state ownership.
6. Check filesystem ownership.
7. Check whether a new domain creates an architectural cycle.
8. Run architecture tests.
9. Only then introduce the new domain.

If a new domain is genuinely justified:

```text
my-domain/
└── default.nix
```

It must then be registered at the host/domain composition boundary according to the repository's architecture.

The critical rule is:

> **Auto-discovery does not authorize creation of new architectural domains.**

---

# 10. Naming Rules

Use descriptive, capability-oriented names.

Good:

```text
networking/networkmanager.nix
security/firewall.nix
security/apparmor.nix
desktop/kde/plasma.nix
desktop/kde/theme.nix
observability/prometheus.nix
recovery/deployment-health.nix
```

Avoid vague names:

```text
misc.nix
stuff.nix
things.nix
config.nix
fixes.nix
temporary.nix
new.nix
test.nix
```

unless the purpose is genuinely represented by the name.

A filename should make sense when encountered by an engineer who has never seen the repository.

---

# 11. The `_` Private Convention

Files and directories beginning with `_` are excluded from automatic discovery.

Examples:

```text
_common.nix
_options.nix
_helpers.nix
_lib/
```

These are intended for implementation details.

Example:

```text
security/
├── default.nix
├── firewall.nix
├── apparmor.nix
└── _options.nix
```

`_options.nix` will not be treated as a NixOS module by the auto-importer.

It may be explicitly imported:

```nix
let
  options = import ./_options.nix;
in
{
  # ...
}
```

This convention is mandatory.

Do not rely on undocumented exclusions.

---

# 12. `default.nix` Semantics

`default.nix` has a special role.

It is the **entry point of a domain or subdomain**.

A typical domain:

```text
networking/
├── default.nix
├── networkmanager.nix
├── time.nix
└── dns.nix
```

The `default.nix` is responsible for composition.

It should generally contain:

```nix
{ ... }:

{
  imports = import ../lib/auto-imports.nix ./.;

  # Domain-level configuration
}
```

It should not become a second monolithic configuration file.

Avoid turning:

```text
networking/default.nix
```

into a 1,000-line collection of unrelated networking configuration.

When a configuration becomes independently meaningful, move it into its own module.

---

# 13. Auto-Import Depth

The canonical import path depends on directory depth.

| Location                     | Auto-import path             |
| ---------------------------- | ---------------------------- |
| `boot/default.nix`           | `../lib/auto-imports.nix`    |
| `networking/default.nix`     | `../lib/auto-imports.nix`    |
| `security/default.nix`       | `../lib/auto-imports.nix`    |
| `desktop/default.nix`        | `../lib/auto-imports.nix`    |
| `storage/default.nix`        | `../lib/auto-imports.nix`    |
| `system/default.nix`         | `../lib/auto-imports.nix`    |
| `cloud/default.nix`          | `../lib/auto-imports.nix`    |
| `services/default.nix`       | `../lib/auto-imports.nix`    |
| `services/msmtp/default.nix` | `../../lib/auto-imports.nix` |
| `cloud/aws/default.nix`      | `../../lib/auto-imports.nix` |
| `cloud/hetzner/default.nix`  | `../../lib/auto-imports.nix` |
| `desktop/kde/default.nix`    | `../../lib/auto-imports.nix` |

Do not invent alternate paths.

If the repository's actual `lib/auto-imports.nix` implementation changes, this document must be updated together with the implementation and its tests.

---

# 14. Module Template

The simplest module is:

```nix
{ config, lib, pkgs, ... }:

{
  services.my-feature = {
    enable = true;
  };
}
```

Modules should:

* declare only the configuration they own;
* use `lib` for conditional configuration;
* avoid unnecessary imports;
* avoid hidden side effects;
* avoid hard-coded host assumptions;
* avoid direct filesystem manipulation;
* avoid shell scripts when native NixOS options exist;
* avoid duplicating configuration owned elsewhere.

---

# 15. Option-Gated Modules

Optional capabilities should generally be controlled through NixOS options.

Example:

```nix
{ config, lib, ... }:

let
  cfg = config.ivial.desktop.kde;
in
{
  options.ivial.desktop.kde.enable =
    lib.mkEnableOption "KDE Plasma desktop";

  config = lib.mkIf cfg.enable {
    # KDE configuration
  };
}
```

This is preferable to unconditional configuration when the capability genuinely needs to be optional.

However:

> Do not create an option merely for the sake of creating an option.

If a module is an unconditional part of a domain's architecture, unnecessary option gates add complexity without value.

---

# 16. KDE Module Organization

The current desktop architecture uses **KDE Plasma** as the desktop platform.

KDE should be treated as a coherent platform rather than a collection of unrelated packages.

Recommended structure:

```text
desktop/
├── default.nix
├── common/
│   ├── default.nix
│   ├── audio.nix
│   ├── gpu.nix
│   ├── portals.nix
│   ├── bluetooth.nix
│   └── displays.nix
│
├── kde/
│   ├── default.nix
│   ├── plasma.nix
│   ├── session.nix
│   ├── theme.nix
│   ├── applications.nix
│   ├── input.nix
│   ├── power.nix
│   ├── networking.nix
│   └── integration.nix
│
└── login/
    └── ...
```

KDE-specific modules should own KDE behavior.

For example:

```text
desktop/kde/theme.nix
```

may own Plasma visual configuration.

```text
desktop/kde/input.nix
```

may own keyboard, touchpad, and input behavior.

```text
desktop/common/audio.nix
```

should own platform-independent audio infrastructure such as PipeWire/WirePlumber rather than KDE-specific presentation.

This preserves separation:

```text
Desktop platform
      │
      ├── KDE
      │
      └── Common Linux desktop infrastructure
              │
              ├── PipeWire
              ├── portals
              ├── GPU
              ├── Bluetooth
              └── displays
```

---

# 17. Module Boundaries

A module should have a coherent responsibility.

Bad:

```text
desktop/everything.nix
```

containing:

* KDE
* PipeWire
* Bluetooth
* Tailscale
* firewall
* Docker
* Prometheus
* SSH
* backups

Good:

```text
desktop/kde/plasma.nix
desktop/common/audio.nix
desktop/common/bluetooth.nix
security/firewall.nix
security/tailscale.nix
virtualization/docker.nix
observability/prometheus.nix
ssh/default.nix
```

The module boundary should reflect ownership.

---

# 18. No Hidden Imports

A module should not secretly pull unrelated architecture into itself.

Avoid:

```nix
imports = [
  ../../security/firewall.nix
  ../../networking/networkmanager.nix
];
```

unless that relationship is explicitly required and architecturally valid.

Prefer domain composition:

```text
Host
 ├── networking
 ├── security
 └── desktop
```

rather than:

```text
desktop
 └── networking
      └── security
```

This preserves domain independence.

---

# 19. Dependency Direction

The module system must obey the repository architecture.

The following should be treated as a warning sign:

```text
desktop → security implementation
security → desktop implementation
observability → application implementation
application → observability state directory
host → individual implementation detail
```

Dependencies should flow through explicit contracts where appropriate.

For example:

```text
Application
    │
    ▼
Service contract
    │
    ▼
Infrastructure implementation
```

rather than:

```text
Application
    │
    ▼
/var/lib/another-domain
```

Filesystem access is also a dependency.

Read-only access is still coupling.

---

# 20. State Ownership

A module that creates persistent state must have an explicit owner.

Examples:

```text
/var/lib/gitops
/var/lib/observability
/var/lib/prometheus
/var/lib/loki
/mnt/backup
```

The rule is:

> **One state path → one owner.**

A module may consume another domain's state only through an explicitly justified contract.

Do not create state directories casually.

Bad:

```nix
systemd.tmpfiles.rules = [
  "d /var/lib/something 0755 root root -"
];
```

without determining who owns the state.

---

# 21. Systemd Modules

When a module creates a systemd service, the service must be treated as an operational component.

Document and verify:

* owner;
* purpose;
* configuration;
* state;
* dependencies;
* privileges;
* sandboxing;
* restart policy;
* startup ordering;
* health behavior;
* logs;
* failure behavior;
* recovery behavior;
* network exposure.

Security-sensitive services should use appropriate systemd hardening such as:

```text
ProtectSystem
ProtectHome
PrivateTmp
PrivateDevices
NoNewPrivileges
RestrictAddressFamilies
RestrictNamespaces
CapabilityBoundingSet
SystemCallFilter
ReadWritePaths
```

Only apply hardening that is compatible with the service.

Do not add security directives blindly and assume the service still works.

---

# 22. Network Ownership

A module that exposes a port must have an explicit reason to do so.

For every network listener determine:

```text
Who owns the port?
What process binds it?
Why is it exposed?
Who can reach it?
Is it localhost-only?
Is it Tailscale-only?
Is it externally exposed?
What firewall rule permits it?
How is it monitored?
How is it secured?
```

Avoid duplicate ownership such as:

```text
module A → port 22
module B → port 22
```

There must be one authoritative policy owner.

---

# 23. Secrets

Modules must follow the repository's SOPS/age secret architecture.

Do not:

* hard-code credentials;
* commit secrets;
* create alternate secret stores without architectural approval;
* copy secrets into arbitrary world-readable paths;
* print secrets during evaluation;
* expose secrets through logs;
* embed credentials into generated scripts.

Preferred model:

```text
SOPS / age
    │
    ▼
Authorized runtime consumer
    │
    ▼
Service
```

A module should consume only the secrets it actually needs.

---

# 24. Hardware Modules

Hardware-specific configuration belongs under `hardware/` unless architecture requires otherwise.

Examples:

```text
hardware/
├── default.nix
├── audio.nix
├── gpu.nix
├── power.nix
├── usb-power.nix
└── laptop.nix
```

Hardware modules should avoid unnecessarily hard-coding one machine's identity.

If a module is genuinely host-specific, that fact should be explicit.

Do not hide:

```nix
hostName == "prague"
```

inside generic infrastructure modules.

---

# 25. Host-Specific Configuration

When host-specific behavior is unavoidable, prefer explicit composition.

For example:

```text
hosts/
├── prague/
│   └── default.nix
├── tuscany/
│   └── default.nix
└── testvm/
    └── default.nix
```

A generic domain should not silently become:

```nix
if config.networking.hostName == "prague" then ...
```

for unrelated behavior.

Host-specific logic belongs at the host boundary unless there is a strong architectural reason otherwise.

---

# 26. Module Purity and Evaluation Safety

Nix evaluation should remain deterministic.

Avoid unnecessary:

```nix
builtins.currentTime
```

network access during evaluation, arbitrary filesystem probing, environment-dependent behavior, and hidden external state.

A module should produce configuration from declared inputs.

Prefer:

```text
Inputs
  ↓
Nix evaluation
  ↓
Configuration
  ↓
System activation
```

rather than:

```text
Nix evaluation
  ↓
environment-dependent discovery
  ↓
unpredictable configuration
```

---

# 27. Testing New Modules

Every meaningful new module should have verification appropriate to its behavior.

At minimum:

```text
format
↓
Nix evaluation
↓
architecture validation
↓
flake checks
```

For behavior-bearing modules, add targeted tests where practical.

Examples:

### Firewall

Verify:

```text
expected port allowed
unexpected port denied
Tailscale traffic preserved
SSH policy preserved
```

### systemd service

Verify:

```text
service evaluates
service starts
service reaches expected state
service fails safely
service restarts appropriately
```

### KDE

Verify:

```text
Plasma evaluates
session starts
required portals exist
audio stack works
display stack works
input stack works
required applications integrate
```

### Networking

Verify:

```text
NetworkManager evaluates
Wi-Fi configuration evaluates
DNS configuration works
Tailscale remains functional
routing remains correct
```

---

# 28. TDD Requirement

For new behavior, the preferred development sequence is:

```text
Requirement
   ↓
Test
   ↓
RED
   ↓
Implementation
   ↓
GREEN
   ↓
Refactor
   ↓
Verification
```

For a bug:

```text
Observed failure
   ↓
Reproduce
   ↓
Regression test
   ↓
RED
   ↓
Fix
   ↓
GREEN
   ↓
Refactor
   ↓
Full verification
```

Do not merely modify a module because the configuration “looks right.”

The desired outcome is:

> **Prove the behavior.**

---

# 29. Architecture Validation

Every module addition must remain compatible with:

```text
architecture/domains.yaml
architecture/dependencies.yaml
architecture/exceptions.yaml
```

as applicable.

Architecture validation should detect at least:

* invalid domains;
* undeclared dependencies;
* forbidden imports;
* dependency cycles;
* duplicate ownership;
* filesystem boundary violations;
* state ownership violations;
* configuration ownership violations;
* internal API boundary violations;
* invalid exceptions;
* host/domain boundary violations.

Auto-importing a file does not make that file architecturally valid.

---

# 30. AI Agent Rules

AI agents working in this repository must understand the distinction between:

```text
Discovery
Architecture
Implementation
Verification
Deployment
```

An AI agent must not:

* create a new top-level domain casually;
* bypass the auto-import architecture;
* manually enumerate modules unnecessarily;
* duplicate configuration;
* create hidden cross-domain dependencies;
* hard-code host-specific behavior into generic modules;
* create unowned state;
* create unowned network listeners;
* bypass architecture tests;
* claim a module works without verification.

The AI should inspect:

```text
AGENTS.md
IVALi_FLOW.md
ARCHITECTURE.md
ARCHITECTURE_AUDIT.md
ARCHITECTURE_PROGRESS.md
architecture/*
lib/auto-imports.nix
```

before making architectural changes.

---

# 31. What the AI Should Do When Adding a Module

The preferred workflow is:

```text
1. Understand the requirement
2. Identify the owning domain
3. Inspect existing modules
4. Search for existing equivalent configuration
5. Check architecture dependencies
6. Determine whether a new module is necessary
7. Determine state/network/secret ownership
8. Write tests first where behavior warrants
9. Create the module
10. Verify auto-discovery
11. Run architecture tests
12. Run Nix evaluation
13. Run flake checks
14. Run targeted runtime verification where possible
15. Review the resulting diff
16. Use IVALi Flow for Git lifecycle
```

Never begin by blindly creating a file.

---

# 32. Avoiding Duplicate Configuration

Before adding configuration, search the repository.

For example, before adding:

```nix
services.openssh.enable = true;
```

search for existing ownership.

Before adding:

```nix
networking.firewall.allowedTCPPorts = [ 22 ];
```

search for existing firewall policy.

Before adding:

```nix
nix.settings.substituters = ...
```

search for every existing substituter definition.

Before adding:

```nix
nixpkgs.config.allowUnfree = true;
```

search for existing package-policy ownership.

The goal is:

> **One configuration concern → one authoritative owner.**

---

# 33. Auto-Import Safety

The auto-import mechanism must be conservative.

A discovered file should be imported only when it satisfies the repository's expected module structure.

The auto-importer must not accidentally import:

```text
README.md
*.sh
*.yaml
*.json
*.txt
private helper files
temporary files
generated artifacts
```

The `_` convention exists specifically to provide an escape hatch for non-module Nix files.

Generated files should not be placed in module directories unless explicitly supported.

---

# 34. Recursive Discovery

Recursive discovery should be intentional.

The expected model is:

```text
domain/default.nix
        │
        ├── leaf.nix
        ├── another.nix
        │
        └── subdomain/default.nix
                 │
                 ├── feature.nix
                 └── another-feature.nix
```

A directory becomes part of automatic composition when it provides the expected `default.nix` entry point.

Do not assume that an arbitrary directory should automatically become a module.

This distinction prevents accidental imports.

---

# 35. Empty and Placeholder Domains

Placeholder directories such as:

```text
cloud/aws/
cloud/digitalocean/
cloud/hetzner/
services/nginx/
services/postgres/
```

must not be interpreted as active functionality unless their `default.nix` actually enables or configures something.

A placeholder exists to establish architectural structure, not to imply that a service is deployed.

Documentation must distinguish:

```text
planned
available
enabled
deployed
healthy
```

---

# 36. Module Lifecycle

Modules follow this lifecycle:

```text
Proposed
   ↓
Designed
   ↓
Implemented
   ↓
Evaluated
   ↓
Tested
   ↓
Merged
   ↓
Deployed
   ↓
Observed
   ↓
Maintained
   ↓
Retired
```

Removing a module should include checking:

* consumers;
* dependencies;
* state;
* systemd units;
* firewall rules;
* secrets;
* packages;
* monitoring;
* dashboards;
* backups;
* documentation;
* architecture manifests.

Removing a file is not necessarily the same thing as removing a capability.

---

# 37. Migration and Refactoring

When restructuring modules:

```text
old module
   ↓
identify ownership
   ↓
identify consumers
   ↓
introduce replacement
   ↓
test replacement
   ↓
migrate consumers
   ↓
remove old implementation
   ↓
verify no references remain
```

Do not perform large-scale directory moves without checking all import relationships.

Search before and after refactoring.

---

# 38. Failure Modes to Avoid

## The Giant Module

```text
security/default.nix
    2,000 lines
```

Avoid.

## The Giant Host

```text
hosts/prague/default.nix
    1,500 lines
```

Avoid.

## The Duplicate Configuration

```text
system/nix.nix
cache/default.nix
caching/default.nix
```

all independently configuring the same Nix cache policy.

Avoid.

## Hidden Cross-Domain Import

```text
desktop → security/firewall.nix
```

without architectural justification.

Avoid.

## Unowned State

```text
/var/lib/something
```

created by whichever module happened to need it.

Avoid.

## Unowned Port

```text
port 8080
```

opened by multiple modules.

Avoid.

## Host Hard-Coding

```nix
if config.networking.hostName == "prague"
```

inside generic infrastructure.

Avoid unless explicitly justified.

## Configuration by Side Effect

Using arbitrary shell commands to mutate configuration outside Nix.

Avoid.

---

# 39. Repository Invariants

The module system must preserve these invariants.

### Invariant 1 — Deterministic Discovery

The same repository state produces the same module set.

### Invariant 2 — Single Discovery Mechanism

All domains use the canonical auto-import implementation.

### Invariant 3 — Explicit Domain Ownership

Every module belongs to a known domain.

### Invariant 4 — No Accidental Imports

Private/helper/generated files cannot become modules accidentally.

### Invariant 5 — No Duplicate Ownership

Configuration and state have authoritative owners.

### Invariant 6 — No Silent Cross-Domain Coupling

Dependencies must be explicit and architecturally valid.

### Invariant 7 — Host Composition

Hosts compose domains rather than implementing every capability.

### Invariant 8 — Testability

Meaningful behavior can be evaluated and verified.

### Invariant 9 — Reproducibility

Configuration does not depend on uncontrolled external state.

### Invariant 10 — Operational Safety

A module cannot silently weaken security, networking, recovery, or observability.

---

# 40. Verification Matrix

When modifying module architecture:

| Change               | Required verification                                 |
| -------------------- | ----------------------------------------------------- |
| New leaf module      | Nix evaluation + flake checks                         |
| New subdomain        | Auto-import + architecture tests + evaluation         |
| New top-level domain | Architecture review + architecture tests + evaluation |
| Systemd service      | Evaluation + service verification                     |
| Firewall             | Architecture + firewall verification                  |
| Network              | Nix evaluation + network verification                 |
| KDE                  | Evaluation + desktop/session verification             |
| Security             | Architecture + security tests                         |
| State directory      | Ownership validation                                  |
| New port             | Port ownership + firewall validation                  |
| Secret               | SOPS/age validation                                   |
| Hardware             | Host evaluation                                       |
| Refactor             | Full reference search + affected checks               |
| Auto-importer        | Dedicated auto-import tests + full evaluation         |

---

# 41. Minimum Verification

At minimum, module changes should pass the repository's current verification pipeline.

Typical checks include:

```bash
nix fmt -- --check
```

```bash
nix flake check --no-build
```

```bash
go test ./...
```

```bash
go build ./...
```

and the repository's architecture validation/linter commands.

The exact authoritative commands are defined by the current repository CI and `IVALi_FLOW.md`.

Do not assume historical commands remain authoritative.

The repository is the source of truth.

---

# 42. Auto-Import Tests

The auto-import mechanism itself should be tested.

Tests should verify at minimum:

```text
normal .nix file
    → discovered

underscore-prefixed file
    → ignored

default.nix
    → handled correctly

subdomain/default.nix
    → discovered correctly

non-Nix file
    → ignored

private directory
    → ignored

nested module
    → discovered according to rules
```

A change to:

```text
lib/auto-imports.nix
```

is therefore a high-impact infrastructure change.

It should trigger broader verification than an ordinary leaf-module change.

---

# 43. Documentation Contract

When module architecture changes materially, update the relevant documentation.

Potential documents include:

```text
MODULES.md
ARCHITECTURE.md
ARCHITECTURE_AUDIT.md
ARCHITECTURE_PROGRESS.md
AGENTS.md
IVALi_FLOW.md
```

Do not allow implementation and architecture documentation to diverge.

If documentation describes behavior that the repository no longer implements, the documentation is a defect.

---

# 44. Relationship to Architecture

The module system is one layer of the larger Ivali architecture.

```text
                    ┌─────────────────────┐
                    │       HOSTS         │
                    │ composition only    │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │      DOMAINS        │
                    │ capability ownership│
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │    SUBDOMAINS       │
                    │ bounded composition │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │      MODULES        │
                    │ implementation      │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │    NixOS OPTIONS    │
                    │ declarative config  │
                    └─────────────────────┘
```

The architecture layer determines **what is allowed**.

The module layer determines **how NixOS configuration is composed**.

The deployment layer determines **how the resulting system reaches the machine**.

These concerns must not be conflated.

---

# 45. Relationship to the Control Plane

The Go control plane is not a replacement for NixOS module composition.

The responsibilities are different:

```text
Nix modules
    │
    ├── desired system configuration
    ├── packages
    ├── services
    ├── networking
    ├── security
    └── desktop
             │
             ▼
        NixOS system
             │
             ▼
      Control Plane
             │
             ├── health
             ├── status
             ├── deployment
             ├── reconciliation
             ├── backup
             ├── metrics
             ├── recovery
             └── operational APIs
```

The control plane should not become a second configuration engine.

Nix remains responsible for declarative system configuration.

The control plane is responsible for orchestration, operations, health, reconciliation, and platform services according to its contracts.

---

# 46. Module vs Control-Plane Responsibility

Use a NixOS module when the concern is primarily:

```text
package installation
service configuration
systemd configuration
kernel configuration
filesystem configuration
network configuration
security configuration
desktop configuration
hardware configuration
system policy
```

Use the control plane when the concern is primarily:

```text
health
status
deployment orchestration
reconciliation
backup orchestration
metrics
operational APIs
recovery workflows
platform commands
```

Do not implement the same responsibility in both layers.

---

# 47. Golden Rule for Module Design

Before creating a module, ask:

```text
What does this module own?
What does it configure?
What state does it create?
What services does it create?
What ports does it expose?
What secrets does it consume?
What domains does it depend on?
Who depends on it?
How is it tested?
How is it recovered?
How is it observed?
How is it eventually removed?
```

If those answers cannot be given clearly, the module boundary probably needs more design work.

---

# 48. AI Decision Procedure

When an AI agent receives a request such as:

> “Add X to the system.”

it should reason in this order:

```text
1. Is X already implemented?
        │
        ├── yes → reuse or modify existing implementation
        │
        └── no
             │
             ▼
2. Which domain owns X?
             │
             ▼
3. Does an existing module already own part of X?
             │
             ▼
4. Is X a leaf capability or a subdomain?
             │
             ▼
5. Does X create persistent state?
             │
             ▼
6. Does X create a network listener?
             │
             ▼
7. Does X require secrets?
             │
             ▼
8. What are its dependencies?
             │
             ▼
9. What tests prove the behavior?
             │
             ▼
10. Implement
             │
             ▼
11. Verify discovery
             │
             ▼
12. Run architecture validation
             │
             ▼
13. Run Nix verification
             │
             ▼
14. Run targeted runtime checks
             │
             ▼
15. Continue through Ivali Flow
```

This procedure is mandatory for architectural changes.

---

# 49. The Ultimate Module Contract

Every module should satisfy the following:

```text
                    MODULE CONTRACT

                         │
        ┌────────────────┼────────────────┐
        │                │                │
        ▼                ▼                ▼
     Ownership       Dependencies      Discovery
        │                │                │
        ▼                ▼                ▼
   Clear domain     Explicit graph    Deterministic
        │                │                │
        └────────────────┼────────────────┘
                         │
                         ▼
                    Configuration
                         │
                         ▼
                    Verification
                         │
                         ▼
                     Operation
                         │
                         ▼
                     Recovery
```

A module is not complete merely because Nix evaluates it.

A production-quality module must be:

* architecturally valid;
* discoverable;
* deterministic;
* testable;
* secure;
* observable where appropriate;
* recoverable where appropriate;
* operationally understandable;
* correctly owned;
* compatible with the control plane where relevant.

---

# 50. Final Standard

The Ivali module system follows one fundamental principle:

> **Convention removes repetitive wiring; it does not remove engineering discipline.**

The repository should feel simple to extend:

```text
create module
      ↓
place in correct domain
      ↓
auto-discovered
      ↓
architecture validated
      ↓
tested
      ↓
verified
      ↓
merged through Ivali Flow
      ↓
deployed
      ↓
observed
```

The desired developer experience is:

> **Zero-touch composition with zero-touch architecture drift.**

Adding a module should be easy.

Adding an architectural violation should be difficult.

Adding an insecure configuration should be caught.

Adding an unowned state path should fail validation.

Adding an undeclared dependency should fail architecture checks.

Breaking auto-discovery should fail tests.

And changing the system should always leave the repository in a state that another senior engineer—or an AI agent—can understand without relying on tribal knowledge.

