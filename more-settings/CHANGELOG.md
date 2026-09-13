# Changelog

## Unreleased

- Renamed More Audio Settings to More Settings across source, configuration display name, build output, workflow, artifact, and release ZIP.
- Imported previous More Audio Settings/Mute Unfocused preferences without deleting backups.
- Added Disable profanity filter, retaining HTML escaping and the standalone saved preference when available.
- Added fast-travel volume, coordinated with unfocused volume and in-game master-volume changes.
- Added location-specific ally attack, buff, and model visibility controls. All default off.
- Kept local-player, enemy, ability timing, and gameplay/network behavior intact.
- Added regression coverage and a CI test gate.

## v1.0.0 - 2026-08-25

- Initial working release.
- Mutes Farever's internal `vca:/MASTER` when the game loses focus.
- Restores the previous master VCA volume when focus returns.
- Uses an HLX postfix hook on `GameApp.update`.
