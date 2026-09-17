# Stabilization Matrix — Gate Coverage & Evidence Contract

**Document:** `STABILIZATION-MATRIX.md`
**Purpose:** Define the verification, security, architecture, deployment, and operational gates that constitute the stabilized `nixos-infrastructure` baseline.

**Status:** Active stabilization contract
**Baseline:** P0–P4 stabilization complete
**Primary host:** `prague`
**Next migration:** GNOME → KDE Plasma
**Strategic runtime migration:** Go → Elixir/OTP
**Authority:** `STABILIZATION.md`, `ARCHITECTURE.md`, `ARCHITECTURE_AUDIT.md`, `IVALi_FLOW.md`

---

## 1. Purpose

This document is the **machine-oriented gate coverage matrix** for the stabilization baseline.

It answers five questions:

1. **What is tested?**
2. **Where is it tested?**
3. **Does failure block progression?**
4. **What evidence proves the gate passed?**
5. **What remains intentionally outside the current gate?**

The matrix is a contract between:

* local development;
* `ivali flow`;
* architecture enforcement;
* GitLab CI;
* GitHub Actions;
* GitOps reconciliation;
* manual rebuild operations;
* deployment health checks;
* rollback and recovery workflows.

A gate is not considered complete merely because a command exists.

A gate is complete only when its:

> **definition + execution + failure behavior + evidence**

are understood and aligned.

---

# 2. Stabilization Principle

The stabilization baseline follows this invariant:

> **Code must be verified before acceptance. A system must be verified before deployment. A deployment must be verified before it is considered successful.**

The lifecycle is:

```text
Change
  ↓
Local verification
  ↓
Architecture verification
  ↓
CI verification
  ↓
Ivali Flow acceptance
  ↓
Merge
  ↓
GitOps reconciliation
  ↓
Build
  ↓
Activation
  ↓
Post-deployment health
  ↓
Observe
  ↓
Rollback if required
```

No stage should implicitly assume that a previous stage succeeded.

---

# 3. Gate Classification

Every gate belongs to one or more of these classes.

| Class                   | Purpose                                          |
| ----------------------- | ------------------------------------------------ |
| Formatting              | Detect formatting drift                          |
| Static analysis         | Detect code and configuration defects            |
| Compilation             | Prove source can be built                        |
| Unit/regression testing | Prove expected behavior                          |
| Security                | Detect known security weaknesses                 |
| Architecture            | Enforce architectural boundaries                 |
| Nix evaluation          | Prove configuration evaluates                    |
| Nix build               | Prove deployable system can be built             |
| Host validation         | Prove configuration targets the intended machine |
| Deployment safety       | Prevent unsafe activation                        |
| Health                  | Prove runtime system is operational              |
| Recovery                | Prove failed deployments can recover             |
| Operational diagnostics | Explain current machine state                    |
| Migration               | Prove a system change is safe to introduce       |

---

# 4. Gate States

The following status vocabulary is authoritative.

| Status     | Meaning                                      |
| ---------- | -------------------------------------------- |
| ✅ PASS     | Gate exists and is currently enforced        |
| 🟡 WARN    | Gate runs but does not block progression     |
| ⚪ OPT-IN   | Gate exists but requires explicit invocation |
| 🔴 FAIL    | Gate currently prevents progression          |
| ❌ MISSING  | Required gate does not exist                 |
| N/A        | Gate does not apply to the execution surface |
| HISTORICAL | Former gap that has been remediated          |

A historical gap must **not** be represented as a current stabilization blocker.

---

# 5. Local Gate Coverage

## 5.1 Developer Validation Surfaces

| Gate                             | `flow validate` | `flow run` | `flow quick` | `ivali verify` | `ivali doctor` |      Blocking?     |
| -------------------------------- | :-------------: | :--------: | :----------: | :------------: | :------------: | :----------------: |
| `nix fmt -- --check .`           |        ✅        |      ✅     |       ✅      |        ✅       |        ✅       |         Yes        |
| `shellcheck --severity=warning`  |        ✅        |      ✅     |       ✅      |        —       |        —       |         Yes        |
| `go build ./...`                 |        ✅        |      ✅     |       ✅      |        —       |        —       |         Yes        |
| `go vet ./...`                   |        ✅        |      ✅     |       ✅      |        —       |        —       |         Yes        |
| `go test -race -count=1 ./...`   |        ✅        |      ✅     |       ✅      |        —       |        —       |         Yes        |
| `gosec -exclude-generated ./...` |        ✅        |      ✅     |       ✅      |        —       |        —       |         Yes        |
| `nix flake check --no-build`     |        ✅        |      ✅     |       ✅      |        ✅       |        ✅       |         Yes        |
| Host `nix eval`                  |    ⚪ `--host`   |      ⚪     |       ⚪      |        —       |        —       | Yes when requested |
| Architecture linter              |        ✅        |      ✅     |       ✅      |        ✅       |        ✅       |         Yes        |
| `deadnix`                        |        —        |      —     |       —      |        —       |        ✅       |     Diagnostic     |
| `statix`                         |        —        |      —     |       —      |        —       |        ✅       |     Diagnostic     |
| Duplicate imports                |        —        |      —     |       —      |        ✅       |        ✅       |         Yes        |
| Orphan modules                   |        —        |      —     |       —      |        ✅       |        ✅       |         Yes        |
| Security diagnostics             |        —        |      —     |       —      |        ✅       |        ✅       |         Yes        |
| Runtime/system health            |        —        |      —     |       —      |        —       |        ✅       | Yes for deployment |

### Local contract

`flow validate`, `flow quick`, and `flow run` must measure the same **core seven-gate source validation suite**:

1. Nix formatting
2. ShellCheck
3. Go build
4. Go vet
5. Go race tests
6. gosec
7. Nix flake validation

Host-specific evaluation remains an explicit host gate because it requires selecting a concrete NixOS configuration.

---

# 6. Core Seven-Gate Suite

The core local suite is:

```text
1. nix fmt -- --check .
2. shellcheck --severity=warning
3. go build ./...
4. go vet ./...
5. go test -race -count=1 ./...
6. gosec -exclude-generated ./...
7. nix flake check --no-build
```

These gates establish **source-level acceptance**.

They do not by themselves prove that a deployment is safe.

The distinction is intentional:

```text
Source correctness
        ≠
Configuration evaluation
        ≠
Deployment safety
        ≠
Runtime health
```

---

# 7. Host Evaluation Gate

Host evaluation is:

```bash
nix eval .#nixosConfigurations.<host>.config.system.build.toplevel.name
```

or the equivalent `flow validate --host` path.

It verifies that the selected NixOS host configuration evaluates successfully.

For `prague`, the authoritative host target is:

```text
.#nixosConfigurations.prague
```

Host evaluation must occur before a deployment is allowed to activate a new system generation.

---

# 8. Architecture Gate

Architecture enforcement is a mandatory stabilization gate.

It verifies at minimum:

* forbidden imports;
* circular dependencies;
* filesystem boundaries;
* duplicate ownership;
* declared dependencies;
* internal API boundaries;
* service-state ownership.

Architecture is represented through:

```text
architecture/
├── domains.yaml
├── dependencies.yaml
└── exceptions.yaml
```

The governing invariant is:

> **Hosts compose capabilities. Domains own capabilities. Services expose contracts. Infrastructure adapters implement those contracts.**

The architecture linter is not merely documentation validation.

It is a **change-control mechanism**.

---

# 9. State Ownership Gate

The stabilization baseline requires:

> **One state path → one owner.**

State ownership must be explicit for:

* GitOps state;
* backup state;
* service state;
* secrets;
* generated configuration;
* caches;
* deployment metadata;
* recovery metadata.

In particular:

```text
/var/lib/gitops
```

must have a single authoritative owner.

Observability may consume state, but must not become an accidental owner of another subsystem's state.

---

# 10. CI Gate Coverage

## 10.1 GitLab CI

| Gate                           | GitLab CI | Enforcement                           |
| ------------------------------ | :-------: | ------------------------------------- |
| `nix fmt -- --check .`         |     ✅     | Blocking                              |
| ShellCheck                     |     ✅     | Blocking                              |
| `golangci-lint run`            |     ✅     | Blocking                              |
| Architecture linter            |     ✅     | Blocking                              |
| `go build ./...`               |     ✅     | Blocking                              |
| `go vet ./...`                 |     ✅     | Blocking                              |
| `go test -race -count=1 ./...` |     ✅     | Blocking                              |
| `gosec`                        |     ✅     | Blocking                              |
| `nix flake check --no-build`   |     ✅     | Blocking                              |
| Host `nix eval`                |     ✅     | Blocking                              |
| CI summary                     |     ✅     | Blocking                              |
| Deployment gate                |     ✅     | Blocking when deployment path invoked |

---

## 10.2 GitHub Actions

| Gate                           | GitHub Actions | Enforcement              |
| ------------------------------ | :------------: | ------------------------ |
| `nix fmt -- --check .`         |        ✅       | Blocking                 |
| ShellCheck                     |        ✅       | Blocking                 |
| `golangci-lint run`            |        ✅       | Blocking                 |
| Architecture linter            |        ✅       | Blocking                 |
| `go build ./...`               |        ✅       | Blocking                 |
| `go vet ./...`                 |        ✅       | Blocking                 |
| `go test -race -count=1 ./...` |        ✅       | Blocking                 |
| `gosec`                        |        ✅       | Blocking                 |
| `nix flake check --no-build`   |        —       | Not currently duplicated |
| Host `nix eval`                |        —       | Not currently duplicated |
| CI summary                     |        —       | Provider-specific        |

GitHub Actions is therefore a **secondary CI surface**, not an assumption that every GitLab deployment gate must be duplicated identically.

The authoritative deployment path remains the repository's defined Ivali Flow + GitLab/GitOps workflow.

---

# 11. CI Security Gate

Security scanning must be consistent across:

```text
local
    ↓
GitLab
    ↓
GitHub
```

The same intended `gosec` rule/exclusion policy must be used.

A security scanner that runs but is permitted to fail silently is not an equivalent security gate.

Current stabilization contract:

> **gosec failures are blocking.**

Exceptions must be:

1. explicit;
2. documented;
3. reviewed;
4. narrowly scoped;
5. represented in the appropriate repository policy/configuration.

---

# 12. Deployment Gate Coverage

| Gate                              |     GitOps Reconcile     |       `rebuild.sh`       |      `ci-deploy.sh`      |
| --------------------------------- | :----------------------: | :----------------------: | :----------------------: |
| Lock acquisition                  |             ✅            |             —            |             ✅            |
| Dirty-tree guard                  |             ✅            |             —            |             ✅            |
| `git fetch`                       |             ✅            |             ✅            |             —            |
| Repository integrity / `git fsck` |             ✅            |             —            |             —            |
| Rebase / synchronization          |             ✅            |             ✅            |             —            |
| Hardware UUID verification        |             ✅            |             ✅            |             ✅            |
| Go vendor hash verification       |             ✅            |       ✅ conditional      |             ✅            |
| Nix flake check                   |             ✅            |             ✅            |             ✅            |
| Nix host evaluation               |             ✅            |             ✅            |             ✅            |
| Nix build                         |             ✅            |         implicit         |             ✅            |
| `nixos-rebuild switch`            |             ✅            |             ✅            |             ✅            |
| Post-deployment health            |             ✅            |             —            |             ✅            |
| Rollback                          |             ✅            |             —            |             ✅            |
| Deployment notification           | implementation-dependent | implementation-dependent | implementation-dependent |

---

# 13. Deployment Safety Model

Deployment is considered successful only after:

```text
PRE-FLIGHT
    ↓
Repository integrity
    ↓
Configuration validation
    ↓
Host evaluation
    ↓
Hardware identity validation
    ↓
Build
    ↓
Activation
    ↓
Health validation
    ↓
SUCCESS
```

If activation succeeds but health validation fails:

```text
Activation
    ↓
Health failure
    ↓
Rollback decision
    ↓
Known-good generation
    ↓
Health validation
    ↓
Recovery
```

Therefore:

> **`nixos-rebuild switch` succeeding is not equivalent to deployment success.**

---

# 14. Combined Gate View

| Scenario        | fmt | shell | build | vet | test | gosec |    flake   | eval |    arch    |     HW     | build system | health |  rollback  |
| --------------- | :-: | :---: | :---: | :-: | :--: | :---: | :--------: | :--: | :--------: | :--------: | :----------: | :----: | :--------: |
| `flow validate` |  ✅  |   ✅   |   ✅   |  ✅  |   ✅  |   ✅   |      ✅     |   ⚪  |      ✅     |      —     |       —      |    —   |      —     |
| `flow quick`    |  ✅  |   ✅   |   ✅   |  ✅  |   ✅  |   ✅   |      ✅     |   ⚪  |      ✅     |      —     |       —      |    —   |      —     |
| `flow run`      |  ✅  |   ✅   |   ✅   |  ✅  |   ✅  |   ✅   |      ✅     |   ⚪  |      ✅     |      —     |       —      |    —   |      —     |
| GitLab CI       |  ✅  |   ✅   |   ✅   |  ✅  |   ✅  |   ✅   |      ✅     |   ✅  |      ✅     |      —     |       —      |    —   |      —     |
| GitHub CI       |  ✅  |   ✅   |   ✅   |  ✅  |   ✅  |   ✅   |      ✅     |   —  |      ✅     |      —     |       —      |    —   |      —     |
| GitOps deploy   |  —  |   —   |   —   |  —  |   —  |   —   |      ✅     |   ✅  |      —     |      ✅     |       ✅      |    ✅   |      ✅     |
| Manual rebuild  |  —  |   —   |   —   |  —  |   —  |   —   |      ✅     |   ✅  |      —     |      ✅     |       ✅      |    —   |      —     |
| CI deploy       |  —  |   —   |   —   |  —  |   —  |   —   |      ✅     |   ✅  |      —     |      ✅     |       ✅      |    ✅   |      ✅     |
| `ivali verify`  |  —  |   —   |   —   |  —  |   —  |   —   |      ✅     |   —  |      ✅     |      —     |       —      |    —   |      —     |
| `ivali doctor`  |  —  |   —   |   —   |  —  |   —  |   —   | diagnostic |   —  | diagnostic | diagnostic |  diagnostic  |    ✅   | diagnostic |

`⚪` = host evaluation available when explicitly requested.

---

# 15. Operational Diagnostics

`ivali doctor` is intentionally different from `flow validate`.

It answers:

> **What is happening on this machine?**

rather than:

> **Is this source tree acceptable?**

Diagnostics may cover:

* SOPS/age availability;
* `/run/secrets`;
* Restic state;
* current NixOS generation;
* disk capacity;
* service state;
* CPU/RAM;
* networking;
* deployment state;
* security state;
* architecture state;
* dead Nix code;
* orphan modules;
* duplicate imports.

A diagnostic warning is not automatically equivalent to a source-code failure.

The command's exit behavior must therefore distinguish:

```text
fatal operational condition
        vs.
degraded but survivable condition
        vs.
informational warning
```

---

# 16. Health Gate

The health gate is the final deployment acceptance barrier.

It must validate the **running system**, not merely the build artifact.

At minimum, deployment health should establish:

* expected system generation is active;
* critical services are running;
* required secrets are available;
* storage is usable;
* required network paths are operational;
* GitOps state is coherent;
* deployment state is not partially applied;
* no critical failure condition is present.

A deployment must not be declared healthy solely because:

```bash
nixos-rebuild switch
```

returned exit code `0`.

---

# 17. Rollback Gate

Rollback is part of deployment correctness.

The stabilization baseline therefore treats:

```text
deployability
+
health validation
+
rollback capability
```

as one reliability unit.

Rollback controls include the established hysteresis protections:

* commit-count delta cap;
* consecutive rollback guard;
* last-rollback timestamp;
* prevention of uncontrolled rollback loops.

The goal is:

> **A bad generation must be recoverable without creating an automated rollback loop.**

---

# 18. Historical Gaps — Remediated

The following issues were identified during stabilization and are retained as historical audit records.

They are **not current blockers**.

## G1 — `flow quick` gate incompleteness

**Original problem:** `flow quick` omitted several full validation gates.

**Risk:** local success could diverge from CI.

**Resolution:** the full seven-gate local suite was aligned.

**Status:** HISTORICAL / FIXED — 6 September 2026.

---

## G2 — `flow run` gate incompleteness

**Original problem:** `flow run` did not execute the full validation suite.

**Resolution:** aligned with the core seven-gate suite.

**Status:** HISTORICAL / FIXED — 6 September 2026.

---

## G3 — CI deployment gate divergence

**Original problem:** `ci-deploy.sh` had fewer pre-flight and deployment checks than GitOps reconciliation.

**Resolution:** added:

* flake validation;
* host evaluation;
* Go vendor hash verification;
* health validation;
* rollback behavior.

`TimeoutStartSec` was also increased from 300 seconds to 3600 seconds.

**Status:** HISTORICAL / FIXED — 6 September 2026.

---

## G4 — Non-blocking `gosec`

**Original problem:** security findings could fail without blocking progression.

**Resolution:** security scanning is now blocking and uses aligned rule/exclusion behavior.

**Status:** HISTORICAL / FIXED — 6 September 2026.

---

## G5 — Architecture enforcement limited to GitLab

**Original problem:** architecture validation was not consistently enforced across CI surfaces.

**Resolution:** GitHub Actions received a dedicated architecture-check job.

**Status:** HISTORICAL / FIXED — 6 September 2026.

---

## G6 — Missing MR pipeline treated as success

**Original problem:** `flow merge` could treat a missing pipeline as successful.

**Resolution:** `flow merge` now waits for the MR pipeline and fails when no pipeline appears.

**Status:** HISTORICAL / FIXED.

---

# 19. P4 — CI Deploy-Gate Alignment

**Status:** ✅ COMPLETE

**Date:** 6 September 2026

The P4 objective was:

> Bring the CI deployment path to functional parity with the established GitOps deployment safety model.

Completed controls:

1. `nix flake check --no-build`
2. host `nix eval`
3. Go vendor hash verification
4. hardware UUID validation
5. build validation
6. deployment activation
7. post-deployment health
8. rollback on failure
9. deployment timeout extended to 3600 seconds

This closes the stabilization P4 deployment-gate gap.

---

# 20. Stabilization Evidence Baseline

The stabilization baseline was verified on `prague` using generation:

```text
26.11.20260829.d2f6794
```

Recorded evidence:

| Verification                               | Result                                   |
| ------------------------------------------ | ---------------------------------------- |
| `ivali doctor`                             | 51/52; CPU warning only; exit 0          |
| `ivali verify`                             | PASS                                     |
| `nix fmt -- --check .`                     | PASS; 0/219 reformatted                  |
| `nix flake check --no-build`               | PASS                                     |
| `nix eval .#nixosConfigurations.prague...` | PASS                                     |
| `go build ./...`                           | PASS                                     |
| `go vet ./...`                             | PASS                                     |
| `go test -race -count=1 ./...`             | PASS                                     |
| `bash -n scripts/*.sh`                     | PASS                                     |
| `gosec`                                    | Available and executable; version 2.29.0 |
| Live `/etc/nix/nix.conf`                   | Verified clean                           |
| Attic poison                               | Absent                                   |
| `timeout = 60`                             | Absent                                   |

---

# 21. Nix Configuration Integrity

The live machine configuration must not contain obsolete or poisoned configuration.

The stabilization evidence explicitly confirmed:

```text
cache.codlet-trench.ts.net
```

was absent from live Nix configuration.

The obsolete:

```text
timeout = 60
```

configuration was also absent.

The live substituter configuration was verified against the intended baseline.

This is important because:

> **Repository correctness does not guarantee runtime configuration correctness.**

The generated/live configuration must therefore be checked after deployment.

---

# 22. Stabilization vs Migration

Stabilization establishes the baseline.

It does **not** authorize the next migration automatically.

The current relationship is:

```text
STABILIZATION
     │
     │ establishes known-good baseline
     ▼
MIGRATION-READINESS
     │
     ├───────────────┐
     ▼               ▼
GNOME → KDE       Go → Elixir/OTP
```

The KDE migration and Elixir/OTP migration are separate change tracks.

Neither should weaken the stabilization gates.

---

# 23. KDE Migration Gate

The GNOME → KDE migration must preserve the stabilization invariants.

The migration must additionally validate:

### Desktop platform

* KDE Plasma session;
* KWin;
* Wayland/X11 behavior as required;
* SDDM;
* D-Bus;
* XDG portals;
* PipeWire;
* WirePlumber;
* NetworkManager;
* Bluetooth;
* external displays;
* suspend/resume.

### User experience

* Garuda Mokka theme;
* KDE-native application integration;
* Firefox + Sidebery;
* launcher/application workflow;
* desktop notifications;
* file manager integration;
* clipboard;
* screenshots;
* screen sharing;
* audio input/output.

### Remote administration

If GUI remote access is introduced:

```text
Remote client
     ↓
Tailscale
     ↓
authenticated RDP/service boundary
     ↓
KDE session
```

Remote access must not bypass the existing security model.

---

# 24. Elixir/OTP Migration Gate

Elixir/OTP remains a **future migration track**.

Stabilization does not authorize replacing the Go control plane.

Before migration:

* service contracts must be documented;
* ownership boundaries must remain unchanged;
* architecture dependencies must remain valid;
* observability contracts must be preserved;
* recovery behavior must be defined;
* supervision trees must be designed;
* failure semantics must be documented;
* migration must be incremental;
* rollback must remain possible.

The first Elixir service should be migrated only after the architecture gate in `MIGRATION-READINESS.md` is satisfied.

---

# 25. Security and Secrets Gate

Stabilization requires:

* SOPS/age integration to remain functional;
* secrets not committed in plaintext;
* generated secrets not exposed through logs;
* break-glass procedures documented;
* service credentials scoped to purpose;
* Tailscale treated as transport rather than blanket authorization;
* host firewall enforcement retained;
* privileged operations explicitly bounded.

A successful build with broken secret delivery is **not** a healthy deployment.

---

# 26. Resource-Constrained Host Considerations

`prague` is a constrained workstation.

The stabilization model therefore distinguishes:

```text
correctness
from
performance
from
resource pressure
```

A CPU or memory warning does not automatically mean the system is invalid.

For example:

```text
CPU warning
    ↓
diagnostic condition
    ↓
not necessarily deployment failure
```

However, resource pressure becomes a blocking condition when it causes:

* service failure;
* deployment failure;
* repeated OOM conditions;
* inability to complete required builds;
* degraded recovery;
* unsafe thermal/power behavior;
* persistent system instability.

---

# 27. Required Evidence Standard

Every stabilization claim must be backed by one of:

1. command output;
2. CI job result;
3. deployment log;
4. health-check result;
5. test result;
6. architecture-linter result;
7. runtime observation;
8. documented operator verification.

The following are prohibited:

```text
"should pass"
"looks good"
"probably fixed"
"CI should catch it"
"deployment appears healthy"
```

unless clearly identified as an unverified assumption.

---

# 28. No Evidence, No Claim

The engineering rule is:

> **No evidence → no completion claim.**

An AI agent, developer, or automation process must not claim:

* tests passed;
* CI passed;
* deployment succeeded;
* health passed;
* rollback succeeded;
* architecture is compliant;

unless the relevant evidence exists.

---

# 29. Gate Ownership

| Area                 | Primary Authority                     |
| -------------------- | ------------------------------------- |
| Source validation    | `ivali flow`                          |
| Architecture         | Architecture linter + `architecture/` |
| CI acceptance        | GitLab CI / repository CI contract    |
| Secondary CI         | GitHub Actions                        |
| Git lifecycle        | Ivali Flow                            |
| Deployment           | GitOps / deployment scripts           |
| Runtime health       | `ivali doctor` + health services      |
| Recovery             | rollback/recovery subsystem           |
| Secrets              | SOPS/age                              |
| Network trust        | Tailscale + firewall                  |
| System configuration | NixOS                                 |
| Desktop              | KDE Plasma migration track            |
| Runtime migration    | `MIGRATION-READINESS.md`              |

---

# 30. Current Stabilization Status

| Area                           | Status                            |
| ------------------------------ | --------------------------------- |
| P0 Foundation                  | ✅ COMPLETE                        |
| P1 Operations                  | ✅ COMPLETE                        |
| P2 Rollback hysteresis         | ✅ COMPLETE                        |
| P3 Doctor runtime              | ✅ COMPLETE                        |
| P4 CI deploy gate              | ✅ COMPLETE                        |
| Core local gates               | ✅ ALIGNED                         |
| Security gate                  | ✅ BLOCKING                        |
| Architecture enforcement       | ✅ ENFORCED                        |
| CI deployment alignment        | ✅ COMPLETE                        |
| Runtime health gate            | ✅ OPERATIONAL                     |
| Rollback protection            | ✅ OPERATIONAL                     |
| GNOME → KDE migration          | 🟡 NEXT GATE                      |
| Go → Elixir/OTP                | 🔒 BLOCKED ON MIGRATION READINESS |
| SOPS break-glass               | 🟡 OPERATOR ITEM                  |
| Real hardware audio validation | 🟡 OPERATOR ITEM                  |

---

# 31. Remaining Open Items

Only genuinely unresolved items belong here.

### O1 — SOPS break-glass key

**Status:** Operator action required.

The procedure, storage location, and recovery process require explicit operator handling.

This is not an AI-autonomous task.

---

### O2 — Real hardware audio validation

**Status:** Operator/hardware validation required.

Firefox/Google Meet microphone and audio behavior must be validated against real microphone hardware.

Software-level configuration can be tested independently, but real hardware acceptance requires the hardware path.

---

### O3 — KDE migration acceptance

**Status:** Pending.

The stabilization baseline is established, but GNOME → KDE remains a separate migration gate.

---

### O4 — Elixir/OTP architecture approval

**Status:** Pending / blocked.

No production migration of the Go runtime should begin until the architecture and migration gates are satisfied.

---

# 32. Future Gate Additions

The following should be considered future enhancements rather than current stabilization blockers unless explicitly promoted into the acceptance contract:

* integration tests against real deployment environments;
* KDE desktop integration tests;
* graphical-session health checks;
* PipeWire functional tests;
* Bluetooth functional tests;
* suspend/resume verification;
* external display verification;
* RDP functional tests;
* disaster-recovery drills;
* backup restoration tests;
* Oracle ARM64 `oracle-edge` validation;
* cross-architecture CI;
* Elixir/OTP dual-run validation;
* service contract compatibility tests.

---

# 33. Stabilization Invariant

The stabilization contract is:

```text
Source
  ↓
Format
  ↓
Static analysis
  ↓
Build
  ↓
Unit/regression tests
  ↓
Security
  ↓
Architecture
  ↓
Nix evaluation
  ↓
Nix build
  ↓
Deployment safety
  ↓
Activation
  ↓
Health
  ↓
Recovery capability
```

A system is stabilized only when the required gates for its lifecycle stage are satisfied.

---

# 34. Relationship to Other Documents

| Document                   | Role                                          |
| -------------------------- | --------------------------------------------- |
| `ARCHITECTURE.md`          | Defines intended architecture                 |
| `ARCHITECTURE_AUDIT.md`    | Records current architectural conformance     |
| `ARCHITECTURE_PROGRESS.md` | Tracks architecture migration                 |
| `STABILIZATION.md`         | Records the known-good stabilization baseline |
| `STABILIZATION-MATRIX.md`  | Defines gate coverage and evidence            |
| `MIGRATION-READINESS.md`   | Determines whether migrations may begin       |
| `IVALi_FLOW.md`            | Defines engineering and deployment lifecycle  |

These documents must not contradict one another.

The hierarchy is:

```text
ARCHITECTURE
     ↓
STABILIZATION
     ↓
STABILIZATION-MATRIX
     ↓
MIGRATION-READINESS
     ↓
IVALi FLOW execution
```

Where implementation differs from the intended architecture, the audit/progress documents record the difference rather than silently redefining the architecture.

---

# 35. Final Stabilization Statement

The stabilization matrix establishes the verification contract for the `nixos-infrastructure` platform.

The current baseline establishes:

```text
P0 Foundation              COMPLETE
P1 Operations              COMPLETE
P2 Rollback Hysteresis     COMPLETE
P3 Doctor Runtime          COMPLETE
P4 CI Deploy Gate          COMPLETE
```

The system therefore has a defined baseline for:

* source validation;
* architecture enforcement;
* security validation;
* Nix evaluation;
* deployment;
* health verification;
* rollback;
* operational diagnostics.

The next change is not considered part of stabilization merely because it uses the stabilized system.

In particular:

> **GNOME → KDE is a controlled desktop migration.**

and:

> **Go → Elixir/OTP is a controlled runtime migration.**

Both must preserve the stabilization contract.

The stabilization baseline is therefore:

> **Known-good, evidence-backed, deployable, observable, and recoverable.**

Any future migration must demonstrate that it preserves these properties before the migration can become part of the new baseline.

