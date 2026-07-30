{
  mainBar = {
    layer = "top";
    position = "top";
    height = 36;
    margin-top = 6;
    margin-left = 10;
    margin-right = 10;
    spacing = 4;

    modules-left = [
      "custom/appmenu"
      "hyprland/workspaces"
      "hyprland/window"
    ];

    modules-center = [
      "clock"
    ];

    modules-right = [
      "cpu"
      "memory"
      "custom/updates"
      "pulseaudio"
      "backlight"
      "network"
      "battery"
      "idle_inhibitor"
      "custom/notification"
      "custom/power"
    ];

    "custom/appmenu" = {
      format = " 󱄅 ";
      tooltip = false;
      on-click = "rofi -show drun";
    };

    "hyprland/workspaces" = {
      disable-scroll = true;
      all-outputs = true;
      format = "{icon}";
      format-icons = {
        "1" = "󰲠";
        "2" = "󰲢";
        "3" = "󰲤";
        "4" = "󰲦";
        "5" = "󰲨";
        "6" = "󰲪";
        "7" = "󰲬";
        "8" = "󰲮";
        "9" = "󰲰";
        default = "";
      };
    };

    "hyprland/window" = {
      format = "{title}";
      max-length = 40;
      separate-outputs = true;
    };

    clock = {
      format = "{:%H:%M  󰃭 %Y-%m-%d}";
      tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
    };

    cpu = {
      format = "󰍛 {usage}%";
      interval = 2;
      on-click = "mission-center";
      on-click-right = "kitty btop";
    };

    memory = {
      format = "󰘚 {percentage}%";
      interval = 2;
      on-click = "mission-center";
      on-click-right = "kitty btop";
    };

    pulseaudio = {
      format = "{icon} {volume}%";
      format-muted = "󰝟 Muted";
      format-icons = {
        default = [ "󰕿" "󰖀" "󰕾" ];
      };
      on-click = "pamixer -t";
      on-click-right = "pavucontrol";
    };

    backlight = {
      format = "{icon} {percent}%";
      format-icons = [ "󰃞" "󰃟" "󰃠" ];
      on-click = "brightnessctl set 5%+";
      on-click-right = "brightnessctl set 5%-";
    };

    network = {
      format-wifi = "󰤨 {essid}";
      format-ethernet = "󰈀 Ethernet";
      format-disconnected = "󰤭 Offline";
      tooltip-format = "{ifname} via {gwaddr}";
      on-click = "nm-connection-editor";
      on-click-right = "nmtui";
    };

    battery = {
      states = {
        warning = 30;
        critical = 15;
      };
      format = "{icon} {capacity}%";
      format-charging = "󰂄 {capacity}%";
      format-plugged = "󰚥 {capacity}%";
      format-icons = [ "󰂎" "󰁺" "󰁼" "󰁽" "󰁿" "󰂁" "󰂂" "󰁹" ];
    };

    idle_inhibitor = {
      format = "{icon}";
      format-icons = {
        activated = "󰅶";
        deactivated = "󰛬";
      };
      tooltip = true;
      tooltip-format = "{icon}: {state}";
    };

    "custom/notification" = {
      tooltip = false;
      format = "{icon}";
      format-icons = {
        notification = "󱅫";
        none = "󰂜";
        dnd-notification = "󰂛";
        dnd-none = "󰪑";
        inhibited-notification = "󱅫";
        inhibited-none = "󰂜";
        dnd-inhibited-notification = "󰂛";
        dnd-inhibited-none = "󰪑";
      };
      return-type = "json";
      exec-if = "which swaync-client";
      exec = "swaync-client -swb";
      on-click = "swaync-client -t -sw";
      on-click-right = "swaync-client -d -sw";
      escape = true;
    };

    "custom/updates" = {
      format = " {}";
      tooltip = true;
      tooltip-format = "NixOS system updates available";
      return-type = "json";
      exec = "echo '{\"text\": \" 0\"}'";
      interval = 3600;
    };

    "custom/power" = {
      format = "󰐥";
      tooltip = false;
      on-click = "wlogout";
    };
  };
}
