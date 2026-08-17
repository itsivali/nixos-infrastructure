# Scripts

This directory contains shell scripts for infrastructure automation, GitOps reconciliation, and operational tasks.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `REPO_DIR` | `/home/ivali/nixos-infrastructure` | Path to the NixOS infrastructure repository |
| `HOST_NAME` | `$(hostname)` | Target host for deployment operations |
| `DEFAULT_USER` | `ivali` | Default user for desktop command execution |

## Scripts

### GitOps & Deployment

| Script | Purpose | Systemd Unit |
|--------|---------|--------------|
| `gitops-reconcile.sh` | Pull latest changes and rebuild NixOS configuration | `ivali-gitops-reconciler.service` |
| `ci-deploy.sh` | CI/CD deployment script for automated builds | `ivali-ci-deploy.service` |
| `rollback.sh` | Roll back to the previous NixOS generation | Manual execution |
| `deployment-health.sh` | Check deployment health and service status | `ivali-deployment-health.service` |

### Security & Secrets

| Script | Purpose | Systemd Unit |
|--------|---------|--------------|
| `sops-setup.sh` | Initialize SOPS with age encryption | Manual execution |
| `sops-breakglass.sh` | Emergency decryption without SOPS key | Manual execution |
| `rotate-sops-key.sh` | Rotate the SOPS encryption key | Manual execution |
| `generate-ssh-key.sh` | Generate SSH key pair for a new host | Manual execution |

### Monitoring & Alerting

| Script | Purpose | Systemd Unit |
|--------|---------|--------------|
| `gitlab-runner-health.sh` | Check GitLab Runner health status | `ivali-gitlab-runner-health.service` |
| `gitlab-runner-reconcile.sh` | Reconcile GitLab Runner registration | `ivali-gitlab-runner-reconcile.service` |
| `notify.sh` | Send Telegram notifications | Called by other scripts |
| `bitwarden.sh` | Bitwarden CLI wrapper for secret retrieval | Manual execution |

### Bot Support

| Script | Purpose |
|--------|---------|
| `bot/config.sh` | Bot configuration helpers |
| `bot/lib/desktop.sh` | Desktop automation helpers for bot commands |

## Systemd Integration

Most scripts are designed to run as systemd services or timers. The corresponding NixOS modules are in the `automation/` directory.

## Testing

To test a script manually:
```bash
# Dry run gitops reconciliation
REPO_DIR=/path/to/repo HOST_NAME=prague ./gitops-reconcile.sh --dry-run

# Check deployment health
./deployment-health.sh

# Test notification (requires valid bot token)
CHAT_ID=<chat_id> BOT_TOKEN=<token> ./notify.sh "Test message"
```

## Troubleshooting

- **Script not found**: Ensure the script is executable (`chmod +x script.sh`)
- **Permission denied**: Scripts may need root access for system operations
- **SOPS errors**: Verify `/run/secrets/` is mounted and SOPS key is available
- **Network errors**: Check firewall rules and Tailscale connectivity
