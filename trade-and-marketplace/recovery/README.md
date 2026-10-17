# Recovery record

The original Haxe source was lost. `reference.zip` preserves the surviving October 14, 2026 build; `provenance.json` records its SHA-256 and original commit ID. The archive is a test fixture and is never packaged into new builds.

The reconstructed source now lives in `trade-and-marketplace/` and installs as `hlx/mods/trade-and-marketplace/`. It is not a byte-for-byte recreation of the lost source.

## Validation

- `haxe test.hxml` runs protocol, controller, capacity, tooltip, and simulated exchange regressions.
- The [Actions workflow](../../.github/workflows/build-trade-and-marketplace.yml) runs 6,110 differential checks against original protocol/session methods from the reference bytecode.
- The oracle harness disables original registration/startup in a temporary binary and uses an isolated HashLink runtime. It preserves the compared business methods.
- The current ten-second stall timeout intentionally differs from the original five-second timeout. The harness normalizes deadlines for comparison; regression tests check the new boundary separately.

Automated checks do not replace in-game testing of native UI, collision, and two-player exchanges.
