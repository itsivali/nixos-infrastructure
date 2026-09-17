# Stabilization — Acceptance Record

**Milestone:** `nixos-infrastructure` stabilization — P0 → P1
**Baseline date:** 5 September 2026
**Primary host:** `prague`
**Hardware at baseline:** AMD A6-9225, 2 cores, 4 GiB RAM
**NixOS:** 26.11
**Repository:** `nixos-infrastructure`

---

# 1. Purpose

This document records the stabilization baseline of the `nixos-infrastructure` repository.

It serves three purposes:

1. **Record what was fixed and why.**
2. **Provide reproducible evidence that the platform reached a known-good baseline.**
3. **Define the baseline that future migrations must not regress.**

This stabilization milestone is a prerequisite for subsequent platform work, particularly:

```text
Stabilization
     ↓
GNOME → KDE Plasma
     ↓
KDE operational stabilization
     ↓
Elixir/OTP architecture approval
     ↓
Incremental Go → Elixir/OTP migration
```

The Elixir/OTP migration is therefore **not a stabilization mechanism**.

> **Migration is allowed only after the existing platform has demonstrated that it can operate correctly without the migration.**

---

# 2. Stabilization Philosophy

The stabilization program follows five principles.

### 2.1 Reproduce before fixing

A reported failure must be reproduced where practical before changing the implementation.

### 2.2 Test before implementation

New behavior and bug fixes follow:

```text
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

### 2.3 Configuration is production code

Nix expressions, systemd units, firewall rules, secrets wiring, scripts, and CI configuration are treated as production code.

A syntactically valid configuration is not sufficient.

It must also:

* evaluate;
* build;
* activate;
* behave correctly;
* recover correctly;
* remain observable.

### 2.4 Evidence beats assumption

Acceptance status is based on evidence from:

1. current repository state;
2. automated tests;
3. architecture checks;
4. Nix evaluation/build results;
5. runtime verification;
6. CI;
7. operator validation.

Documentation alone does not prove operational correctness.

### 2.5 Stabilization must be reversible

Every stabilization change must preserve:

* NixOS generation rollback;
* Git history;
* service recovery;
* secret recovery;
* operational diagnostics.

---

# 3. Milestone Status

## Stabilization State

```text
P0  Foundation             COMPLETE
P1  Operations             COMPLETE
P2  Rollback Hysteresis    COMPLETE
P3  Doctor Runtime         COMPLETE
P4  CI Deploy-Gate         COMPLETE
P5  Elixir/OTP Refactor    NOT STARTED / BLOCKED
```

### Interpretation

| Milestone | Status     | Meaning                                                      |
| --------- | ---------- | ------------------------------------------------------------ |
| P0        | ✅ Complete | Fundamental configuration/runtime defects resolved           |
| P1        | ✅ Complete | Operational diagnostics and reliability controls established |
| P2        | ✅ Complete | Rollback loop protection implemented and tested              |
| P3        | ✅ Complete | Runtime health diagnostics implemented                       |
| P4        | ✅ Complete | CI deployment gates aligned with GitOps gates                |
| P5        | ⛔ Blocked  | Elixir/OTP work remains gated by `MIGRATION-READINESS.md`    |

The previous record described P4 as both `BACKLOG` and `DONE`. This document resolves that inconsistency:

> **P4 is considered complete based on the subsequent CI deployment-gate implementation.**

---

# 4. Stabilization Exit Criteria

The stabilization baseline is considered operationally established when the following categories are green.

## Foundation

* [x] Nix configuration evaluates.
* [x] Flake validates.
* [x] Host configuration evaluates.
* [x] Formatting is clean.
* [x] Critical configuration defects are resolved.

## Runtime

* [x] Go application builds.
* [x] Go tests pass.
* [x] Race-enabled tests pass.
* [x] Runtime diagnostics execute.
* [x] Systemd/service health can be inspected.
* [x] Rollback logic is guarded against loops.

## Security

* [x] Nix security configuration is functional.
* [x] SOPS runtime secret wiring works.
* [x] Security scanner false-positive behavior is covered by tests.
* [x] `gosec` executes successfully.
* [ ] Break-glass SOPS recovery mechanism finalized and tested.

## Deployment

* [x] NixOS deployment evaluates.
* [x] Deployment gate performs required validation.
* [x] Health validation exists.
* [x] Rollback validation exists.
* [x] GitOps reconciliation remains operational.
* [x] CI gate parity is established.

## Desktop

* [ ] Real-hardware microphone verification complete.
* [ ] Google Meet/Firefox media verification complete.
* [ ] GNOME → KDE migration separately validated before desktop cutover.

The desktop items are intentionally **not treated as proof of infrastructure instability**. They are operator-level acceptance items for the workstation platform and must be completed before declaring the desktop migration baseline complete.

---

# 5. P0 — Foundation Stabilization

## 5.1 Attic Cache Configuration Poisoning

**Commit:** `e548a64`
**Classification:** Configuration + runtime

### Failure

`cache/default.nix` generated:

```text
trusted-public-keys = cache.codlet-trench.ts.net-1:
```

when the configured public key was empty.

This produced an invalid Nix trusted-key entry and caused uncached Nix operations to fail with a corrupt-key error.

The defect affected operations including:

* `nix run`;
* CI jobs;
* uncached dependency retrieval;
* other Nix operations requiring a valid configuration.

### Contributing failure

The repository also contained an invalid `attic-server` service definition.

The service attempted to invoke an obsolete/incorrect `atticd` command form and entered a restart/crash loop.

This obscured the underlying cache-key configuration problem.

### Root cause

The cache feature had existed since commit `6953253`.

A later change renamed `attic` to `atticd` in commit `0dda834`, but did not resolve the underlying configuration/service-model mismatch.

### Fix

`cache/default.nix` now uses a fail-safe condition equivalent to:

```text
cache enabled
AND
public key is non-empty
```

before generating cache trust configuration.

The server-side options and broken `attic-server` unit were removed.

Related documentation and scripts were updated.

### Result

An empty cache public key no longer poisons the generated Nix configuration.

The cache configuration therefore follows:

> **Invalid/incomplete cache configuration must fail closed rather than generate invalid global Nix configuration.**

---

# 6. P0 — Nix Build Timeout

**Commit:** `773477f`
**Classification:** Configuration

### Failure

`system/nix.nix` explicitly configured:

```text
timeout = 60
```

This imposed a 60-second limit on derivation builds.

On the baseline hardware, local builds of tools such as `ivali` and `bw-tui` could exceed this limit.

The result was intermittent failure during otherwise valid NixOS rebuilds.

### Root cause

The repository introduced a local build timeout where Nix's normal behavior does not impose the same artificial restriction.

### Fix

The explicit 60-second timeout was removed.

The configuration now avoids imposing an inappropriate global build limit.

### Result

Long-running local builds are no longer incorrectly terminated by the repository's Nix configuration.

### Design rule

> **Global build limits must be introduced only when their operational purpose is understood and their effect on the supported hardware has been validated.**

---

# 7. P1 — Operations Diagnostics

**Commit:** `16b17dd`

Operational diagnostics were expanded through runtime checks and associated tests.

The checks cover areas including:

* SOPS age-key availability;
* `/run/secrets`;
* restic availability;
* NixOS generation health;
* disk capacity;
* service state.

The doctor/scanner command paths were updated to distinguish between:

```text
FAIL
WARN
PASS
```

where appropriate.

### CPU warning policy

The baseline machine may produce a high CPU-utilization diagnostic.

This is classified as advisory rather than a hard stabilization failure where the underlying platform remains operational.

Therefore:

> **Resource pressure may be reported without automatically converting a known hardware limitation into a platform failure.**

---

# 8. P1 — Rollback Hysteresis

**Commit:** `16b17dd`

Rollback automation was hardened against repeated rollback loops.

The implementation introduced guards including:

* commit-count delta limits;
* consecutive rollback protection;
* last-rollback timestamp protection;
* scenario-specific unit tests.

### Objective

Prevent:

```text
Bad generation
   ↓
Rollback
   ↓
Reconcile
   ↓
Rollback again
   ↓
Reconcile
   ↓
Infinite rollback loop
```

### Required behavior

Rollback automation must be:

* bounded;
* observable;
* hysteresis-aware;
* evidence-driven.

A transient failure must not automatically cause repeated generation changes.

---

# 9. P1 — SOPS Web UI Secret

**Commit:** `16b17dd`

The web UI secret was added through the repository's SOPS architecture.

Components include:

```text
secrets/web-ui.yaml
        ↓
sops.secrets.web-ui.nix
        ↓
runtime secret
        ↓
/run/secrets
```

The secret is not intended to become part of the Nix store as plaintext.

---

# 10. P1 — Fresh Branch Flow Fix

A defect in the flow push path affecting fresh branches was corrected.

This is important to stabilization because repository automation is part of the deployment control plane.

The required invariant is:

> **A new engineering branch must be able to enter the authorized Ivali Flow without requiring undocumented Git manipulation.**

The fix was associated with commit:

```text
37baae7
```

---

# 11. P4 — CI Deployment-Gate Alignment

**Status:** ✅ Complete

The deployment pipeline was brought into parity with the required GitOps deployment gates.

`ci-deploy.sh` now performs the required validation sequence, including the applicable:

* flake checks;
* Nix evaluation;
* hardware validation;
* Go integrity/hash verification;
* build validation;
* health gate;
* rollback validation.

The CI deployment timeout was increased to:

```text
3600 seconds
```

to accommodate legitimate builds on the supported environment.

This closes the previously documented P4 gap.

---

# 12. Validation Evidence

The following validation was performed on the baseline `prague` hardware.

| Gate                                    | Result     | Evidence                                     |
| --------------------------------------- | ---------- | -------------------------------------------- |
| `ivali doctor`                          | ✅ `51/52`  | CPU check advisory; exit code `0`            |
| `ivali verify`                          | ✅ Pass     | Required verification checks passed          |
| Nix formatting                          | ✅ Pass     | `0/219` files require formatting             |
| `nix flake check --no-build`            | ✅ Pass     | Flake validation successful                  |
| `nix eval .#nixosConfigurations.prague` | ✅ Pass     | `nixos-system-prague-26.11.20260829.d2f6794` |
| Go build                                | ✅ Pass     | `go build ./...`                             |
| Go vet                                  | ✅ Pass     | `go vet ./...`                               |
| Go tests                                | ✅ Pass     | `go test -race -count=1 ./...`               |
| Shell syntax                            | ✅ Pass     | `bash -n scripts/*.sh`                       |
| `gosec`                                 | ✅ Executed | Version `2.29.0`                             |
| Live Nix configuration                  | ✅ Pass     | Poisoned cache key and 60s timeout absent    |

---

# 13. Live Nix Configuration Verification

Following the authorized NixOS rebuild, the live configuration was inspected.

Verified:

```text
No cache.codlet-trench.ts.net poisoned entries
No timeout = 60
Valid substituter configuration
```

The live system therefore demonstrated that the declarative configuration successfully replaced the previously poisoned runtime configuration.

This is important because:

> **Successful Nix evaluation does not by itself prove that the generated live system is correct.**

Both declarative and runtime verification are required.

---

# 14. Deployment Verification

The stabilization deployment sequence was:

```text
NixOS configuration
       ↓
nixos-rebuild switch
       ↓
Generated /etc/nix/nix.conf
       ↓
CI runner consumes corrected configuration
       ↓
Security/build operations recover
       ↓
MR merged
       ↓
GitOps reconciliation
```

The rebuild was operator-driven and required root authorization.

The resulting live configuration was then verified.

---

# 15. Files Changed

| File                                       | Stabilization purpose                                       |
| ------------------------------------------ | ----------------------------------------------------------- |
| `cache/default.nix`                        | Fail-safe cache configuration; removed broken server wiring |
| `system/nix.nix`                           | Removed inappropriate 60-second build timeout               |
| `internal/commands/runtime_checks.go`      | Runtime diagnostics                                         |
| `internal/commands/runtime_checks_test.go` | Runtime diagnostic tests                                    |
| `internal/commands/doctor.go`              | Diagnostic severity behavior                                |
| `internal/commands/doctor_test.go`         | Doctor regression coverage                                  |
| `internal/security/scanner.go`             | Scanner behavior                                            |
| `internal/security/scanner_test.go`        | Scanner regression coverage                                 |
| `internal/commands/flow.go`                | Fresh-branch flow behavior                                  |
| `internal/commands/flow_test.go`           | Flow regression coverage                                    |
| `scripts/rollback.sh`                      | Rollback hysteresis                                         |
| `scripts/audio-diagnostic.sh`              | Audio/microphone diagnostics                                |
| `secrets/web-ui.yaml`                      | Encrypted web UI secret                                     |
| `lib/host-templates/laptop.nix`            | Dormant cache configuration                                 |
| `scripts/cache-stats.sh`                   | Removed obsolete server assumptions                         |
| `DOCS.md`                                  | Updated cache documentation                                 |

---

# 16. Known Operator-Only Items

These items require physical/operator action and cannot be completely validated through repository-only automation.

## 16.1 SOPS Break-Glass Recovery

**Status:** ⏳ Pending

The operator must decide:

* where the break-glass recovery material is stored;
* which hardware is trusted;
* how recovery access is controlled;
* how recovery is tested;
* how rotation/revocation will work.

This remains a migration-readiness requirement.

---

## 16.2 Firefox / Google Meet Audio

**Status:** ⏳ Pending real-hardware verification

The repository contains diagnostic tooling, but successful media operation requires physical hardware validation.

Required checks include:

* Firefox microphone access;
* speaker output;
* PipeWire;
* WirePlumber;
* browser permissions;
* Google Meet microphone;
* Google Meet speaker;
* camera;
* screen sharing.

This is particularly important because the next desktop migration is:

```text
GNOME
  ↓
KDE Plasma
```

The audio baseline should therefore be established before and after the KDE migration.

---

# 17. Stabilization and KDE Migration

Stabilization is the prerequisite for the GNOME → KDE migration.

The KDE migration must preserve the stabilization invariants.

### Before KDE cutover

Verify:

* [ ] Existing GNOME desktop baseline is understood.
* [ ] GNOME dependencies are inventoried.
* [ ] Audio works or known failures are documented.
* [ ] Wi-Fi works.
* [ ] Bluetooth works.
* [ ] Display configuration works.
* [ ] Suspend/resume behavior is understood.
* [ ] Firefox works.
* [ ] Remote access works.
* [ ] Tailscale connectivity works.

### After KDE cutover

Repeat the same acceptance surface.

The migration is successful only if:

```text
KDE functionality
+
Infrastructure functionality
+
Security
+
Networking
+
Observability
+
Recovery
```

remain within the defined acceptance criteria.

---

# 18. Stabilization and Elixir/OTP

Elixir/OTP remains **blocked by design**.

The stabilization milestone does not authorize an Elixir rewrite.

The required sequence is:

```text
Stabilization baseline
        ↓
KDE migration
        ↓
KDE stabilization
        ↓
Migration readiness
        ↓
Elixir/OTP architecture
        ↓
Service contract extraction
        ↓
First Elixir service
```

This prevents Elixir from being used to solve unresolved problems in the existing Go/NixOS platform.

---

# 19. Architecture Requirements After Stabilization

Future stabilization work must conform to the repository's architectural invariant:

> **Hosts compose capabilities. Domains own capabilities. Services expose contracts. Infrastructure adapters implement those contracts.**

The following must remain true:

### State

```text
One state path
      ↓
One owner
```

### Configuration

```text
One configuration responsibility
      ↓
One authoritative owner
```

### Services

Every runtime service should have an identifiable:

* owner;
* purpose;
* configuration;
* state;
* dependency set;
* privilege model;
* network exposure;
* health model;
* recovery model;
* logging model.

### Architecture enforcement

The stabilization baseline must remain protected by automated checks covering:

* forbidden imports;
* circular dependencies;
* filesystem boundaries;
* duplicate ownership;
* declared dependencies;
* internal API boundaries;
* service state ownership.

---

# 20. Operational Verification Order

Future stabilization changes should use the following verification sequence where applicable:

```text
1. Format
       ↓
2. Architecture tests
       ↓
3. Architecture linter
       ↓
4. Unit tests
       ↓
5. Race tests
       ↓
6. Static analysis / security
       ↓
7. Go build
       ↓
8. Nix evaluation
       ↓
9. Nix build
       ↓
10. Integration tests
       ↓
11. Runtime verification
       ↓
12. Health verification
       ↓
13. Deployment
       ↓
14. Post-deployment health
       ↓
15. Observe
```

Not every change requires every stage, but skipping a stage must be justified by the change's scope.

---

# 21. Regression Protection

Every stabilization fix must leave behind appropriate regression protection.

The minimum model is:

| Change type       | Required protection                                   |
| ----------------- | ----------------------------------------------------- |
| Nix configuration | Evaluation + targeted regression                      |
| Go behavior       | Unit/integration test                                 |
| Runtime failure   | Reproduction + regression test                        |
| Security behavior | Security test/scan                                    |
| Shell script      | Syntax + ShellCheck + behavioral test where practical |
| Architecture      | Architecture test/linter                              |
| Deployment        | Gate + health verification                            |
| Rollback          | Scenario tests                                        |
| Desktop           | Real-hardware validation where hardware is involved   |
| Secrets           | Provisioning/recovery validation                      |

The purpose is to ensure that stabilization is not temporary.

---

# 22. Definition of Stable

The repository is considered stabilized when:

```text
Declarative configuration
        +
Automated tests
        +
Architecture enforcement
        +
Security validation
        +
Deployment gates
        +
Runtime diagnostics
        +
Rollback protection
        +
Operational evidence
        ↓
Known-good baseline
```

Stabilization does **not** mean:

* every warning disappears;
* every optimization is complete;
* every desktop feature is perfect;
* every future architecture decision is finalized.

It means the system has enough correctness and operational control that future changes can be made safely.

---

# 23. Remaining Work

| Item                           | Owner        | Status        | Classification       |
| ------------------------------ | ------------ | ------------- | -------------------- |
| SOPS break-glass recovery      | Operator     | ⏳ Pending     | Migration blocker    |
| Firefox/Google Meet audio      | Operator     | ⏳ Pending     | Desktop acceptance   |
| CI deploy-gate alignment       | Engineering  | ✅ Complete    | P4 closed            |
| `gosec` enforcement            | Engineering  | ✅ Complete    | Stabilization        |
| `flow merge` pipeline handling | Engineering  | ✅ Complete    | Stabilization        |
| CI parity                      | Engineering  | ✅ Complete    | Stabilization        |
| Stabilization matrix           | Engineering  | 🟡 Maintained | Evidence/gates       |
| Migration readiness            | Architecture | 🟡 Active     | GNOME → KDE + Elixir |
| GNOME inventory                | Desktop      | ⏳ Pending     | KDE migration        |
| KDE acceptance                 | Desktop      | ⏳ Pending     | KDE migration        |
| Elixir architecture briefing   | Architecture | ⏳ Pending     | Elixir blocker       |

---

# 24. Relationship to Other Documents

This document is part of a larger engineering-control system.

```text
ARCHITECTURE.md
        │
        │ defines target architecture
        ▼
ARCHITECTURE_AUDIT.md
        │
        │ records actual conformance
        ▼
ARCHITECTURE_PROGRESS.md
        │
        │ records migration progress
        ▼
STABILIZATION.md
        │
        │ establishes known-good baseline
        ▼
STABILIZATION-MATRIX.md
        │
        │ maps detailed gates/evidence
        ▼
MIGRATION-READINESS.md
        │
        │ determines whether migration may begin
        ▼
IVALi_FLOW.md
        │
        │ governs engineering/deployment lifecycle
        ▼
CI / GitOps / Runtime
```

### Document responsibilities

**`ARCHITECTURE.md`**

Defines where the system is going.

**`ARCHITECTURE_AUDIT.md`**

Defines where the system actually is.

**`ARCHITECTURE_PROGRESS.md`**

Defines how architecture migration is progressing.

**`STABILIZATION.md`**

Defines the known-good engineering baseline.

**`STABILIZATION-MATRIX.md`**

Provides detailed gate-to-evidence mapping.

**`MIGRATION-READINESS.md`**

Determines whether GNOME → KDE and Elixir/OTP migration work may begin.

**`IVALi_FLOW.md`**

Defines how engineering changes are investigated, implemented, tested, reviewed, merged, deployed, and recovered.

---

# 25. Final Stabilization Statement

The stabilization milestone establishes the following engineering position:

> **The NixOS infrastructure has a documented and tested baseline from which subsequent platform evolution can proceed under controlled conditions.**

The next migration is **not** an uncontrolled rewrite.

The intended progression is:

```text
                   STABILIZE
                       │
                       ▼
              PROVE THE BASELINE
                       │
                       ▼
                 GNOME → KDE
                       │
                       ▼
              STABILIZE KDE
                       │
                       ▼
          APPROVE ELIXIR ARCHITECTURE
                       │
                       ▼
             MIGRATE ONE SERVICE
                       │
                       ▼
                OBSERVE + TEST
                       │
                       ▼
                  CUT OVER
                       │
                       ▼
                 STABILIZE
                       │
                       ▼
                   REPEAT
```

The governing rule is:

> **Every migration must leave the system at least as reproducible, secure, observable, testable, and recoverable as the system it replaced.**

---

## Acceptance Signature

**Stabilization baseline:** `P0–P4 COMPLETE`
**KDE migration:** `NOT YET AUTHORIZED`
**Elixir/OTP migration:** `BLOCKED`
**Next formal gate:** `MIGRATION-READINESS.md`

**Baseline evidence date:** 5 September 2026
**Primary validation host:** `prague`

