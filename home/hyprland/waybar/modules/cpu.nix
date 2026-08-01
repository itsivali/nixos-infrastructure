{
  cpu = {
    format = "󰍛 {usage}%";
    interval = 2;
    tooltip-format = "CPU {usage}%  ·  {core_count} cores  ·  {avg_frequency}\n{cores}";
    on-click = "konsole -e btop";
    on-click-middle = "konsole -e htop";
    on-click-right = "mission-center";
  };
}
