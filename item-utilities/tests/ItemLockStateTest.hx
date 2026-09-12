import haxe.Json;
import itemutilities.ItemLockState;

class ItemLockStateTest {
    static var assertions = 0;

    static function check(value:Bool, message:String):Void {
        assertions++;
        if (!value) throw message;
    }

    static function fingerprint(kind:String = "sword"):String {
        return "v4|" + Json.stringify([kind, "0", "[]", "rare", "20", "0", "{}"]);
    }

    static function saved(uid:String = "old", index:Int = 0,
        location:String = "inventory", characterId:String = "db:A", fp:String = null):Dynamic {
        // The persisted config intentionally contains no runtime object or state.
        var record:Dynamic = Json.parse(Json.stringify({uid: uid, index: index,
            location: location, characterId: characterId,
            fingerprint: fp == null ? fingerprint() : fp}));
        record.restored = false;
        record.known = [];
        return record;
    }

    static function item(uid:String, index:Int = 0, location:String = "inventory",
        characterId:String = "db:A", fp:String = null):Dynamic {
        return {uid: uid, index: index, location: location, characterId: characterId,
            fingerprint: fp == null ? fingerprint() : fp, item: {}};
    }

    static function scan(records:Array<Dynamic>, items:Array<Dynamic>, ready:Bool = true,
        characterId:String = "db:A"):Bool {
        var current:Map<String, Dynamic> = new Map();
        for (entry in items) current.set(entry.uid, entry);
        return ItemLockState.reconcile(records, current, characterId, ready);
    }

    static function main():Void {
        var record = saved();
        var moved = item("new", 9);
        check(!scan([record], [moved], false), "Do not restore from partial login data");
        check(record.uid == "old" && !record.restored, "Loading must preserve the saved lock");
        check(scan([record], [moved]), "Restore a moved item on the first ready scan");
        check(record.uid == "new" && record.index == 9 && record.item == moved.item,
            "A login lock follows the item to its new UID and slot");
        check(!scan([record], [moved]), "An unchanged scan must not trigger a config write");

        record = saved("old", 4, "equipment");
        moved = item("new", 17);
        scan([record], [moved]);
        check(record.restored && record.location == "inventory", "Restore across containers at login");

        record = saved();
        var wrong = item("old", 0, "inventory", "db:A", fingerprint("axe"));
        scan([record], [wrong]);
        check(!record.restored && record.fingerprint == fingerprint(),
            "Reused UID and slot must not overwrite the saved fingerprint");
        moved = item("replacement", 3);
        scan([record], [wrong, moved]);
        check(record.item == moved.item, "Find the real item despite a reused UID");

        // Same fingerprints exist in both containers. An early partial view
        // must not steal the equipment lock, even at the saved inventory slot.
        record = saved("old", 2, "equipment");
        var duplicate = item("duplicate", 2);
        var equipped = item("equipped", 2, "equipment");
        scan([record], [duplicate], false);
        check(!record.restored, "Wait for equipment before considering a lone inventory duplicate");
        scan([record], [duplicate, equipped]);
        check(record.item == equipped.item, "Prefer the saved container and slot among duplicates");

        record = saved("old", 20);
        scan([record], [duplicate, equipped]);
        check(!record.restored, "Do not guess when identical items moved and identity is ambiguous");
        for (_ in 0...150) scan([record], []);
        check(!record.restored && record.uid == "old", "Missing locks must never expire");
        scan([record], [moved]);
        check(record.restored, "A missing lock must recover when its unique item appears");

        // Reserve saved slots before fallback, independent of record order.
        for (reverse in [false, true]) {
            var first = saved("first", 40);
            var second = saved("second", 2);
            var records = reverse ? [second, first] : [first, second];
            var a = item("a", 2);
            var b = item("b", 5);
            scan(records, [a, b]);
            check(second.item == a.item && first.item == b.item,
                "Moved fallback must not claim another record's saved-slot match");
        }
        var first = saved("first", 40);
        var second = saved("second", 41);
        scan([first, second], [moved]);
        check(!first.restored && !second.restored, "Two missing locks must not collapse onto one item");
        first = saved("first", 3);
        second = saved("second", 3);
        scan([first, second], [moved]);
        check(!first.restored && !second.restored, "Conflicting saved-slot claims must remain unresolved");

        record = saved();
        var source = item("source");
        scan([record], [source]);
        var split = item("split", 1);
        scan([record], [source, split]);
        scan([record], [split]);
        check(record.uid == "source", "A split-off stack must not take the source's live lock");
        moved = item("transferred", 7, "equipment");
        scan([record], [split, moved]);
        check(record.item == moved.item, "A cloned transfer follows the lock while excluding an old duplicate");
        moved.fingerprint = fingerprint("upgraded");
        check(scan([record], [split, moved]), "Persist upgrades to a confirmed object");
        check(record.fingerprint == moved.fingerprint, "The saved fingerprint follows a live upgrade");

        record = saved();
        var otherCharacter = item("old", 0, "inventory", "db:B");
        scan([record], [otherCharacter], true, "db:B");
        check(!record.restored, "Never restore another character's lock");
        scan([record], [otherCharacter]);
        check(!record.restored, "Reject mismatched ownership even in a mixed snapshot");

        // Reset runtime identities on every actual session/container change;
        // ordinary calls resolving the same hero leave the confirmed lock alone.
        var state = new ItemLockState();
        var hero:Dynamic = {};
        var host:Dynamic = {};
        var inventory:Dynamic = {};
        var equipment:Dynamic = {};
        check(state.updateSession([record], hero, "db:A", host, inventory, equipment),
            "Initialize tracking even if a caller already resolved the hero");
        source = item("source");
        scan([record], [source]);
        check(!state.updateSession([record], hero, "db:A", host, inventory, equipment)
            && record.restored, "Repeated hero lookups must not reset locks");
        check(state.updateSession([record], {}, "db:A", host, inventory, equipment),
            "A recreated hero for the same character begins a new session");
        check(!record.restored && record.item == null && record.known.length == 0,
            "Reset restored state, object references, and duplicate exclusions together");
        // The old UID is allowed again only after the session reset.
        scan([record], [source]);
        check(record.restored, "Stale duplicate exclusions must not block a later login");
        check(state.updateSession([record], null, null, null, null, null)
            && !record.restored, "Logout clears runtime lock ownership");
        state.updateSession([record], hero, "db:A", host, inventory, equipment);
        scan([record], [source]);
        check(state.updateSession([record], hero, "db:B", host, inventory, equipment)
            && !record.restored, "A changed character ID resets tracking even with the same hero reference");
        state.updateSession([record], hero, "db:A", host, inventory, equipment);
        scan([record], [source]);
        check(state.updateSession([record], hero, "db:A", {}, inventory, equipment)
            && !record.restored, "A new network host invalidates runtime identities");
        state.updateSession([record], hero, "db:A", host, inventory, equipment);
        scan([record], [source]);
        check(state.updateSession([record], hero, "db:A", host, {}, equipment)
            && !record.restored, "A replacement inventory invalidates old identities");
        state.updateSession([record], hero, "db:A", host, inventory, equipment);
        scan([record], [source]);
        check(state.updateSession([record], hero, "db:A", host, inventory, {})
            && !record.restored, "Late/replacement equipment invalidates old identities");

        // Legacy configurations are retried after readiness/contents change.
        var legacy = "v3|" + Json.stringify(["sword", "0", "old-affix-uid", "rare", "20", "0", "{}"]);
        record = saved("old", 40, "inventory", "db:A", legacy);
        scan([record], []);
        check(!record.restored && record.fingerprint == legacy, "Missing legacy records remain migratable");
        scan([record], [source]);
        check(record.restored && record.fingerprint == fingerprint(), "Migrate a unique legacy lock after it appears");
        record = saved("old", 0, "inventory", "db:A", "sword|old-format");
        scan([record], [source, split]);
        check(!record.restored, "Kind-only legacy fingerprints must not guess between duplicates");
        scan([record], [source]);
        check(record.restored, "Retry legacy migration once ambiguity is resolved");
        check(!ItemLockState.fingerprintMatches("v3|bad-json", fingerprint()),
            "Malformed legacy data must not crash or match");

        record = saved();
        source = item("source");
        scan([record], [source]);
        var persisted = saved(record.uid, record.index, record.location, record.characterId, record.fingerprint);
        scan([persisted], [item("next-login", 30)]);
        check(persisted.restored && persisted.uid == "next-login" && persisted.index == 30,
            "A saved/restored lock survives another login without runtime fields");
        testManualLocking();
        Sys.println('Item locks: $assertions assertions passed.');
    }

    static function testManualLocking():Void {
        // Same shape as the reported net records; no user/character IDs needed.
        var netFingerprint = 'v4|["Net_Basic","0","[]","0","0","<null>","Rare"]';
        var old = saved("old-net", 71, "inventory", "db:A", netFingerprint);
        var net = item("new-net", 71, "inventory", "db:A", netFingerprint);
        var records:Array<Dynamic> = [old];
        var current:Map<String, Dynamic> = [net.uid => net];
        check(ItemLockState.setLocked(records, current, net, true), "Persist a reused net record's new UID");
        check(records.length == 1 && records[0] == old && old.item == net.item && old.restored,
            "Re-locking updates the saved record instead of appending");
        check(!ItemLockState.setLocked(records, current, net, true) && records.length == 1,
            "Repeated lock requests are idempotent and need no config write");

        var restored = saved(old.uid, old.index, old.location, old.characterId, old.fingerprint);
        var movedNet = item("next-login-net", 75, "inventory", "db:A", netFingerprint);
        scan([restored], [movedNet]);
        check(restored.restored && restored.item == movedNet.item,
            "The reused net record survives the next login at a different slot");
        check(ItemLockState.setLocked(records, current, net, false) && records.length == 0,
            "Unlock removes the reused record rather than leaving a second copy");

        old = saved("old-net", 70, "inventory", "db:A", netFingerprint);
        records = [old];
        current = [movedNet.uid => movedNet];
        ItemLockState.setLocked(records, current, movedNet, true);
        check(records.length == 1 && old.index == 75 && old.uid == movedNet.uid,
            "Reuse an unresolved record when its only eligible item moved slots");

        // A lock click can race the next reconciliation scan. Capture the
        // choice before the scan and apply it afterwards, without toggling.
        old = saved("old-net", 71, "inventory", "db:A", netFingerprint);
        records = [old];
        current = [net.uid => net];
        var requestedLock = old.restored != true;
        ItemLockState.reconcile(records, current, "db:A", true);
        ItemLockState.setLocked(records, current, net, requestedLock);
        check(records.length == 1 && old.restored && old.item == net.item,
            "A lock restored during the click must remain locked");

        // Old duplicates are left for the user to clean up, but re-locking
        // must not keep adding more entries to the reported three-record case.
        records = [for (uid in ["old-1", "old-2", "old-3"])
            saved(uid, 71, "inventory", "db:A", netFingerprint)];
        ItemLockState.setLocked(records, current, net, true);
        check(records.length == 3 && records[2].item == net.item,
            "Reuse the last matching saved-slot entry without growing existing duplicates");
        records = [saved("old-1", 70, "inventory", "db:A", netFingerprint),
            saved("old-2", 74, "inventory", "db:A", netFingerprint)];
        current = [movedNet.uid => movedNet];
        ItemLockState.setLocked(records, current, movedNet, true);
        check(records.length == 2 && records[1].item == movedNet.item,
            "Several stale records for one eligible net must not cause another appended record");

        var ring = item("left-ring", 12, "equipment");
        var otherRing = item("right-ring", 14, "equipment");
        old = saved("old-left-ring", 12, "equipment");
        records = [old];
        current = [ring.uid => ring, otherRing.uid => otherRing];
        ItemLockState.setLocked(records, current, ring, true);
        check(records.length == 1 && old.item == ring.item,
            "The saved slot identifies the selected ring despite an identical second ring");
        ItemLockState.setLocked(records, current, otherRing, true);
        check(records.length == 2 && records[0].item == ring.item && records[1].item == otherRing.item,
            "A confirmed separate identical ring needs its own lock record");
        ItemLockState.setLocked(records, current, ring, false);
        check(records.length == 1 && records[0].item == otherRing.item,
            "Unlocking one ring preserves the other ring's lock");

        // A known split-off/existing twin is a separate item even when the
        // original is temporarily absent and its saved slot is reused.
        old = saved();
        var source = item("source");
        var split = item("split", 1);
        records = [old];
        scan(records, [source, split]);
        split.index = 0;
        current = [split.uid => split];
        ItemLockState.setLocked(records, current, split, true);
        check(records.length == 2 && old.item == source.item && records[1].item == split.item,
            "A known separate twin must not overwrite the missing source's lock");

        // Conversely, a disappearing locked object's unique replacement can
        // reuse its live-session record as well as a record loaded from disk.
        records = [old];
        var replacement = item("replacement", 8);
        current = [replacement.uid => replacement];
        ItemLockState.setLocked(records, current, replacement, true);
        check(records.length == 1 && old.item == replacement.item && old.index == 8,
            "Reuse a live-session record whose old object disappeared");

        old = saved("missing-ring", 20, "equipment");
        records = [old];
        current = [ring.uid => ring, otherRing.uid => otherRing];
        ItemLockState.setLocked(records, current, ring, true);
        check(records.length == 2 && !old.restored && records[1].item == ring.item,
            "Do not guess which unresolved ring record belongs to an ambiguous moved pair");

        old = saved("other-character-net", 71, "inventory", "db:B", netFingerprint);
        records = [old];
        current = [net.uid => net];
        ItemLockState.setLocked(records, current, net, true);
        check(records.length == 2 && !old.restored && old.characterId == "db:B",
            "Re-locking must not reuse another character's saved record");
        old = saved("different-item", 71, "inventory", "db:A", fingerprint("axe"));
        records = [old];
        ItemLockState.setLocked(records, current, net, true);
        check(records.length == 2 && old.fingerprint == fingerprint("axe"),
            "Same slot does not justify reusing a different item's record");

        records = [];
        check(!ItemLockState.setLocked(records, current, movedNet, true) && records.length == 0,
            "A selected item absent from the current snapshot must not create a lock");
    }
}
