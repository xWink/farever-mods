# Changelog

## Unreleased

- Renamed the project, module, settings tab and archives to More Audio Settings.
- Existing settings are imported from the previous module name on first launch.

## v1.0.0 - 2026-08-25

- Initial working release.
- Mutes Farever's internal `vca:/MASTER` when the game loses focus.
- Restores the previous master VCA volume when focus returns.
- Uses an HLX postfix hook on `GameApp.update`.
