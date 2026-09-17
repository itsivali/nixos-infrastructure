# CONTEXT HANDOFF

> **Purpose:** This document is the continuity contract for AI/LLM agents working on the `nixos-infrastructure` repository.
>
> It exists so work can continue safely when the current LLM reaches its usage limit, is replaced, or a new session/model is started.
>
> **Any new LLM MUST read this document before making architectural changes.**
>
> The incoming LLM must assume that previous work described here has already been performed unless repository evidence proves otherwise.

---

# 1. LLM HANDOFF PROTOCOL

## 1.1 Purpose

This repository may be developed across multiple LLMs and sessions.

For example:

```text
LLM A
  ↓
usage limit reached
  ↓
CONTEXT_HANDOFF.md
  ↓
LLM B
  ↓
continues from exact state
  ↓
LLM C
  ↓
continues from updated state
```

The goal is:

> **Never restart an architectural investigation merely because the LLM changed.**

The repository itself is the source of truth.

This document provides the current project state, architectural decisions, completed work, remaining work, verification requirements, and rules for continuing.

---

# 2. INCOMING LLM BOOTSTRAP PROCEDURE

When starting work, the incoming LLM MUST follow this sequence.

## Step 1 — Read project governance

Read:

```text
AGENTS.md
ENGINEERING.md
CONTRIBUTING.md
ARCHITECTURE.md
ARCHITECTURE_AUDIT.md
ARCHITECTURE_PROGRESS.md
IVALi_FLOW.md
README.md
SUMMARY.md
```

If the task concerns a specific subsystem, also read the relevant documentation under:

```text
docs/
opencode/
scripts/README.md
security/README.md
```

---

## Step 2 — Establish repository state

Run:

```bash
git status --short
git branch --show-current
git log -5 --oneline --decorate
```

Record:

* current branch
* current commit
* modified files
* untracked files
* whether previous work is committed

### IMPORTANT

Do NOT assume the repository is clean.

Do NOT discard existing modifications.

Do NOT reset or revert another LLM's work unless explicitly instructed.

---

## Step 3 — Verify the current implementation

Run the relevant verification gates:

```bash
nix fmt -- --check
nix flake check --no-build
go build ./...
go test ./...
~/go/bin/golangci-lint run ./... --timeout=5m
go test ./internal/architecture/... -v
./ci/check-architecture
```

If a gate fails:

1. determine whether the failure existed before the current task;
2. determine whether it is caused by the current change;
3. do not silently ignore it;
4. document it in the handoff.

---

## Step 4 — Inspect the current task state

Before modifying anything, determine:

```text
CURRENT PHASE
CURRENT OBJECTIVE
COMPLETED WORK
OPEN WORK
BLOCKERS
LAST VERIFIED COMMIT
```

These values are maintained in this document.

---

# 3. CORE PROJECT IDENTITY

Repository:

```text
nixos-infrastructure
```

Primary host:

```text
prague
```

Primary user:

```text
ivali
```

Repository purpose:

> A domain-oriented NixOS infrastructure platform combining NixOS configuration, Home Manager, Go-based infrastructure tooling, GitOps automation, observability, security, recovery, developer tooling, and a local-first `ivali` control plane.

Primary technologies:

```text
NixOS
Nix
Home Manager
Go
GitLab CI
GitHub Actions
SOPS
Tailscale
systemd
Prometheus
Grafana
Loki
Alloy
Falco
PostgreSQL
Redis
NGINX
Docker
```

---

# 4. CURRENT REPOSITORY STATE

## 4.1 Architectural Status

A comprehensive architectural audit covering phases 0–33 has been completed.

The repository now contains:

* domain-oriented architecture
* explicit architecture manifests
* documented domain ownership
* dependency graphs
* service contracts
* architecture exceptions
* architecture linter
* CI enforcement
* dead-code remediation
* architectural-magic remediation
* comprehensive architectural documentation

---

# 5. COMPLETED PHASES

## Phase 0–18 — Audit and Discovery

| Phase | Description                  | Result                                                |
| ----- | ---------------------------- | ----------------------------------------------------- |
| 0     | Repository understanding     | 187 Nix files, 127 Go files, 16 scripts, ~40 services |
| 1     | Complete audit               | Domain hierarchy mapped                               |
| 2     | Full inventory               | Modules, services, timers, scripts, packages, secrets |
| 3     | Dependency graph             | Nix/runtime/script/filesystem dependencies            |
| 4     | Dependency graphs            | Mermaid diagrams created                              |
| 5     | Runtime service graph        | Service interactions documented                       |
| 6     | Circular dependencies        | None found                                            |
| 7     | Cross-domain coupling        | 7 findings                                            |
| 8     | Cross-domain filesystem      | 8 findings                                            |
| 9     | Duplicate configuration      | 7 findings                                            |
| 10    | Undeclared dependencies      | 6 findings                                            |
| 11    | Internal API violations      | Documented                                            |
| 12    | Cross-service state mutation | Documented                                            |
| 13–18 | Domain boundaries            | Ownership hierarchy established                       |

---

## Phase 19–25 — Architecture Enforcement

Completed:

```text
architecture/domains.yaml
architecture/dependencies.yaml
architecture/exceptions.yaml
```

Architecture linter implemented in:

```text
internal/architecture/
```

CI enforcement implemented in:

```text
.github/workflows/ci.yml
.gitlab-ci.yml
```

Architecture linter tests:

```text
5/5 passing
```

---

## Phase 26–33 — Remediation and Documentation

Completed:

* HIGH-severity architectural violations resolved
* repository functionality verified
* dead code audit completed
* 38+ dead-code findings resolved
* architectural magic removed
* 57+ hardcoded/implicit patterns addressed
* service contracts created
* architecture documentation completed
* context handoff created

---

# 6. CURRENT VERIFICATION STATUS

At the last verified state:

| Gate                         | Status   |
| ---------------------------- | -------- |
| `nix fmt -- --check`         | PASS     |
| `nix flake check --no-build` | PASS     |
| NixOS host evaluation        | PASS     |
| `go build ./...`             | PASS     |
| `go test ./...`              | PASS     |
| `golangci-lint run`          | PASS     |
| Architecture linter          | PASS     |
| Architecture tests           | 5/5 PASS |

### IMPORTANT

These statuses describe the **last known verified state**.

An incoming LLM MUST re-run relevant gates before claiming they still pass.

---

# 7. CURRENT GIT STATE

Last known repository state:

```text
Branch:
main

Last known commit:
3f1ad3d

Working tree:
Contains modifications/uncommitted work unless verified otherwise.
```

The incoming LLM MUST run:

```bash
git status --short
git log -5 --oneline --decorate
```

before making changes.

---

# 8. CURRENT ARCHITECTURE

## 8.1 Domain Structure

Major domains include:

```text
automation/
boot/
cache/
caching/
ci/
cloud/
desktop/
developer/
hardware/
home/
hosts/
i18n/
networking/
observability/
packages/
recovery/
security/
services/
shared/
ssh/
storage/
system/
virtualization/
```

Go application architecture primarily resides under:

```text
cmd/
internal/
```

---

# 9. ARCHITECTURAL GOVERNANCE

The architecture is enforced through:

```text
architecture/domains.yaml
architecture/dependencies.yaml
architecture/exceptions.yaml
internal/architecture/
ci/check-architecture
```

These files together define:

```text
domain ownership
allowed dependencies
forbidden dependencies
documented exceptions
architectural validation
```

An LLM MUST NOT bypass the architecture linter merely to make a change easier.

If a legitimate architectural exception is required:

1. document the reason;
2. update the appropriate architecture manifest;
3. update the exception documentation;
4. add/update tests where appropriate;
5. verify CI.

---

# 10. SERVICE CONTRACT ARCHITECTURE

Service contracts currently exist under:

```text
internal/services/
```

Contracts:

```text
NotificationService
BackupService
MetricsProvider
HealthChecker
PlatformService
```

Current structure:

```text
internal/services/
├── backup.go
├── health.go
├── metrics.go
├── notification.go
├── platform.go
├── registry.go
└── impl/
```

These contracts are intended to become the stable interfaces between application components and infrastructure implementations.

---

# 11. OPEN ARCHITECTURAL VIOLATIONS

## HIGH

```text
NONE
```

All HIGH-severity violations have been resolved.

---

## MEDIUM

### EXC-007

```text
ci-notify.nix
```

depends on:

```text
fleet.gitlabRunner.enable
```

Status:

```text
OPEN
DOCUMENTED EXCEPTION
```

---

### EXC-008

```text
deployment-health.nix
```

reads:

```text
fleet.gitops
```

options.

Status:

```text
OPEN
DOCUMENTED EXCEPTION
```

---

### EXC-009

```text
gitlab-runner.nix
```

reads:

```text
fleet.gitops
```

options.

Status:

```text
OPEN
DOCUMENTED EXCEPTION
```

---

### EXC-005

```text
security/apparmor.nix
```

contains hardcoded bot paths.

Status:

```text
OPEN
DOCUMENTED EXCEPTION
```

---

### Firewall ownership

Tailscale port 22 configuration has split ownership.

Status:

```text
OPEN
```

---

# 12. LOW-PRIORITY OPEN ITEMS

### Duplicate Nix substituters

```text
nix.settings.substituters
```

is split across three locations.

---

### Duplicate allowUnfree configuration

```text
nixpkgs.config.allowUnfree
```

is duplicated.

---

### Embedded notification script

```text
observability/lite.nix
```

uses:

```nix
builtins.readFile
```

to embed:

```text
notify.sh
```

Documented exception:

```text
EXC-002
```

---

# 13. NEXT PHASE

## PHASE 34 — FINAL ACCEPTANCE TEST

The next architectural milestone is:

```text
Phase 34: Final Acceptance Test
```

The objective is NOT to blindly change code.

The objective is to prove that the architecture satisfies its defined requirements.

Acceptance checklist:

```text
[ ] Repository fully audited
[ ] Actual dependency graph created
[ ] Runtime dependency graph created
[ ] Domains defined
[ ] Domain ownership documented
[ ] Public interfaces defined
[ ] Internal implementations isolated
[ ] State ownership defined
[ ] Filesystem ownership defined
[ ] Circular dependencies eliminated
[ ] Forbidden imports eliminated
[ ] Cross-domain filesystem access eliminated or documented
[ ] Duplicate configuration eliminated
[ ] Undeclared dependencies eliminated
[ ] Internal API violations eliminated
[ ] Cross-service state mutation eliminated
[ ] Architecture manifest implemented
[ ] Architecture exceptions documented
[ ] Architecture linter implemented
[ ] Architecture linter tested
[ ] CI integration implemented
[ ] CI rejects architectural violations
[ ] Existing CI continues working
[ ] Nix flake check passes
[ ] Relevant tests pass
[ ] Existing functionality preserved
[ ] Dead code identified and handled
[ ] Documentation complete
```

### Acceptance rule

Do not mark Phase 34 complete simply because files exist.

Each requirement must have evidence.

Evidence may be:

```text
source code
tests
architecture manifests
CI configuration
command output
documentation
dependency graphs
```

---

# 14. IMMEDIATE DEVELOPMENT ROADMAP

After Phase 34 acceptance, continue with service implementation.

## Step 1 — Implement concrete services

Implement:

```text
NotificationService
BackupService
MetricsProvider
HealthChecker
PlatformService
```

Expected implementations:

```text
NotificationService → notification implementation
BackupService       → ResticBackup
MetricsProvider     → PrometheusMetrics
HealthChecker       → SystemHealth
PlatformService     → NixOSPlatform
```

---

## Step 2 — Service registry

Wire the service registry into:

```text
cmd/ivali/main.go
```

---

## Step 3 — Refactor consumers

Gradually replace direct infrastructure coupling with service contracts.

Priority:

```text
notify.sh
health implementations
GitOps backup logic
hardcoded observability ports
platform-specific infrastructure access
```

---

# 15. MEDIUM-TERM ROADMAP

## Notification

Replace:

```text
scripts/notify.sh
```

with:

```text
NotificationService
```

---

## Health

Unify the multiple health implementations around:

```text
HealthChecker
```

---

## Backup

Extract backup functionality from GitOps into:

```text
BackupService
```

---

## Observability

Eliminate hardcoded ports and URLs in favor of:

```text
MetricsProvider
internal/observability/
```

---

## Architecture enforcement

Once the architecture linter is stable and false positives are eliminated:

```text
architecture-check
```

must remain blocking in CI.

---

# 16. IMPORTANT ENGINEERING RULES FOR ALL LLMS

## Rule 1 — Do not redo completed work

Before investigating an architectural concern, check:

```text
ARCHITECTURE.md
ARCHITECTURE_AUDIT.md
ARCHITECTURE_PROGRESS.md
architecture/
```

Do not repeat a completed audit unless new repository evidence requires it.

---

## Rule 2 — Repository is the source of truth

If this document conflicts with the repository:

```text
repository > current generated state > handoff document
```

The LLM must investigate the discrepancy and update this document.

---

## Rule 3 — Never fabricate verification

Never claim:

```text
tests pass
build passes
CI passes
architecture is clean
```

unless verified.

---

## Rule 4 — Preserve existing functionality

Architectural improvements must not unnecessarily alter runtime behavior.

Before refactoring:

```text
understand existing behavior
identify consumers
identify state ownership
identify side effects
identify rollback behavior
```

---

## Rule 5 — Prefer minimal architectural changes

Do not introduce abstractions simply because they appear elegant.

New abstractions must solve an identified architectural problem.

---

## Rule 6 — No silent architectural exceptions

If a violation cannot reasonably be eliminated:

```text
document it
justify it
give it an exception ID
```

Never hide it.

---

## Rule 7 — No destructive Git operations

Unless explicitly instructed:

```text
DO NOT git reset --hard
DO NOT git clean -fd
DO NOT discard another LLM's changes
DO NOT rewrite history
DO NOT force push
```

---

## Rule 8 — Do not commit unrelated changes

A task should produce a focused change set.

Do not combine:

```text
architecture refactoring
desktop changes
security changes
unrelated cleanup
```

into one change unless required.

---

## Rule 9 — Verify after modifications

At minimum, run the gates relevant to the changed subsystem.

For architectural or Go changes, prefer:

```bash
nix fmt -- --check
nix flake check --no-build
go build ./...
go test ./...
~/go/bin/golangci-lint run ./... --timeout=5m
go test ./internal/architecture/... -v
./ci/check-architecture
```

---

# 17. FILES THAT MUST NOT BE IGNORED

The following files are architectural control-plane documents:

```text
AGENTS.md
ARCHITECTURE.md
ARCHITECTURE_AUDIT.md
ARCHITECTURE_PROGRESS.md
CONTEXT_HANDOFF.md
ENGINEERING.md
CONTRIBUTING.md
IVALi_FLOW.md
MODULES.md
```

Architecture manifests:

```text
architecture/domains.yaml
architecture/dependencies.yaml
architecture/exceptions.yaml
```

---

# 18. IMPORTANT REPOSITORY AREAS

## NixOS

```text
boot/
desktop/
hardware/
hosts/
networking/
security/
services/
storage/
system/
```

## Home Manager

```text
home/
```

## Automation

```text
automation/
ci/
recovery/
scripts/
```

## Observability

```text
observability/
```

## Go Control Plane

```text
cmd/ivali/
internal/
```

## AI / OpenCode integration

```text
opencode/
developer/
```

---

# 19. AI/LLM DEVELOPMENT MODEL

The repository is intentionally designed to support AI-assisted development.

LLMs are expected to behave as:

```text
architect
developer
reviewer
tester
documentarian
```

but NOT as uncontrolled autonomous committers.

The LLM must understand the architecture before modifying it.

Preferred workflow:

```text
READ
 ↓
UNDERSTAND
 ↓
INSPECT
 ↓
PLAN
 ↓
MODIFY
 ↓
TEST
 ↓
AUDIT
 ↓
DOCUMENT
 ↓
HANDOFF
```

---

# 20. TASK CONTINUITY PROTOCOL

When beginning a task, the LLM should establish:

```text
TASK:
CURRENT PHASE:
OBJECTIVE:
FILES INVOLVED:
DEPENDENCIES:
RISKS:
VERIFICATION REQUIRED:
```

When completing a task:

```text
FILES CHANGED:
IMPLEMENTATION:
TESTS:
VERIFICATION:
KNOWN ISSUES:
NEXT STEP:
```

---

# 21. HANDOFF UPDATE PROTOCOL

Before the current LLM stops working because of:

```text
usage limit
session termination
model switch
context exhaustion
task completion
```

it SHOULD update this file.

The update must contain:

### Current state

```text
CURRENT PHASE:
CURRENT OBJECTIVE:
CURRENT COMMIT:
WORKING TREE:
```

### Completed during this session

```text
- ...
- ...
- ...
```

### Not completed

```text
- ...
- ...
- ...
```

### Verification

```text
nix fmt:
nix flake check:
go build:
go test:
golangci-lint:
architecture-check:
```

### Known failures

```text
- ...
```

### Next action

```text
The next LLM should:
1. ...
2. ...
3. ...
```

---

# 22. SESSION CHANGE LOG

Every significant LLM session should append a short entry here.

Format:

```text
## YYYY-MM-DD — LLM Session

Model:
Phase:
Objective:

Completed:
- ...

Changed:
- ...

Verification:
- ...

Open issues:
- ...

Next action:
- ...
```

Example:

```text
## 2026-09-17 — Architecture Session

Model:
Phase: 34
Objective: Final architecture acceptance

Completed:
- Reviewed architecture manifests
- Verified architecture linter
- Reviewed remaining exceptions

Changed:
- None

Verification:
- architecture-check: PASS
- go test: PASS

Open issues:
- Firewall Tailscale SSH ownership remains duplicated

Next action:
- Resolve remaining medium/low violations
- Complete Phase 34 acceptance checklist
```

---

# 23. LAST KNOWN REPOSITORY TREE

The repository currently contains the following major structure:

```text
ansible/
architecture/
automation/
boot/
cache/
caching/
ci/
cloud/
cmd/
desktop/
developer/
docs/
hardware/
home/
hooks/
hosts/
i18n/
internal/
lib/
networking/
observability/
opencode/
packages/
recovery/
scripts/
secrets/
security/
services/
shared/
ssh/
storage/
system/
tests/
theme/
vendor/
virtualization/
wallpapers/

AGENTS.md
ARCHITECTURE.md
ARCHITECTURE_AUDIT.md
ARCHITECTURE_PROGRESS.md
CONTEXT_HANDOFF.md
CONTRIBUTING.md
ENGINEERING.md
IVALi_FLOW.md
MODULES.md
README.md
SUMMARY.md
configuration.nix
flake.nix
flake.lock
go.mod
go.sum
Makefile
```

The complete repository tree should be obtained from the actual filesystem when needed.

Do not treat this abbreviated tree as authoritative if it differs from the repository.

---

# 24. KEY COMMANDS

## Repository state

```bash
git status --short
git branch --show-current
git log -5 --oneline --decorate
```

## Formatting

```bash
nix fmt -- --check
```

## Nix validation

```bash
nix flake check --no-build
```

## Go build

```bash
go build ./...
```

## Go tests

```bash
go test ./...
```

## Go lint

```bash
~/go/bin/golangci-lint run ./... --timeout=5m
```

## Architecture tests

```bash
go test ./internal/architecture/... -v
```

## Architecture validation

```bash
./ci/check-architecture
```

---

# 25. ARCHITECTURAL REFERENCE FILES

| File                             | Purpose                          |
| -------------------------------- | -------------------------------- |
| `ARCHITECTURE.md`                | Complete architectural reference |
| `ARCHITECTURE_AUDIT.md`          | Audit findings                   |
| `ARCHITECTURE_PROGRESS.md`       | Phase tracking                   |
| `architecture/domains.yaml`      | Domain definitions               |
| `architecture/dependencies.yaml` | Dependency rules                 |
| `architecture/exceptions.yaml`   | Approved exceptions              |
| `AGENTS.md`                      | Engineering contract             |
| `ENGINEERING.md`                 | Engineering standards            |
| `CONTRIBUTING.md`                | Contribution rules               |
| `IVALi_FLOW.md`                  | Development workflow             |
| `MODULES.md`                     | Nix module organization          |

---

# 26. DEFINITION OF DONE

A task is NOT complete merely because the code compiles.

A task is complete when:

```text
[ ] Implementation is correct
[ ] Architecture remains valid
[ ] Existing functionality is preserved
[ ] Tests pass
[ ] Relevant verification passes
[ ] No new unexplained architectural violations exist
[ ] Documentation is updated when necessary
[ ] Git diff has been reviewed
[ ] Handoff state is updated
```

For architectural tasks:

```text
[ ] architecture manifests updated if necessary
[ ] exceptions documented if necessary
[ ] architecture linter passes
[ ] CI configuration remains valid
```

---

# 27. FINAL INSTRUCTION TO THE NEXT LLM

You are continuing an existing engineering effort.

Do NOT assume that you need to start over.

Do NOT repeat completed audits without evidence that the repository has changed.

Do NOT trust this document blindly if the repository contradicts it.

Instead:

```text
1. Read this document.
2. Read AGENTS.md.
3. Inspect git state.
4. Inspect the relevant architecture documents.
5. Verify the current implementation.
6. Determine the current phase.
7. Continue from the first incomplete objective.
8. Make the smallest correct change.
9. Run appropriate verification.
10. Update CONTEXT_HANDOFF.md before handing work to another LLM.
```

The most important principle is:

> **The next LLM should be able to continue the work without needing the previous LLM's memory, hidden context, or conversation history.**

The repository, its documentation, its tests, its architecture manifests, and this handoff document together form the continuity mechanism.

---

# 28. CURRENT RESUME POINT

```text
PROJECT:
nixos-infrastructure

HOST:
prague

BRANCH:
main

LAST KNOWN COMMIT:
3f1ad3d

ARCHITECTURAL AUDIT:
Phases 0–33 complete

CURRENT PHASE:
34 — Final Acceptance Test

HIGH VIOLATIONS:
0

MEDIUM VIOLATIONS:
5 open/documented

LOW VIOLATIONS:
3 open/documented

NEXT PRIMARY OBJECTIVE:
Complete Phase 34 acceptance verification.

THEN:
Implement and wire the concrete service implementations.

FIRST ACTION FOR NEXT LLM:
Inspect git status and verify the repository against this handoff.
```

---

# END OF HANDOFF

> **If this document is updated, preserve the historical session change log and update the CURRENT RESUME POINT.**
>
> **Never delete useful continuity information merely because a new LLM has taken over.**

