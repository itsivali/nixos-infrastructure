{
  pulseaudio = {
    format = "{icon} {volume}%";
    format-muted = "󰝟 Muted";
    format-icons = {
      default = [ "󰕿" "󰖀" "󰕾" ];
    };
    tooltip-format = "{desc}: {volume}%";
    on-click = "swaync-client -t -sw";
    on-click-middle = "pamixer -t";
    on-click-right = "pavucontrol";
    on-scroll-up = "pamixer -i 5";
    on-scroll-down = "pamixer -d 5";
  };
}
