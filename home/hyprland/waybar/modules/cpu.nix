{
  cpu = {
    format = "󰍛 {usage}%";
    interval = 2;
    tooltip-format = "CPU {usage}%  ·  {core_count} cores  ·  {avg_frequency}\n{cores}";
    on-click = "kitty -e btop";
    on-click-middle = "kitty -e htop";
    on-click-right = "mission-center";
  };
}
