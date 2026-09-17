# Observability Architecture & Operations

**Platform:** `nixos-infrastructure`
**Primary host:** `prague`
**Observability model:** Local-first, lightweight, privacy-preserving
**Primary stack:** Prometheus + Grafana + Loki + Alloy + Alertmanager
**Metrics:** Prometheus
**Logs:** Loki
**Collection:** Alloy
**Visualization:** Grafana
**Alert routing:** Alertmanager
**Health:** `ivali` health services / health endpoint
**Security:** SOPS + age, localhost binding, Tailscale-controlled remote access
**Status:** Active architecture and operational contract

---

# 1. Purpose

The observability subsystem provides visibility into:

* system health;
* NixOS state;
* service availability;
* deployment state;
* resource utilization;
* security-relevant events;
* networking;
* Tailscale;
* storage;
* backups;
* GitOps reconciliation;
* system failures;
* application/service errors.

The observability subsystem is intentionally **local-first**.

The default design is:

```text
                         ┌──────────────────────┐
                         │      KDE Desktop     │
                         │      / Operator      │
                         └──────────┬───────────┘
                                    │
                              Grafana UI
                                    │
                                    ▼
                         ┌──────────────────────┐
                         │      Prometheus      │
                         │       Metrics        │
                         └──────────┬───────────┘
                                    │
                ┌───────────────────┼───────────────────┐
                │                   │                   │
                ▼                   ▼                   ▼
          Node Exporter       NixOS Exporter      Health Endpoint
                │                   │                   │
                └───────────────────┴───────────────────┘


System Journal
      │
      ▼
    Alloy
      │
      ▼
    Loki
      │
      ▼
   Grafana


Prometheus
      │
      ▼
 Alertmanager
      │
      ▼
 Notification subsystem
```

The observability subsystem is a **consumer of system state**, not the owner of that state.

---

# 2. Architectural Principle

The observability subsystem follows the platform invariant:

> **Observability observes. It does not own the state it observes.**

For example:

* Prometheus does not own service configuration.
* Grafana does not own deployment state.
* Loki does not own systemd state.
* Alloy does not own journald.
* Alertmanager does not own notification credentials.
* Dashboards do not become configuration authorities.

Observability must never become a hidden dependency required for the core system to boot.

---

# 3. Design Goals

The stack is designed around six goals:

### 3.1 Visibility

Operators should be able to answer:

> What is happening on `prague` right now?

### 3.2 Diagnosis

Operators should be able to answer:

> Why did it happen?

### 3.3 Correlation

Metrics, logs, deployments, generations, and health events should be correlated where practical.

### 3.4 Early warning

The system should detect degradation before it becomes an outage.

### 3.5 Recovery support

Observability must provide enough evidence to diagnose failed deployments and recovery events.

### 3.6 Low overhead

`prague` is a resource-constrained workstation.

Observability must therefore remain lightweight.

---

# 4. Observability Boundaries

The platform separates:

```text
Telemetry
   │
   ├── Metrics
   ├── Logs
   ├── Traces
   └── Events

Health
   │
   ├── Service state
   ├── Deployment state
   ├── Storage
   ├── Secrets
   └── Recovery state

Control
   │
   ├── GitOps
   ├── NixOS
   ├── Ivali Flow
   └── Deployment
```

These are related but not interchangeable.

In particular:

> **A monitoring failure must not automatically become a system failure.**

If Grafana is unavailable, the NixOS host should continue operating.

If Loki is unavailable, systemd/journald remains authoritative for local logs.

If Prometheus is unavailable, the system itself should remain functional.

---

# 5. Service Inventory

| Component       | Bind                 | Purpose                                  | Target Budget       |
| --------------- | -------------------- | ---------------------------------------- | ------------------- |
| Prometheus      | `127.0.0.1:9090`     | Metrics collection, queries, alert rules | ~48 MB / ~1% CPU    |
| Grafana         | `127.0.0.1:3000`     | Dashboards and exploration               | ~48 MB / ~1% CPU    |
| Loki            | `127.0.0.1:3100`     | Local log aggregation                    | ~32 MB / ~0.5% CPU  |
| Alloy           | local/system service | Journal/log collection                   | ~24 MB / ~0.5% CPU  |
| Alertmanager    | `127.0.0.1:9093`     | Alert grouping/routing                   | ~16 MB / ~0.5% CPU  |
| Node Exporter   | `127.0.0.1:9100`     | Host metrics                             | ~8 MB / ~0.5% CPU   |
| NixOS Exporter  | `127.0.0.1:9101`     | NixOS-specific metrics                   | ~16 MB / ~0.25% CPU |
| Health Endpoint | `127.0.0.1:9102`     | System health contract                   | ~8 MB / ~0.25% CPU  |
| OTel Collector  | `127.0.0.1:8888`     | OpenTelemetry telemetry                  | ~24 MB / ~0.5% CPU  |

**Approximate intended budget:** ~280 MB RAM / ~4% CPU.

These figures are **budgets, not guarantees**.

Actual resource consumption must be measured on the target generation and hardware.

If resource pressure causes instability, observability components must be reduced before compromising core system reliability.

---

# 6. Network Exposure

All observability services should bind to loopback unless there is an explicit architecture decision to expose them.

Default:

```text
127.0.0.1
```

No observability endpoint should be exposed directly to the public Internet.

Remote access should follow:

```text
Operator
   ↓
Tailscale
   ↓
authenticated service boundary
   ↓
localhost-bound observability service
```

Tailscale provides network transport and identity context.

It does not replace:

* application authentication;
* service authorization;
* host firewall policy;
* Grafana authentication;
* secret management.

---

# 7. Prometheus

Prometheus is the authoritative local metrics store.

Endpoint:

```text
http://127.0.0.1:9090
```

Primary responsibilities:

* scrape exporters;
* store time-series metrics;
* evaluate alert rules;
* provide PromQL;
* expose target health;
* provide metrics to Grafana.

Prometheus must not become a general-purpose event database.

---

# 8. Prometheus Targets

Expected targets include:

```text
Prometheus
Node Exporter
NixOS Exporter
Health Endpoint
Application/service exporters
```

Check targets:

```bash
curl -s \
  http://127.0.0.1:9090/api/v1/targets |
  jq '.data.activeTargets[] |
      {
        scrapeUrl,
        health,
        lastError
      }'
```

A target being reachable is not sufficient to establish service health.

The target's:

* scrape health;
* scrape latency;
* error state;
* metric freshness

should be considered.

---

# 9. Core Metrics

Important platform metrics include:

### CPU

```promql
rate(node_cpu_seconds_total[5m])
```

### Memory

```promql
node_memory_MemAvailable_bytes
```

### Filesystem

```promql
node_filesystem_avail_bytes{
  mountpoint="/"
}
/
node_filesystem_size_bytes{
  mountpoint="/"
}
```

### NixOS generation

```promql
nixos_generation_current
```

### NixOS closure

```promql
nixos_system_closure_size_bytes
```

### Tailscale

```promql
tailscale_connected
```

### Tailscale key expiry

```promql
tailscale_key_expiry_days
```

Metrics should be selected based on operational value rather than collecting everything possible.

---

# 10. NixOS Exporter

The NixOS exporter exposes NixOS-specific platform state.

Current metrics include:

```text
nixos_generation_current
nixos_generation_total
nixos_system_closure_size_bytes
nixos_flake_inputs
```

The exporter should remain focused on **NixOS operational state**.

It should not become a general-purpose command execution mechanism.

---

# 11. Health Endpoint

Endpoint:

```text
http://127.0.0.1:9102/health
```

The health endpoint exposes structured operational health.

Example:

```bash
curl -s \
  http://127.0.0.1:9102/health |
  jq
```

Quick status:

```bash
curl -s \
  http://127.0.0.1:9102/health |
  jq -r '.status'
```

Health information may include:

* system generation;
* disk state;
* memory state;
* service state;
* deployment state;
* secret availability;
* recovery state.

The health endpoint should consume authoritative service contracts rather than duplicate subsystem logic.

---

# 12. Health vs Metrics

These have different meanings.

### Metrics

Answer:

> What value is being measured?

Examples:

```text
CPU = 73%
memory_available = 1.2 GB
disk_available = 34%
```

### Health

Answers:

> Is the system currently operating within acceptable conditions?

Examples:

```text
deployment = healthy
backup = healthy
gitops = degraded
disk = healthy
```

### Alerts

Answer:

> Does an operator need to take action?

These distinctions should remain explicit.

---

# 13. Loki

Loki provides local log aggregation.

Endpoint:

```text
http://127.0.0.1:3100
```

The current design intentionally collects **error-level journal entries**, rather than attempting to duplicate the entire system journal.

This reduces:

* disk consumption;
* CPU usage;
* memory pressure;
* query noise.

The system journal remains the authoritative local log source.

---

# 14. Alloy

Alloy is responsible for forwarding selected logs into Loki.

The intended filtering policy is:

```text
err
crit
alert
emerg
```

Conceptually:

```text
systemd journal
      ↓
    Alloy
      ↓
severity filter
      ↓
    Loki
```

Alloy must not silently become a bottleneck for local logging.

If Alloy fails:

```text
journald
```

must remain available.

---

# 15. Log Retention

Current Loki retention target:

```text
4 hours
```

Compaction target:

```text
1 hour
```

The short retention period is intentional because `prague` is resource constrained.

Long-term historical logs should not be assumed to exist locally.

If long-term retention becomes necessary, it should be implemented as a separate storage architecture rather than silently increasing local resource consumption.

---

# 16. LogQL Examples

### All collected errors

```logql
{job="systemd-journal"}
  | level=~"err|crit|alert|emerg"
```

### Ivali service failures

```logql
{unit="ivali.service"}
  |~ "(?i)(error|panic|fatal)"
```

### NixOS rebuild failures

```logql
{unit="nixos-rebuild.service"}
  |~ "(?i)error"
```

### Failed systemd units

```logql
{job="systemd-journal"}
  |= "Failed"
  | unit=~".*\\.service"
```

---

# 17. Grafana

Grafana provides the operator-facing observability interface.

Endpoint:

```text
http://127.0.0.1:3000/grafana/
```

Grafana provides:

* dashboards;
* PromQL exploration;
* LogQL exploration;
* alert visibility;
* annotations;
* deployment correlation;
* system overview.

Grafana is a **presentation and exploration layer**.

It is not the authoritative source of system state.

---

# 18. Grafana Authentication

Grafana credentials are managed through SOPS.

Expected secret file:

```text
secrets/grafana.yaml
```

Example structure:

```yaml
grafana_admin_password: "<secret>"
grafana_secret_key: "<secret>"
```

Credentials must never be committed in plaintext.

Do not place credentials in:

* shell history;
* dashboards;
* Git;
* documentation;
* command output captured in CI;
* public issue trackers.

To inspect the secret interactively:

```bash
sops -d secrets/grafana.yaml
```

Prefer controlled secret access rather than repeatedly printing credentials to terminal output.

---

# 19. Grafana Dashboards

Dashboards are provisioned from:

```text
/var/lib/grafana/dashboards/nixos/
```

The dashboard hierarchy should prioritize:

### System Overview

* CPU;
* memory;
* disk;
* load;
* uptime;
* system generation.

### Services

* systemd service health;
* restart frequency;
* resource consumption;
* failed units.

### Deployment

* current generation;
* deployment state;
* reconciliation;
* health checks;
* rollback events.

### Networking

* NetworkManager;
* Tailscale;
* connectivity;
* route state.

### Storage

* filesystem utilization;
* I/O;
* backup state;
* available space.

### Security

* authentication failures;
* AppArmor events;
* security scanner findings;
* unusual service failures.

---

# 20. Dashboard Design Principles

Dashboards should prioritize:

```text
Status
   ↓
Impact
   ↓
Cause
   ↓
Evidence
   ↓
Action
```

Avoid dashboards that merely display large quantities of telemetry.

The operator should be able to determine quickly:

> Is the system healthy?

and then:

> If not, where should I investigate?

---

# 21. Deployment Correlation

Observability should correlate system changes with runtime behavior.

Useful deployment annotations include:

* Git commit;
* generation;
* deployment start;
* deployment completion;
* health result;
* rollback;
* reconciliation event.

The ideal operational view is:

```text
Deployment
    │
    ├── generation
    ├── services
    ├── metrics
    ├── logs
    └── health
```

This makes it possible to investigate:

> What changed immediately before the system became unhealthy?

---

# 22. Alertmanager

Alertmanager receives alerts generated by Prometheus.

Endpoint:

```text
http://127.0.0.1:9093
```

Responsibilities:

* grouping;
* deduplication;
* routing;
* severity handling;
* silencing;
* notification integration.

Alertmanager should not contain business logic that belongs in the service layer.

---

# 23. Notification Architecture

The previous design referenced Telegram directly.

That is no longer the preferred architecture.

Alertmanager should instead route alerts through the platform's **notification contract**.

Conceptually:

```text
Prometheus
    ↓
Alertmanager
    ↓
Notification contract
    ↓
Configured notification adapter
    ├── desktop
    ├── email
    ├── web UI
    └── WhatsApp / other provider when explicitly configured
```

This keeps Alertmanager independent of a particular messaging provider.

Telegram should not be treated as an architectural dependency.

---

# 24. Alert Severity

Recommended severity classes:

| Severity   | Meaning                         | Expected handling      |
| ---------- | ------------------------------- | ---------------------- |
| `critical` | Immediate operational risk      | Immediate notification |
| `warning`  | Degradation requiring attention | Grouped notification   |
| `info`     | Useful operational event        | Dashboard/log only     |

Example:

```text
critical
  → immediate

warning
  → grouped / delayed

info
  → retained for visibility
```

Alert severity must describe operational impact, not merely how interesting an event is.

---

# 25. Alert Quality

Every alert should answer:

1. What is wrong?
2. What is affected?
3. How serious is it?
4. What evidence triggered it?
5. What should the operator inspect?
6. Can the system recover automatically?

Avoid alerts that merely restate metrics.

Bad:

```text
CPU > 80%
```

Better:

```text
Sustained CPU pressure is affecting system responsiveness
for 15 minutes.
```

The alert should include useful annotations where practical.

---

# 26. Alert Silencing

Alerts can be silenced through Alertmanager.

Example:

```bash
curl -X POST \
  http://127.0.0.1:9093/api/v2/silences \
  -H "Content-Type: application/json" \
  -d '{
    "matchers": [
      {
        "name": "alertname",
        "value": "HighMemory"
      }
    ],
    "startsAt": "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'",
    "endsAt": "'"$(date -u -d "+2 hours" +%Y-%m-%dT%H:%M:%SZ)"'",
    "createdBy": "admin",
    "comment": "Silenced for maintenance"
  }'
```

Silences must have:

* a reason;
* an expiration;
* an identifiable creator.

Permanent silences should be avoided unless intentionally documented.

---

# 27. OpenTelemetry

The OpenTelemetry collector is available at:

```text
127.0.0.1:8888
```

Its role is to provide a path for future:

* traces;
* telemetry;
* application metrics;
* service instrumentation.

OpenTelemetry is currently an extension point rather than a reason to increase collection volume indiscriminately.

The platform should adopt tracing where it provides meaningful diagnostic value.

---

# 28. Observability and Service Contracts

The Go service layer defines explicit contracts such as:

```text
Health
Metrics
Notification
Backup
Platform
```

Observability should consume these contracts.

It should not directly reach into private service implementation details.

This preserves:

```text
Service contract
      ↓
Implementation
      ↓
Observability adapter
```

rather than:

```text
Grafana / Prometheus
      ↓
private implementation
      ↓
hidden state
```

---

# 29. Backup Observability

Backup health must be observable.

At minimum, operators should be able to determine:

* whether backup is enabled;
* last successful backup;
* last failure;
* repository availability;
* storage pressure;
* backup age;
* recovery-test status where available.

A backup process that reports:

```text
service = running
```

but has not successfully completed a backup is not necessarily healthy.

The meaningful signal is **successful recoverability**, not merely process existence.

---

# 30. GitOps Observability

GitOps should expose enough state to answer:

```text
What commit is deployed?
What generation is active?
Is reconciliation running?
Did reconciliation succeed?
Did health validation succeed?
Was rollback triggered?
```

Useful dimensions include:

```text
commit
generation
host
deployment_state
health_state
rollback_state
```

This should correlate with deployment annotations and system logs.

---

# 31. Tailscale Observability

Tailscale state should include, where supported:

* connection status;
* peer availability;
* exit-node state;
* route state;
* key expiry;
* relevant service reachability.

Example:

```promql
tailscale_connected
```

and:

```promql
tailscale_key_expiry_days
```

Tailscale telemetry is diagnostic.

Authorization remains governed by:

* Tailscale policy;
* host firewall;
* service authentication;
* application authorization.

---

# 32. Security Observability

Security telemetry should cover useful operational signals without generating excessive noise.

Potential sources include:

* failed authentication;
* SSH failures;
* AppArmor denials;
* unexpected service failures;
* security scanner findings;
* privilege escalation events;
* unusual network behavior.

Security observability must not replace preventative controls.

The model is:

```text
Prevent
  ↓
Detect
  ↓
Alert
  ↓
Investigate
  ↓
Recover
```

---

# 33. Systemd Integration

For troubleshooting:

```bash
systemctl status \
  prometheus \
  grafana \
  loki \
  alloy \
  alertmanager
```

Logs:

```bash
journalctl -u prometheus -n 100
journalctl -u grafana -n 100
journalctl -u loki -n 100
journalctl -u alloy -n 100
journalctl -u alertmanager -n 100
```

Follow live logs:

```bash
journalctl -fu prometheus
```

The system journal remains authoritative for service-level diagnostics.

---

# 34. Prometheus Troubleshooting

List targets:

```bash
curl -s \
  http://127.0.0.1:9090/api/v1/targets |
  jq '.data.activeTargets[] |
      {
        instance: .labels.instance,
        health: .health,
        lastError: .lastError
      }'
```

Query a metric:

```bash
curl -s \
  'http://127.0.0.1:9090/api/v1/query?query=nixos_generation_current' |
  jq
```

Inspect alert rules:

```bash
curl -s \
  http://127.0.0.1:9090/api/v1/rules |
  jq '.data.groups[].rules[] |
      {
        name: .name,
        state: .state
      }'
```

Test exporter availability:

```bash
curl -s http://127.0.0.1:9100/metrics | head
curl -s http://127.0.0.1:9101/metrics | head
```

---

# 35. Loki Troubleshooting

Check Alloy:

```bash
systemctl status alloy
```

Inspect Alloy configuration:

```bash
cat /etc/alloy/config.alloy
```

Check Loki:

```bash
curl -s \
  http://127.0.0.1:3100/ready
```

If Loki is unavailable, use:

```bash
journalctl
```

directly.

Never treat Loki as the only copy of critical operational evidence.

---

# 36. Alertmanager Troubleshooting

Status:

```bash
curl -s \
  http://127.0.0.1:9093/api/v2/status |
  jq
```

Active alerts:

```bash
curl -s \
  http://127.0.0.1:9093/api/v2/alerts |
  jq
```

Alertmanager configuration problems should first be investigated through:

```bash
journalctl -u alertmanager
```

Provider-specific notification testing should use the platform's configured notification adapter rather than embedding provider-specific assumptions in this document.

---

# 37. Grafana Troubleshooting

Check service:

```bash
systemctl status grafana
```

Check logs:

```bash
journalctl -u grafana -n 100
```

Check health:

```bash
curl -s \
  http://127.0.0.1:3000/grafana/api/health |
  jq
```

Check resource limits:

```bash
systemctl show grafana.service \
  -p MemoryMax \
  -p CPUQuota
```

---

# 38. Configuration Validation

Before deploying observability changes:

```bash
nix fmt -- --check .
nix flake check --no-build
```

Then evaluate the intended host:

```bash
nix eval \
  .#nixosConfigurations.prague.config.system.build.toplevel.name
```

For source-level changes, use the standard Ivali Flow validation suite.

Observability configuration must not bypass architecture or deployment gates.

---

# 39. Deployment Verification

After a deployment:

### 1. Confirm generation

```bash
nixos-rebuild list-generations
```

### 2. Confirm core services

```bash
systemctl --failed
```

### 3. Confirm Prometheus

```bash
curl -fsS \
  http://127.0.0.1:9090/-/ready
```

### 4. Confirm Loki

```bash
curl -fsS \
  http://127.0.0.1:3100/ready
```

### 5. Confirm Alertmanager

```bash
curl -fsS \
  http://127.0.0.1:9093/-/ready
```

### 6. Confirm health

```bash
curl -fsS \
  http://127.0.0.1:9102/health
```

### 7. Confirm targets

```bash
curl -s \
  http://127.0.0.1:9090/api/v1/targets |
  jq
```

A deployment should not be considered fully healthy until the relevant runtime checks pass.

---

# 40. Resource Monitoring

Because observability itself consumes resources, monitor:

```text
Prometheus
Grafana
Loki
Alloy
Alertmanager
OTel Collector
```

Monitor:

* resident memory;
* CPU;
* disk usage;
* restart count;
* scrape failures;
* log ingestion;
* retention pressure.

The observability stack must remain subordinate to core system workloads.

---

# 41. Failure Behavior

Expected degradation behavior:

| Failure                         | Expected impact                                      |
| ------------------------------- | ---------------------------------------------------- |
| Prometheus down                 | Metrics unavailable; system continues                |
| Grafana down                    | UI unavailable; metrics/log stores continue          |
| Loki down                       | Aggregated logs unavailable; journald remains        |
| Alloy down                      | New logs stop reaching Loki; journald remains        |
| Alertmanager down               | Alert routing unavailable; Prometheus remains        |
| Node Exporter down              | Host metrics unavailable                             |
| NixOS Exporter down             | Nix-specific metrics unavailable                     |
| Health endpoint down            | Health API unavailable; underlying services continue |
| OTel Collector down             | OTel telemetry unavailable                           |
| Entire observability stack down | Core OS should remain operational                    |

This is a critical architectural property:

> **Observability failure must not become a single point of failure for the operating system.**

---

# 42. Storage Failure

If observability storage becomes constrained:

1. alert;
2. identify the consuming component;
3. verify retention;
4. reduce retention if appropriate;
5. remove nonessential telemetry;
6. protect system-critical storage.

Do not allow telemetry retention to consume storage required by:

* NixOS generations;
* `/`;
* `/nix`;
* secrets;
* Git repositories;
* backups;
* recovery mechanisms.

---

# 43. Disabling Observability

Full observability can be disabled at the module level:

```nix
ivali.observability.enable = false;
```

A reduced configuration may enable only selected components:

```nix
ivali.observability = {
  enable = true;
  loki.enable = true;
  alloy.enable = true;
};
```

The exact option names must follow the current Nix module implementation.

Documentation must not invent module options that do not exist in the repository.

---

# 44. Lite Observer

The lightweight observer:

```text
fleet.observability.lite.enable
```

is intentionally independent from the full Prometheus/Grafana/Loki stack.

It exists to provide basic health/notification behavior when the full observability platform is unavailable or unnecessary.

This creates a useful resilience relationship:

```text
Full observability
       │
       ├── Prometheus
       ├── Grafana
       ├── Loki
       ├── Alloy
       └── Alertmanager

Fallback observation
       │
       └── Lite observer
```

The lite observer must remain lightweight and must not duplicate the entire observability stack.

---

# 45. Secrets Management

All observability credentials and provider secrets must be managed through SOPS/age.

Example:

```bash
sops -d secrets/grafana.yaml
```

Edit:

```bash
sops secrets/grafana.yaml
```

Secret rotation must use a controlled SOPS workflow.

Do not use fragile shell pipelines that can accidentally:

* corrupt YAML;
* expose plaintext;
* overwrite the wrong key;
* write secrets to shell history.

For example, credential rotation should be performed through:

```bash
sops secrets/grafana.yaml
```

rather than an unverified `sed | sops` pipeline.

---

# 46. Privacy

Observability should collect only what is operationally necessary.

Avoid collecting:

* credentials;
* access tokens;
* private keys;
* full request bodies;
* unnecessary personal data;
* sensitive application payloads.

Logs should be treated as potentially sensitive operational data.

Before adding a new log source, ask:

> Does this information materially improve diagnosis?

If not, do not collect it.

---

# 47. Operational Query Reference

## Prometheus

```bash
# Ready
curl -fsS http://127.0.0.1:9090/-/ready

# Targets
curl -s http://127.0.0.1:9090/api/v1/targets | jq

# Rules
curl -s http://127.0.0.1:9090/api/v1/rules | jq
```

## Loki

```bash
curl -fsS http://127.0.0.1:3100/ready
```

## Alertmanager

```bash
curl -fsS http://127.0.0.1:9093/-/ready
curl -s http://127.0.0.1:9093/api/v2/alerts | jq
```

## Health

```bash
curl -s http://127.0.0.1:9102/health | jq
```

## Systemd

```bash
systemctl --failed
```

---

# 48. Ansible

Ansible remains a fleet-management mechanism rather than an observability component.

Fleet access is expected to use the Tailscale network.

Examples:

```bash
ansible-playbook ansible/playbooks/ping.yml
```

```bash
ansible-playbook \
  ansible/playbooks/system-info.yml
```

```bash
ansible-playbook \
  ansible/playbooks/security-audit.yml
```

Target one host:

```bash
ansible-playbook \
  ansible/playbooks/ping.yml \
  -l prague
```

Ad-hoc:

```bash
ansible all -m ping
```

```bash
ansible all -a "uptime" -l prague
```

Common aliases:

```text
an   → ansible
ap   → ansible-playbook
ali  → ansible-lint
ag   → ansible-galaxy
```

Ansible should not become a hidden dependency of the local observability stack.

---

# 49. Observability Architecture Rules

The following rules are mandatory.

### Rule 1 — Local-first

Observability services default to localhost.

### Rule 2 — No public telemetry endpoints

Metrics and logs must not be exposed publicly without an explicit security architecture.

### Rule 3 — Journald remains authoritative

Loki is an aggregation layer, not the only log store.

### Rule 4 — Health is separate from telemetry

Metrics do not automatically equal health.

### Rule 5 — Observability is not control

Dashboards and monitoring must not silently mutate system state.

### Rule 6 — Observability is not ownership

The observability subsystem must not take ownership of state belonging to another domain.

### Rule 7 — Failure must degrade gracefully

Loss of observability must not prevent the operating system from functioning.

### Rule 8 — Resource budgets are enforced

Observability must not consume resources required by the primary workload.

### Rule 9 — Secrets remain outside telemetry

Secrets must never be intentionally emitted into metrics or logs.

### Rule 10 — Architecture gates apply

Observability changes are subject to the same architecture and Ivali Flow gates as every other subsystem.

---

# 50. Future Evolution

The observability platform may evolve toward:

```text
Local Prague
      │
      ├── Prometheus
      ├── Grafana
      ├── Loki
      └── Alertmanager
             │
             ▼
       Oracle Edge
             │
       external/remote
       observation plane
```

The planned `oracle-edge` ARM64 node can eventually provide:

* external monitoring;
* watchdog functionality;
* backup alert routing;
* always-on web UI;
* webhook ingestion;
* remote health observation;
* cross-host monitoring.

This must remain separate from the current `prague` stabilization baseline until implemented and verified.

---

# 51. Migration Compatibility

The observability architecture must survive both planned migrations.

## GNOME → KDE

The observability stack must remain independent of the desktop environment.

Only the operator interface changes.

Expected relationship:

```text
Observability backend
        │
        ▼
      Grafana
        │
        ▼
     KDE Plasma
```

No observability service should depend on GNOME components.

---

## Go → Elixir/OTP

The observability contracts must survive runtime migration.

Metrics, health, notifications, logs, deployment events, and service state must remain observable regardless of whether the implementation is:

```text
Go
```

or:

```text
Elixir/OTP
```

The migration must not create an observability blind spot.

---

# 52. Observability Acceptance Criteria

The observability subsystem is considered operational when:

* [ ] Prometheus is running.
* [ ] Prometheus targets are healthy.
* [ ] Node metrics are available.
* [ ] NixOS metrics are available.
* [ ] Health metrics are available.
* [ ] Loki is ready.
* [ ] Alloy is forwarding intended logs.
* [ ] Grafana is reachable locally.
* [ ] Grafana can query Prometheus.
* [ ] Grafana can query Loki.
* [ ] Alertmanager is ready.
* [ ] Alert rules load successfully.
* [ ] Notifications route through the configured notification contract.
* [ ] Health endpoint returns valid status.
* [ ] Core services remain operational if observability is stopped.
* [ ] Resource usage remains within the intended budget.
* [ ] No credentials appear in telemetry.
* [ ] Deployment events can be correlated with runtime evidence.
* [ ] The observability stack passes the standard Ivali Flow validation gates.

---

# 53. Verification Commands

A basic acceptance sequence:

```bash
systemctl is-active prometheus
systemctl is-active grafana
systemctl is-active loki
systemctl is-active alloy
systemctl is-active alertmanager
```

Prometheus:

```bash
curl -fsS http://127.0.0.1:9090/-/ready
```

Loki:

```bash
curl -fsS http://127.0.0.1:3100/ready
```

Alertmanager:

```bash
curl -fsS http://127.0.0.1:9093/-/ready
```

Health:

```bash
curl -fsS http://127.0.0.1:9102/health
```

Targets:

```bash
curl -s \
  http://127.0.0.1:9090/api/v1/targets |
  jq '.data.activeTargets[] |
      {url: .scrapeUrl, health: .health, error: .lastError}'
```

System failures:

```bash
systemctl --failed
```

---

# 54. Relationship to Stabilization

Observability is part of the stabilization baseline because a system that cannot be diagnosed or health-validated is not operationally complete.

However:

> **Observability validates the platform; it does not define the platform.**

The authoritative hierarchy remains:

```text
Architecture
     ↓
Service contracts
     ↓
Implementation
     ↓
Observability
     ↓
Health
     ↓
Operator action
```

Observability therefore supports:

* stabilization;
* deployment;
* incident response;
* rollback;
* recovery;
* KDE migration;
* future Elixir/OTP migration.

---

# 55. Final Invariant

The observability platform exists to make the infrastructure:

> **visible, diagnosable, measurable, alertable, and recoverable**

without making observability itself:

> **a single point of failure, a hidden state owner, a security boundary bypass, or an uncontrolled resource consumer.**

The target operational model is:

```text
                  ┌─────────────────────┐
                  │       Operator      │
                  └──────────┬──────────┘
                             │
                          Grafana
                             │
          ┌──────────────────┼──────────────────┐
          │                  │                  │
      Prometheus            Loki          Health API
          │                  │                  │
     Metrics              Logs              Health
          │                  │                  │
          └──────────────────┼──────────────────┘
                             │
                        Alertmanager
                             │
                    Notification Contract
                             │
                    Operator / Web / Email /
                    configured messaging
```

The system remains operational even when any individual observability component fails.

That property is a core part of the `nixos-infrastructure` reliability model.

