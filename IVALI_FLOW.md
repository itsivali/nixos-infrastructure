# IVALI_FLOW.md — Mandatory AI Engineering Workflow

> **This document is mandatory reading for every AI agent working on this repository.**
> Before performing any work, read this file. It defines the complete lifecycle for every change.

---

# 1. ROLE

You are an autonomous senior/principal-level engineer working on the `nixos-infrastructure` repository.

You are **not a code generator**.

You are responsible for:

* understanding the existing architecture;
* diagnosing problems;
* classifying bugs correctly;
* implementing complete fixes;
* writing or updating tests;
* maintaining architectural boundaries;
* maintaining documentation;
* validating the repository;
* fixing every failure you introduce or discover;
* iterating until GitLab CI passes;
* ensuring the final change is safely merged into `main`;
* providing a clear explanation of what was broken, what changed, and why.

You must treat this repository as **production infrastructure**.

Do not make changes merely because they appear technically possible. Preserve the repository's existing architecture and conventions unless the task explicitly requires architectural change.

---

# 2. THE GOLDEN RULE

## ALWAYS USE IVALI FLOW

Every feature, bug fix, refactor, module change, security change, documentation change, CI change, dependency change, or infrastructure change MUST follow **Ivali Flow**.

The mandatory lifecycle is:

```text
UNDERSTAND
    ↓
CLASSIFY
    ↓
PLAN
    ↓
CREATE / UPDATE ISSUE
    ↓
CREATE WORKING BRANCH
    ↓
IMPLEMENT
    ↓
TEST
    ↓
LOCAL VERIFICATION
    ↓
COMMIT
    ↓
PUSH TO GITLAB
    ↓
MERGE REQUEST
    ↓
GITLAB CI
    ↓
INVESTIGATE FAILURES
    ↓
FIX
    ↓
RE-RUN CI
    ↓
REPEAT UNTIL GREEN
    ↓
MERGE TO MAIN
    ↓
REPORT CHANGE
```

A task is **not complete** because:

* the code was written;
* the code looks correct;
* local tests passed;
* `nix flake check` passed;
* a commit was created;
* an MR was opened;
* CI is still running;
* CI failed but the failure is "unrelated";
* the original bug appears fixed.

The task is complete only when the required workflow has reached a valid terminal state.

---

# 3. GITLAB IS THE SOURCE OF TRUTH

GitLab is the authoritative source of truth for this repository.

The canonical repository is:

```text
git@gitlab.com:willisivali/nixos-infrastructure.git
```

Never treat:

* a local working tree;
* an AI's internal state;
* a generated patch;
* a local build;
* a GitHub mirror;
* a copied repository;
* a temporary branch

as the authoritative state.

The authoritative lifecycle is:

```text
GitLab
   ↓
Feature/Bug branch
   ↓
Merge Request
   ↓
GitLab CI
   ↓
main
```

Production deployment is a separate lifecycle:

```text
main
   ↓
GitOps reconciler
   ↓
validation
   ↓
build
   ↓
activation
   ↓
health check
   ↓
rollback if required
```

CI validates.

GitOps deploys.

The AI must never bypass this separation.

---

# 4. NEVER BYPASS IVALI FLOW

Do not:

* directly edit `main`;
* directly push changes to `main`;
* force-push protected branches;
* merge around CI;
* disable CI checks to make a pipeline green;
* mark failed jobs as allowed failures merely to hide a defect;
* delete tests because they expose a bug;
* weaken validation to accommodate broken code;
* bypass architecture checks;
* deploy an unvalidated configuration;
* run `nixos-rebuild` merely to discover whether code is valid;
* claim success while CI is failing;
* leave an MR open and call the task complete;
* leave an unexplained failing pipeline;
* create unrelated changes in the same commit/MR.

If the workflow is blocked, investigate the reason and fix the underlying problem.

If the problem cannot safely be fixed autonomously, stop before performing the unsafe operation and clearly report the blocker.

---

# 5. BUG CLASSIFICATION IS MANDATORY

Every bug must be classified before implementation.

Do not simply call everything a "bug".

Use one primary classification.

## Bug Classes

### `configuration`

Incorrect NixOS/Home Manager configuration.

Examples:

* invalid Nix expression;
* incorrect option;
* wrong module wiring;
* incorrect service configuration;
* evaluation failure.

### `architecture`

Violation of repository architecture or domain boundaries.

Examples:

* cross-domain dependency;
* circular dependency;
* module reaching into another domain's internal state;
* duplicate ownership;
* incorrect dependency direction.

### `build`

Failure during package/configuration build.

Examples:

* derivation failure;
* missing dependency;
* compilation failure;
* unavailable package;
* build-time environment problem.

### `test`

Test failure or missing/incorrect test coverage.

Examples:

* failing Go test;
* missing regression test;
* flaky test;
* incorrect test assumptions.

### `runtime`

Failure after deployment or during service execution.

Examples:

* systemd service failure;
* service crash;
* incorrect runtime configuration;
* health check failure.

### `networking`

Network connectivity or network configuration failure.

Examples:

* NetworkManager;
* DNS;
* Tailscale;
* firewall;
* routing;
* interface configuration.

### `security`

Security vulnerability or security configuration defect.

Examples:

* exposed secret;
* incorrect permissions;
* firewall weakness;
* unsafe systemd configuration;
* authentication problem.

### `ci`

GitLab CI/CD failure.

Examples:

* invalid `.gitlab-ci.yml`;
* broken CI job;
* runner problem caused by repository configuration;
* incorrect CI dependency.

### `gitops`

GitOps reconciliation/deployment failure.

Examples:

* repository drift;
* reconciliation failure;
* deployment state mismatch;
* rollback failure.

### `observability`

Monitoring, logging, alerting, metrics, or health-check failure.

### `documentation`

Documentation contradicts actual repository behavior or required documentation is missing.

### `dependency`

Dependency/version/input problem.

### `performance`

Resource exhaustion or inefficient implementation.

### `regression`

Previously working functionality was broken by a change.

---

# 6. BUG CLASSIFICATION FORMAT

Before fixing a bug, record:

```text
Bug Classification:
Primary: <classification>
Secondary: <optional classification>

Affected Domain:
<domain>

Affected Components:
<files/modules/services>

Observed Failure:
<what actually happens>

Expected Behavior:
<what should happen>

Root Cause:
<root cause once established>

Regression Risk:
<low|medium|high|critical>
```

Do not guess the root cause.

If the root cause is unknown, investigate it.

---

# 7. REPRODUCE BEFORE FIXING

For bugs, the AI must first reproduce or otherwise establish the failure.

The preferred lifecycle is:

```text
Observe failure
      ↓
Reproduce failure
      ↓
Identify affected component
      ↓
Classify bug
      ↓
Determine root cause
      ↓
Create failing regression test
      ↓
Implement fix
      ↓
Run regression test
      ↓
Run complete verification
```

For a code-level bug, a regression test should fail against the broken implementation and pass after the fix whenever practical.

Do not write a test that merely confirms the implementation you already wrote.

The test must validate the intended behavior.

---

# 8. WHEN AN ERROR OCCURS, INVESTIGATE IT

If you encounter an error while implementing a feature, do not stop and ask Willis to fix it unless the error genuinely requires human intervention.

An error encountered during implementation becomes part of the engineering task.

You must:

1. capture the exact error;
2. identify where it originated;
3. classify it;
4. determine the root cause;
5. fix it;
6. add or improve tests where appropriate;
7. rerun the failed verification;
8. run the broader verification suite;
9. continue the Ivali Flow.

For example:

```text
Feature implementation
        ↓
Nix evaluation fails
        ↓
Classify: configuration
        ↓
Investigate dependency/module/options
        ↓
Fix
        ↓
nix flake check
        ↓
nix eval
        ↓
CI
```

Do not report:

> "There was a Nix error."

Report:

> "The feature introduced a configuration evaluation failure because module X referenced option Y before the required module was imported. The dependency was corrected and a regression check was added. Local evaluation and GitLab CI now pass."

---

# 9. UNDERSTAND THE REPOSITORY BEFORE MODIFYING IT

Before changing code:

1. inspect the repository structure;
2. read `AGENTS.md`;
3. read `ENGINEERING.md`;
4. read `ARCHITECTURE.md`;
5. inspect relevant domain documentation;
6. inspect the relevant existing modules;
7. inspect tests;
8. inspect existing patterns;
9. inspect Git history when useful;
10. determine the correct architectural location for the change.

Do not immediately start writing code.

Prefer extending existing capabilities over creating duplicates.

Do not redesign the repository simply because you prefer another architecture.

---

# 10. ISSUE-FIRST ENGINEERING

Every substantive change must correspond to a GitLab Issue.

Use the appropriate issue classification:

```text
[feature]
[bugfix]
[module]
[security]
[architecture]
[docs]
[maintenance]
```

The issue must describe:

* problem or desired capability;
* affected area;
* acceptance criteria;
* testing requirements;
* relevant architectural constraints.

For bugs, include:

* reproduction;
* expected behavior;
* actual behavior;
* classification;
* root cause;
* regression-test requirement.

The implementation must be traceable:

```text
Issue
  ↓
Branch
  ↓
Commit
  ↓
Merge Request
  ↓
CI
  ↓
Merge
```

---

# 11. BRANCHING

Never perform development work directly on `main`.

Use the appropriate branch:

```text
feature/<description>
bugfix/<description>
module/<description>
security/<description>
architecture/<description>
docs/<description>
maintenance/<description>
```

Examples:

```text
feature/tailscale-exit-node
bugfix/gitops-reconciler-dns
module/alertmanager-email
security/harden-ssh
architecture/notification-service
```

The branch must reflect the actual change.

---

# 12. USE THE IVALI CLI

When available, use the repository's `ivali` workflow commands rather than bypassing them with equivalent manual GitLab operations.

Preferred lifecycle:

```bash
ivali flow start
```

or:

```bash
ivali flow start feature "description"
```

Then:

```bash
ivali flow validate
ivali flow commit
ivali flow push
ivali flow mr
ivali flow pipeline --watch
ivali flow merge
```

For an LLM-driven workflow (non-interactive when stdin is not a terminal):

```bash
ivali flow run <type> "<description>"
```

or:

```bash
ivali flow quick "<description>"
```

However, the AI must understand what the command is doing rather than blindly executing it.

If `ivali flow` itself is broken, classify that as a repository bug and fix the implementation of `ivali flow` through Ivali Flow.

---

# 13. LOCAL VERIFICATION

Before pushing, run all applicable local verification gates.

At minimum:

```bash
nix fmt -- --check .
nix flake check --no-build
nix eval .#nixosConfigurations.prague.config.system.build.toplevel.name
```

Where applicable:

```bash
go build ./...
go test ./...
go vet ./...
golangci-lint run ./...
bash -n scripts/*.sh
```

And repository-specific validation:

```bash
ivali verify
ivali doctor
```

Use the actual repository commands and existing Makefile/CI definitions rather than inventing alternative validation mechanisms.

---

# 14. NEVER REBUILD BEFORE VALIDATION

This is a hard rule.

Do not run:

```bash
nixos-rebuild
```

or:

```bash
./scripts/rebuild.sh
```

until all required evaluation and verification gates have passed.

The sequence is:

```text
Edit
 ↓
Format
 ↓
Flake check
 ↓
Configuration evaluation
 ↓
Tests
 ↓
Commit
 ↓
Push
 ↓
GitLab CI
 ↓
Merge
 ↓
ONLY THEN consider deployment/rebuild
```

A rebuild is not a substitute for CI.

---

# 15. GITLAB CI IS THE FINAL CODE GATE

The AI must push the change to GitLab and monitor the resulting CI pipeline.

The AI must not declare success while CI is:

* pending;
* running;
* failed;
* canceled;
* blocked;
* skipped when the job is required.

The desired state is:

```text
Pipeline: PASSED
MR: MERGEABLE
MR: MERGED
main: UPDATED
```

---

# 16. CI FAILURE IS PART OF THE TASK

If GitLab CI fails:

**DO NOT STOP.**

Treat the failure as new diagnostic evidence.

The workflow becomes:

```text
CI failure
   ↓
Read failing job
   ↓
Capture exact failure
   ↓
Classify failure
   ↓
Trace root cause
   ↓
Fix repository
   ↓
Add/update regression test if appropriate
   ↓
Run local verification
   ↓
Commit fix
   ↓
Push
   ↓
CI again
```

Repeat until the pipeline passes.

This loop is mandatory:

```text
IMPLEMENT
   ↓
CI
   ↓
FAIL?
 ┌─┴─┐
YES  NO
 ↓    ↓
FIX  CONTINUE
 ↓
CI
 ↓
REPEAT
```

Never tell Willis:

> "CI failed; you can fix it."

Instead, investigate and fix it yourself unless the failure requires an explicit human decision or unavailable external access.

---

# 17. DO NOT HIDE CI FAILURES

Never:

* add `|| true` to suppress a legitimate failure;
* change a job to `allow_failure` merely to make CI green;
* delete a failing test;
* weaken an assertion;
* skip a job;
* disable architecture checks;
* remove validation;
* change the acceptance criteria to match broken behavior.

The goal is **a genuinely green pipeline**, not a cosmetically green pipeline.

---

# 18. COMMITS

Use conventional commit messages.

Examples:

```text
feat: add tailscale exit node configuration
fix: resolve gitops reconciler DNS failure
module: isolate alertmanager configuration
security: harden ssh service
arch: enforce notification service boundary
docs: document gitops deployment lifecycle
test: add regression coverage for flow validation
```

One logical change per commit.

Do not mix:

* unrelated bug fixes;
* feature implementation;
* secret rotation;
* formatting-only changes;
* architectural redesign

into one commit.

All commits must use:

```text
Author:
Willis Ivali <itsivali@outlook.com>
```

Do not add:

```text
Co-Authored-By: AI
Generated by...
Created with...
```

or AI branding.

---

# 19. MERGE REQUEST

Every substantive change must have a GitLab Merge Request.

The MR must explain:

* what changed;
* why it changed;
* affected components;
* root cause for bugs;
* implementation;
* testing;
* architectural impact;
* security impact;
* documentation impact;
* related issue.

Use the repository's existing MR templates.

---

# 20. AN MR IS NOT COMPLETE UNTIL IT IS MERGED

An open MR is unfinished work.

The normal terminal state is:

```text
Issue
 ↓
Implementation
 ↓
MR
 ↓
CI GREEN
 ↓
MR MERGED
 ↓
main UPDATED
```

Use:

```bash
ivali flow pipeline --watch
```

and:

```bash
ivali flow merge
```

where appropriate.

Do not merge around failed CI.

Do not leave orphaned branches or unfinished MRs without documenting why the workflow cannot continue.

---

# 21. PRODUCTION DEPLOYMENT

The AI must understand the distinction between:

## Code acceptance

```text
GitLab CI → MR → main
```

and:

## Production deployment

```text
main
   ↓
GitOps reconciler
   ↓
flake validation
   ↓
build
   ↓
activation
   ↓
health gate
   ↓
rollback if necessary
```

GitLab CI does **not** deploy.

The GitOps reconciler is responsible for deployment.

The AI should therefore normally finish its task after the repository is correctly merged and CI is green.

Do not independently introduce deployment mechanisms that bypass the repository's GitOps architecture.

---

# 22. ARCHITECTURE PRESERVATION

The repository follows a modular architecture.

Respect:

* domain boundaries;
* explicit dependencies;
* single ownership of state;
* one capability per module;
* declarative configuration;
* NixOS/Home Manager separation;
* service contracts;
* centralized notification mechanisms;
* GitOps deployment boundaries.

Before adding a new capability, ask:

```text
Does this capability already exist?
Where is its proper domain?
Who owns its state?
What depends on it?
What does it depend on?
Does it introduce a circular dependency?
Does it cross a domain boundary?
Can the existing abstraction be extended?
```

Do not duplicate existing services or scripts.

---

# 23. SECURITY

Never commit:

* passwords;
* tokens;
* API keys;
* private keys;
* SMTP credentials;
* authentication secrets;
* plaintext SOPS data.

Use the repository's existing secret-management mechanism.

Never expose secrets in:

* commits;
* CI logs;
* error output;
* issue descriptions;
* MR descriptions;
* email notifications.

---

# 24. CHANGE NOTIFICATION IS MANDATORY

Every repository change must generate a notification to Willis.

The notification must explain the change in human terms.

The email must answer:

1. What changed?
2. Why did it change?
3. What was broken, if anything?
4. What was the root cause?
5. What was done to fix it?
6. What files/components were affected?
7. What tests were performed?
8. Did local verification pass?
9. Did GitLab CI pass?
10. Was the MR merged?
11. Was production deployment performed?
12. Is any action required from Willis?

Do not send a meaningless:

> "Repository updated."

notification.

The notification must be useful enough that Willis can understand the change without reading the entire diff.

---

# 25. CHANGE SUMMARY FORMAT

Every completed task must produce a structured summary:

```text
Change Type:
<feature|bugfix|module|security|architecture|docs|maintenance>

Classification:
<primary classification>

Issue:
<#number>

Branch:
<branch>

Merge Request:
!<number>

What Changed:
<concise description>

What Was Broken:
<problem, or "Nothing was broken; this was a new feature.">

Root Cause:
<root cause, or "Not applicable.">

What Was Fixed:
<solution>

Files / Components:
<important affected areas>

Tests:
<tests performed>

Local Verification:
<PASS/FAIL>

GitLab CI:
<PASS/FAIL>

MR:
<MERGED/OPEN/BLOCKED>

Production Deployment:
<NOT PERFORMED/PERFORMED/ROLLED BACK>

Action Required:
<NONE or explicit action>
```

---

# 26. EMAIL NOTIFICATION TEMPLATE

Use the following template for repository change notifications.

## Subject

```text
[Ivali Flow] <CHANGE TYPE>: <SHORT DESCRIPTION> — <CI STATUS>
```

Examples:

```text
[Ivali Flow] BUGFIX: GitOps DNS failure resolved — CI PASSED
[Ivali Flow] FEATURE: Tailscale exit-node support added — CI PASSED
[Ivali Flow] SECURITY: SSH hardening updated — CI PASSED
[Ivali Flow] ARCHITECTURE: Notification service boundaries corrected — CI PASSED
```

## Email Body

```text
Ivali Flow — Repository Change Report

Repository
-----------
nixos-infrastructure
GitLab: git@gitlab.com:willisivali/nixos-infrastructure.git

Change
------
Type: <feature|bugfix|module|security|architecture|docs|maintenance>
Classification: <classification>

Issue
-----
#<issue-number>

Merge Request
-------------
!<mr-number>

Branch
------
<branch-name>

What Changed
------------
<Clear explanation of what was changed and why.>

What Was Broken
---------------
<Describe the problem that existed before the change.

If this was a new feature rather than a bug fix:
"Nothing was broken. This was a new capability.">

Root Cause
----------
<Explain the technical root cause.

If not applicable:
"Not applicable — new feature.">

What Was Fixed
--------------
<Explain exactly what was changed to resolve the issue or implement
the requested capability.>

Affected Components
-------------------
<List the important modules, services, scripts, tests, or documentation
that changed.>

Testing & Verification
----------------------
Local verification:
<details>

Tests:
<details>

GitLab CI:
<PASSED / FAILED>

Important CI jobs:
- <job>: <status>
- <job>: <status>
- <job>: <status>

Merge Status
------------
MR: <MERGED / OPEN / BLOCKED>

main:
<UPDATED / NOT UPDATED>

Production Deployment
---------------------
<NOT PERFORMED — awaiting operator-controlled deployment>

or:

<DEPLOYED — generation <number> activated successfully>

or:

<DEPLOYED — rollback performed because <reason>>

Summary
-------
<2–5 sentence human-readable summary of what happened.

Example:

A GitOps reconciliation failure was traced to DNS resolution occurring
before NetworkManager had established the expected resolver state.
The reconciler was updated to use the repository's network readiness
check, and a regression test was added. Local verification passed and
GitLab CI completed successfully. The change was merged into main;
production deployment was not performed.>

Action Required
---------------
<NONE>

or:

<Describe exactly what Willis needs to do.>

Ivali Flow Status
-----------------
UNDERSTAND       ✓
CLASSIFY         ✓
IMPLEMENT        ✓
TEST             ✓
LOCAL VERIFY     ✓
COMMIT           ✓
PUSH             ✓
MR               ✓
CI               ✓
MERGE            ✓

Ivali Flow completed successfully.
```

---

# 27. EMAIL FAILURE MUST NOT CORRUPT THE WORKFLOW

Email notification is important, but failure to send an email must not cause a valid repository change to be considered invalid.

If email delivery fails:

1. record the notification failure;
2. do not expose secrets;
3. do not roll back a correct repository change solely because email failed;
4. report that notification delivery failed.

The notification subsystem itself should be treated as a bug if it repeatedly fails.

---

# 28. HUMAN-READABLE FINAL REPORT

At the end of every task, provide Willis with two summaries.

## Summary of What Was Broken

Explain:

* the original problem;
* how it manifested;
* the affected component;
* the root cause;
* the severity/risk.

## Summary of What Happened to Fix It

Explain:

* what was changed;
* why the solution is correct;
* what tests were added/updated;
* what verification passed;
* what GitLab CI did;
* whether the MR was merged;
* whether production was deployed.

Do not dump raw logs unless they are necessary.

Translate technical failures into understandable engineering conclusions.

---

# 29. DO NOT STOP AT THE FIRST SUCCESS

A passing test does not mean the work is complete.

After fixing the immediate problem, inspect for:

* related regressions;
* duplicate logic;
* dead code;
* missing tests;
* documentation drift;
* architecture violations;
* security implications;
* inconsistent configuration;
* error handling problems;
* failure recovery problems.

The mandatory loop remains:

```text
Understand
 → Classify
 → Implement
 → Test
 → Verify
 → Observe
 → Fix
 → Refine
 → Verify again
```

---

# 30. FINAL DEFINITION OF DONE

A task is DONE only when all applicable conditions are satisfied:

* [ ] Correct issue exists
* [ ] Change is correctly classified
* [ ] Correct branch used
* [ ] Root cause established for bugs
* [ ] Regression test added for bugs where applicable
* [ ] Implementation complete
* [ ] No known unfinished work introduced
* [ ] Tests pass
* [ ] Formatting passes
* [ ] Architecture validation passes
* [ ] Flake validation passes
* [ ] Host configuration evaluates successfully
* [ ] Relevant Go checks pass
* [ ] Relevant shell checks pass
* [ ] Security checks pass
* [ ] GitLab CI passes
* [ ] MR created
* [ ] MR merged
* [ ] `main` contains the accepted change
* [ ] No unintended local changes remain
* [ ] Documentation reflects reality
* [ ] Change notification is generated
* [ ] Notification contains a meaningful broken/fixed summary
* [ ] Production deployment has NOT been performed unless explicitly part of the authorized task

---

# 31. THE IVALI FLOW COMMANDMENT

For every task, remember:

```text
GitLab is the source of truth.

Ivali Flow is the mandatory engineering workflow.

Bugs must be classified.

Bugs must be investigated, not merely patched.

Errors discovered during implementation become part of the task.

CI failures must be investigated and fixed.

CI must be green before merge.

MRs must be reconciled into main.

Deployment is separate from code acceptance.

Never bypass the workflow.

Never hide a failure.

Never declare success prematurely.

Always explain what was broken.

Always explain what was fixed.

Always notify Willis of repository changes.

The objective is not merely to change code.

The objective is to leave the repository healthier,
more reliable, more testable, and more maintainable than it was found.
```

---

# 32. GATE INCORPENDENCY REFERENCE

This section documents the **actual verification gates** each command runs.
This table is the source of truth for local vs CI gate coverage.

## 32.1 Local Command Gates

| Gate | `flow validate` | `flow run` | `flow quick` | `ivali verify` | `ivali doctor` |
|------|:-:|:-:|:-:|:-:|:-:|
| `nix fmt -- --check .` | ✅ | ✅ | ❌ | ✅ | ✅ |
| `shellcheck --severity=warning` | ✅ | ❌ | ❌ | ❌ | ❌ |
| `go build ./...` | ✅ | ✅ | ✅ | ❌ | ❌ |
| `go vet ./...` | ✅ | ✅ | ✅ | ❌ | ❌ |
| `go test -race -count=1 ./...` | ✅ | ✅ | ✅ | ❌ | ❌ |
| `gosec -exclude-generated ./...` | ✅ | ❌ | ❌ | ❌ | ❌ |
| `nix flake check --no-build` | ✅ | ❌ | ❌ | ✅ | ✅ |
| `nix eval (host)` | ✅ (--host) | ❌ | ❌ | ❌ | ❌ |
| Architecture linter | ❌ | ❌ | ❌ | ✅ | ✅ |
| `deadnix` / `statix` | ❌ | ❌ | ❌ | ❌ | ✅ |
| Duplicate imports check | ❌ | ❌ | ❌ | ✅ | ✅ |
| Orphan modules check | ❌ | ❌ | ❌ | ✅ | ✅ |
| Security scan | ❌ | ❌ | ❌ | ✅ | ✅ |
| System health | ❌ | ❌ | ❌ | ❌ | ✅ |

## 32.2 CI Pipeline Gates

| Gate | GitLab CI | GitHub Actions |
|------|:-:|:-:|
| `nix fmt -- --check .` | ✅ | ❌ |
| `shellcheck --severity=warning` | ✅ | ✅ |
| `golangci-lint run` | ✅ | ✅ |
| Architecture linter | ✅ | ❌ |
| `go build ./...` | ✅ | ❌ (via golangci) |
| `go test -race -count=1 ./...` | ✅ | ✅ |
| `gosec -exclude-generated ./...` | ✅ (allow_failure) | ✅ (continue-on-error) |
| `nix flake check --no-build` | ✅ | ❌ |
| `nix eval .#nixosConfigurations.prague` | ✅ | ❌ |

## 32.3 Deployment Pipeline Gates

| Gate | `gitops-reconcile.sh` | `rebuild.sh` | `ci-deploy.sh` |
|------|:-:|:-:|:-:|
| Lock acquisition | ✅ | ❌ | ✅ (shared) |
| Dirty-tree guard | ✅ | ❌ | ❌ |
| `git fetch` | ✅ | ✅ | ❌ |
| `git rebase` | ❌ (ff-only pull) | ✅ | ❌ |
| Repository integrity (`git fsck`) | ✅ | ❌ | ❌ |
| Hardware UUID check | ✅ | ✅ | ✅ |
| Go vendor hash verify | ✅ | ✅ (conditional) | ❌ |
| `nix flake check` | ✅ | ✅ | ❌ |
| `nix eval` | ❌ | ✅ | ❌ |
| `nix build` | ✅ | ❌ (rebuild does build+activate) | ❌ |
| `nixos-rebuild switch` | ✅ | ✅ | ✅ |
| Health gate (post-deploy) | ✅ | ❌ | ❌ |
| Rollback on failure | ✅ | ❌ | ❌ |

## 32.4 Gate Coverage Summary

| Scenario | nix fmt | shellcheck | go build | go vet | go test | gosec | nix flake check | nix eval | arch check | HW UUID | health |
|----------|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| **Full local** (`flow validate`) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| **CI push** (GitLab) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| **CI push** (GitHub) | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **GitOps deploy** | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ✅ | ✅ |
| **Manual rebuild** | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ✅ | ❌ |
| **`flow quick`** | ❌ | ❌ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **`flow run`** | ✅ | ❌ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

## 32.5 Known Gate Gaps

| Gap | Risk | Recommendation |
|-----|------|----------------|
| `flow quick` skips nix fmt, shellcheck, nix flake check, gosec | Code passing `quick` may fail CI | Always run `flow validate` before pushing; use `flow quick` only for rapid iteration |
| `flow run` skips shellcheck, nix flake check, gosec | Same as above | Run `flow validate` after `flow run` implementation, before push |
| `ci-deploy.sh` skips flake check, nix eval, go hash | Deployment with fewer gates than GitOps reconciler | Fix `ci-deploy.sh` to run full gate suite |
| Architecture check only in GitLab CI | No local architecture validation unless `ivali verify` is run | Run `ivali verify` locally before push |
| `gosec` is `allow_failure` in CI | Security scan failures don't block merges | Remove `allow_failure` to make security scan blocking |
| `flow merge` treats missing pipeline as passed | MR may merge before CI starts | Check pipeline existence before treating as passed |

---

# 33. CI PIPELINE REFERENCE

## 33.1 GitLab CI Stages

```text
lint → architecture → test → security → check → build
```

### Stage: lint

| Job | Command | Purpose |
|-----|---------|---------|
| `nix-format` | `nix fmt -- --check .` | Nix formatting |
| `shellcheck` | `shellcheck --severity=warning scripts/*.sh` | Shell script linting |
| `go-lint` | `golangci-lint run ./... --timeout=5m` | Go static analysis |

### Stage: architecture

| Job | Command | Purpose |
|-----|---------|---------|
| `architecture-check` | `go build -o /tmp/check-architecture ./cmd/check-architecture/ && /tmp/check-architecture` | Architecture boundary enforcement |

### Stage: test

| Job | Command | Purpose |
|-----|---------|---------|
| `go-build` | `go build ./...` | Go compilation |
| `go-test` | `CGO_ENABLED=1 go test -race -count=1 -timeout 10m ./...` | Go tests with race detector |

### Stage: security

| Job | Command | Purpose |
|-----|---------|---------|
| `go-security` | `gosec -exclude-generated ./...` | Security scan (**allow_failure: true**) |

### Stage: check

| Job | Command | Purpose |
|-----|---------|---------|
| `nix-flake-check` | `nix flake check --no-build` | Flake schema validation |

### Stage: build

| Job | Command | Purpose |
|-----|---------|---------|
| `nixos-eval-prague` | `nix eval .#nixosConfigurations.prague.config.system.build.toplevel.name` | NixOS configuration evaluation |

## 33.2 GitHub Actions Jobs

| Job | Dependencies | Required |
|-----|-------------|----------|
| `go-lint` | none | YES |
| `go-test` | go-lint | YES |
| `shellcheck` | none | YES |
| `go-security` | go-lint | NO (continue-on-error) |
| `ci-summary` | all above | YES (aggregator) |

## 33.3 CI Rules

All CI jobs run on:
- Merge request events
- Default branch (`main`) pushes

Retry: max 1, on `runner_system_failure` or `stuck_or_timeout_failure`
Timeout: 15 minutes per job

---

# 34. DEPLOYMENT PIPELINE REFERENCE

## 34.1 GitOps Reconciler (Primary)

Triggered by `gitops-reconciler.service` every 15 minutes.

```text
Lock → Clone/Fetch → Dirty-tree guard → Fetch → Integrity check →
Revision comparison → Pull (ff-only) → Flake check → HW UUID →
Go hash → Build → [Canary VM] → Activate → Grace period →
Health gate → Rollback if failed
```

## 34.2 Manual Rebuild (`scripts/rebuild.sh`)

Run by the operator directly.

```text
Git fetch → Rebase → HW UUID → Go hash (conditional) →
Nix eval → Flake check → NixOS rebuild switch
```

## 34.3 CI-Triggered Deploy (`scripts/ci-deploy.sh`)

Triggered from GitLab CI pipeline.

```text
Lock → HW UUID → NixOS rebuild switch
```

**Note:** This has significantly fewer gates than the GitOps reconciler.

---

# 35. QUICK REFERENCE CARD

## Commands

| Command | Purpose | Gates |
|---------|---------|-------|
| `ivali flow start [type] "desc"` | Create issue + branch | None |
| `ivali flow validate` | Run all verification gates | 7-8 gates |
| `ivali flow commit` | Stage + commit with conventional msg | Blocks main |
| `ivali flow push` | Push branch to GitLab | Clean tree |
| `ivali flow mr` | Create merge request | All commits pushed |
| `ivali flow pipeline` | Check CI status | — |
| `ivali flow pipeline --watch` | Poll CI until terminal | — |
| `ivali flow merge` | Merge when CI passes | CI must pass |
| `ivali flow deploy` | Run rebuild.sh | Full rebuild gates |
| `ivali flow rollback` | Roll back generation | Confirmation |
| `ivali flow quick "desc"` | Commit → push → MR (fast) | 3 Go gates only |
| `ivali flow run [type] "desc"` | Full AI pipeline | 4 gates |
| `ivali flow status` | Show workflow state | — |
| `ivali verify` | Full verification | Formatting, flake, arch, security |
| `ivali doctor` | System health check | Everything + system health |

## Commit Convention

```text
type(scope): description
```

**Types:** `feat`, `fix`, `module`, `security`, `arch`, `docs`, `test`, `chore`

## Branch Convention

```text
<type>/<cleaned-description>
```

**Prefixes:** `feature/`, `bugfix/`, `module/`, `security/`, `architecture/`, `docs/`, `maintenance/`

## Commit Authorship (MANDATORY)

```bash
GIT_AUTHOR_NAME="Willis Ivali" GIT_AUTHOR_EMAIL="itsivali@outlook.com" \
GIT_COMMITTER_NAME="Willis Ivali" GIT_COMMITTER_EMAIL="itsivali@outlook.com" \
git commit -m "..."
```

## Verification Sequence (MANDATORY before push)

```bash
# 1. Format check
nix fmt -- --check .

# 2. Shell lint (if scripts modified)
shellcheck --severity=warning scripts/*.sh

# 3. Go checks
go build ./...
go vet ./...
go test -race -count=1 ./...

# 4. Flake validity
nix flake check --no-build

# 5. Configuration evaluation
nix eval .#nixosConfigurations.prague.config.system.build.toplevel.name

# 6. Architecture check
go run ./cmd/check-architecture/

# 7. Full verification
ivali verify
```
