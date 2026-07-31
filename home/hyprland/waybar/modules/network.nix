{
  network = {
    format-wifi = "󰤨 {essid}";
    format-ethernet = "󰈀 Ethernet";
    format-disconnected = "󰤭 Offline";
    tooltip-format = "{essid}  ({signalStrength}%)\n{ipaddr}  ·  {freq}  ·  {bitrate}\n{ifname} via {gwaddr}";
    on-click = "networkmanager_dmenu";
    on-click-middle = "nm-connection-editor";
    on-click-right = "nmtui";
  };
}
