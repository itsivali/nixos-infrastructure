{
  battery = {
    states = {
      warning = 30;
      critical = 15;
    };
    format = "{icon} {capacity}%";
    format-charging = "󰂄 {capacity}%";
    format-plugged = "󰚥 {capacity}%";
    format-icons = [ "󰂎" "󰁺" "󰁼" "󰁽" "󰁿" "󰂁" "󰂂" "󰁹" ];
    tooltip-format = "Battery {capacity}%\n{time}  ·  {power} W\nHealth {health}%  ·  {cycles} cycles";
    on-click = "power-profile-cycle";
    on-click-right = "mission-center";
  };
}
