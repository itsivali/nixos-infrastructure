# Plan: Reduce CPU Usage by Disabling Non-Essential Services

## Objective
Disable/uninstall all non-essential services to reduce CPU usage while keeping GNOME desktop fully functional on host `prague`.

## Current State Analysis

### Services Enabled on `prague` (from `hosts/prague.nix`)
| Service | Purpose | CPU Impact | Keep? |
|---------|---------|------------|-------|
| `ivali.security.firewall` | nftables firewall | Low | **YES** (security) |
| `ivali.desktop.gnome` | GNOME Wayland desktop | Medium | **YES** (required) |
| `ivali.desktop.remote-desktop` | RDP over Tailscale | Low | Optional |
| `ivali.kilocode` | AI tooling | Low | Optional |
| `ivali.antigravity` | AI tooling | Low | Optional |
| `ivali.observability.loki` | Log aggregation | **High** | NO |
| `ivali.observability.alloy` | Log collector | **High** | NO |
| `ivali.services.blocky` | DNS proxy + ad-blocker | Medium | NO |
| `services.syncthing` | File sync with fsWatcher | **High** | NO |
| `programs.kdeconnect` | GSConnect bridge | Low | NO |
| `fleet.deploymentHealth.enableRollback` | Self-healing | Low | Optional |
| `ivali.docker` | Container runtime | **High** (if containers run) | NO |
| `ivali.devops.*` | Terraform, K8s, CI | Medium | NO |

### Auto-Discovered Domain Modules (from `configuration.nix`)
| Module | Purpose | CPU Impact | Action |
|--------|---------|------------|--------|
| `automation` | GitOps reconciler, channel bump | Medium | Disable gitops-reconciler |
| `boot` | Boot configuration | Low | Keep |
| `cache` | Caching utilities | Low | Keep |
| `caching` | Caching utilities | Low | Keep |
| `ci` | CI configuration | Low | Keep |
| `cloud` | Cloud integrations | Low | Disable |
| `hardware` | Hardware config | Low | Keep |
| `i18n` | Internationalization | Low | Keep |
| `lib` | Helper functions | None | Keep |
| `networking` | Network config | Low | Keep |
| `observability` | Prometheus, Grafana, Loki, Alloy, Falco, OTEL | **Very High** | **Disable entirely** |
| `recovery` | Disaster recovery | Low | Keep |
| `security` | AppArmor, audit, fail2ban, firewall, hardening, tailscale | Medium | Keep firewall/hardening, disable scanning |
| `services` | msmtp, nginx, postgres, redis, blocky, web-ui | Medium | Disable all except msmtp (for alerts) |
| `ssh` | SSH configuration | Low | Keep |
| `storage` | Storage config | Low | Keep |
| `system` | System config | Low | Keep |
| `virtualization` | Docker | **High** | Disable |

### Home Manager Modules (from `home/default.nix`)
| Module | Purpose | CPU Impact | Action |
|--------|---------|------------|--------|
| `identity` | User identity | None | Keep |
| `fonts.nix` | Fonts | None | Keep |
| `theming.nix` | Theming | None | Keep |
| `firefox` | Browser config | None | Keep |
| `audio` | PipeWire/PulseAudio | Low | Keep (required for GNOME) |
| `cloud` | Cloud sync | Low | Disable |
| `gnome` | GNOME user config | Low | **Keep** |
| `shell` | Shell config | None | Keep |
| `git` | Git config | None | Keep |
| `environment` | Environment vars | None | Keep |
| `editors` | Editor config | None | Keep |
| `services/auto-format` | Auto-formatting | Low | Keep |

## Plan

### Phase 1: Disable Observability Stack (Highest CPU Impact)
**Files to modify:**
- `hosts/prague.nix` - Disable `ivali.observability.loki.enable`, `ivali.observability.alloy.enable`
- `hosts/prague.nix` - Remove `ivali.observability.alertmanager.emailTo` (or keep for critical alerts only)

**Rationale:** Prometheus, Grafana, Loki, Alloy, Alertmanager, Falco, OTEL collector consume significant CPU/memory.

### Phase 2: Disable Syncthing (High CPU with fsWatcher)
**Files to modify:**
- `hosts/prague.nix` - Remove entire `services.syncthing` block
- `hosts/prague.nix` - Remove firewall rules for tailscale0 ports 22000/8384

**Rationale:** fsWatcher on 3 folders with rescanIntervalS=3600 causes constant filesystem monitoring.

### Phase 3: Disable Docker & Virtualization
**Files to modify:**
- `hosts/prague.nix` - Set `ivali.docker.enable = false`
- `hosts/prague.nix` - Disable all `ivali.devops.*` options

**Rationale:** Docker daemon + potential containers consume significant resources.

### Phase 4: Disable Blocky DNS Proxy
**Files to modify:**
- `hosts/prague.nix` - Set `ivali.services.blocky.enable = false`

**Rationale:** DNS proxy on all interfaces adds overhead; use systemd-resolved instead.

### Phase 5: Disable DevOps Tooling
**Files to modify:**
- `hosts/prague.nix` - Set `ivali.devops.enable = false` (disables terraform, kubernetes, containers, ci)

### Phase 6: Disable Optional Desktop Features
**Files to modify:**
- `hosts/prague.nix` - Set `ivali.desktop.remote-desktop.enable = false` (if not needed)
- `hosts/prague.nix` - Set `ivali.kilocode.enable = false`
- `hosts/prague.nix` - Set `ivali.antigravity.enable = false`
- `hosts/prague.nix` - Set `programs.kdeconnect.enable = false`

### Phase 7: Disable GitOps Reconciler (Automation)
**Files to modify:**
- `automation/options.nix` - Add option to disable gitops-reconciler
- `automation/gitops-reconciler.nix` - Gate on new option
- `hosts/prague.nix` - Set disable option

**Rationale:** Runs every 15 minutes, does git operations, builds, health checks.

### Phase 8: Disable Security Scanning (Keep Firewall/Hardening)
**Files to modify:**
- `security/scanning.nix` - Already gated? Check and disable
- `security/falco.nix` - Disable Falco runtime security monitoring

### Phase 9: Disable Cloud/Home Services
**Files to modify:**
- `home/default.nix` - Remove `./cloud` from imports
- `home/cloud/` - Can remain but not imported

### Phase 10: Verify GNOME Still Works
**Required for GNOME:**
- `ivali.desktop.gnome.enable = true` (system)
- `./gnome` in home imports (user)
- `desktop/common/audio` (PipeWire) - keep
- `desktop/common/portals` - keep
- `desktop/common/environment` - keep
- `desktop/login/gdm.nix` - keep
- `home/audio` - keep
- `home/fonts.nix` - keep
- `home/theming.nix` - keep

## Implementation Order

1. **Edit `hosts/prague.nix`** - Disable all high-impact services (Phases 1-6)
2. **Edit `automation/options.nix`** - Add gitops-reconciler disable option
3. **Edit `automation/gitops-reconciler.nix`** - Gate on option
4. **Edit `home/default.nix`** - Remove cloud import
5. **Run verification gates** - `nix fmt`, `nix flake check`, `nix eval`
6. **Test via ivali flow**

## Verification Gates
```bash
nix fmt -- --check .
nix flake check --no-build
nix eval .#nixosConfigurations.prague.config.system.build.toplevel.name
go build ./...
go test ./...
go test -race -count=1 ./...
golangci-lint run ./...
bash -n scripts/*.sh
ivali verify
```

## Rollback Plan
- All changes are in `prague.nix` and a few module options
- Git history allows instant revert
- `nixos-rebuild switch --rollback` available if needed

## Risk Assessment
| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| GNOME breaks | Low | High | Keep all desktop/common modules |
| No log aggregation | Medium | Low | journalctl still works |
| No file sync | Medium | Medium | Manual sync or re-enable later |
| No DNS ad-blocking | Low | Low | Use browser extensions |
| No container runtime | Low | Low | Re-enable if needed |

## Success Criteria
- [ ] GNOME desktop starts and functions normally
- [ ] CPU usage significantly reduced (target: < 20% idle)
- [ ] All verification gates pass
- [ ] No regression in core desktop functionality (audio, display, input, network)
- [ ] Firewall still active
- [ ] SSH access maintained
- [ ] Tailscale connectivity maintained