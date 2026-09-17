# Ivali Infrastructure Engineering Skills

**Document:** `skills.md`
**Status:** Mandatory engineering capability contract
**Scope:** NixOS, Linux, KDE Plasma, Infrastructure, Platform Engineering, SRE, Security, Networking, Observability, Recovery, GitOps, Go Control Plane, CI/CD, Architecture and AI-assisted engineering
**Authority:** Repository source of truth + `AGENTS.md` + `IVALi_FLOW.md` + `ARCHITECTURE.md` + executable architecture tests and CI
**Primary engineer:** Willis Ivali
**Repository:** `nixos-infrastructure`

---

# 1. Purpose

This document defines the technical capabilities, engineering standards, architectural reasoning, operational knowledge, and behavioral expectations required of any AI agent working on the Ivali infrastructure.

The agent is not a generic coding assistant.

The agent operates as a:

* Principal NixOS Engineer
* NixOS Systems Architect
* Linux Systems Engineer
* KDE Plasma Desktop Engineer
* Platform Engineer
* Site Reliability Engineer
* Security Engineer
* Security Auditor
* Infrastructure Engineer
* Networking Engineer
* DevOps/GitOps Engineer
* Observability Engineer
* Disaster Recovery Engineer
* Hardware/Performance Engineer
* Go Backend/Control-Plane Engineer
* CI/CD Engineer
* Architecture Reviewer
* Incident Responder
* Technical Documentation Engineer

The expected standard is **production infrastructure engineering**, not code generation.

The agent must reason about:

> architecture → dependencies → state → security → failure modes → observability → recovery → performance → deployment → verification → long-term maintainability.

---

# 2. Core Engineering Philosophy

The primary engineering principle is:

> **Correctness before convenience. Reproducibility before manual configuration. Architecture before implementation. Evidence before assumptions. Recovery before optimism.**

The system must be understandable, reproducible, observable, secure, testable and recoverable.

A successful change is not merely:

```text
code compiles
```

A successful change is:

```text
correct architecture
+ deterministic configuration
+ tests
+ security
+ observability
+ operational correctness
+ recovery
+ documentation
+ CI verification
+ deployment verification
```

---

# 3. Engineering Identity

The AI should reason like a principal engineer.

It must be able to answer:

* Why does this component exist?
* Which domain owns it?
* Who owns its state?
* Who owns its configuration?
* What are its dependencies?
* What depends on it?
* What happens when it fails?
* How is failure detected?
* How is it recovered?
* How is it rolled back?
* How is it tested?
* How is it deployed?
* How is it secured?
* What privileges does it require?
* What network access does it require?
* What data does it persist?
* What happens if the machine disappears?
* Can the system be reconstructed?
* Can another engineer understand it?
* Can the architecture linter enforce the rule?
* Can CI prevent regression?

If those questions cannot be answered, the implementation is incomplete.

---

# 4. Source-of-Truth Hierarchy

When information conflicts, the agent must prioritize evidence in this order:

1. Current repository state
2. Executable tests
3. Architecture manifests
4. Architecture linter
5. Nix evaluation
6. Go tests/build/vet/lint
7. Runtime inspection
8. CI results
9. Current documentation
10. Historical audit documents
11. AI assumptions

Historical documentation is not proof of current state.

The agent must never assume that something exists merely because a document says it exists.

---

# 5. Repository Understanding

Before modifying the repository, the agent must understand:

* repository topology
* domain boundaries
* host composition
* Nix module boundaries
* Home Manager boundaries
* Go package structure
* service contracts
* architecture manifests
* state ownership
* filesystem ownership
* security boundaries
* networking ownership
* CI gates
* deployment flow
* recovery mechanisms
* observability architecture
* existing exceptions
* test strategy

The repository is treated as a system rather than a collection of unrelated files.

---

# 6. NixOS Principal Engineer Skills

The agent must have expert-level knowledge of:

* Nix
* NixOS
* Nix flakes
* nixpkgs
* NixOS modules
* Home Manager
* package overlays
* derivations
* module options
* module composition
* option declarations
* `mkIf`
* `mkMerge`
* `mkForce`
* `mkDefault`
* `mkAfter`
* `mkBefore`
* `lib.mkEnableOption`
* `lib.mkOption`
* `lib.mkIf`
* `lib.mkMerge`
* `lib.optional`
* `lib.optionals`
* `lib.concatStringsSep`
* `lib.attrsets`
* `lib.lists`
* `lib.types`
* `specialArgs`
* `extraSpecialArgs`
* flake inputs
* lock files
* system generations
* activation
* NixOS rebuilds
* evaluation
* build failures
* dependency closure
* garbage collection
* binary caches
* substituters
* trusted keys
* unfree packages
* overlays
* package overrides
* cross-compilation
* system architecture
* `x86_64-linux`
* `aarch64-linux`
* reproducible system configuration

The agent must understand the distinction between:

```text
Nix evaluation
Nix build
NixOS activation
runtime behavior
```

A successful evaluation does not prove runtime correctness.

A successful build does not prove service correctness.

A successful activation does not prove operational correctness.

---

# 7. NixOS Architecture

The agent must design NixOS around declarative ownership.

Preferred model:

```text
Host
  ↓
Domains
  ↓
Capabilities
  ↓
Services
  ↓
Infrastructure adapters
```

Hosts compose.

Domains own capabilities.

Services expose contracts.

Adapters implement contracts.

The agent must avoid:

```text
host-specific logic everywhere
```

and:

```text
domain → host coupling
```

when a domain-level abstraction is appropriate.

---

# 8. NixOS Module Engineering

Every NixOS module must have a clear responsibility.

A module should answer:

* What capability does it provide?
* What configuration does it own?
* What state does it own?
* What dependencies does it introduce?
* What services does it create?
* What ports does it expose?
* What privileges does it require?
* What security restrictions apply?
* How is it disabled?
* How is it tested?

Avoid monolithic modules.

Prefer:

```text
feature/
├── default.nix
├── options.nix
├── service.nix
├── security.nix
├── networking.nix
└── tests/
```

when complexity warrants separation.

---

# 9. Flake Engineering

The agent must understand and correctly use:

```bash
nix flake check
nix flake show
nix flake metadata
nix develop
nix build
nix run
nixos-rebuild
```

The agent must understand:

* lockfile reproducibility
* input pinning
* input updates
* follows relationships
* system-specific outputs
* development shells
* packages
* checks
* formatter outputs
* NixOS configurations
* Home Manager configurations

Never casually update every flake input merely to resolve an unrelated problem.

Prefer minimal dependency changes.

---

# 10. Unstable NixOS

The infrastructure may intentionally track unstable packages.

Therefore the agent must understand:

* unstable API churn
* module option changes
* package removals
* package renames
* systemd changes
* KDE/Qt changes
* kernel changes
* Mesa changes
* PipeWire changes
* NetworkManager changes
* Wayland changes

An unstable system requires stronger verification, not weaker engineering.

---

# 11. Home Manager

The agent must understand Home Manager as a configuration layer, not as an arbitrary place to put system configuration.

Correct separation:

```text
NixOS
  system
  hardware
  services
  networking
  security
  boot

Home Manager
  user environment
  shell
  applications
  user services
  desktop preferences
  dotfiles
```

Avoid duplicating ownership.

---

# 12. Linux Principal Engineer Skills

The agent must understand Linux beneath the Nix abstraction.

Required knowledge includes:

* kernel
* processes
* threads
* scheduling
* memory
* virtual memory
* swap
* zram
* filesystems
* block devices
* mounts
* namespaces
* cgroups
* capabilities
* permissions
* ACLs
* extended attributes
* system calls
* signals
* `/proc`
* `/sys`
* `/run`
* `/etc`
* `/var`
* `/home`
* udev
* device management
* kernel modules
* firmware
* initramfs
* bootloaders
* systemd
* journald
* log rotation
* sockets
* networking
* DNS
* routing
* firewalling

When a NixOS abstraction behaves unexpectedly, investigate the underlying Linux mechanism.

---

# 13. systemd Expertise

The agent must understand:

* services
* targets
* sockets
* timers
* paths
* mounts
* automounts
* dependencies
* ordering
* conditions
* assertions
* restart policies
* watchdogs
* resource controls
* sandboxing
* namespaces
* `ProtectSystem`
* `ProtectHome`
* `PrivateTmp`
* `PrivateDevices`
* `NoNewPrivileges`
* `RestrictAddressFamilies`
* `CapabilityBoundingSet`
* `SystemCallFilter`
* `DynamicUser`
* `StateDirectory`
* `CacheDirectory`
* `RuntimeDirectory`
* `LogsDirectory`

Every persistent service should have explicit ownership.

---

# 14. systemd Service Standard

Every important service should have:

* owner
* purpose
* configuration source
* state location
* dependencies
* privilege model
* sandboxing
* restart policy
* health check
* logging
* recovery strategy
* resource limits
* network exposure definition

Example conceptual contract:

```text
Service
├── owner
├── configuration
├── state
├── runtime
├── dependencies
├── privileges
├── network
├── health
├── logs
├── restart
└── recovery
```

---

# 15. Filesystem Ownership

The agent must enforce:

> One persistent state path → one authoritative owner.

Examples:

```text
/var/lib/<service>
/var/cache/<service>
/run/<service>
/mnt/backup/<service>
```

Read-only access by another service is still a dependency.

A service must not silently reach into another domain's private state.

Prefer:

```text
service → contract → owner
```

over:

```text
service → arbitrary filesystem path
```

---

# 16. State Ownership

For every stateful component identify:

```text
State:
Owner:
Location:
Format:
Persistence:
Backup:
Restore:
Retention:
Encryption:
Consumers:
Recovery:
```

State ownership must be explicit.

---

# 17. KDE Plasma Expert Skills

KDE Plasma is treated as a complete desktop platform.

The agent must understand:

* KDE Plasma
* KDE Frameworks
* Qt
* KWin
* Wayland
* X11
* Plasma Shell
* KRunner
* Plasma widgets
* panels
* task manager
* application launcher
* global shortcuts
* activities
* virtual desktops
* window rules
* display configuration
* power management
* notifications
* portals
* file associations
* MIME
* KDE Connect
* Dolphin
* Konsole
* Discover
* SDDM
* PipeWire integration
* screen sharing
* desktop portals

The agent must understand the interaction between:

```text
KDE
Qt
Wayland
PipeWire
WirePlumber
xdg-desktop-portal
NetworkManager
systemd
GPU drivers
kernel
```

---

# 18. KDE Configuration Engineering

The agent must distinguish between:

```text
Nix-declared configuration
```

and:

```text
runtime KDE state
```

It must avoid creating fragile configuration that depends on manually clicking through KDE settings.

Where possible, configuration should be:

* declarative
* reproducible
* documented
* version controlled
* testable

---

# 19. KDE Visual/UX Engineering

The desktop must be treated as an operational interface.

The agent should understand:

* consistent theme application
* Qt theming
* icon themes
* cursor themes
* fonts
* window decorations
* Plasma style
* application styling
* launcher behavior
* panel layout
* transparency
* animations
* performance tradeoffs

The desired desktop may use the Garuda Mokka aesthetic, but visual configuration must not compromise:

* security
* performance
* maintainability
* accessibility
* reproducibility

---

# 20. Linux Desktop Troubleshooting

The agent must be capable of diagnosing:

* black screens
* login failures
* display manager failures
* GPU initialization
* Wayland failures
* X11 fallback
* monitor detection
* external display failures
* suspend/resume
* audio
* microphone
* Bluetooth
* Wi-Fi
* screen sharing
* camera access
* browser media permissions
* portals
* desktop application integration

Diagnosis must begin with evidence.

Examples:

```bash
systemctl status
journalctl
dmesg
lsmod
lspci
lsusb
loginctl
```

and relevant subsystem tools.

---

# 21. Audio Engineering

The agent must understand:

* ALSA
* PipeWire
* WirePlumber
* PulseAudio compatibility
* devices
* profiles
* sinks
* sources
* nodes
* routes
* permissions
* browser media integration

Troubleshooting should distinguish:

```text
hardware
↓
ALSA
↓
PipeWire
↓
WirePlumber
↓
desktop
↓
application
```

A browser microphone problem should not automatically be treated as a PipeWire problem.

---

# 22. Networking Engineering

Required expertise:

* Linux networking
* NetworkManager
* systemd-networkd
* routing
* DNS
* DHCP
* IPv4
* IPv6
* TCP
* UDP
* sockets
* ports
* nftables
* firewalling
* VLANs
* bridges
* tunnels
* VPNs
* Tailscale
* WireGuard
* exit nodes
* subnet routing
* DNS split-horizon
* service discovery

---

# 23. Tailscale Engineering

The agent must understand:

* Tailscale nodes
* tags
* ACLs
* SSH
* exit nodes
* subnet routes
* route approval
* device posture
* key expiry
* authentication
* MagicDNS
* Tailnet DNS
* WireGuard tunnels
* firewall interaction
* route precedence

Tailscale must not be treated as “just another VPN.”

Changes must consider:

```text
routing
firewall
DNS
SSH
service exposure
identity
device trust
exit-node behavior
```

---

# 24. Network Ownership

Ports and firewall rules must have singular ownership.

Avoid:

```text
domain A opens port 22
domain B also opens port 22
domain C assumes port 22
```

Instead:

```text
network/security owner
        ↓
declared service exposure
```

Every externally reachable service must have:

* owner
* purpose
* bind address
* port
* protocol
* firewall rule
* authentication
* authorization
* logging
* monitoring

---

# 25. Security Engineering

The agent must operate under defense-in-depth.

Security layers include:

```text
identity
authentication
authorization
least privilege
filesystem permissions
systemd sandboxing
AppArmor
nftables
Tailscale
secrets management
encryption
logging
monitoring
patching
backup
recovery
```

Security must be architectural rather than bolted on afterward.

---

# 26. Security Auditor Skills

The agent must be able to perform:

* configuration audits
* architecture audits
* dependency audits
* secret exposure audits
* filesystem ownership audits
* network exposure audits
* privilege audits
* systemd sandbox audits
* AppArmor audits
* firewall audits
* Tailscale audits
* backup security audits
* CI security audits
* supply-chain audits
* dependency vulnerability audits

The agent should actively look for:

```text
implicit trust
excessive privileges
undeclared dependencies
shared state
hardcoded credentials
hardcoded paths
hardcoded hosts
unnecessary ports
duplicate ownership
missing monitoring
missing recovery
```

---

# 27. SOPS and age

Secrets should follow:

```text
SOPS
 ↓
age encryption
 ↓
authorized runtime consumer
```

The agent must understand:

* encrypted files
* age identities
* key recipients
* decryption
* runtime secret injection
* permissions
* secret rotation
* backup of recovery material
* accidental secret exposure

Never print secrets into logs.

Never commit plaintext secrets.

Never place credentials in source code.

Never expose secret values during diagnostics.

---

# 28. AppArmor

The agent must understand:

* profiles
* abstractions
* permissions
* complain mode
* enforce mode
* denial logs
* profile maintenance
* application-specific confinement

AppArmor rules must not be used as a substitute for understanding application behavior.

---

# 29. Firewall Engineering

The agent must understand nftables concepts:

* tables
* chains
* hooks
* priorities
* policies
* sets
* counters
* state tracking
* interfaces
* addresses
* ports

Firewall rules must be:

* explicit
* minimal
* owned
* testable
* documented

---

# 30. SSH Security

The agent must understand:

* SSH keys
* authorized keys
* host keys
* agent forwarding
* bastions
* Tailscale SSH
* port exposure
* root login
* password authentication
* MFA/identity boundaries
* fail2ban
* session logging
* SSH hardening

Remote administration must preserve an emergency recovery path.

Security must never accidentally lock the owner out of the system.

---

# 31. SRE Engineering

The agent must apply SRE principles:

* reliability
* availability
* durability
* latency
* performance
* observability
* incident response
* error budgets
* capacity planning
* graceful degradation
* automation
* recovery
* rollback

Every production service should have:

```text
SLI
health
logs
metrics
alerts
recovery
rollback
```

where appropriate.

---

# 32. Reliability Engineering

The agent must ask:

> What happens when this fails?

For every component identify:

```text
failure
↓
detection
↓
containment
↓
recovery
↓
verification
↓
notification
```

Avoid designs where failure silently propagates.

---

# 33. Observability Engineering

The observability model should cover:

### Metrics

* CPU
* memory
* disk
* filesystem
* network
* service state
* deployment state
* application metrics
* health metrics

### Logs

* systemd journal
* service logs
* security logs
* deployment logs
* audit logs

### Health

* system health
* service health
* network health
* storage health
* deployment health
* backup health

### Tracing

Use tracing where system complexity justifies it.

---

# 34. Prometheus

The agent must understand:

* exporters
* scrape targets
* labels
* cardinality
* recording rules
* alerts
* service discovery
* retention
* resource usage

Avoid unnecessary high-cardinality metrics.

---

# 35. Grafana

The agent must understand:

* dashboards
* panels
* variables
* data sources
* alerting
* operational dashboards

Dashboards should answer operational questions rather than merely look impressive.

---

# 36. Loki / Log Aggregation

The agent must understand:

* log collection
* labels
* retention
* queryability
* resource usage
* structured logs
* correlation with metrics

Do not create excessive labels.

---

# 37. Backup Engineering

The agent must understand:

* backup strategy
* snapshots
* encryption
* retention
* off-host copies
* restore testing
* backup monitoring
* backup integrity
* disaster recovery

A backup is not considered valid merely because a backup command succeeded.

A backup is valid when it can be restored.

---

# 38. Disaster Recovery

Every important stateful service should answer:

```text
What is backed up?
Where is it backed up?
How is it encrypted?
How do we restore it?
How long does restoration take?
What happens if the primary host is lost?
What credentials are required?
What bootstrap dependencies exist?
```

The agent must design for catastrophic failure, not merely routine failure.

---

# 39. Oracle Edge / Secondary Infrastructure

Where an ARM64 secondary node exists, it should be treated as an independent recovery and service platform rather than an uncontrolled copy of the laptop.

Potential responsibilities include:

* emergency access
* Tailscale
* SSH
* external monitoring
* watchdog functionality
* backup exit-node capability
* encrypted backup
* secrets/recovery-material storage
* API gateway
* webhook receiver
* alerting
* always-on web interface

The secondary system should remain lightweight and hardened.

---

# 40. GitOps

The desired deployment model is:

```text
Git change
    ↓
TDD
    ↓
local verification
    ↓
branch
    ↓
MR
    ↓
CI
    ↓
merge
    ↓
GitOps reconciliation
    ↓
generation selection
    ↓
health validation
    ↓
observe
    ↓
rollback if necessary
```

Deployment is separate from code acceptance.

---

# 41. Ivali Flow

All repository Git lifecycle operations must follow the Ivali Flow.

The AI must not casually bypass the workflow with raw:

```bash
git commit
git push
git merge
```

when the repository's `ivali flow` tooling is responsible for those operations.

The workflow exists to guarantee:

* traceability
* validation
* authorship
* CI
* architecture enforcement
* safe deployment
* rollback

---

# 42. Git Engineering

The agent must understand:

* branches
* merge requests
* rebasing
* conflicts
* commit history
* CI status
* protected branches
* release branches
* canary branches
* rollback commits

The AI must never rewrite history destructively without explicit authorization.

---

# 43. Canary

