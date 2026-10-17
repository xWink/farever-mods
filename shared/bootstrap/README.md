# Required dependency checks

Mods using this bootstrap load an outer entry module before `implementation/<mod>.hl`. The entry verifies that Better Mod Settings and Mod Update Alerts binaries are installed, then checks the implementation's embedded SHA-256 to reject incomplete or mixed upgrades. Better Mod Settings and Mod Update Alerts do not depend on each other.

Missing or invalid files produce a desktop error and stop startup. These are installation checks, not checks of dependency runtime health or minimum versions.

Validation reads file headers and follows symbolic links. Do not rely on file-size metadata: Windows can report valid Vortex symlinks as zero bytes. Broken links, invalid binaries, and mismatched implementation hashes must still fail.

## Tests

From `shared/`, run `haxe test-dependencies.hxml`. From the repository root, run the native module-loading suite on Linux with Haxe, HashLink, and a C compiler:

```sh
python3 -m unittest discover -s shared/tests -p 'test_dependency_bootstrap.py' -v
```

`HAXE` and `HL` can select the executables; `LD_LIBRARY_PATH` must include the HashLink runtime when it is not installed system-wide. The suite covers dependency failures, implementation matching, and symlinks using a mock native dialog. Verify the actual Windows dialog in game.
