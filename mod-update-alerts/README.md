# Mod Update Alerts

[Builds](https://github.com/xWink/farever-mods/actions/workflows/build-mod-update-alerts.yml) · [Releases](https://github.com/xWink/farever-mods/releases?q=mod-update-alerts%2Fv&expanded=true)

Checks Nexus Mods for updates in the background once per game launch and shows installed and available versions in a native popup.

## Usage

- Select **Changes** to read an update's changelog.
- Close the popup to dismiss it for the current launch.
- Select **Don't remind me again about these versions** to remember the listed updates. A newer update can trigger another reminder.
- To update, close Farever, install the updates in Vortex, and deploy.

This mod only notifies: it never downloads, installs, or changes other mods. No Nexus login, API key, or Premium subscription is required.

## Installation

Requires HLX Core 0.0.8+. Download from [Nexus Mods](https://www.nexusmods.com/farever/mods/17) or Releases and follow the [installation instructions](../README.md#installation). Better Mod Settings is not required.

If upgrading from **Mod Updater**, remove or disable the old `mod-updater` installation to avoid running both copies. Existing reminder preferences are migrated.

## Supported installs

Vortex mods must be deployed and match their installed files. Manual installs need valid `update-info.json` metadata. Unknown or modified versions are skipped, not reported as up to date. Network failures do not block startup.

Reminder preferences are saved in `hlx/config/mod-update-alerts/reminders.json`.

For mod authors, see [manual-install metadata](docs/update-metadata.md).

See [Building](../README.md#building) for source builds and tests.
