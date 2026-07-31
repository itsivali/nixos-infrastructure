{
  backlight = {
    format = "{icon} {percent}%";
    format-icons = [ "󰃞" "󰃟" "󰃠" ];
    tooltip-format = "Backlight {percent}%\n{brightness} / {max}";
    on-click = "swaync-client -t -sw";
    on-click-middle = "brightnessctl set 5%-";
    on-click-right = "brightness-menu";
    on-scroll-up = "brightnessctl set 5%+";
    on-scroll-down = "brightnessctl set 5%-";
  };
}
