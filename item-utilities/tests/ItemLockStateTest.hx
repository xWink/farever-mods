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
        Sys.println('Item locks: $assertions assertions passed.');
    }
}
