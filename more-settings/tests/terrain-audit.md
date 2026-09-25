# Terrain composition reuse audit

Checked against the supplied clients:

- Live HL4: SHA-256 `7d0c189415ad6832b11da0fafda29eaaa2a41f93330c4489942820b495e1df89`.
- PTR HL6: SHA-256 `9b7a7481c84e14d3f5b0123f0c969d79642ca8f9c5fc05d27d1055b891e3084b`.

`Terrain.updateGlobals` has equivalent logic in both clients after normalizing
debug metadata and anonymous array-constructor indices. It selects a 3x3
neighborhood using `TerrainData.getChunk`, updates buffer/position arrays,
clears and composes the normal and soft-height targets, sets the chunk-aligned
global position, then calls `Renderer.setTerrainGlobals`. Source selectors read
`ChunkObject.ground.shader.normalTex__` and `heightTex__`. The optimization
retains the native method for every rebuild and only bypasses identical results.

Important invariants:

- `getChunk` calls `ensureUpdatedOnce`; its native lookups must still happen on
  reuse. Camera position alone is not a sufficient cache key.
- `ChunkGround.refresh` uploads pixels into existing textures. Its prefix
  invalidates the owning terrain even when the texture and GPU handle do not
  change. Pending refresh flags also prevent reuse.
- Each terrain owns one pair of destination textures. Switching to a different
  camera neighborhood overwrites them; returning cameras rebuild them. A cache
  hit still binds globals to the current renderer.
- DX12 texture selection calls `Texture.set_lastFrame(driver.frameCount)`.
  Reuse preserves this lifetime for source and destination textures using the
  native setter, including its `PREVENT_AUTO_DISPOSE` handling. It does not
  permanently pin textures or modify the driver's pipeline cache.
- Chunk/object/buffer identities, buffer handles and offsets, texture identities,
  handles/dimensions/formats, output descriptors, engine/driver identity, and
  graphics context loss participate in validation.
- Disposal and disabling the setting release retained references. At most four
  terrain entries are retained. Unexpected cache errors disable only terrain
  reuse and return to the native path.

The native ground-refresh, chunk-lookup, texture-lifetime setter, and renderer
binding routines were also compared between both clients. Static scans of
terrain/soft-terrain field accesses confirmed the source refresh and binding
paths. Tests exercise the production cache with simulated native objects,
including in-place uploads, resource recreation, multiple cameras, missing
chunks, disposal, and error recovery. They do not measure actual GPU/CPU savings
or substitute for rendering tests in the game.
