# Deployment

## Deployment Methods

### 1. Local Rebuild

```bash
sudo nixos-rebuild switch --flake .#prague
```

### 2. GitHub Actions Mirror + GitOps

- GitLab is the source of truth and push-mirrors to GitHub.
- GitHub Actions validates the mirror and posts status back to GitLab.
- Deployment is automatic via the GitOps reconciler (no manual CI deploy step).

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
│  Code Push  │ →  │ GH Actions   │ →  │  Deploy      │
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

GitHub Actions (`.github/workflows/ci.yml`), run on the GitLab→GitHub mirror:
1. **test** — Go lint/test/build, shell lint
2. **build** — `nix fmt --check`, `nix flake check`, gitleaks
3. **validate** — build NixOS toplevel + Home Manager (self-hosted)
4. **status** — posts commit status back to GitLab via the GitLab API

Deployment is performed by the GitOps reconciler, not by CI.

## Secrets in CI

GitHub Actions uses repository secrets:
- `GITLAB_TOKEN` — posts commit status back to GitLab (source of truth)
- `GITHUB_TOKEN` — checkout / artifact upload
- (Telegram/email notifications are sent by the running host, not CI)

## Generation Tracking

Each deployment creates a NixOS generation with:
- Git commit hash
- Timestamp
- Changelog of changed files

View generations:
```bash
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
```
