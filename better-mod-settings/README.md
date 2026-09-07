# Better Mod Settings

Adds a **Mod Settings** button to Farever's Game Menu and presents compatible mods' settings in a native game window.

![Better Mod Settings displaying checkboxes, a slider, hotkeys, tab pagination, and vertical scrolling](docs/images/better-mod-settings.png)

## Installation

Download the mod with Vortex on [NexusMods](https://www.nexusmods.com/farever/mods/10).

## For developers: How to make a mod compatible with Better Mod Settings

A compatible mod needs:

1. A JSON settings file in the mod's folder.
2. A `configFormats.json` descriptor in the same folder.
3. A Better Mod Settings bus subscription so the running mod reloads its settings immediately after an edit.

The resulting folder should look like this:

```text
hlx/mods/example-mod/
├── example-mod.hl
├── config.json
└── configFormats.json
```

### 1. Create the settings file

Better Mod Settings edits an existing JSON object. Each exposed setting must be a top-level property whose JSON type matches its control:

```json
{
  "enabled": true,
  "volume": 50,
  "actionHotkey": 0
}
```

The settings file must exist before the Mod Settings window opens and must contain valid JSON. It may contain additional properties that are not exposed in the UI; Better Mod Settings preserves them when saving.

### 2. Add `configFormats.json`

Create `configFormats.json` beside the settings file and describe the controls in the order they should appear:

```json
{
  "schemaVersion": 1,
  "displayName": "Example Mod",
  "configFile": "config.json",
  "configs": [
    {
      "key": "enabled",
      "type": "checkbox",
      "label": "Enabled"
    },
    {
      "key": "volume",
      "type": "slider",
      "label": "Volume %",
      "min": 0,
      "max": 100,
      "step": 1
    },
    {
      "key": "actionHotkey",
      "type": "keybinding",
      "label": "Action hotkey"
    }
  ]
}
```

#### Top-level options

| Option | Required | Type | Behavior and limitations |
| --- | --- | --- | --- |
| `schemaVersion` | Recommended | Number | Use `1`. The current reader reserves this field for format evolution but does not reject or branch on it yet. |
| `displayName` | No | String | Name shown on the mod's tab. Defaults to the mod folder name. Tabs are sorted alphabetically by this value. |
| `configFile` | No | String | Settings filename. Defaults to `config.json`. It must be a plain filename in the same mod folder: paths, `..`, `/`, and `\` are rejected. |
| `configs` | Yes | Array | Control definitions. Items are displayed in array order. |

#### Options shared by every control

| Option | Required | Type | Behavior and limitations |
| --- | --- | --- | --- |
| `key` | Yes | String | Exact top-level property name in the settings JSON. An empty key is ignored; nested paths are not supported. |
| `type` | Yes | String | Must be exactly `checkbox`, `slider`, or `keybinding`. Other values do not create a usable control. |
| `label` | No | String | Text displayed beside the control. Defaults to `key`. |

#### Control types

| `type` | Settings value | Extra descriptor options | Limitations |
| --- | --- | --- | --- |
| `checkbox` | Boolean (`true` or `false`) | None | Represents a boolean only. A missing value is displayed as `false`. |
| `slider` | Number | `min` (default `0`), `max` (default `100`), and `step` (default `1`), all numbers | Supply sensible bounds with `min <= max` and a positive `step`. A missing value starts at `min`. |
| `keybinding` | Integer key code | None | Captures one `hxd.Key`-compatible key only. Modifier combinations and multi-key chords are not supported. `0` means **Not set**. Escape cancels capture and cannot be assigned through the UI. |

The current format does not provide text inputs, dropdowns, buttons, color pickers, nested objects, groups, conditional controls, or settings that span multiple JSON properties.

### 3. Subscribe to live setting changes

Better Mod Settings writes the updated JSON first, then publishes a notification on:

```text
better-mod-settings/config-changed/<mod-folder-name>
```

Subscribe with the mod's runtime module name so it automatically matches the installed folder:

```haxe
import hlx.runtime.Bus;

static inline var SETTINGS_CHANGED_TOPIC_PREFIX =
    "better-mod-settings/config-changed/";

static function main():Void {
    loadConfig();
    saveConfig();

    Bus.subscribe(
        SETTINGS_CHANGED_TOPIC_PREFIX + HlxRuntime.moduleName(),
        onBetterModSettingsChanged
    );
}

static function onBetterModSettingsChanged(_:Dynamic):Void {
    loadConfig();
    applyConfig(); // Optional: immediately apply runtime side effects.
}
```

If the mod already has a `main()`, add only the `Bus.subscribe(...)` call after its initial config load. The event payload is intentionally unused: the JSON file remains the source of truth, so the callback should reload it unconditionally. Do not save the old in-memory values from this callback, because that would overwrite the user's edit.

Bus notifications require HLX Core `0.0.7` or newer. Without the subscription, Better Mod Settings can still edit the file, but the mod must poll the file or wait until its next load/restart to observe the change.

## Building

Requires [HLX Core](https://github.com/hlx-framework/hlx-core) and the Farever `hl-imgui` library.

```sh
haxe compile.hxml
```
