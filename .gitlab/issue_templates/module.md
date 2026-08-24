---
name: Module
about: New or updated NixOS/Home Manager module
title: "[module] "
labels: module
---

## Module Purpose

<!-- What capability does this module provide? -->

## Domain

<!-- Which domain does this belong to? (desktop, networking, security, services, etc.) -->

## Options

<!-- What configuration options will be exposed? -->

```nix
config.modules.<domain>.<name> = {
  enable = mkEnableOption "...";
  # additional options
};
```

## Dependencies

<!-- What does this module depend on? -->

- [ ] NixOS modules
- [ ] Home Manager modules
- [ ] Packages
- [ ] Secrets

## Testing

- [ ] Module evaluates without error
- [ ] Default config works
- [ ] Custom config works
- [ ] Documentation added

## Checklist

- [ ] Follows module conventions (lib.mkIf, lib.mkOption)
- [ ] Disabled by default
- [ ] No hardcoded paths
- [ ] All options documented
- [ ] Verification gates pass
