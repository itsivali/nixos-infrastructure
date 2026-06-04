{ config, gitlabUrl, hostName, pkgs, ... }:

{
###########################################################

# HOST IDENTITY

###########################################################

networking.hostName = hostName;

###########################################################

# LOCALE

###########################################################

i18n.defaultLocale = "en_US.UTF-8";

###########################################################

# HOST PACKAGES

###########################################################

environment.systemPackages =
(import ../packages/system { inherit pkgs; })
++ [
pkgs.btop
pkgs.fastfetch
pkgs.htop
pkgs.iproute2
pkgs.tailscale
];

###########################################################

# SOPS

###########################################################

sops = {
age.keyFile = "/var/lib/sops-nix/key.txt";

```
defaultSopsFile = ../secrets/tailscale.yaml;

secrets = {
  tailscale_authkey = {
    sopsFile = ../secrets/tailscale.yaml;
  };

  grafana_secret_key = {
    sopsFile = ../secrets/tailscale.yaml;
  };
};
```

};

###########################################################

# ZERO-TRUST NETWORKING

###########################################################

ivali.tailscale = {
enable = true;

```
# Automatically enroll into the tailnet using the
# SOPS-managed auth key.
authKeyFile =
  config.sops.secrets.tailscale_authkey.path;

# Matches your ACL model.
tag = "tag:admin";

# Prague acts as an exit node.
advertiseExitNode = true;

# Prevent Tailscale from taking over DNS.
acceptDns = false;

# Prevent automatic route acceptance.
acceptRoutes = false;

# Tailnet split-DNS domain.
tailnetDomain = "codlet-trench.ts.net";
```

};

###########################################################

# NIX / GITOPS

###########################################################

nix.settings.warn-dirty = false;

system.autoUpgrade = {
enable = true;

```
flake = "git+${gitlabUrl}#${hostName}";

flags = [
  "--refresh"
  "--print-build-logs"
];

dates = "04:30";

randomizedDelaySec = "45min";

allowReboot = false;
```

};
}
