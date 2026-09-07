# Repository migration

The five repositories below were imported with their full `main` commit
histories. Import merge commits retain the original commit IDs, authors, and
messages, and place each tree in its own subproject. The mod source, Haxe build
settings, config descriptors, and bundled images were copied without changes.

| Project | Imported commit | Last release in original repository | First monorepo release |
| --- | --- | --- | --- |
| Better Mod Settings | `e6751b645719ba5d7bb3771b9e3478d322c3254a` | `v1.0.0` | `better-mod-settings/v1.0.1` |
| Item Utilities | `7581d9e0f82b29f6463c3078bd9e29e4e0d39872` | `v1.2.1` | `item-utilities/v1.2.2` |
| Disable Profanity Filter | `6b139e0618f8327fe126f8ce970c420ec605f759` | `v1.1.0` | `disable-profanity-filter/v1.1.1` |
| Mute on Unfocus | `dc20d1b760ad32cc219205042e781aefaf996c5b` | `v1.2.0` | `mute-on-unfocus/v1.2.1` |
| Fix Target Lock | `e86f5339df420316171cde83782661dce1d45764` | `v1.2.0` | `fix-target-lock/v1.2.1` |

Original version tags are retained here as `archive/<project>/<original-tag>`
to avoid collisions. Historical commits and tags retain their original
repository-root paths. For example:

```sh
git log archive/item-utilities/v1.2.1 -- src/itemutilities/ItemUtilitiesMod.hx
```

The first monorepo releases build each project's latest imported `main`, which
can include changes made after its last release in the original repository.
Their patch versions distinguish these new builds from earlier published ZIPs.

Earlier release binaries and release notes remain in the original repositories:

- [Better Mod Settings releases](https://github.com/xWink/farever-better-mod-settings/releases)
- [Item Utilities releases](https://github.com/xWink/farever-item-utilities/releases)
- [Disable Profanity Filter releases](https://github.com/xWink/farever-disable-profanity-filter/releases)
- [Mute on Unfocus releases](https://github.com/xWink/farever-mute-on-unfocus/releases)
- [Fix Target Lock releases](https://github.com/xWink/farever-fix-target-lock/releases)

Issues, pull requests, and previous Actions runs remain in their original
repositories. New development and releases belong in `xWink/farever-mods`.
