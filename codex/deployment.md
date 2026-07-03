# Deployment

## Deployment Methods

### 1. Local Rebuild

```bash
sudo nixos-rebuild switch --flake .#prague
```

### 2. GitLab CI/CD

1. Push to `main` branch
2. CI pipeline runs: test → build
3. Manual deploy trigger: `sudo systemctl start ci-deploy.service`

### 3. GitOps Reconciler

Runs every 15 minutes automatically:
```
git pull --ff-only → nix flake check → nix build → nixos-rebuild switch → health check
```

### 4. Telegram Bot

```
/deploy    # Run nixos-rebuild switch
/update    # git pull + nix flake update
/rollback  # Revert to previous generation
```

### 5. Remote Deploy

```bash
ivali deploy --host prague
```

## Deployment Flow

```
┌─────────────┐    ┌──────────────┐    ┌──────────────┐
│  Code Push  │ →  │  CI Build    │ →  │  Deploy      │
│  (git push) │    │  (nix build) │    │  (rebuild)   │
└─────────────┘    └──────────────┘    └──────┬───────┘
                                              │
                                        ┌─────▼─────┐
                                        │  Health   │
                                        │  Check    │
                                        └─────┬─────┘
                                              │
                              ┌────────────────┼────────────────┐
                              │                │                │
                        ┌─────▼─────┐    ┌─────▼─────┐    ┌────▼────┐
                        │   Pass    │    │   Fail    │    │ Notify  │
                        │           │    │ Rollback  │    │ User    │
                        └───────────┘    └───────────┘    └─────────┘
```

## Health Checks

`scripts/deployment-health.sh` checks:
- System sanity (systemd, network)
- DNS resolution
- GitLab availability
- GitOps repo reachability
- Local worktree (flake.nix, git status)
- System baseline (Tailscale, NTP)

## Rollback

Automatic rollback on deployment failure:
1. Health check detects failure
2. `scripts/rollback.sh` reverts to previous generation
3. Health check runs again
4. User notified via Telegram + email

Manual rollback:
```bash
sudo nixos-rebuild switch --rollback
# or
/scripts/rollback.sh
```

## CI Pipeline

`.gitlab-ci.yml` stages:
1. **test** — Go tests, nix flake check, YAML lint
2. **build** — NixOS toplevel, Home Manager activation
3. **deploy** — Manual trigger, runs `ci-deploy.service`
4. **notify** — Telegram + email notification

## Secrets in CI

GitLab CI uses SOPS-decrypted secrets:
- `GITLAB_TOKEN` — API access
- `TELEGRAM_BOT_TOKEN` — Bot notifications
- `TELEGRAM_CHAT_ID` — Chat target
- `NOTIFY_EMAIL` — Email notifications

## Generation Tracking

Each deployment creates a NixOS generation with:
- Git commit hash
- Timestamp
- Changelog of changed files

View generations:
```bash
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
```
