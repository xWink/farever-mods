# Mod Update Alerts

[Builds](https://github.com/xWink/farever-mods/actions/workflows/build-mod-update-alerts.yml) · [Releases](https://github.com/xWink/farever-mods/releases?q=mod-update-alerts&expanded=true)

Checks Nexus Mods for updates in the background once per game launch. When updates
are found, a native window lists mod names, installed versions, and available
versions. Close it with its X or Escape to keep playing. To update, close Farever,
open Vortex, check for updates, install them, and deploy.
The popup waits for an initialized UI, registers with the game's window manager,
and keeps the mouse cursor available. Loading/menu transitions cannot permanently
exhaust its retries. Routine startup, version verification, and popup success are
silent. Initial UI-readiness retries are also quiet; persistent initialization
failures and other errors include the operation and actual error, with repeated
identical errors suppressed while retries continue.

The checkbox **Don't remind me again about these versions** remembers the listed
available versions immediately. Unchecking it restores the prior preference.
If any mod later has a newer update, or another mod gains an update, the next
launch shows the **entire outstanding update list**, including previously dismissed
updates. Installing some updates or a temporary failure to check one mod does not
erase remembered versions. Large lists have Previous/Next pages.

## Installation

Requires HLX Core 0.0.8 or newer for the new/PTR client. Also supports the current
live client. No ImGui or Better Mod Settings dependency, Nexus login, API key,
Premium subscription, or external executable.

Install the build ZIP with Vortex or extract it into the Farever game directory.
The installed file is `hlx/mods/mod-update-alerts/mod-update-alerts.hl`.
This mod only notifies; it never downloads, installs, or changes other mods.

**Upgrading from Mod Updater:** remove/disable the old `mod-updater` installation
before installing Mod Update Alerts, so both copies do not run. Existing dismissed
versions are read from the old reminder file until a new preference is saved.

## How installed versions are identified

HLX binaries in this repository do not contain a standard release-version field.
The checker reads current local metadata without locking or modifying Vortex's
database or requesting its credentials:

1. Vortex's `vortex.deployment.*json` records select mods actually deployed into
   this game directory. Only present, unmodified deployed code/package files
   (`.hl`, `.dll`, `.hdll`, `.pak`) qualify.
2. Farever's current installed-mod records in `%APPDATA%/Vortex/state.v2/`
   supply Nexus IDs, names, and installed versions. The reader follows LevelDB's
   active manifest, compressed tables, and recent write log, including updates and
   deletions. It retries if those files change during the read. If discovery still
   fails or records change during verification, the background worker retries the
   entire scan after 5 seconds and then 15 seconds in the same launch. Each scan
   has a 30-second budget, and quitting cancels the wait. It never opens the
   database for writing, takes its lock, or performs recovery/compaction.
3. Deployed binaries must also match the corresponding files in the manifest's
   Vortex staging folder by SHA-256. Current mod records are rechecked after file
   verification. Installed-but-not-deployed replacements and modified test builds
   cannot be labeled with a stale version. Disabled/staged-only mods are excluded.
   **Backup snapshots and archive/folder names are never version authorities:**
   Vortex may reuse an older version's folder name when updating in place.
   Farever mods and tools published under Nexus's Site category are supported.
4. Manual installs can include the opt-in metadata below.

This cannot identify every arbitrary manual install, portable Vortex installation,
or mod lacking version metadata. Unreadable/unsupported current Vortex databases,
missing/stale deployment records, changed binaries, unknown version schemes, and
unavailable Nexus metadata are logged as `[Mod Update Alerts]` and skipped; they
are never reported as up to date. Vortex need not be running, but mods must have
been deployed. These diagnostics do not prevent alerts for other identified mods.
Recovered database errors stay quiet. If all discovery attempts fail, the log
includes the underlying error once instead of repeating it for every deployed mod.

The public [Nexus GraphQL API](https://api.nexusmods.com/v2/graphql) supplies current
page versions and file metadata. The newest numeric/SemVer version among active
public main/update files is compared with the installed version. The page's
separate version field can lag behind a published download; it neither blocks a
new file nor advertises a version without an active download. Optional, archived,
or removed files alone do not trigger alerts. Only requested Nexus game domains
and mod IDs leave the computer; no file paths, binaries, Vortex database, or
credentials are uploaded.
Each identity is checked once per launch, using a worker thread, verified TLS,
bounded responses, request timeouts, and an overall time budget. Network failures
do not block startup; the next launch retries. Public API changes may require a
checker update.

Discovery format references: Vortex's
[deployment manifest](https://github.com/Nexus-Mods/Vortex/blob/master/src/renderer/src/extensions/mod_management/types/IDeploymentManifest.ts),
[deployed files](https://github.com/Nexus-Mods/Vortex/blob/master/src/renderer/src/extensions/mod_management/types/IDeploymentMethod.ts),
and [current state persistence](https://github.com/Nexus-Mods/Vortex/blob/master/src/main/src/store/LevelPersist.ts).
The reader follows LevelDB's [table](https://github.com/google/leveldb/blob/main/doc/table_format.md)
and [log](https://github.com/google/leveldb/blob/main/doc/log_format.md) formats.

## Manual-install metadata

A mod author can package `update-info.json` beside their binary:

```json
{
  "name": "Example Mod",
  "domain": "farever",
  "modId": 123,
  "version": "1.2.3",
  "binary": "example.hl",
  "sha256": "<64-character SHA-256 of the packaged binary>"
}
```

Use the real Nexus mod ID and the installed release version. Regenerate the hash
for each build. Mismatched hashes are ignored so stale metadata cannot label a
replacement binary as an older release. Mod Update Alerts itself can use this metadata
once it has a Nexus page; until then, its missing metadata is silently skipped.

Reminder preferences are stored in `hlx/config/mod-update-alerts/reminders.json`.
Delete the `reminders.json` and `.bak` files from both the new and old config
folders while Farever is closed to reset all suppressed reminders.

## Build and test

```sh
haxelib git hlx-runtime https://github.com/hlx-framework/hlx-core.git main hlx-runtime/src
haxe test.hxml
haxe compile.hxml
```

Tests cover numeric/prerelease ordering, reminders and rename migration, current
Vortex records overriding stale backups/folder names, staged-versus-deployed
contents, delayed discovery recovery and cancellation, release files newer than
their page version, manual metadata hashes, and popup dismissal releasing its
owner's modal registration without closing other windows. The synthetic database fixture was generated
by real LevelDB (via `plyvel-ci`) and exercises Snappy tables, multi-block write
logs, deletions, obsolete tables, and checksum failures. Regenerate it with
`python tests/generate_vortex_fixture.py` after installing `plyvel-ci`.
Native popup layout and discovery should also be verified in-game.
