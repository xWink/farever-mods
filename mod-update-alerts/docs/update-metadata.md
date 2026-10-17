# Manual-install update metadata

Package `update-info.json` beside the mod's binary:

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

Use the real Nexus mod ID and installed release version. Regenerate the hash for each build. Mismatched hashes are ignored so stale metadata cannot misidentify a replacement binary.

An update alert requires a newer Nexus page version and a matching public main/update file. Optional, archived, or newer beta files alone do not trigger alerts.
