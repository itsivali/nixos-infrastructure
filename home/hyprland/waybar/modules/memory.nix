{
  memory = {
    format = "󰘚 {percentage}%";
    interval = 2;
    tooltip-format = "RAM {used}/{total}  ({percentage}%)\nAvailable {available}  ·  Cache {cache}  ·  Buffers {buffers}\nSwap {swapUsed}/{swapTotal}";
    on-click = "kitty -e btop";
    on-click-middle = "kitty -e htop";
    on-click-right = "mission-center";
  };
}
