{
  "custom/updates" = {
    format = " {}";
    tooltip = true;
    tooltip-format = "NixOS system updates available";
    return-type = "json";
    exec = "echo '{\"text\": \" 0\"}'";
    interval = 3600;
  };
}
