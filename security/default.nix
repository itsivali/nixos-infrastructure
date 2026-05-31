{
  imports = [
    ./firewall.nix
    ./tailscale.nix
  ];

  security = {
    sudo.execWheelOnly = true;
    protectKernelImage = true;
    rtkit.enable = true;
    polkit.enable = true;
  };

  services.fail2ban = {
    enable = true;
    maxretry = 5;
    bantime = "1h";
  };
}
