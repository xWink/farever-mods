# Gameplay pacing and reuse audit

Static review, 2026-09-26. This is not a measured frame-time benchmark.

## Inspected clients

| Client | HL bytecode | SHA-256 |
| --- | --- | --- |
| Live (`hlboot(8).dat`) | 4 | `7d0c189415ad6832b11da0fafda29eaaa2a41f93330c4489942820b495e1df89` |
| PTR (`hlboot(6).dat`) | 6 | `9b7a7481c84e14d3f5b0123f0c969d79642ca8f9c5fc05d27d1055b891e3084b` |

No client binaries or extracted game source are distributed.

## Terrain

`Terrain.updateChunkLoad` services native quality work in the order 0, 1, 2, 5, 3, 4. `ChunkObject.updateQuality` changes its quality entry before performing that feature's native operation. Features 0/1 are terrain geometry, 2 decoration, 3 prop refresh, 4 block AO refresh, and 5 physics. These paths match across the inspected clients.

`TerrainPacing` only defers features 2–4 and only before their native call. It leaves `featuresQuality` unchanged for a retry. The native loop still discovers changes on subsequent passes; the overall loading budget and feature ordering are unchanged. It does not interrupt a job already running. A soft 2 ms deadline and two optional changes per pass limit bursts, with one optional change allowed every fourth pass when the soft deadline is already exhausted. Initial/loading-screen and fast/instant work bypass pacing.

`unloadFarChunks` removes a far chunk's loading-queue entry before calling `removeChunkObject`. Skipped removal retains the object in the native active list/maps, so its distance is checked again next pass. Retirement is limited to two real chunks per pass, allowing at least one. Explicit removals outside that routine are unchanged. Empty-chunk mesh removal remains native. Deferred chunks temporarily retain their resources; there is no external unbounded removal queue.

## Character and weapon work

Both clients' `addWeaponAsync` clear the slot, then submit `addWeapon` and `checkReady` through `Workers.addJob(..., false)`. The replacement retains that queue/thread and all arguments. Per-view/slot/index tokens reject superseded work, explicit clears, detached views, changed owners, and world disposal. Valid queued work can finish after the option is disabled.

`checkReady` performs material/Dither setup, animation/FX refresh, fade-in, and readiness callbacks. PTR additionally builds character silhouette resources. Calls from a worker pass are coalesced per asynchronous world view and flushed at the end of that same pass, including nested-worker handling. The native method is still called in full, including PTR-specific behavior. A failed worker scope is flushed at the next game-frame boundary. One failed finalization does not prevent attempting the other pending views.

These changes remove redundant initialization; they do not subdivide the body of `makeObject`, `addWeapon`, or a whole character constructor, and do not move scene/GPU work to background threads.

## Floating damage numbers

Both clients' `DamageDisplay.display` construct a native `Widget` with an owned fixed world-position vector. The native damage receiver does not retain the returned display. `UnitEffectDisplay.init` installs a lifetime/curve callback; its expired display is ordinarily detached. A native wait-until callback removes the widget when its container is empty.

The pool keeps its display attached while idle, hides the widget and removes it from `BaseUI.widgets` projection work. The wrapper pauses the native animation callback while idle. Reuse changes the owned position, damage result and lifetime, calls native `updateDamage`, resets native animation, and restores widget projection/visibility. Each reuse keeps the original curve/random-spread parameters of that display. No gameplay damage event or meter log is skipped.

`UIElement.bindUpdate` takes `(UIElement, Float -> Void) -> Void` on both clients. The hook must declare its closure by value: HLX derives the native receiver from the hook signature and does not interpret `hl.Ref` as an argument-replacement instruction. The initial pooling build used `hl.Ref<Float -> Void>` and blocked startup at `Fader.init`. The corrected hook passes unrelated UI through unchanged and forwards only wrapped damage callbacks through a guarded native call, returning `Skip` after that call to avoid duplicate registration. Boundary tests cover startup faders with the option on/off, recursive dispatch, single registration, callback execution and failure cleanup.

Styles are isolated by affinity, skill kind and critical flag. Live uses `DamageResult.baseSkill.kind`; PTR uses `DamageResult.skill.kind`. Using the kind avoids retaining or stringifying a whole replicated skill object. Amount formatting remains native. Idle entries release the damage result, expire after six seconds, and never transfer between UI owners. Eviction empties the container before removing the widget, so the native wait-until closure also terminates. Capacity is 48; further numbers remain native. A failed reactivation removes its partial widget before falling back to native display creation.

## Minimap

`Any.toImage`, `Image.toTexture`, `Image.toTile`, `Image.loadTexture` and `ThreadAsyncLoader.isSupported` match across these clients. The native loader chooses asynchronous decoding only for supported formats/backends. The request temporarily enables that preference and restores it even after exceptions; it does not force unsupported formats or change the global loader.

The texture's native loading flag is 512 in both clients. A tile is cloned only after this flag clears so its full dimensions/UVs are used. Its origin is independent of the native world-map tile. At most two requests are pending, with one foreground finalization/attachment per update. A four-tile adjacent prefetch fits within the existing cache allowance and is marked recently used to prevent immediate eviction/re-request churn. Visible tiles have priority. Resource loading and GPU upload are owned by the engine; no completion closure captures a disposed minimap.

## Verification and remaining limits

Interpreter tests exercise terrain deferral/essential-feature bypass/progress, weapon replacement/clearing/disposal/nested scopes, damage styling/native formatting/idle lifetime/UI changes/failure cleanup/capacity, and asynchronous tile readiness/full dimensions/flag restoration/native fallback. Both mods are also compiled to HashLink bytecode; GitHub Actions packages the installable artifacts.

Runtime validation still needs combat bursts, exploration/rapid travel, zoning, changed equipment, live/PTR UI scaling, and toggling the setting during pending work. There are no measured gain claims. Native constructors, some image formats, empty-chunk work, and GPU uploads remain indivisible. Shader compilation, pipeline prewarming, and the shader-cache mod are untouched.
