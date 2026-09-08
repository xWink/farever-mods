# Releasing a mod

Release each mod independently with an annotated tag of the form
`<project>/v<major>.<minor>.<patch>`. The tag points to the monorepo commit to
build; the matching workflow publishes only that project's ZIP.

| Project/tag prefix | Archive | Installed directory |
| --- | --- | --- |
| `better-mod-settings` | `farever-better-mod-settings.zip` | `hlx/mods/better-mod-settings/` |
| `item-utilities` | `farever-item-utilities.zip` | `hlx/mods/item-utilities/` |
| `disable-profanity-filter` | `farever-disable-profanity-filter.zip` | `hlx/mods/disable-profanity-filter/` |
| `more-audio-settings` | `farever-more-audio-settings.zip` | `hlx/mods/more-audio-settings/` |
| `fix-target-lock` | `farever-fix-target-lock.zip` | `hlx/mods/fix-target-lock/` |
| `dps-meter` | `farever-dps-meter.zip` | `hlx/mods/dps-meter/` (including `uploader.exe`) |

## Procedure

1. Commit and push the mod's changes to `main`.
2. Wait for that mod's build to pass in Actions.
3. Choose its next unused version. Review both current tags and, for the first
   release after migration, the historical versions in `MIGRATION.md`.
4. Create and push an annotated tag. Its message becomes the release notes.

For example, after Item Utilities v1.2.2:

```sh
git switch main
git pull --ff-only
git tag -a item-utilities/v1.2.3 -m "Fix inventory sorting after zone changes."
git push origin refs/tags/item-utilities/v1.2.3
```

For longer release notes, write the exact text to a file and use
`git tag -a item-utilities/v1.2.3 -F /path/to/release-notes.md`.

The workflow validates the tag, compiles and packages the mod, then publishes
the release only if the build succeeded. A prerelease tag such as
`item-utilities/v1.2.3-rc.1` creates a GitHub prerelease. The workflow uses the
built-in `GITHUB_TOKEN`; no additional release secret is required.

Push release tags individually. GitHub does not create tag-push events when
more than three tags are pushed at once. A build started with **Run workflow**
on `main` only uploads a build artifact. Running the workflow on one of its
release tags builds and publishes that release, which also allows recovery if
a tag-push event was missed:

```sh
gh workflow run build-item-utilities.yml --ref item-utilities/v1.2.3
```

Release retries leave existing releases intact. Do not move a published tag to
different source; publish a new version instead.

GitHub has one repository-wide Releases list and one repository-wide Latest
marker. Use the per-project release links in the README to find the appropriate
mod. The workflows do not set a repository-wide Latest release.

Original release tags and ZIPs remain in the original repositories, linked in
`MIGRATION.md`. That document also explains how to fetch a historical tag locally
under `archive/<project>/v...` when needed. Such tags retain the original root
layout and do not trigger the new release workflows.
