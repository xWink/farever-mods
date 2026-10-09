# Bounded freeze diagnostics

Native signatures checked against supplied October 1 Live `hlboot.dat` (HL6),
SHA-256 `617f602066c762869d5c15a01c83714664b0026868f0d24b129bbcc850da88d8`.

| Timing | Native boundary | Return |
| --- | --- | --- |
| Frame body | `hxd.System.mainLoop()` | Void |
| Update | `GameApp.update(Float)` | Void |
| Render | `h3d.Engine.render({render:Engine->Void})` | Bool, passed through |
| Present | `h3d.impl.DX12Driver.present()` | Void |
| Shader source | `h3d.impl.DX12Driver.compileSource(RuntimeShaderData, String, String)` | Bytes object, passed through |
| Frame wait | `h3d.impl.DX12Driver.waitForFrame(Int)` | Void |
| Graphics texture cleanup | `h3d.impl.MemoryManager.cleanTextures(Ref<Bool>)` | Bool, passed through; reference unchanged |
| Worker jobs | Existing `lib.Workers.work()` hook | Void |
| Character model | Existing `client.UnitView.displaySkin()` hook | Void |
| Pipeline replay | Existing `h3d.impl.PSOConfigCache.resolveConfig(CompiledShader)` hook | Void |
| Character component | Existing staged-component construction scope | No new native hook |
| Frame submission | `h3d.impl.DX12Driver.flushFrame(Ref<Bool>)` | Void |
| Pipeline-cache save | `h3d.impl.PSOConfigCache.save()` | Void |
| Next-frame preparation | `h3d.impl.DX12Driver.beginFrame()` | Void |
| DLSS state | `h3d.impl.DX12Driver.refreshDLSSGState()` | Bool, passed through |
| DLSS mode change | `h3d.impl.DX12Driver.setDLSSGMode(DLSSGMode, Ref<Int>, Ref<Bool>)` | Bool, passed through |
| Driver reset | Existing `h3d.impl.DX12Driver.reset()` hook | Void |
| Buffer reset checkpoint | `h3d.impl.BufferAllocator.reset(Ref<Bool>)` | Void; reference unchanged |
| Query readback checkpoint | `h3d.impl.DX12Driver.beginQueries()` | Void |

Hook targets must also be callable through HLX's member resolver. A named
function in the bytecode alone is insufficient: MemoryManager.garbage is an
instance function-valued field, absent from its method prototypes. The original
diagnostics incorrectly targeted it. HLX refused the instance lookup, tried the
static fallback, then skipped that one target while installing the others.
Consequently earlier captures have no reliable graphics-cleanup measurement.
The corrected target cleanTextures is a real prototype method. The default
garbage callback calls it with false, then with true if the first call returns
false. Its Bool return and nullable Ref<Bool> argument are preserved. This
measurement covers texture cleanup, not every possible custom garbage callback.
All other DiagnosticHooks targets were checked against native prototypes or the
static System companion; none are instance callback fields.

`mainLoop` handles platform events, calls the app loop, then presents. Work in
the surrounding event loop is visible as a separate gap before the next measured
frame. `present` includes native frame submission and `waitForFrame`, so its
duration cannot be interpreted as GPU execution time. `compileSource` loads or
compiles source for new shaders; the hotter `compileShader` cache-hit path and
per-draw `flushPipeline` are deliberately not instrumented. Required pipeline
creation can therefore remain inside the broader render timing.

## Version 2: presentation detail

User captures showed a 375 ms frame dominated by 373 ms of rendering, followed
by a 2054 ms frame dominated by 2047 ms of presentation, with `frame-wait`
rounding to zero in both. There were no recorded shader-source, pipeline-replay,
worker or character-loading calls in those two frames. This locates the observed
wall time; it does not identify its underlying cause or rule out mod effects on
graphics work.

In the supplied native code, `present` calls `flushFrame`, platform
`command_queue_present`, optional DLSS state checks/mode changes, `waitForFrame`
and `beginFrame`, and may recover a lost device. `flushFrame` submits GPU command
lists and calls `PSOConfigCache.save`. The latter, when dirty and permitted,
takes a mutex, sorts and serializes the cache, writes a temporary file, deletes
the old file and renames the new one synchronously. `beginFrame` resets command
and buffer allocators and releases queued graphics resources. Version 2 times
these Haxe boundaries; it does not change their arguments, scheduling, locks,
return values or behavior. Native-library Present and marker calls remain within
the broader presentation measurement. An unaccounted presentation stall is not
proof of a particular driver/GPU issue.

`flushFrame` and cache saves can also occur outside `present`, so their totals
are for the entire measured frame, not exclusive presentation subtotals. Nested
save/flush/present times are deliberately not added or subtracted in the report.
Two new synthetic timing cases distinguish a slow cache save from an equally
slow presentation with a fast save and retain separate reset/mode-change timings.

## Version 3: next-frame preparation

The next user capture showed a 438 ms frame (426 ms render) followed two seconds
later by a 1965 ms frame (1960 ms present and 1960 ms begin-frame). Frame wait,
flush-frame and pso-save each rounded to zero. Both captures were outside combat.
This locates the large pause inside beginFrame; it does not prove why it stalled
or establish a causal link to the preceding render stall.

Two additional Haxe method hook pairs partition native beginFrame in order:

| Checkpoint region | Native work between boundaries |
| --- | --- |
| frame-setup | Select current back buffer/frame; reset render command allocator/list; calculate buffer allocator size |
| buffer-reset | BufferAllocator.reset: reset page cursors and dispose excess/old pages |
| frame-recycle | Reset copy command allocator/list; release queued resources; recycle texture/buffer handles and descriptors |
| frame-queries | beginQueries: when needed, map query buffer, collect pending results and unmap |
| frame-tail | Back-buffer transition, primitive topology, render-target setup, descriptor-cache reset, flushHeaps, optional DLSS frame token and Reflex state |

Native BufferAllocator.reset takes Ref<Bool>, defaulting null to false. It keeps
the first page and disposes other pages when unusedFrame > 3600 or forced. Native
beginFrame requests forced trimming when that frame's buffer allocator size is
at least 512 MiB. `buffer-trims` counts the true flags received at the reset
checkpoint; no buffer pages are scanned or memory usage queried by diagnostics.
ScratchHeapArray.reset merely sets a cursor to zero; it gets no separate hook.
There are no per-resource release, allocation or per-draw hooks.

Checkpoints outside a measured beginFrame are ignored. Their state resets with
each main loop; interrupted, recursive or unexpected sequences are incomplete.
All checkpoint operations use the same main-thread/disabled gate as existing
timers. The code neither replaces beginFrame nor delays disposal, weakens GPU
fences, changes native arguments, or adjusts allocation limits. A large recycle
measurement still includes copy-command reset and descriptor work; it is not
proof that resource_release alone was slow. A large tail measurement similarly
does not single out DLSS.

Synthetic tests put a 1960 ms pause in each of the five regions independently,
verify inclusive parent/root totals and retained/reset trim counts, and cover
standalone resets, missing/out-of-order/recursive checkpoints and recovery.
All 90 checks pass in interpreter and HashLink, including background-thread and
disabled bypasses. The local v3 timing-core benchmark was about 1.53 microseconds
per simulated frame (100,000 iterations, fourteen scopes), excluding HLX/native
dispatch. This is not an in-game overhead measurement or a controlled comparison
with the earlier benchmark.

The existing worker/skin/cache hooks start a timer even when their optimization
is off, so A/B comparisons use the same diagnostics. HLX runs postfixes after a
prefix skips native execution too, covering the mod's replacement work. Timings
include nested scopes; root-phase union avoids subtracting them twice. Exceptions
that bypass postfixes are marked incomplete or discarded on the next frame.
Other mods' hook order may affect which enclosing scope includes their work.

All samples are restricted to the main-loop thread before reading the clock or
mutating shared timing data. Threaded compilation continues without touching the
buffer. Only a few frame-level and rare-operation hooks are added. Collection
reuses fixed numeric arrays and 32 records; no names, scene scans, stacks or heap
dumps are collected. HLX dispatch itself may allocate and is not claimed to be
free. No GC configuration, native scheduling, return value or rendering decision
is changed by diagnostics.

Gameplay/focus/combat state is read during the normal GameApp update. Two stable
seconds are required before capture. Records of >=500 ms frame body or inter-loop
gap retain their original timestamp, combat flag and optimization flag. Overflow
keeps the newest records and increments a visible counter. Formatting and normal
mod-log output happen only after two seconds of quiet, focused gameplay outside
combat, one record per second. Output failure disables diagnostics. Their own
deferred output time is excluded from the next measured gap. World disposal
suspends collection without writing during a loading transition; process exit or
turning off diagnostics discards any unreported records.

`FrameMetricsTest` passes on interpreter and HashLink. It exercises nested and
recursive scopes, retained snapshots, interval versus body timing, quiet/combat
and loading gates, capacity/rate limits, output-delay exclusion, incomplete
scopes, session boundaries, disabled timers and a real background-thread bypass.
An optional `--bench` measures only the in-memory timing core. The local v2
HashLink run took approximately 2.54 microseconds per simulated frame across
100,000 iterations with nine timed scopes; it excludes HLX dispatch and native
context lookups, and is not an in-game overhead measurement.

The metric locates elapsed time, not necessarily its cause. Implicit HashLink GC,
OS preemption, native locks, disk and GPU waits may contribute inside any measured
scope. A remaining unmeasured gap must not be labeled as GC without more evidence.

## Version 4: cleanup decisions and waits

The October 5 samples again spent about 1,957 ms inside `frame-recycle` despite
`optimization=true`. That flag is the setting, not confirmation of offloading.
The release worker's pressure fallback can join in this region, as can the DXGI
memory query and the remaining native command/resource/descriptor operations.

No new native hooks are installed. The existing allocator postfix starts a
`recycle-native` scope after the cleanup callback returns; the existing
beginQueries prefix closes it. `cleanup-hook`, `cleanup-memory`, `cleanup-join`
and `cleanup-publish` time the mod's own boundaries. Timings stay inclusive:
`cleanup-memory` and pressure joins overlap `cleanup-hook`; none should be summed
with their parents. Join reasons distinguish pressure, lifecycle and error waits.

A preallocated CleanupSample is reset each frame and copied into the same
32-entry ring only on a captured >=500 ms stall. It records all observed outcome
flags, totals of inspected native queues and transferred/submitted references,
maximum pending count observed before decisions (including an empty current
queue), and the most recent memory sample and sample count in that frame.
`unobserved`/`unknown` distinguish missing observations from zero. These are
main-thread observations, not worker execution time or exact retained bytes.
Staged means removed from native ownership; submitted means publication succeeded.

There are no additional DXGI queries, per-resource timers, worker-thread log
writes, disk output or strings allocated during collection. With diagnostics
on, empty queues also sample the existing short pending-count mutex. Normal
memory guards, fallback, reference ownership and worker publication order remain
unchanged. Output still waits for quiet gameplay outside combat.

Tests simulate identical 1,957 ms delays in memory-query, worker-wait and native
recycle scopes; retain outcome snapshots through subsequent quiet frames; reset
unknown values; aggregate multiple queues; gate foreign threads and disabled
diagnostics; and run the real cleanup scheduler's offload, pressure, unknown
memory, cap, disabled, failed and in-flight-empty-queue paths. Query exceptions
close scopes and preserve native ownership. Windows GPU attribution still
requires the user's gameplay sample; these tests do not reproduce their driver.


## Version 5: rendering detail and allocation context

Verified against the October 7 Live HL6 upload, SHA-256
`5f288029b34682fa63d22e90000cb8ff91d23d08fbacc965952a799ba92e452f`.
The bytecode reader needed its HL6 debug-assignment third field and Catch
global operand support corrected; structure validation then succeeded. Native
signatures were checked from that client's functions and prototype/static
companion bindings.

| Scope/boundary | Native signature | Handling |
| --- | --- | --- |
| engine-begin | h3d.Engine.begin() -> Bool | Return unchanged |
| engine-end | h3d.Engine.end() -> Void | Continue |
| scene-3d | h3d.scene.Scene.render(Engine) -> Void | Start/end named-stage stack |
| scene-2d | h2d.Scene.render(Engine) -> Void | Continue |
| named stages | client.Renderer.mark(String) -> Void | Observe existing label; continue |
| render-passes | h3d.scene.Renderer.process(ArrayObj) -> Void | renderer-setup / scene-tail markers |
| pipeline-create | static DX12Driver.makePipeline(CompiledShader, PipelineBuilder) -> abstract | Dynamic pass-through preserves the game's abstract identity |
| pbr-begin / pbr-end | client.Renderer.beginPbr() / endPbr() -> Void | Continue |
| lighting | client.Renderer.lighting() -> Void | Continue |
| dlss-render | client.Renderer.dlss() -> Void | Continue |
| reserved-memory | client.Renderer.updateReservedMem() -> Void | Continue |

Scene.mark is a callback field and must not be hooked. Its default forwards to
the renderer's real mark method. Scene.render emits sync/emit markers, and the
client override is called even without the game's benchmark enabled. The marker
prefix neither replaces the callback nor changes the native benchmark. Other
renderers or overridden callbacks may provide fewer markers; enclosing scene
and process scopes still measure their time.

makePipeline is static (no instance argument). It runs on required cache misses
or optional warmup and ends with native graphics-pipeline creation. The main-thread
gate excludes worker compilation. Arguments, return object/null, exceptions and
ownership are preserved; no pipeline is retained. Waits before entering the method
are outside its timer. No hooks are added to flushPipeline, compileShader, scene
syncRec/emitRec, resource allocation or individual draw calls.

RenderStages uses 48 fixed slots and an eight-level scene stack. Existing immutable
marker string references are retained in bounded records; no names are constructed
while collecting. Nested scenes pause the parent interval. Repeated labels
aggregate time and retain maximum interval/count. Output sorts after quiet,
out-of-combat gameplay and prints the top four totals. Marker/depth overflow is
visible as dropped; unmatched scene postfixes mark the frame incomplete. Intervals
include all work until the next marker, not only a named draw call.

RenderAllocations reads std.gc_stats directly, avoiding the object allocated by
hl.Gc.stats(). Only outer Engine.render calls are paired. Separate render deltas
are summed, excluding allocations between them. Counters include worker and hook
dispatch allocations. The native reports cumulative allocation bytes/count and
managed heap pages; it does not expose collection count/duration. No GC flags,
collection behavior, GPU queries, tracing, stacks or heap dumps are changed/added.
Missing pairs/counter resets stay unknown. Allocation activity is not GC attribution.

The 500 ms threshold, 32-record ring, focused-gameplay gate, deferred noncombat
output and one-record-per-second drain are unchanged. Tests cover a 750 ms pipeline
creation inside the character stage; equally slow UI/DLSS/lighting/reserved-memory/
PBR work without pipeline calls; nested scenes/renders; overflow; missing postfix
recovery; retained/reset snapshots; disabled/foreign-thread gates; and real HL
allocation-counter reads. Interpreter: 169 checks. HashLink: 173 checks. The
v5 timing-core benchmark with 30 markers and native counter sampling measured
about 8.86 microseconds/frame (100,000 iterations), excluding HLX dispatch and
native context lookups. This is not in-game overhead or a controlled v4 comparison.
