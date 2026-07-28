# Multi-Host Tailscale Mesh

## Overview

This document describes how to set up a multi-host Tailscale mesh for the nixos-infrastructure repository. Each host runs Tailscale and connects to the same tailnet, enabling secure communication between machines.

## Architecture

```
                    ┌─────────────────────────────────────────┐
                    │              Tailscale Cloud             │
                    │         (Coordination + DERP)           │
                    └─────────────────────────────────────────┘
                                        │
                    ┌───────────────────┼───────────────────┐
                    │                   │                   │
              ┌─────┴─────┐       ┌─────┴─────┐       ┌─────┴─────┐
              │  prague   │       │  server   │       │  laptop   │
              │ (primary) │       │  (backup) │       │ (mobile)  │
              └───────────┘       └───────────┘       └───────────┘
```

## Host Configuration

### Primary Host (prague)

```nix
# hosts/prague.nix
{ lib, ... }:

{
  hostName = "prague";
  userName = "ivali";
  tags = [ "tag:admin" "tag:infra" ];
  tailnetDomain = "codlet-trench.ts.net";
  features = {
    tailscale = true;
    tailscaleExitNode = true;
    ssh = true;
    secrets = true;
    gitlabRunner = true;
    bot = true;
  };
  sopsKeyPath = "/home/ivali/.config/sops/age/keys.txt";
  config = { };
}
```

### Server Host (backup)

```nix
# hosts/server.nix
{ lib, ... }:

{
  hostName = "server";
  userName = "admin";
  tags = [ "tag:admin" "tag:server" ];
  tailnetDomain = "codlet-trench.ts.net";
  features = {
    tailscale = true;
    tailscaleExitNode = true;
    ssh = true;
    secrets = true;
  };
  sopsKeyPath = "/home/admin/.config/sops/age/keys.txt";
  config = { };
}
```

### Mobile Host (laptop)

```nix
# hosts/laptop.nix
{ lib, ... }:

{
  hostName = "laptop";
  userName = "ivali";
  tags = [ "tag:admin" "tag:personal" ];
  tailnetDomain = "codlet-trench.ts.net";
  features = {
    tailscale = true;
    tailscaleExitNode = false;
    ssh = true;
    secrets = true;
  };
  sopsKeyPath = "/home/ivali/.config/sops/age/keys.txt";
  config = { };
}
```

## ACL Tags

### Tag Hierarchy

| Tag | Purpose | Usage |
|-----|---------|-------|
| `tag:admin` | Full admin access | Primary management host |
| `tag:infra` | Infrastructure services | Servers running critical services |
| `tag:server` | Server-only access | Dedicated servers |
| `tag:personal` | Personal devices | Laptops, phones |
| `tag:exit-node` | Exit node capability | Auto-added when advertising exit node |

### ACL Policy Example

```json
{
  "tagOwners": {
    "tag:admin": ["group:admin"],
    "tag:infra": ["tag:admin"],
    "tag:server": ["tag:admin"],
    "tag:personal": ["group:users"],
    "tag:exit-node": ["tag:admin"]
  },
  "acls": [
    {
      // Admins can access everything
      "action": "accept",
      "src": ["tag:admin"],
      "dst": ["*:*"]
    },
    {
      // Infrastructure can access infrastructure
      "action": "accept",
      "src": ["tag:infra"],
      "dst": ["tag:infra:*", "tag:server:*"]
    },
    {
      // Personal devices can access infrastructure (SSH only)
      "action": "accept",
      "src": ["tag:personal"],
      "dst": ["tag:infra:22", "tag:server:22"]
    }
  ]
}
```

## Subnet Routing

### Advertising Subnets

To advertise a subnet through a host:

```nix
# In host configuration
ivali.tailscale = {
  advertiseExitNode = true;
  advertiseSubnet = true;
  subnets = [ "192.168.1.0/24" "10.0.0.0/8" ];
};
```

### Accessing Remote Subnets

Once a host advertises subnets, other hosts can access them:

```bash
# From any host in the tailnet
ping 192.168.1.100  # Access device on remote subnet
ssh admin@192.168.1.100  # SSH into remote device
```

## Tailscale SSH

### Enabling Tailscale SSH

```nix
ivali.tailscale = {
  enableTailscaleSsh = true;
};
```

### SSH ACL Rules

```json
{
  "ssh": [
    {
      // Admins can SSH anywhere
      "action": "accept",
      "src": ["tag:admin"],
      "dst": ["*"],
      "users": ["root", "admin", "ivali"]
    },
    {
      // Personal devices can SSH to infrastructure
      "action": "accept",
      "src": ["tag:personal"],
      "dst": ["tag:infra"],
      "users": ["ivali"]
    }
  ]
}
```

## MagicDNS

### Configuration

```nix
ivali.tailscale = {
  tailnetDomain = "codlet-trench.ts.net";
  acceptDns = true;
};
```

### DNS Resolution

With MagicDNS enabled, hosts can be reached via:

```bash
# Using full DNS name
ssh ivali@prague.codlet-trench.ts.net

# Using short name (if acceptDns = true)
ssh ivali@prague
```

## Key Management

### Key Expiry

- **Default expiry**: 90 days (configurable in Tailscale admin console)
- **Monitoring**: `tailscale-key-check` service runs daily
- **Alerts**: Warning at 14 days, critical at 0 days

### Key Rotation

```bash
# Check current key expiry
tailscale status | grep KeyExpiry

# Force key rotation (requires admin)
tailscale up --reset
```

## Health Monitoring

### Services

| Service | Interval | Purpose |
|---------|----------|---------|
| `tailscale-key-check` | Daily | Check key expiry |
| `tailscale-magicdns-check` | Hourly | Verify MagicDNS resolution |
| `tailscale-metrics` | 60s | Prometheus metrics |

### Prometheus Metrics

| Metric | Description |
|--------|-------------|
| `tailscale_connected` | Connection status (1=connected, 0=disconnected) |
| `tailscale_key_expiry_days` | Days until key expires |
| `tailscale_magicdns_status` | MagicDNS resolution status (1=ok, 0=failed) |

### Alerting Rules

| Alert | Condition | Severity |
|-------|-----------|----------|
| `TailscaleServiceDown` | tailscaled not active | critical |
| `TailscaleKeyExpiryWarning` | Key expires in <14 days | warning |
| `TailscaleKeyExpired` | Key has expired | critical |
| `TailscaleMagicDNSFailed` | MagicDNS resolution fails | warning |

## Troubleshooting

### Connection Issues

```bash
# Check Tailscale status
tailscale status

# Check tailscaled logs
journalctl -u tailscaled -f

# Restart tailscaled
sudo systemctl restart tailscaled

# Force reconnection
tailscale up
```

### DNS Issues

```bash
# Check MagicDNS
tailscale status | grep DNSName

# Test resolution
host prague.codlet-trench.ts.net

# Check resolvectl
resolvectl status tailscale0
```

### Key Issues

```bash
# Check key expiry
tailscale status | grep KeyExpiry

# View key details
tailscale debug | grep -A 5 "KeyExpiry"
```

## Security Considerations

1. **Tag-based access control**: Use tags to limit host access
2. **SSH restriction**: Prefer Tailscale SSH over traditional sshd
3. **Key rotation**: Monitor key expiry and rotate regularly
4. **Exit nodes**: Limit exit node access to trusted hosts
5. **Subnet routing**: Only advertise necessary subnets

## Adding New Hosts

1. Create `hosts/<name>.nix` with the host spec
2. Run `ivali bootstrap host <name>` to generate hardware config and secrets
3. Set appropriate tags and features
4. Deploy with `nixos-rebuild switch --flake .#<name>`
5. Verify connectivity in Tailscale admin console
