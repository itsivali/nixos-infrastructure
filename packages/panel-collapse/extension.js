import Gio from 'gi://Gio'
import St from 'gi://St'

import * as Main from 'resource:///org/gnome/shell/ui/main.js'

export default class PanelCollapse {
  enable() {
    this._settings = Gio.Settings.new('org.gnome.shell.extensions.panel-collapse')

    this._chevron = new St.Button({
      style_class: 'panel-button',
      can_focus: false,
      track_hover: true,
      reactive: true,
      accessible_name: 'Show indicators',
      child: new St.Icon({
        style_class: 'system-status-icon',
        icon_name: 'pan-end-symbolic',
      }),
    })

    this._chevron.connect('clicked', () => {
      this._settings.set_boolean(
        'collapsed',
        !this._settings.get_boolean('collapsed'),
      )
    })

    this._rightBox = Main.panel._rightBox
    this._rightBox.add_child(this._chevron)

    this._actorAddedId = this._rightBox.connect('actor-added', (_box, actor) => {
      if (actor !== this._chevron && this._isCollapsed())
        actor.visible = false
    })

    this._panelChildAddedId = Main.panel.connect('child-added', () => {
      if (this._isCollapsed())
        this._hideQuickSettings()
    })

    this._settingsChangedId = this._settings.connect(
      'changed::collapsed',
      () => this._apply(),
    )

    this._apply()
  }

  disable() {
    if (this._settingsChangedId) {
      this._settings.disconnect(this._settingsChangedId)
      this._settingsChangedId = 0
    }
    if (this._panelChildAddedId) {
      Main.panel.disconnect(this._panelChildAddedId)
      this._panelChildAddedId = 0
    }
    if (this._actorAddedId && this._rightBox) {
      this._rightBox.disconnect(this._actorAddedId)
      this._actorAddedId = 0
    }

    this._applyCollapsed(false)

    if (this._chevron) {
      this._chevron.destroy()
      this._chevron = null
    }

    this._settings = null
  }

  _isCollapsed() {
    return this._settings?.get_boolean('collapsed') ?? true
  }

  _apply() {
    const collapsed = this._isCollapsed()

    this._applyCollapsed(collapsed)

    if (this._chevron) {
      const icon = this._chevron.get_first_child()
      icon.icon_name = collapsed ? 'pan-end-symbolic' : 'pan-start-symbolic'
      this._chevron.accessible_name = collapsed
        ? 'Show indicators'
        : 'Hide indicators'
    }
  }

  _applyCollapsed(collapsed) {
    if (this._rightBox) {
      for (const child of this._rightBox.get_children()) {
        if (child !== this._chevron)
          child.visible = !collapsed
      }
    }

    if (collapsed)
      this._hideQuickSettings()
    else
      this._showQuickSettings()
  }

  _quickSettingsContainer() {
    const qs = Main.panel.statusArea.quickSettings
    return qs?.container ?? null
  }

  _hideQuickSettings() {
    const container = this._quickSettingsContainer()
    if (container)
      container.visible = false
  }

  _showQuickSettings() {
    const container = this._quickSettingsContainer()
    if (container)
      container.visible = true
  }
}
