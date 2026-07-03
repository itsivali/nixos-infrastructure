# Codex — Knowledge Base

Structured documentation for this NixOS infrastructure repository.

## Files

| File | Description |
|------|-------------|
| [architecture.md](architecture.md) | System overview, core principles, module system, data flow, security model |
| [modules.md](modules.md) | Complete catalog of NixOS modules, Home Manager modules, Go CLI, scripts, and bot commands |
| [hosts.md](hosts.md) | Host registry, adding new hosts, template system, hardware config, per-host secrets |
| [deployment.md](deployment.md) | Deployment methods, CI/CD pipeline, health checks, rollback, generation tracking |
| [troubleshooting.md](troubleshooting.md) | Common issues and fixes for flake, build, SOPS, Tailscale, Home Manager, GitLab Runner |

## Quick Reference

### Adding a New Host
1. Add entry to `hosts/hosts.nix`
2. Create `hosts/<name>/hardware-configuration.nix`
3. Run `ivali bootstrap host <name>`
4. Apply: `sudo nixos-rebuild switch --flake .#<name>`

### Deploying Changes
```bash
git push origin main         # Push changes
sudo nixos-rebuild switch --flake .#prague  # Or use /deploy bot command
```

### Diagnosing Issues
```bash
ivali doctor                 # Full health check
ivali doctor --fix           # Auto-fix issues
ivali status                 # Repository state
```
