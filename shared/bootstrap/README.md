# Required dependency checks

DPS Meter, Minimap, Item Utilities, More Settings and Fix Target Lock compile
two modules. The outer entry checks that the Better Mod Settings and Mod Update
Alerts binaries are installed. None of these mods requires ImGui.

Missing dependencies produce a native desktop error and exit with status 1.
HLX catches ordinary mod exceptions, so throwing would allow the game to continue.
No game UI, new DLL, or updated Better Mod Settings is needed to
display this message. If the game's desktop dialog library is unavailable, the
same message is logged before exiting. Without HLX itself installed, none of our
mod code can run, including this check.

After validation the entry loads `implementation/<mod>.hl` using HashLink's
`sys_load_plugin`, the same API HLX uses. The unchanged basename preserves HLX
module names, configuration paths, event topics, and log labels. The entry embeds
and checks its implementation's SHA-256 to reject incomplete/mixed upgrades and
keep manual-install binary-hash version metadata tied to the actual code.

The Better Mod Settings and Mod Update Alerts checks verify installed binaries,
not their runtime health or minimum versions. These are installation checks, so
Mod Update Alerts may be loaded later in HLX's alphabetical load order. We do not
add a dependency to Better Mod Settings itself or Mod Update Alerts.

Binary validation opens the file and reads its four-byte header (the `HLB`
magic plus a version byte), following symbolic links to their targets. It does
not use filesystem metadata to reject small files: Windows `_wstat`, used by
HashLink's filesystem functions, can report a valid symbolic link as zero
bytes. This previously caused Vortex symlink deployments to be reported as
missing dependencies. See [Microsoft's stat documentation](https://learn.microsoft.com/en-us/cpp/c-runtime-library/reference/stat-functions).
Broken links, directories, empty/truncated files and invalid magic still fail;
implementation hashes remain mandatory.

Run the dependency policy tests from `shared/` with `haxe test-dependencies.hxml`.
On Linux with Haxe, HashLink and a C compiler, run the real module-loading tests:

```sh
python3 -m unittest discover -s shared/tests -p 'test_dependency_bootstrap.py' -v
```

`HAXE` and `HL` can point to the executables; `LD_LIBRARY_PATH` must include the
HashLink runtime if it is not installed system-wide. Tests use a mock native
dialog and run without an ImGui plugin. They verify that all five entry modules
load matching implementations and that missing dependencies exit before
implementation initializers run. Actual Windows/game display still needs an
in-game check.

The subprocess suite also tests real symbolic links for dependency binaries,
entry modules and implementation files, including a staging path containing
spaces and non-ASCII text. A Linux preload fixture reproduces zero-byte symlink
metadata while keeping file reads intact, with a HashLink probe verifying both
conditions. All five old bootstraps fail this regression; all five fixed ones
load their implementation. Broken/invalid targets and mismatched linked
implementations still stop before any implementation initializer runs.
