# Architecture Audit

> **Evidence-based architectural conformance audit for the ivali NixOS
> infrastructure.**
>
> This document determines how closely the **current repository and, where
> observable, the current runtime environment** conform to the architecture
> defined by `ARCHITECTURE.md`.
>
> `ARCHITECTURE.md` is the normative architectural authority.
>
> `ARCHITECTURE_AUDIT.md` is **not** the architecture. It is the evidence-backed
> assessment of current reality against that architecture.
>
> `ARCHITECTURE_PROGRESS.md` records migration progress and remediation state.
>
> Machine-enforceable architectural rules belong under `architecture/` and are
> enforced by architecture tests, schemas, linters, CI, Nix assertions, and the
> `ivali` verification workflow.
>
> **Historical audit findings are not current truth. Every finding must be
> revalidated against the current repository before it is treated as active
> debt.**

---

# Table of Contents

1. [Audit Identity](#1-audit-identity)
2. [Audit Purpose](#2-audit-purpose)
3. [Audit Principles](#3-audit-principles)
4. [Audit Scope](#4-audit-scope)
5. [Authority and Evidence Model](#5-authority-and-evidence-model)
6. [Evidence Classification](#6-evidence-classification)
7. [Finding Confidence](#7-finding-confidence)
8. [Severity Model](#8-severity-model)
9. [Audit Lifecycle](#9-audit-lifecycle)
10. [Current Repository Inventory](#10-current-repository-inventory)
11. [Current System Model](#11-current-system-model)
12. [Host Composition Audit](#12-host-composition-audit)
13. [Capability Audit](#13-capability-audit)
14. [Domain Inventory Audit](#14-domain-inventory-audit)
15. [Nix Architecture Audit](#15-nix-architecture-audit)
16. [Home Manager Audit](#16-home-manager-audit)
17. [Go Control Plane Audit](#17-go-control-plane-audit)
18. [Runtime Service Audit](#18-runtime-service-audit)
19. [Dependency Graph Audit](#19-dependency-graph-audit)
20. [State Ownership Audit](#20-state-ownership-audit)
21. [Filesystem Ownership Audit](#21-filesystem-ownership-audit)
22. [Configuration Ownership Audit](#22-configuration-ownership-audit)
23. [Secret Architecture Audit](#23-secret-architecture-audit)
24. [Network Architecture Audit](#24-network-architecture-audit)
25. [Prague Gateway Audit](#25-prague-gateway-audit)
26. [Identity and Access Audit](#26-identity-and-access-audit)
27. [Process and systemd Audit](#27-process-and-systemd-audit)
28. [Security Architecture Audit](#28-security-architecture-audit)
29. [Observability Audit](#29-observability-audit)
30. [Reliability and Resilience Audit](#30-reliability-and-resilience-audit)
31. [Deployment and GitOps Audit](#31-deployment-and-gitops-audit)
32. [Supply-Chain and Provenance Audit](#32-supply-chain-and-provenance-audit)
33. [Testing and TDD Audit](#33-testing-and-tdd-audit)
34. [Architecture Enforcement Audit](#34-architecture-enforcement-audit)
35. [Documentation and ADR Audit](#35-documentation-and-adr-audit)
36. [Historical Finding Revalidation](#36-historical-finding-revalidation)
37. [Active Violation Register](#37-active-violation-register)
38. [Architectural Debt Register](#38-architectural-debt-register)
39. [Ownership Resolution Register](#39-ownership-resolution-register)
40. [Target-State Gap Analysis](#40-target-state-gap-analysis)
41. [Remediation Prioritization](#41-remediation-prioritization)
42. [Migration Verification Gates](#42-migration-verification-gates)
43. [Audit Evidence Requirements](#43-audit-evidence-requirements)
44. [Audit Completion Criteria](#44-audit-completion-criteria)
45. [Final Audit Report Template](#45-final-audit-report-template)
46. [Audit Operating Loop](#46-audit-operating-loop)

---

# 1. Audit Identity

Every completed audit MUST record its identity.

```yaml
audit:
  id:
  date:
  auditor:
  repository:
  branch:
  commit:
  architecture_version:
  architecture_schema_version:
  nixpkgs_revision:
  flake_lock_revision:
```

Where the audit is performed by an AI agent, record:

```yaml
auditor:
  type: ai
  model:
  execution_environment:
```

The purpose is reproducibility.

A future auditor must be able to determine exactly what repository state was
examined.

---

# 2. Audit Purpose

The audit answers:

> **Does the current implementation conform to the normative architecture?**

It evaluates:

* domain ownership;
* capability ownership;
* host composition;
* dependency direction;
* state ownership;
* filesystem ownership;
* configuration ownership;
* secrets;
* network boundaries;
* identity and access;
* process isolation;
* observability;
* reliability;
* deployment;
* recovery;
* testing;
* architecture enforcement;
* supply-chain integrity.

The audit MUST NOT silently redesign the architecture.

When the architecture itself needs to change:

```text
Architecture decision
        ↓
ARCHITECTURE.md / ADR
        ↓
Audit against new target
```

---

# 3. Audit Principles

## 3.1 Evidence before conclusion

No material finding should exist without evidence.

---

## 3.2 Current reality before historical narrative

The current repository is inspected first.

Historical documents are secondary evidence.

---

## 3.3 No assumption masquerading as fact

An unverified runtime behavior is not a confirmed finding.

---

## 3.4 One finding, one root cause

Avoid creating ten findings for ten symptoms caused by one ownership defect.

---

## 3.5 Verify remediation

Closing a finding requires evidence that the defect was actually removed.

---

## 3.6 Security findings require adversarial thinking

For security-relevant findings, examine both:

```text
allowed behavior
```

and:

```text
forbidden behavior
```

---

## 3.7 Architecture is tested, not merely described

If a rule can be mechanically enforced, the audit SHOULD identify why it is or
is not enforced.

---

## 3.8 Runtime behavior matters

A system can:

```text
build successfully
```

while:

```text
not actually working
```

Runtime verification is therefore required for runtime claims.

---

# 4. Audit Scope

The audit covers all relevant executable and declarative infrastructure:

```text
NixOS modules
Home Manager
host composition
hardware configuration
flake inputs
systemd units
Go control plane
shell scripts
CI/CD
GitOps
security controls
Tailscale
networking
firewall
storage
secrets
observability
backup
recovery
architecture manifests
architecture tests
architecture linter
documentation affecting implementation
```

Where relevant, audit the runtime environment:

```text
systemd
network
Tailscale
nftables
mounted filesystems
listening sockets
active services
boot generation
desktop session
```

---

# 5. Authority and Evidence Model

The audit distinguishes four layers.

## 5.1 Architectural authority

The intended architecture is defined by:

```text
ARCHITECTURE.md
architecture/*.yaml
approved ADRs
active exceptions
```

---

## 5.2 Repository reality

The repository establishes:

```text
what files exist
what code exists
what modules are imported
what configuration is declared
what tests exist
```

---

## 5.3 Runtime reality

Runtime inspection establishes:

```text
what services are active
what ports are listening
what routes exist
what interfaces exist
what policies are loaded
what the deployed system is actually doing
```

---

## 5.4 Enforcement reality

Tests and CI establish:

```text
what the repository currently prevents
what it allows
what it verifies
```

---

## 5.5 Comparison model

The audit performs:

```text
Architectural Policy
        │
        ▼
Expected State
        │
        ├──────── compare ────────┐
        ▼                          ▼
Repository Reality          Runtime Reality
        │                          │
        └──────────┬───────────────┘
                   ▼
             Audit Findings
```

---

# 6. Evidence Classification

Every finding MUST identify evidence type.

## E1 — Static repository evidence

Examples:

```text
file content
import graph
Nix option
Go source
systemd declaration
YAML manifest
```

---

## E2 — Executable verification

Examples:

```text
architecture test
unit test
Nix evaluation
Go test
lint
schema validation
```

---

## E3 — Build evidence

Examples:

```text
nix build
nixos-rebuild dry-build
package build
CI artifact
```

---

## E4 — Runtime evidence

Examples:

```text
systemctl status
journalctl
ss
ip
nft
tailscale status
gsettings
```

---

## E5 — External evidence

Examples:

```text
vendor documentation
upstream documentation
published security advisory
```

External evidence MUST be attributed.

---

## E6 — Historical evidence

Examples:

```text
previous audit
previous CI output
old implementation
old migration document
```

Historical evidence cannot by itself establish a current finding.

---

# 7. Finding Confidence

Every finding MUST have a confidence level.

## CONFIRMED

Direct evidence demonstrates the issue.

## PROBABLE

Evidence strongly indicates the issue, but one important verification is
missing.

## POSSIBLE

The architecture suggests a risk, but evidence is insufficient.

## UNVERIFIED

Requires runtime, hardware, external-system, or operator verification.

The audit MUST NOT label an UNVERIFIED item as a confirmed defect.

---

# 8. Severity Model

## CRITICAL

Potential for:

* infrastructure-wide compromise;
* root compromise;
* secret compromise;
* catastrophic data loss;
* unrecoverable deployment;
* loss of primary management path.

---

## HIGH

Potential for:

* significant security boundary bypass;
* unsafe deployment;
* broken recovery;
* major service disruption;
* significant persistent-state corruption.

---

## MEDIUM

Potential for:

* operational instability;
* maintainability failure;
* moderate security weakness;
* duplicated ownership;
* significant architectural coupling.

---

## LOW

Limited operational or architectural impact.

---

## INFORMATIONAL

Useful observation with no current defect.

---

# 9. Audit Lifecycle

A complete audit follows:

```text
1. Identify repository state
2. Load architectural policy
3. Inventory implementation
4. Inventory runtime where possible
5. Compare expected vs actual
6. Revalidate historical findings
7. Record current findings
8. Assign confidence
9. Assign severity
10. identify root causes
11. assign ownership
12. define remediation
13. define verification
14. track migration
15. re-audit after changes
```

A finding is not closed because code was modified.

It is closed only after verification.

---

# 10. Current Repository Inventory

Every audit MUST regenerate inventory.

At minimum:

```bash
find . -type f | sort
```

Then classify:

```text
Nix files
Go files
Shell scripts
YAML/JSON
systemd definitions
architecture manifests
tests
documentation
```

Record:

```yaml
inventory:
  nix_files:
  go_files:
  shell_files:
  yaml_files:
  json_files:
  systemd_units:
  architecture_manifests:
  test_files:
```

Historical counts MUST NOT be copied forward without revalidation.

---

# 11. Current System Model

The audit MUST reconstruct the current system graph.

```text
                   HOST COMPOSITION
                          │
                          ▼
                    CAPABILITIES
                          │
                          ▼
                       DOMAINS
                          │
                          ▼
                     SERVICES
                          │
                          ▼
                  INFRASTRUCTURE
                          │
                          ▼
                   RUNTIME SYSTEM
```

The audit should document discrepancies between:

```text
architecture target
implementation
runtime
```

---

# 12. Host Composition Audit

For every host, determine:

```text
hostname
hardware
profiles
capabilities
domains
services
network role
security role
state
secrets
```

Minimum conceptual matrix:

| Host          | Hardware | Profiles | Capabilities | Services | Build  | Runtime |
| ------------- | -------- | -------- | ------------ | -------- | ------ | ------- |
| `prague`      | verify   | verify   | verify       | verify   | verify | verify  |
| `tuscany`     | verify   | verify   | verify       | verify   | verify | verify  |
| `testvm`      | verify   | verify   | verify       | verify   | verify | verify  |
| `oracle-edge` | verify   | verify   | verify       | verify   | verify | verify  |

Only list hosts that actually exist in the current repository.

---

## Host isolation checks

Audit for accidental inheritance of:

* disk UUIDs;
* hardware configuration;
* swap devices;
* GPU settings;
* hostnames;
* IP addresses;
* Tailscale roles;
* secrets;
* deployment targets.

Physical hardware configuration MUST NOT silently become another host's
fallback.

---

# 13. Capability Audit

For every important capability:

```text
Capability
Owner
Hosts
Dependencies
Security boundary
Configuration owner
State owner
Health check
Recovery
Tests
```

Examples:

```text
Tailscale
Exit Node
GitOps
Desktop
Remote Desktop
Backup
Monitoring
Developer Workstation
```

Audit for capabilities enabled implicitly through shared modules.

---

# 14. Domain Inventory Audit

Compare:

```text
actual repository domains
```

against:

```text
architecture/domains.yaml
```

Record:

```text
declared but absent
present but undeclared
duplicate ownership
ambiguous domain
obsolete domain
wrong directory
```

The domain inventory SHOULD be machine-generated or machine-validated.

---

# 15. Nix Architecture Audit

Inspect:

```text
flake.nix
flake.lock
configuration.nix
hosts
profiles
modules
auto-import mechanisms
overlays
checks
packages
devShells
```

Audit:

* evaluation determinism;
* host isolation;
* module ownership;
* automatic imports;
* option typing;
* duplicate definitions;
* assertions;
* unsupported assumptions;
* mutable dependencies.

---

## Auto-import audit

Automatic imports MUST NOT become implicit architecture authorization.

The audit MUST determine:

```text
Does an unregistered directory/file automatically enter system composition?
```

If yes, determine whether architecture policy prevents unsafe or unintended
composition.

---

# 16. Home Manager Audit

Inspect:

```text
home configuration
desktop settings
shell
applications
themes
MIME associations
GNOME configuration
user services
environment variables
```

Audit for:

* duplicated ownership with NixOS;
* host leakage;
* mutable user state assumptions;
* obsolete desktop configuration;
* user-level secrets;
* conflicting package declarations.

---

# 17. Go Control Plane Audit

Inspect:

```text
cmd/
internal/
services
interfaces
adapters
commands
configuration
tests
```

For every significant package determine:

```text
owner
responsibility
dependencies
state
filesystem access
network access
command execution
privileges
security boundary
```

Audit for:

* direct shell execution;
* arbitrary command construction;
* direct access to unrelated state;
* duplicated Nix configuration;
* hardcoded hostnames;
* hardcoded ports;
* bypassed service contracts;
* excessive privileges.

---

# 18. Runtime Service Audit

For each long-running service:

```text
Service
Owner
User
Group
StateDirectory
Configuration
Ports
Dependencies
Restart policy
Health check
Logs
Metrics
Security profile
Recovery
```

A service without clear ownership is an audit finding.

A persistent service without meaningful failure semantics SHOULD be considered
operationally incomplete.

---

# 19. Dependency Graph Audit

Reconstruct dependencies from:

```text
Nix imports
Go imports
service dependencies
systemd relationships
scripts
configuration references
architecture manifests
```

The audit must identify:

* cycles;
* undeclared dependencies;
* forbidden dependencies;
* host-to-domain dependencies;
* domain-to-private-state dependencies;
* service coupling.

---

## Dependency rule

Expected:

```text
host
 ↓
domain
 ↓
contract
 ↓
adapter
 ↓
platform/runtime
```

Unexpected:

```text
domain
 ↓
private implementation
```

or:

```text
service
 ↓
arbitrary shell
```

---

# 20. State Ownership Audit

For every important state resource determine:

```text
Path
Owner
Classification
Persistence
Backup
Consumers
Mutation authority
Recovery
```

Examples:

```text
/var/lib/tailscale
/var/lib/gitops
/var/lib/prometheus
/var/lib/loki
/var/lib/attic
/var/lib/deployment-health
```

A path with multiple mutation authorities is a HIGH or MEDIUM finding depending
on impact.

Read-only cross-domain access still constitutes a dependency and must be
reviewed.

---

# 21. Filesystem Ownership Audit

Inventory:

```text
/var/lib/*
/etc/*
/run/*
/home/*
/persist/*
/mnt/*
```

where relevant to repository policy.

Determine:

```text
owner
reader
writer
persistence class
backup class
security class
```

Audit for:

* undeclared writes;
* hidden state directories;
* cross-domain reads;
* cross-domain writes;
* services writing outside declared paths.

---

# 22. Configuration Ownership Audit

Search for duplicate configuration of:

```text
ports
paths
service endpoints
timeouts
resource limits
network policy
Tailscale
firewall
Nix settings
package lists
allowUnfree
substituters
```

For each resource:

```text
authoritative owner
declarations
consumers
conflicts
```

Duplicate configuration is an architectural finding only after ownership has
been established.

---

# 23. Secret Architecture Audit

Audit:

```text
SOPS
age
secret rules
CI secrets
runtime secret paths
service secret consumers
backup/recovery
rotation
revocation
```

Search for:

```text
private keys
tokens
passwords
credentials
AWS secrets
Git credentials
Tailscale credentials
```

Use secret-scanning tools in addition to textual searches.

---

## Required checks

Verify:

```text
no plaintext secret in Git
no secret in logs
no unnecessary broad secret scope
no duplicate secret-management system
host/service boundaries are explicit
recovery keys are protected
rotation procedures exist
```

---

# 24. Network Architecture Audit

Audit the entire network model:

```text
NetworkManager
DNS
IPv4
IPv6
routing
forwarding
NAT
nftables
Tailscale
LAN services
remote access
firewall
```

Determine:

```text
management plane
egress plane
LAN plane
tailnet plane
public/WAN plane
```

Audit:

* open ports;
* bind addresses;
* interface scope;
* forwarding;
* NAT;
* DNS behavior;
* VPN interaction;
* IPv6 behavior.

---

# 25. Prague Gateway Audit

Prague has an intentional gateway capability.

The audit MUST treat these as architectural invariants:

```text
Tailscale enabled
Tailscale operational
exit-node advertised
forwarding enabled
NAT functional
firewall permits intended forwarding
remote administration reachable
phone can use Prague for exit traffic
```

---

## 25.1 ACL baseline

The current working Tailscale ACL is the baseline.

The audit MUST NOT classify the ACL itself as defective merely because a newer
Tailscale policy model exists.

A policy migration requires independent validation.

---

## 25.2 Gateway test model

Separate:

```text
Tailscale connectivity
```

from:

```text
exit-node routing
```

Required conceptual tests:

```text
Phone
  ↓
Tailscale
  ↓
Prague
```

and independently:

```text
Phone
  ↓
Tailscale
  ↓
Prague exit node
  ↓
Internet
```

---

## 25.3 Gateway runtime evidence

Where runtime access exists inspect:

```bash
tailscale status
tailscale netcheck
tailscale ping <peer>
ip route
ip -6 route
sysctl net.ipv4.ip_forward
sysctl net.ipv6.conf.all.forwarding
sudo nft list ruleset
systemctl status tailscaled
```

Record whether connectivity is:

```text
DIRECT
DERP/RELAY
UNKNOWN
```

Do not infer one from the other.

---

# 26. Identity and Access Audit

Audit identity layers:

```text
human
device
Tailscale identity
SSH identity
service identity
root
CI runner
GitOps controller
```

Determine:

```text
who can connect
who can administer
who can deploy
who can decrypt
who can route traffic
who can access secrets
```

---

# 27. Process and systemd Audit

For each privileged service inspect:

```text
User
Group
Capabilities
NoNewPrivileges
ProtectSystem
ProtectHome
PrivateTmp
PrivateDevices
RestrictAddressFamilies
SystemCallFilter
ReadWritePaths
InaccessiblePaths
AppArmor
```

The audit must identify contradictory or ineffective security controls.

Example:

```text
NoNewPrivileges=yes
+
runtime reliance on sudo escalation
```

should be reviewed as a potentially contradictory security design.

---

# 28. Security Architecture Audit

Audit:

```text
SSH
Polkit
sudo
AppArmor
nftables
Tailscale
systemd hardening
auditd
fail2ban
SOPS
age
CI trust
GitOps privilege
filesystem permissions
```

Security findings MUST include:

```text
asset
threat
boundary
control
failure mode
evidence
```

---

## Security audit question

For every privileged component ask:

```text
What happens if this component is compromised?
```

Then determine:

```text
can it become root?
can it access secrets?
can it modify Git state?
can it modify deployment state?
can it modify firewall policy?
can it access other services?
```

---

# 29. Observability Audit

Determine whether important components expose:

```text
health
status
metrics
logs
failure reason
recovery state
```

Audit particularly:

```text
Tailscale
GitOps
deployment
rollback
backup
security services
critical systemd units
```

Observability must not become a second state owner.

---

# 30. Reliability and Resilience Audit

For critical capabilities determine:

```text
failure mode
detection
retry
recovery
RTO
RPO
SLO
```

At minimum audit:

```text
boot
network
Tailscale
exit node
SSH
GitOps
deployment
rollback
backup
observability
```

A recovery mechanism that exists only as a script but has never been exercised
is not considered proven recovery.

---

# 31. Deployment and GitOps Audit

Inspect:

```text
CI
merge flow
artifact flow
reconciliation
activation
health gate
rollback
deployment locks
```

Expected:

```text
commit
 ↓
review
 ↓
CI
 ↓
artifact / desired state
 ↓
deployment
 ↓
health
 ↓
accepted / rollback
```

Audit for:

* unrestricted repository execution;
* unnecessary root access;
* ambiguous exit codes;
* concurrent deployment;
* deployment without health validation;
* deployment state owned by multiple systems.

---

# 32. Supply-Chain and Provenance Audit

Audit:

```text
flake inputs
flake.lock
CI actions/images
package sources
binary caches
signing keys
build artifacts
deployment provenance
```

Desired relationship:

```text
commit SHA
   ↓
review
   ↓
CI
   ↓
build
   ↓
artifact
   ↓
signature/provenance
   ↓
deployment
   ↓
generation
```

The audit MUST identify breaks in that chain.

---

# 33. Testing and TDD Audit

Determine whether the repository validates:

```text
behavior
architecture
security
deployment
recovery
runtime integration
```

Audit whether tests:

* fail for the right reason;
* actually assert required behavior;
* suppress failure;
* test only file existence;
* test both allowed and forbidden behavior.

---

## TDD classification

For behavior-changing work classify:

```text
RED/GREEN verified
verification-first but no literal RED appropriate
no verification
```

The last category is architectural debt.

---

# 34. Architecture Enforcement Audit

Determine which policies are actually machine-enforced.

Minimum desired areas:

```text
domains
capabilities
dependencies
filesystem ownership
configuration ownership
exceptions
host isolation
security invariants
```

For every architectural rule ask:

```text
Is it documented?
Is it machine-readable?
Is it tested?
Does CI enforce it?
Can an AI agent accidentally violate it?
```

---

# 35. Documentation and ADR Audit

Audit consistency between:

```text
ARCHITECTURE.md
ARCHITECTURE_AUDIT.md
ARCHITECTURE_PROGRESS.md
architecture/*.yaml
ADRs
README
operational documentation
```

Find contradictions.

Examples:

```text
documentation says A
implementation does B
manifest says C
```

Those require explicit resolution.

---

# 36. Historical Finding Revalidation

Historical findings MUST be classified before use.

For every historical finding:

```text
OLD FINDING
    ↓
Does evidence still exist?
    │
    ├── YES → reclassify as active
    │
    └── NO
         ↓
      RESOLVED
```

Possible statuses:

```text
ACTIVE
RESOLVED
SUPERSEDED
INVALIDATED
UNVERIFIED
DEFERRED
```

Do not carry historical violations indefinitely.

---

# 37. Active Violation Register

All current confirmed findings belong here.

## Required format

| ID | Severity | Confidence | Domain | Finding | Evidence | Owner | Remediation | Verification | Status |
| -- | -------- | ---------- | ------ | ------- | -------- | ----- | ----------- | ------------ | ------ |

Each finding MUST have:

```text
unique ID
severity
confidence
owner
evidence
root cause
remediation
verification method
status
```

---

## Finding example

```yaml
id: ARCH-SEC-001
severity: HIGH
confidence: CONFIRMED
domain: security
finding: CI runner has broader Nix trust than required
evidence:
  - path: system/nix.nix
    type: E1
root_cause: privilege boundary too broad
owner: security
remediation: remove unnecessary trusted-user authority
verification:
  - architecture test
  - Nix evaluation
  - CI security test
status: OPEN
```

---

# 38. Architectural Debt Register

Track debt separately from active violations.

Examples:

```text
unclear ownership
duplicate abstraction
temporary compatibility layer
manual architecture inventory
missing ADR
missing runtime test
incomplete recovery testing
```

Debt should include:

```text
ID
description
impact
owner
priority
remediation
target milestone
status
```

---

# 39. Ownership Resolution Register

Every ownership conflict should be resolved explicitly.

Required fields:

```text
resource
current owners
target owner
reason
migration steps
verification
status
```

Example:

```text
Resource:
    /var/lib/gitops

Current:
    CI
    GitOps
    Recovery

Target:
    GitOps

Migration:
    define state contract
    migrate consumers
    remove direct filesystem access
    enforce ownership rule
```

---

# 40. Target-State Gap Analysis

The audit MUST compare current reality with target architecture.

At minimum evaluate:

| Area                     | Current | Target               | Gap    | Priority |
| ------------------------ | ------- | -------------------- | ------ | -------- |
| Domain ownership         | verify  | explicit             | verify |          |
| Capability model         | verify  | explicit             | verify |          |
| Host isolation           | verify  | enforced             | verify |          |
| Dependencies             | verify  | DAG + enforcement    | verify |          |
| State ownership          | verify  | one owner            | verify |          |
| Filesystem ownership     | verify  | enforced             | verify |          |
| Configuration ownership  | verify  | one source           | verify |          |
| Secret lifecycle         | verify  | explicit             | verify |          |
| Network model            | verify  | explicit planes      | verify |          |
| Prague gateway           | verify  | permanent invariant  | verify |          |
| Security boundaries      | verify  | least privilege      | verify |          |
| Observability            | verify  | contract-driven      | verify |          |
| Reliability              | verify  | measurable           | verify |          |
| GitOps                   | verify  | controlled privilege | verify |          |
| Supply chain             | verify  | attributable         | verify |          |
| Recovery                 | verify  | tested               | verify |          |
| Architecture enforcement | verify  | CI-gated             | verify |          |
| AI safety                | verify  | machine constrained  | verify |          |

Do not invent Current values.

---

# 41. Remediation Prioritization

Prioritize based on:

```text
Security impact
Availability impact
Recovery impact
Blast radius
Likelihood
Architectural centrality
Ease of remediation
```

Preferred remediation order:

```text
1. CRITICAL security / recovery defects
2. HIGH privilege and deployment defects
3. HIGH state/configuration ownership conflicts
4. Host isolation
5. Network and gateway correctness
6. Architecture enforcement
7. Observability gaps
8. Medium coupling/duplication
9. Low maintainability debt
```

Do not prioritize cosmetic cleanup over a deployment or security boundary.

---

# 42. Migration Verification Gates

Every remediation SHOULD pass progressive gates.

## Gate 1 — Static

```text
format
schema
architecture test
lint
```

---

## Gate 2 — Evaluation

```text
nix eval
host evaluation
assertions
```

---

## Gate 3 — Build

```text
nix build
dry-build
```

---

## Gate 4 — Integration

```text
service interaction
network policy
filesystem ownership
contract tests
```

---

## Gate 5 — Runtime

```text
systemd
network
Tailscale
desktop
ports
```

---

## Gate 6 — Recovery

```text
failure injection
rollback
recovery
health
```

---

## Gate 7 — CI

```text
full pipeline
architecture enforcement
security scanning
host matrix
```

A finding is not closed simply because Gate 1 passes.

---

# 43. Audit Evidence Requirements

Every audit finding MUST retain enough evidence for another engineer to
reproduce the conclusion.

Minimum evidence:

```text
repository commit
file/path
relevant code/configuration
test or command
result
interpretation
```

For runtime findings include:

```text
command
runtime timestamp
host
relevant output
```

Sensitive output MUST be sanitized.

Never store secrets in audit artifacts.

---

# 44. Audit Completion Criteria

An audit is complete only when:

## Identity

* [ ] Audit commit recorded.
* [ ] Architecture version recorded.
* [ ] Tool/environment version recorded.

## Inventory

* [ ] Repository inventory regenerated.
* [ ] Host inventory regenerated.
* [ ] Domain inventory regenerated.
* [ ] Runtime inventory performed where possible.

## Findings

* [ ] Historical findings revalidated.
* [ ] Active findings separated from resolved findings.
* [ ] Confidence assigned.
* [ ] Severity assigned.
* [ ] Owner assigned.
* [ ] Verification defined.

## Ownership

* [ ] State ownership audited.
* [ ] Filesystem ownership audited.
* [ ] Configuration ownership audited.
* [ ] Port ownership audited.
* [ ] Service ownership audited.

## Security

* [ ] Trust boundaries audited.
* [ ] Privilege boundaries audited.
* [ ] Secret lifecycle audited.
* [ ] Network exposure audited.
* [ ] Negative tests identified.

## Reliability

* [ ] Failure modes audited.
* [ ] Recovery paths audited.
* [ ] Backup reviewed.
* [ ] Rollback reviewed.
* [ ] Critical gateway behavior reviewed.

## Enforcement

* [ ] Architecture manifests audited.
* [ ] Architecture tests audited.
* [ ] Architecture linter audited.
* [ ] CI enforcement audited.
* [ ] Exceptions audited.

## Documentation

* [ ] Architecture consistency checked.
* [ ] ADR consistency checked.
* [ ] Audit updated.
* [ ] Progress document updated.

---

# 45. Final Audit Report Template

Every completed audit SHOULD end with this summary.

## Audit Summary

```text
Repository:
Branch:
Commit:
Audit date:

Overall conformance:
    CONFORMING
    PARTIALLY CONFORMING
    NON-CONFORMING
    INSUFFICIENT EVIDENCE
```

Do not use a numeric score unless a separate scoring model is formally
defined.

---

## Current Findings

```text
CRITICAL: N
HIGH:     N
MEDIUM:   N
LOW:      N
INFO:     N
```

---

## Confidence

```text
CONFIRMED:  N
PROBABLE:   N
POSSIBLE:   N
UNVERIFIED: N
```

---

## Top Root Causes

Identify systemic causes rather than repeating symptoms.

Example categories:

```text
implicit ownership
duplicate configuration
weak privilege boundary
insufficient architecture enforcement
missing runtime verification
host-specific logic embedded in generic code
```

---

## Host Status

For each host:

```text
host
build
evaluation
architecture
security
network
runtime
recovery
```

---

## Prague Gateway Status

Explicitly report:

```text
Tailscale:
Exit node:
Forwarding:
NAT:
Firewall:
DNS:
Remote administration:
Phone connectivity:
Exit-node routing:
Network recovery:
```

Each item MUST be marked:

```text
VERIFIED
UNVERIFIED
FAILED
NOT APPLICABLE
```

---

## Architecture Enforcement Status

Report:

```text
domains:
capabilities:
dependencies:
ownership:
exceptions:
security:
host isolation:
```

---

## Security Posture Summary

Do not provide an overall numeric security score unless a defined methodology
exists.

Instead report:

```text
confirmed weaknesses
unverified areas
important compensating controls
highest-risk boundaries
```

---

## Recovery Readiness

Report:

```text
backup:
rollback:
boot recovery:
service recovery:
network recovery:
Tailscale recovery:
deployment recovery:
```

---

## Open Remediation

Link every open issue to:

```text
ARCHITECTURE_PROGRESS.md
issue / MR
ADR
architecture exception
```

where applicable.

---

# 46. Audit Operating Loop

The repository's audit loop is:

```text
                    ┌─────────────────────┐
                    │ IDENTIFY AUDIT STATE│
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │ LOAD ARCHITECTURAL  │
                    │       POLICY        │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │ INVENTORY CURRENT   │
                    │       REALITY       │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │ INSPECT RUNTIME     │
                    │     WHERE POSSIBLE  │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │ COMPARE TO TARGET   │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │ REVALIDATE HISTORY  │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │ RECORD FINDINGS     │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │ CLASSIFY CONFIDENCE │
                    │    AND SEVERITY     │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │ ASSIGN OWNERSHIP    │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │ DEFINE REMEDIATION  │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │ VERIFY REMEDIATION  │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │ UPDATE AUDIT STATE  │
                    └──────────┬──────────┘
                               │
                               └──────────► RE-AUDIT
```

---

# Audit Doctrine

The following rules govern every future audit.

```text
1. The current repository is evidence of reality, not proof of architectural correctness.

2. ARCHITECTURE.md defines the normative target.

3. architecture/*.yaml defines machine-readable policy.

4. Tests and CI define executable enforcement.

5. ARCHITECTURE_AUDIT.md records evidence-backed conformance.

6. ARCHITECTURE_PROGRESS.md records migration state.

7. ADRs explain significant architectural decisions.

8. Historical findings must be revalidated.

9. An unverified runtime behavior must not be reported as a confirmed defect.

10. A change is not a remediation until verification proves the defect is gone.

11. Security findings must consider compromise and blast radius.

12. Read-only cross-domain access is still an architectural dependency.

13. Duplicate ownership is a root architectural defect, not merely a style issue.

14. Runtime functionality must be tested separately from build correctness.

15. Recovery is not considered proven until it has been exercised.

16. AI agents must not manufacture evidence.

17. AI agents must not silently change architectural policy.

18. AI-generated recommendations are not evidence.

19. Findings should identify root causes rather than multiply symptoms.

20. Architecture should progressively move from documented policy toward
    machine-enforced invariants.
```

---

# Closing Principle

The purpose of this audit is not to produce a long list of problems.

The purpose is to establish a reliable feedback loop:

```text
Architecture
     ↓
Current Reality
     ↓
Evidence
     ↓
Gap
     ↓
Root Cause
     ↓
Remediation
     ↓
Verification
     ↓
Enforcement
     ↓
Architecture becomes harder to violate
```

A healthy repository is therefore not one with a permanently empty audit.

A healthy repository is one in which:

```text
new drift is detected quickly
        +
violations are reproducible
        +
ownership is clear
        +
remediation is measurable
        +
architecture rules become increasingly automated
```

**`ARCHITECTURE.md` says what the system is supposed to be.**

**`ARCHITECTURE_AUDIT.md` proves where the system actually stands.**

**`ARCHITECTURE_PROGRESS.md` explains how remaining gaps are being closed.**

That separation is the foundation of an architecture that can safely evolve under
human and AI-assisted engineering.
