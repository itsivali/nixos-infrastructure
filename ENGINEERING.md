# IVALI Engineering Standards

> **Repository:** `nixos-infrastructure`
> **Owner:** Willis Ivali
> **Primary Host:** `prague`
> **Primary User:** `ivali`
> **Timezone:** `Africa/Nairobi`
> **Engineering Model:** Test-Driven Development + Domain-Driven Architecture + GitOps
> **Status:** Production Engineering Standard

---

# 1. Purpose

This document defines the engineering standards, architectural rules, development methodology, testing requirements, security principles, deployment model, and AI/LLM operating rules for the `nixos-infrastructure` repository.

It is a **normative engineering document**.

The rules in this document apply to:

* human contributors
* AI/LLM agents
* automation
* scripts
* NixOS modules
* Home Manager modules
* Go applications
* infrastructure services
* CI/CD
* GitOps reconciliation
* security configuration
* observability
* recovery systems
* documentation that defines system behavior

The objective is not simply to make the repository work.

The objective is to make it:

* correct
* testable
* reproducible
* secure
* observable
* recoverable
* maintainable
* architecturally coherent
* understandable by both humans and AI agents

---

# 2. Core Engineering Philosophy

The repository follows these principles:

1. **Test before implementation.**
2. **Understand before modifying.**
3. **Prefer explicit behavior over magic.**
4. **Prefer simple designs over unnecessary abstraction.**
5. **Keep domain ownership explicit.**
6. **Make security and reliability properties executable through tests where possible.**
7. **Make infrastructure reproducible.**
8. **Make failures observable.**
9. **Preserve existing working behavior.**
10. **Never claim verification that was not actually performed.**
11. **Do not implement speculative functionality.**
12. **Treat Git as the historical record of engineering decisions.**
13. **Treat documentation as part of the system contract.**
14. **Design for another engineer—or another LLM—to continue the work without hidden context.**

---

# 3. Engineering Priority Order

When engineering concerns conflict, use this priority order:

```text
1. Security
2. Data integrity
3. Reliability
4. Correctness
5. Architectural integrity
6. Reproducibility
7. Maintainability
8. Observability
9. Performance
10. Convenience
```

A lower-priority concern must not compromise a higher-priority concern without an explicit architectural decision.

---

# 4. Source-of-Truth Hierarchy

When information conflicts, use the following order:

```text
1. Actual repository state
2. Executable tests
3. Architecture manifests and enforcement
4. CI configuration and gates
5. Current implementation
6. Engineering standards
7. Architecture documentation
8. CONTEXT_HANDOFF.md
9. Other documentation
10. Previous LLM assumptions
```

The current repository state always takes precedence over an LLM's memory.

AI agents must inspect the repository rather than assuming that previous conversation context is still accurate.

---

# 5. AI/LLM Engineering Contract

AI agents are first-class engineering participants but are not authoritative over the repository.

An AI agent must:

* inspect before changing
* understand before implementing
* follow TDD
* preserve existing work
* respect architecture boundaries
* run verification
* report actual results
* update documentation when required
* maintain handoff continuity
* avoid destructive Git operations
* avoid speculative changes
* avoid silently expanding scope

An AI agent must **not**:

* fabricate test results
* claim a command was run when it was not
* claim a build passed without verification
* rewrite unrelated files
* delete existing functionality without justification
* weaken tests to make implementation pass
* modify architecture merely to accommodate an easier implementation
* introduce dependencies without justification
* commit directly to `main`
* discard user changes
* perform destructive Git operations without explicit authorization

The repository is the authority.

The LLM is an implementation assistant.

---

# 6. Mandatory Test-Driven Development

## 6.1 TDD Is the Default Development Method

All new production functionality must follow:

```text
RED → GREEN → REFACTOR
```

The required development cycle is:

```text
Requirement
    ↓
Behavior / Acceptance Criterion
    ↓
Write Test
    ↓
Run Test
    ↓
Confirm Expected Failure
    ↓
Implement Minimum Code
    ↓
Run Test
    ↓
Confirm Success
    ↓
Refactor
    ↓
Run Tests Again
```

**Production implementation must not precede its corresponding test.**

---

# 7. The RED Phase

The first step of implementation is writing a test.

The test must describe the behavior that is required.

Example:

```text
Given a valid deployment request
When the deployment service executes it
Then the deployment is successful
And the resulting generation is recorded
```

The test must then be executed.

The expected result is failure.

The failure must occur because the required behavior does not yet exist.

This establishes that the test actually protects the new behavior.

## 7.1 Red Means Actually Red

It is insufficient to merely write a test.

The developer or AI agent must establish:

```text
Test exists
    ↓
Test runs
    ↓
Test fails
    ↓
Failure is understood
```

Only then should implementation begin.

An AI agent must not claim TDD compliance if it wrote the test after the implementation or never demonstrated the initial failure.

---

# 8. The GREEN Phase

Once the test is demonstrably failing, implement the **minimum amount of production code required to make it pass**.

Do not prematurely implement:

* speculative features
* unused abstractions
* future requirements
* unnecessary interfaces
* unrelated refactors
* additional behavior that has no test

The objective is:

> Make the failing test pass with the smallest correct implementation.

---

# 9. The REFACTOR Phase

Once the test is green:

* improve naming
* remove duplication
* simplify control flow
* improve interfaces
* improve package boundaries
* improve error handling
* improve maintainability
* remove accidental complexity

Tests must remain green during refactoring.

Refactoring must not change externally observable behavior unless that behavior is intentionally being changed through a new TDD cycle.

---

# 10. One Behavior at a Time

Development should proceed in small behavioral increments.

Preferred:

```text
Test: notification sends successfully
→ implementation
→ green

Test: notification failure is reported
→ implementation
→ green

Test: transient notification failure retries
→ implementation
→ green
```

Avoid:

```text
Build entire notification system
→ write hundreds of tests afterward
```

Small cycles provide:

* clearer failures
* smaller diffs
* easier reviews
* easier rollback
* better AI reasoning
* better architectural discipline

---

# 11. Tests Are the Behavioral Specification

Tests are not merely coverage mechanisms.

They are executable specifications.

Tests should describe:

* what the system does
* what the system must not do
* how errors behave
* how security boundaries behave
* how state transitions occur
* how services interact
* what configuration produces
* what happens during recovery

Prefer behavioral assertions over implementation-specific assertions.

---

# 12. Regression-First Bug Fixing

Every reproducible bug must become a regression test whenever practical.

Required workflow:

```text
Reproduce bug
    ↓
Write regression test
    ↓
Run test
    ↓
Confirm failure
    ↓
Fix implementation
    ↓
Confirm test passes
    ↓
Refactor
    ↓
Run relevant suite
```

This prevents the same bug from silently returning.

---

# 13. Test Modification Rules

Tests are part of the system specification.

Therefore, modifying a test requires justification.

A test may be changed when:

* requirements intentionally changed
* the existing test is incorrect
* an obsolete contract has been intentionally removed
* architecture has intentionally changed
* the original test encoded an invalid assumption

An AI agent must never modify a test simply because the implementation cannot currently satisfy it.

When changing an existing behavioral contract, document:

```text
Previous behavior:
...

New behavior:
...

Reason:
...

Affected tests:
...
```

---

# 14. Test Pyramid

Testing should operate at multiple levels.

```text
             E2E
              ▲
         Integration
              ▲
            Unit
```

## Unit Tests

Use for:

* business logic
* validation
* parsers
* services
* state transitions
* error handling
* configuration logic
* security decisions

## Integration Tests

Use when behavior crosses boundaries:

* filesystem
* PostgreSQL
* Git
* Nix
* system commands
* APIs
* persistence
* service boundaries

Do not replace meaningful integration behavior with excessive mocking.

## End-to-End Tests

Use for critical user workflows.

Example:

```text
CLI
 ↓
Application
 ↓
Service
 ↓
Repository / Platform
 ↓
Observable Result
```

---

# 15. Go Engineering Standards

Go code must follow idiomatic Go practices.

## 15.1 Package Ownership

Every package must have a clear responsibility.

Avoid packages that become miscellaneous utility collections.

## 15.2 Interfaces

Use interfaces where they provide meaningful:

* abstraction
* testability
* dependency inversion
* architectural boundaries

Do not create interfaces merely because Go permits them.

## 15.3 Error Handling

Errors must be:

* checked
* contextualized
* actionable

Prefer:

```go
return fmt.Errorf("deploy generation %s: %w", generation, err)
```

over:

```go
return err
```

where additional context is meaningful.

Never silently discard errors.

## 15.4 Panics

Panics are not acceptable for normal operational failures.

Expected failures must return errors.

## 15.5 Context

Long-running operations and external calls should propagate `context.Context`.

## 15.6 Go TDD

New Go functionality follows:

```text
Write *_test.go
    ↓
go test ./path/...
    ↓
Confirm failure
    ↓
Implement
    ↓
go test ./path/...
    ↓
Refactor
```

---

# 16. Nix/NixOS Engineering Standards

Nix configuration must remain declarative, reproducible, explicit, and composable.

## 16.1 Module Ownership

One module should represent one coherent capability.

Examples:

```text
security/firewall
security/fail2ban
observability/prometheus
desktop/gnome
networking/tailscale
```

Avoid giant modules containing unrelated responsibilities.

## 16.2 Configuration

Prefer explicit options.

Avoid hidden configuration magic.

Where practical, features should be opt-in and have predictable defaults.

Foundational system functionality may be enabled centrally where required by the platform architecture.

## 16.3 Evaluation Safety

Nix expressions must remain evaluatable independently wherever practical.

Avoid unnecessary:

* `builtins.getEnv`
* dynamic filesystem assumptions
* hidden host dependencies
* imperative behavior
* undeclared runtime dependencies

## 16.4 Nix TDD

Nix behavior must be tested before implementation where practical.

Tests should cover:

* option defaults
* enabled behavior
* disabled behavior
* generated services
* generated configuration
* assertions
* dependencies
* security properties
* evaluation

Example:

```text
Test:
feature is disabled by default
    ↓
Implement module
    ↓
Test passes
```

---

# 17. Home Manager Standards

Home Manager configuration must:

* remain declarative
* have clear ownership
* avoid duplicate configuration
* avoid imperative installation
* remain reproducible
* integrate with system-level configuration through explicit boundaries

User-level behavior should not silently modify system-level behavior.

---

# 18. Shell Script Standards

Shell scripts must use:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

unless there is a documented reason not to.

Requirements:

* quote variables
* validate inputs
* avoid `eval`
* handle command failures
* avoid accidental word splitting
* use explicit paths where required
* produce useful error messages
* avoid leaking secrets
* remain idempotent where practical

Shell behavior should also be tested.

At minimum:

```bash
bash -n script.sh
```

For meaningful behavior, use executable tests rather than syntax checking alone.

---

# 19. Architecture Standards

Architecture must be explicit.

The repository uses domain boundaries to prevent uncontrolled coupling.

Each domain should define:

* responsibility
* ownership
* public interface
* dependencies
* state ownership
* filesystem ownership
* security boundary

Architecture rules should be executable whenever practical.

---

# 20. Architecture TDD

Architectural constraints should be expressed as tests.

Examples:

```text
Test:
deployment domain cannot directly depend on notification implementation.
```

```text
Test:
only the deployment service owns deployment execution.
```

```text
Test:
security secrets cannot be imported by presentation-layer packages.
```

Architecture tests prevent gradual architectural erosion.

An architecture rule that is important enough to document should be considered for automated enforcement.

---

# 21. Service Contract Standards

Services must have explicit responsibilities.

Current service architecture includes concepts such as:

* NotificationService
* BackupService
* MetricsProvider
* HealthChecker
* PlatformService

Each service must:

* have a clear contract
* own its responsibility
* expose only required behavior
* avoid leaking implementation details
* be testable independently
* have tests before implementation

Consumers should depend on contracts rather than concrete implementations where appropriate.

---

# 22. State Ownership

Every persistent state must have a clearly identified owner.

Examples:

```text
Deployment state → Deployment domain
Backup state → Backup domain
Health state → Health domain
Notification state → Notification domain
```

Two unrelated domains must not silently become co-owners of the same state.

Shared state requires an explicit contract.

---

# 23. Filesystem Ownership

Filesystem paths must have an identified owner.

Do not allow multiple services to independently mutate the same state directory without an explicit contract.

Path ownership should be documented and tested where practical.

---

# 24. Security Engineering

Security is a system property.

Security controls must be:

* explicit
* testable
* observable
* least-privilege
* reproducible

## Secrets

Secrets must never be committed as plaintext.

Use:

* SOPS
* age
* appropriate secret management
* protected runtime access

Never:

* log secrets
* echo secrets
* place secrets in command arguments unnecessarily
* embed credentials in source
* commit generated secret material

---

# 25. Systemd Hardening

Services should use appropriate hardening where compatible with their function.

Consider:

```text
DynamicUser=
NoNewPrivileges=
ProtectSystem=
ProtectHome=
PrivateTmp=
PrivateDevices=
RestrictAddressFamilies=
RestrictNamespaces=
CapabilityBoundingSet=
```

Hardening must be tested against actual service behavior.

Security must not be assumed merely because a hardening option is present.

---

# 26. Network Security

Networking must follow least privilege.

Firewall rules must have:

* explicit ownership
* documented purpose
* minimal exposure
* predictable interaction with Tailscale
* test coverage where practical

Port ownership must not be duplicated across unrelated modules.

---

# 27. Tailscale Security

Tailscale configuration must follow the repository security model.

Requirements include:

* explicit node roles
* explicit access policy
* least privilege
* controlled SSH
* explicit exit-node behavior
* firewall integration
* separation between personal, administrative, infrastructure, and quarantine roles where applicable

Network access must not be granted merely because connectivity is convenient.

---

# 28. Observability

Every important operational component should provide appropriate:

* logs
* metrics
* health state
* failure information
* diagnostic information

A service that fails silently is not considered operationally complete.

Observability should be designed alongside functionality rather than added only after failures occur.

---

# 29. Health Checks

Health checks must answer meaningful questions.

Bad:

```text
Process exists
```

Better:

```text
Service is running
AND
required dependency is reachable
AND
expected state is valid
AND
critical operation can execute
```

Health checks should themselves be tested.

---

# 30. Backup Engineering

Backups must be treated as production functionality.

Backup systems must define:

* what is backed up
* where it is stored
* encryption
* retention
* verification
* restoration procedure
* failure handling
* monitoring

A backup that has never been restored or verified is not sufficient evidence of recoverability.

Backup and restore workflows should have tests appropriate to their risk.

---

# 31. Recovery Engineering

Recovery is part of the architecture.

Important recovery procedures must be:

* documented
* executable
* tested
* observable

Examples:

```text
deployment rollback
SOPS break-glass recovery
backup restoration
service recovery
host recovery
Git repository recovery
```

---

# 32. Git Engineering Standards

`main` represents production-ready state.

Development should normally occur on feature branches.

Preferred naming:

```text
feature/<name>
fix/<name>
refactor/<name>
security/<name>
test/<name>
docs/<name>
```

Changes should move through review before reaching `main`.

AI agents must not directly push unreviewed production changes to `main`.

---

# 33. Git Safety

AI agents must never casually execute destructive operations such as:

```text
git reset --hard
git clean -fd
git checkout -- .
git restore .
```

unless explicitly authorized and the consequences are understood.

Existing user changes must be preserved.

Before significant modifications, inspect:

```bash
git status
git diff
git branch --show-current
git log -n 10 --oneline
```

---

# 34. Commit Standards

Commits should be:

* focused
* understandable
* atomic where practical
* traceable to a purpose

Commit authorship should use:

```text
Willis Ivali <itsivali@outlook.com>
```

AI agents must not add:

```text
Co-authored-by:
Generated by AI
Created by ChatGPT
Created by Claude
```

or similar attribution unless explicitly requested.

---

# 35. CI/CD Contract

CI validates the repository.

GitOps performs deployment.

The normal flow is:

```text
Developer
   ↓
Feature Branch
   ↓
TDD
   ↓
Tests
   ↓
Merge Request
   ↓
CI
   ↓
Review
   ↓
main
   ↓
GitOps Reconciliation
   ↓
Deployment
```

CI must not silently become a second deployment engine.

---

# 36. CI Verification Order

The preferred verification pipeline is:

```text
Lint
  ↓
Architecture
  ↓
Unit Tests
  ↓
Integration Tests
  ↓
Repository Checks
  ↓
Build
```

Deployment is handled by the GitOps mechanism.

---

# 37. Required Verification

Where applicable, run:

```bash
nix fmt -- --check
```

```bash
nix flake check --no-build
```

```bash
go build ./...
```

```bash
go test ./...
```

```bash
go vet ./...
```

```bash
~/go/bin/golangci-lint run ./... --timeout=5m
```

```bash
bash -n scripts/*.sh
```

```bash
go test ./internal/architecture/... -v
```

```bash
./ci/check-architecture
```

The exact verification set may vary according to the files changed.

---

# 38. Verification Integrity

Never report:

```text
Tests pass
```

unless the tests were actually run.

Instead, report:

```text
go test ./...
PASS
```

or:

```text
Not run — environment unavailable.
```

Never infer successful verification.

Never fabricate:

* command output
* CI status
* test results
* build results
* deployment results
* security scan results

---

# 39. Documentation Standards

Documentation must describe the current system.

Important documentation includes:

* `README.md`
* `AGENTS.md`
* `ENGINEERING.md`
* `CONTRIBUTING.md`
* `ARCHITECTURE.md`
* `ARCHITECTURE_AUDIT.md`
* `ARCHITECTURE_PROGRESS.md`
* `CONTEXT_HANDOFF.md`
* `IVALi_FLOW.md`
* OpenCode documentation

Documentation must be updated when behavior or architecture changes materially.

---

# 40. AI Documentation Continuity

AI agents must leave enough information for another AI agent to continue.

The handoff must record:

* current objective
* completed work
* active work
* tests performed
* tests not performed
* failures
* blockers
* architectural decisions
* files changed
* next recommended action

`CONTEXT_HANDOFF.md` is the primary continuity mechanism between LLM sessions.

---

# 41. OpenCode Integration

OpenCode and other AI development tools must operate under the same repository rules.

AI tooling must respect:

* `AGENTS.md`
* `ENGINEERING.md`
* architecture manifests
* TDD
* security rules
* Git workflow
* verification requirements
* handoff requirements

AI tooling does not receive permission to bypass repository standards simply because it is automated.

---

# 42. Dependency Management

Dependencies must have a reason.

Before introducing a dependency, consider:

* security
* maintenance
* license
* size
* transitive dependencies
* reproducibility
* operational complexity
* whether existing functionality already solves the problem

Avoid dependencies for trivial functionality that can be implemented safely using the standard library.

---

# 43. Performance

Performance optimization must be evidence-driven.

Do not optimize based on assumptions.

Preferred sequence:

```text
Measure
 ↓
Identify bottleneck
 ↓
Write regression/performance test where appropriate
 ↓
Change implementation
 ↓
Measure again
```

Performance improvements must not compromise:

* security
* correctness
* reliability
* maintainability

without explicit justification.

---

# 44. Dead Code

Dead code should not accumulate.

Unused:

* functions
* packages
* modules
* configuration
* scripts
* dependencies
* documentation

should be removed when confidently identified.

Do not remove code merely because an AI agent does not immediately understand its purpose.

Investigate first.

---

# 45. TODO and Placeholder Policy

Do not introduce vague placeholders such as:

```text
TODO: implement later
FIXME
stub
temporary hack
```

without a concrete reason.

When deferred work is necessary, document:

```text
What:
Why:
Impact:
Owner:
Follow-up:
```

Do not allow temporary architecture to silently become permanent architecture.

---

# 46. Refactoring Rules

Refactoring should be driven by evidence.

Before refactoring:

1. Understand current behavior.
2. Identify existing tests.
3. Add missing tests using TDD.
4. Confirm tests pass.
5. Refactor.
6. Confirm tests remain green.

Large refactors should be broken into smaller verified steps.

Avoid mixing:

```text
feature implementation
+
unrelated refactor
+
formatting changes
+
dependency migration
```

unless there is a compelling reason.

---

# 47. Definition of Done

A feature is complete only when all applicable requirements are satisfied.

### Requirements

* [ ] Requirement is understood.
* [ ] Acceptance criteria are defined.
* [ ] Scope is clear.

### TDD

* [ ] Test was written first.
* [ ] Test initially failed.
* [ ] Failure was understood.
* [ ] Minimum implementation was written.
* [ ] Test passed.
* [ ] Implementation was refactored where appropriate.
* [ ] Relevant regression tests exist.

### Architecture

* [ ] Correct domain owns the functionality.
* [ ] Dependencies respect architecture.
* [ ] State ownership is explicit.
* [ ] Architecture tests pass where applicable.

### Security

* [ ] Secrets are protected.
* [ ] Permissions follow least privilege.
* [ ] Security behavior is tested where applicable.
* [ ] No sensitive data is unnecessarily logged.

### Reliability

* [ ] Failure behavior is defined.
* [ ] Recovery behavior is defined where required.
* [ ] Observability exists where required.

### Verification

* [ ] Relevant unit tests pass.
* [ ] Relevant integration tests pass.
* [ ] Relevant E2E tests pass.
* [ ] Nix checks pass where applicable.
* [ ] Go checks pass where applicable.
* [ ] Architecture checks pass.
* [ ] Shell validation passes where applicable.

### Documentation

* [ ] Documentation reflects the resulting behavior.
* [ ] Architecture documentation is updated if required.
* [ ] `CONTEXT_HANDOFF.md` is updated when session continuity requires it.

---

# 48. AI Session Workflow

Every AI session should follow this lifecycle:

```text
BOOTSTRAP
    ↓
INSPECT
    ↓
UNDERSTAND
    ↓
PLAN
    ↓
WRITE TEST
    ↓
RED
    ↓
IMPLEMENT
    ↓
GREEN
    ↓
REFACTOR
    ↓
VERIFY
    ↓
DOCUMENT
    ↓
HANDOFF
```

## Bootstrap

Read the repository's governing documents before modifying code.

At minimum:

```text
AGENTS.md
ENGINEERING.md
CONTRIBUTING.md
ARCHITECTURE.md
ARCHITECTURE_AUDIT.md
ARCHITECTURE_PROGRESS.md
IVALi_FLOW.md
README.md
CONTEXT_HANDOFF.md
```

## Inspect

Inspect:

```bash
git status --short
git branch --show-current
git log -n 10 --oneline
```

Understand existing changes before touching files.

---

# 49. AI Scope Control

An AI agent must not silently expand the task.

If asked:

```text
Implement notification retries.
```

Do not automatically:

* redesign the entire notification system
* replace the logging framework
* migrate databases
* rewrite unrelated services
* change the deployment architecture

unless those changes are necessary and justified.

If broader architectural work becomes necessary:

1. identify it
2. explain it
3. isolate it
4. obtain appropriate authorization

---

# 50. AI Change Discipline

Before modifying a file, understand:

* why it exists
* who owns it
* what depends on it
* what tests cover it
* what architecture rules apply
* whether another implementation already exists

Search before creating.

Reuse before duplicating.

Extend before replacing.

Delete only with evidence.

---

# 51. Git Diff Review

Before considering work complete:

```bash
git diff --stat
```

and:

```bash
git diff
```

Review for:

* accidental changes
* unrelated modifications
* debugging code
* secrets
* generated files
* weakened tests
* architecture violations
* formatting noise
* unintended dependency changes

---

# 52. TDD and AI: Non-Negotiable Rules

For AI-assisted development, the following rules are absolute unless an explicit exception applies:

```text
DO NOT:

implement first
then write tests
```

```text
DO:

write test
→ run test
→ observe failure
→ implement
→ run test
→ observe success
→ refactor
```

AI agents must not:

* fake a RED phase
* fake a GREEN phase
* modify tests to conceal implementation defects
* remove assertions to make tests pass
* reduce test coverage merely to simplify implementation
* create meaningless tests
* test private implementation details unnecessarily
* claim a test was executed when it was not

---

# 53. Exceptions to TDD

TDD is the default for production behavior.

Exceptions may include:

* documentation-only changes
* formatting
* generated code
* dependency metadata
* emergency recovery
* exploratory prototypes
* unavoidable infrastructure bootstrapping

Exceptions must be explicit.

A prototype must not silently become production code without subsequently receiving proper tests.

---

# 54. Engineering Decision Record

Significant architectural decisions should record:

```text
Context:
Decision:
Alternatives:
Reason:
Consequences:
```

Decisions should favor:

* security
* correctness
* simplicity
* reproducibility
* maintainability

---

# 55. Repository Evolution

The repository should evolve incrementally.

Preferred:

```text
small change
→ test
→ verify
→ merge
→ observe
→ next change
```

Avoid giant unverified transformations.

The objective is to maintain a repository that remains understandable and recoverable at every stage.

---

# 56. Final Engineering Contract

Every contributor and every AI agent working on this repository accepts the following principles:

> **Understand before changing.**

> **Test before implementing.**

> **Make the test fail first.**

> **Implement the minimum required behavior.**

> **Make the test pass.**

> **Refactor while keeping tests green.**

> **Protect architectural boundaries.**

> **Protect secrets and system state.**

> **Verify actual behavior rather than assuming it.**

> **Preserve existing work.**

> **Document meaningful decisions.**

> **Leave the repository in a state another engineer—or another LLM—can understand and continue.**

The fundamental development loop is:

```text
                 ┌───────────────┐
                 │   Requirement │
                 └───────┬───────┘
                         ↓
                 ┌───────────────┐
                 │   Write Test  │
                 └───────┬───────┘
                         ↓
                 ┌───────────────┐
                 │      RED      │
                 │ Test Fails    │
                 └───────┬───────┘
                         ↓
                 ┌───────────────┐
                 │ Implement     │
                 │ Minimum Code  │
                 └───────┬───────┘
                         ↓
                 ┌───────────────┐
                 │     GREEN     │
                 │ Test Passes   │
                 └───────┬───────┘
                         ↓
                 ┌───────────────┐
                 │   REFACTOR    │
                 └───────┬───────┘
                         ↓
                 ┌───────────────┐
                 │   VERIFY      │
                 └───────┬───────┘
                         ↓
                 ┌───────────────┐
                 │   DOCUMENT    │
                 └───────┬───────┘
                         ↓
                    Next Behavior
```

**The repository is not considered engineered merely because the code works.**

It is engineered when the behavior is specified, tested, reproducible, secure, observable, architecturally sound, and maintainable.

**Test first. Build second. Refactor third. Verify always.**

