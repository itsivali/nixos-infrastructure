# Panel Collapse (GNOME Shell extension)

Hides the non-essential right-side panel indicators — quick settings, vitals
gauges, clipboard indicator and AppIndicator tray icons — behind a chevron
arrow, keeping the date and time permanently visible on the minimal
dash-to-panel top bar.

## Behavior

- **Collapsed by default** at login: only the clock sits next to the `»` arrow.
- **Click the arrow** to reveal/hide the indicators (icon flips to `«`).
- New tray icons appearing while collapsed stay hidden automatically;
  the indicators keep running underneath (hiding is purely visual).
- State persists in GSettings, so your collapsed/expanded choice survives
  shell restarts.

## Options

| Option      | Default | Meaning                                          |
|-------------|---------|--------------------------------------------------|
| `collapsed` | `true`  | Indicators hidden behind the arrow at login time |

## Troubleshooting

- **Nothing collapses:** confirm the extension is enabled
  (`gnome-extensions list`) and `collapsed = true` in dconf.
- **Quick settings still visible:** dash-to-panel must own the panel; the
  button lives at `Main.panel.statusArea.quickSettings.container`.
- **Changes not applied:** GNOME Shell extensions load at login — log out and
  back in after installing or toggling this extension.
