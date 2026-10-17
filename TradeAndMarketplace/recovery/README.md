# Recovery record

The original Haxe source and commit were unavailable. `reference.zip` preserves
exactly the last surviving October 14 status-spacing build. See `provenance.json`
for its SHA-256 and original commit ID. This archive is a reference fixture only;
Actions packages newly compiled source from `src/`, never this archive.

The recovery checkpoint retained the original `trade` module name and config paths.
The current build installs as `trade-and-marketplace` at the author's request.
The recovered source preserves the whisper protocol, offer hashes, acceptance handshake, inventory confirmations,
movement controls and native UI integration. UI framing is factored into
`TradeFrame` instead of duplicating it between the two windows. Source comments,
original formatting, and original tests cannot be recovered from bytecode.

Validation performed for the recovery checkpoint:

- Haxe 4.3.7 production compilation succeeds.
- 6,110 differential checks execute original protocol/session methods directly
  from the reference bytecode: offer and preview hashing, fragmented whispers,
  invitation/join/ack/ready/prepare/commit, duplicate delivery, changes after
  acceptance, cancellation locks, receipts and watchdog deadlines.
- 12 protocol assertions and 17 simulated native exchange assertions cover
  partial cloned stacks, no duplicate drop requests, RPC failure, delayed
  inventory replication, exact ground item matching, movement targets, scoped
  pickup authorization, timeout and stale callbacks.
- 104 named native members were checked against the supplied October 15 game
  metadata. The original optional `Data.infusion` lookup is absent there; its
  existing null fallback displays the infusion ID. No other lookup was missing.

The differential harness removes only HLX registration/startup from a temporary
copy of the reference binary. Tested business methods remain unchanged. A
separate disposable HashLink runtime returns reference classes without patching
methods in the test module. Foreign arrays are constructed by the reference
module's JSON parser; this prevents cross-module array casting errors from
invalidating the comparison. See the Actions workflow for reproducible commands.

This is a source reconstruction, not a byte-for-byte recreation of the lost
source. The author has visually checked the stacked trade window in game. Native
callback wiring, collision and actual two-player RPC behavior still require
in-game testing. Automated checks are not a substitute
for that validation. No release is created by this workflow.

Current regression coverage also includes 16 controller/inventory checks for
locked-item rejection (right-click and drag), locks added after offering, red
chat errors, green completion, and the readable invitation sent by the controller.
The exchange suite now has 18 checks, including a lock added after acceptance
preventing any drop request. The removed solo preview has no hotkey, settings,
controller branches or test fixtures left in the current source.
