# OpenCode — Knowledge Base

Structured documentation for this NixOS infrastructure repository.

## Files

| File | Description |
|------|-------------|
| [architecture.md](architecture.md) | System overview, core principles, module system, data flow, security model |
| [modules.md](modules.md) | Complete catalog of NixOS modules, Home Manager modules, Go CLI, and scripts |
| [hosts.md](hosts.md) | Host registry, adding new hosts, template system, hardware config, per-host secrets |
| [deployment.md](deployment.md) | Deployment methods, CI/CD pipeline, health checks, rollback, generation tracking |
| [troubleshooting.md](troubleshooting.md) | Common issues and fixes for flake, build, SOPS, Tailscale, Home Manager, GitLab Runner |
| [tailscale-mesh.md](tailscale-mesh.md) | Multi-host Tailscale mesh setup, ACLs, MagicDNS, monitoring |
| [workflow.md](workflow.md) | Ivali Flow workflow — mandatory lifecycle for all AI agents |

## Quick Reference

### Deploying Changes (via Ivali Flow)
```bash
ivali flow start feature "description"   # Create issue + branch
ivali flow validate                       # Run all verification gates
ivali flow commit                         # Stage + commit
ivali flow push                           # Push to GitLab
ivali flow mr                             # Create merge request
ivali flow pipeline --watch               # Wait for CI
ivali flow merge                          # Merge when CI passes
```

### Fast Path
```bash
ivali flow quick "description"           # Commit → push → MR
ivali flow run feature "description"     # Full pipeline in one command
```

### Diagnosing Issues
```bash
ivali doctor                 # Full health check
ivali doctor --fix           # Auto-fix issues
ivali status                 # Repository state
```
