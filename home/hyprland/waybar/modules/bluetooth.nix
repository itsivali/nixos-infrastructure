{
  bluetooth = {
    format = "{status}";
    format-connected = "󰂯 {num_connections}";
    format-on = "󰂯";
    format-off = "󰂲";
    format-disabled = "󰂲";
    tooltip-format = "{controller_alias}\n{controller_address}\n{device_enumerate}";
    tooltip-format-enumerate-connected = "{device_alias}  ({device_address})";
    on-click = "blueman-manager";
    on-click-right = "bash -c 'bluetoothctl power \$(bluetoothctl show | grep -q \"Powered: yes\" && echo off || echo on)'";
  };
}
