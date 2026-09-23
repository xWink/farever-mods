# Releasing a mod

Use the **Farever Mod Release** skill with:

```text
Release Item Utilities 1.9.0
- Expanded presets to five slots per category.
- Improved dropdown styling.
```

The supplied notes become the GitHub release body, annotated tag message, and
Nexus changelog. They are not generated from commit messages or rewritten.
An explicit release command authorizes both publishing destinations. Preparing
notes, building a test artifact, or asking about a release does not publish it.

## One-time Nexus setup

1. Get your personal API key from <https://www.nexusmods.com/settings/api-keys>.
2. In [repository Actions secrets](https://github.com/xWink/farever-mods/settings/secrets/actions),
   add a repository secret named **NEXUSMODS_API_KEY**. Enter its value directly
   there; do not put it in chat, source control, a release request, or a log.
3. The mappings in [tools/release/mods.json](tools/release/mods.json) already
   identify all seven existing mod pages. The workflow resolves the Nexus v3
   mod ID and main file ID through the API. Usually no other setup is needed.

If a page has several main files with no unique primary download, set that
project's `nexus_file_id` in `mods.json` to the persistent **File ID** from
**Files > Advanced** (or **Manage Files > edit**). This is the v3 file ID,
not a historical numeric file-version/download ID. The workflow checks that
an override belongs to the configured mod page before using it.

The key must belong to an account allowed to upload to the configured pages.
GitHub publishing uses the built-in workflow token and needs no additional key.

## What happens

1. The skill resolves the requested mod and records an exact source commit from
   `main`, the version, and the supplied notes in `.github/release-request.json`.
2. Pushing that request to `main` starts **Release mod to GitHub and Nexus**.
   Ordinary code pushes still only create build artifacts.
3. The workflow validates the request and Nexus destination before publishing.
   It calls the selected mod's existing build/test workflow at the source SHA.
   DPS Meter also passes its Windows clipboard and recycle-bin tests.
4. After all selected checks pass, it packages one Vortex-compatible ZIP, creates
   `<project>/v<version>` as an annotated tag, and publishes the GitHub release.
5. For stable versions, the pinned official Nexus upload Action uploads that
   same ZIP, makes it the main/default mod-manager download, updates the mod-page
   version, and adds the supplied changelog. Older downloads are retained.
6. GitHub stores `release-manifest.json` (source/request identity and ZIP hash)
   and, after successful Nexus upload/changelog creation, `nexus-receipt.json`.
   The run summary shows the GitHub and Nexus links and any failed stage.

Prerelease versions such as `1.9.0-rc.1` publish a **GitHub prerelease only**.
They do not change the Nexus stable file or advertised page version.

The pipeline performs Nexus publishing directly after GitHub publishing.
It does not rely on a release event caused by `GITHUB_TOKEN`, because that event
would not start a second workflow. The existing tag workflows remain available
for GitHub-only releases; they do not perform Nexus publication.

## Release request format

```json
{
  "project": "item-utilities",
  "version": "1.9.0",
  "commit": "FULL_40_CHARACTER_COMMIT_SHA_FROM_MAIN",
  "notes": "- Expanded presets to five slots per category.\n- Improved dropdown styling.",
  "dry_run": false
}
```

Use a version without a `v` prefix. Do not manually type JSON escapes for notes;
write the exact text to a UTF-8 file, then run:

```sh
python3 tools/release/release.py request \
  --project item-utilities --version 1.9.0 \
  --commit FULL_40_CHARACTER_COMMIT_SHA_FROM_MAIN \
  --notes-file /path/to/release-notes.md
python3 tools/release/release.py check
```

Inspect and commit just `.github/release-request.json`, then push to `main`.
The source must already be an ancestor of the request commit. Build jobs check
out that exact source; they never silently switch to a newer `main` commit.
Preserve unrelated local changes. Check the latest remote `main` before updating
it, and never force-push to resolve a competing update.

Submit one request at a time and wait for its result. GitHub's concurrency queue
retains only one pending run, so do not enqueue multiple release requests at once.
**Run workflow** on `main` reruns the current request; it is a publishing action
when that request has `dry_run: false`.

## Validation without publishing

Use `--dry-run` when generating a request. The workflow then builds, tests, and
packages the selected source without requiring a Nexus key or creating tags,
releases, or uploads. Its `release-dry-run-<project>` artifact contains the ZIP
and manifest. The initial checked-in request is such a dry run, not a release.

Offline checks:

```sh
python3 -m unittest discover -s tools/release -p 'test_*.py' -v
python3 tools/release/release.py check
```

**Release automation checks** also validates all workflow syntax with actionlint.
Live Nexus credentials and an authorized real release are needed to exercise
Nexus uploads; dry runs deliberately do not upload test files to public pages.

## Retries and partial failures

- A missing Nexus secret, ambiguous destination, duplicate Nexus version, or
  failed build stops publishing. A version already published with different
  notes/source is never overwritten, and a tag is never moved.
- If GitHub publishing succeeded and Nexus failed before creating a version,
  rerun the request. The ZIP already attached to GitHub is reused and its hash
  is checked; a newly compiled ZIP never replaces it.
- A matching Nexus receipt makes a completed retry skip uploading again.
- If Nexus created the file but failed later (for example while adding its
  changelog), there may be no completion receipt. The next run stops on the
  existing version instead of uploading a duplicate. Inspect the failed Action
  and Nexus page, finish the missing step, and verify the result before recording
  completion. Do not delete a published version just to make a retry pass.
- A draft GitHub release missing its expected manifest or ZIP requires inspection
  before resuming. Network/permission errors are not treated as missing releases.

GitHub and Nexus are separate services: a later Nexus error cannot undo an
already published GitHub release. Report both platform outcomes accurately.

## Projects

| Project/tag prefix | Nexus page | Installable archive |
| --- | --- | --- |
| `better-mod-settings` | [Better Mod Settings](https://www.nexusmods.com/farever/mods/10) | `farever-better-mod-settings.zip` |
| `item-utilities` | [Item Utilities](https://www.nexusmods.com/farever/mods/9) | `farever-item-utilities.zip` |
| `more-settings` | [More Settings](https://www.nexusmods.com/farever/mods/6) | `farever-more-settings.zip` |
| `fix-target-lock` | [Fix Target Lock](https://www.nexusmods.com/farever/mods/8) | `farever-fix-target-lock.zip` |
| `dps-meter` | [DPS Meter](https://www.nexusmods.com/farever/mods/11) | `farever-dps-meter.zip` |
| `minimap` | [Minimap](https://www.nexusmods.com/farever/mods/15) | `farever-minimap.zip` |
| `mod-update-alerts` | [Mod Update Alerts](https://www.nexusmods.com/farever/mods/17) | `farever-mod-update-alerts.zip` |

Each ZIP starts with `hlx/` and contains only that mod and its native plugins.
Versions are independent; the repository has no shared Latest release.
Historical releases remain linked from [MIGRATION.md](MIGRATION.md).
