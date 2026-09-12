package itemutilities;

import haxe.Json;

/** Lock identity and session state, independent of the game/UI bindings. */
class ItemLockState {
    public static inline var FINGERPRINT_VERSION = "v4|";

    public var hero(default, null):Dynamic;
    public var characterId(default, null):String;
    var host:Dynamic;
    var inventory:Dynamic;
    var equipment:Dynamic;

    public function new() {}

    public function updateSession(records:Array<Dynamic>, nextHero:Dynamic,
        nextCharacterId:String, nextHost:Dynamic, nextInventory:Dynamic,
        nextEquipment:Dynamic):Bool {
        if (hero == nextHero && characterId == nextCharacterId && host == nextHost
            && inventory == nextInventory && equipment == nextEquipment)
            return false;
        hero = nextHero;
        characterId = nextCharacterId;
        host = nextHost;
        inventory = nextInventory;
        equipment = nextEquipment;
        // These identities belong to one materialized loadout only. UI
        // initialization and hero lookups must never bypass this reset.
        for (record in records) {
            record.restored = false;
            record.item = null;
            record.known = [];
        }
        return true;
    }

    /** Apply an explicit UI choice without appending a second identity for it. */
    public static function setLocked(records:Array<Dynamic>, current:Map<String, Dynamic>,
        tracked:Dynamic, locked:Bool):Bool {
        if (tracked == null || tracked.uid == null || tracked.item == null
            || tracked.characterId == null || tracked.fingerprint == null
            || current.get(tracked.uid) != tracked)
            return false;

        var knownByFingerprint:Map<String, Array<Dynamic>> = new Map();
        knownByFingerprint.set(tracked.fingerprint,
            matchingUids(current, tracked.fingerprint, tracked.characterId));
        var claimed:Map<String, Bool> = new Map();
        for (record in records) {
            if (!isConfirmed(record, current) || record.characterId != tracked.characterId)
                continue;
            if (record.item == tracked.item) {
                if (!locked) return records.remove(record);
                // Reconciliation may have restored it after the user clicked
                // an unlocked icon. Keep their original choice, not a toggle.
                return confirm(record, tracked, knownByFingerprint);
            }
            claimed.set(record.uid, true);
        }
        if (!locked) return false;

        var savedSlot:Dynamic = null;
        var unique:Dynamic = null;
        for (record in records) {
            if (record.characterId != tracked.characterId || record.location == "bank"
                || record.fingerprint != tracked.fingerprint || isConfirmed(record, current))
                continue;
            var matches = candidates(record, current, claimed);
            if (matches.indexOf(tracked) < 0) continue;
            if (isSavedSlot(record, tracked)) savedSlot = record;
            if (matches.length == 1) unique = record;
        }
        // The selected item is explicit. Prefer its saved slot, otherwise a
        // record with only this eligible live item. If old duplicate records
        // exist, reuse the last applicable one without deleting other records.
        var record:Dynamic = savedSlot != null ? savedSlot : unique;
        var added = record == null;
        if (added) {
            record = {characterId: tracked.characterId};
            records.push(record);
        }
        var changed = confirm(record, tracked, knownByFingerprint);
        return added || changed;
    }

    static function isConfirmed(record:Dynamic, current:Map<String, Dynamic>):Bool {
        var live = current.get(record.uid);
        return record.restored == true && record.item != null && live != null
            && live.characterId == record.characterId && live.item == record.item;
    }

    public static function reconcile(records:Array<Dynamic>, current:Map<String, Dynamic>,
        characterId:String, ready:Bool):Bool {
        if (!ready || characterId == null)
            return false;

        var changed = false;
        var claimed:Map<String, Bool> = new Map();
        var knownByFingerprint:Map<String, Array<Dynamic>> = new Map();
        for (entry in current) {
            if (entry.characterId != characterId) continue;
            var known = knownByFingerprint.get(entry.fingerprint);
            if (known == null) {
                known = [];
                knownByFingerprint.set(entry.fingerprint, known);
            }
            known.push(entry.uid);
        }
        var pending:Array<Dynamic> = [];
        for (record in records) {
            if (record.characterId != characterId || record.location == "bank")
                continue;
            var exact = current.get(record.uid);
            // Only a confirmed object from this session may change its
            // fingerprint (e.g. an upgrade). Disk UIDs can be reused at login.
            if (exact != null && exact.characterId == characterId
                && record.restored == true && record.item != null
                && record.item == exact.item && !claimed.exists(exact.uid)) {
                if (confirm(record, exact, knownByFingerprint)) changed = true;
                claimed.set(exact.uid, true);
            } else {
                pending.push(record);
            }
        }

        // Reserve saved-slot matches for every record before considering
        // moved items, so record iteration order cannot steal another lock.
        var proposals:Array<{record:Dynamic, item:Dynamic}> = [];
        var counts:Map<String, Int> = new Map();
        for (record in pending) {
            var matches = candidates(record, current, claimed);
            var replacement:Dynamic = null;
            for (candidate in matches) {
                // The oldest fingerprints only contain the item kind. They
                // are safe to migrate only when the whole match is unique.
                if (isSavedSlot(record, candidate)
                    && (isDetailed(record.fingerprint) || matches.length == 1)) {
                    replacement = candidate;
                    break;
                }
            }
            if (replacement != null) {
                proposals.push({record: record, item: replacement});
                var count = counts.get(replacement.uid);
                counts.set(replacement.uid, count == null ? 1 : count + 1);
            }
        }
        var resolved:Array<Dynamic> = [];
        for (proposal in proposals) {
            if (counts.get(proposal.item.uid) != 1) continue;
            if (confirm(proposal.record, proposal.item, knownByFingerprint)) changed = true;
            claimed.set(proposal.item.uid, true);
            resolved.push(proposal.record);
        }
        pending = [for (record in pending) if (resolved.indexOf(record) < 0) record];

        // Both containers are loaded. A unique remaining item can now follow
        // its lock across slot/container changes, including the first login
        // scan. Require a unique record too; never collapse two locks to one.
        proposals = [];
        counts = new Map();
        for (record in pending) {
            var matches = candidates(record, current, claimed);
            for (candidate in matches) {
                var count = counts.get(candidate.uid);
                counts.set(candidate.uid, count == null ? 1 : count + 1);
            }
            if (matches.length == 1)
                proposals.push({record: record, item: matches[0]});
        }
        for (proposal in proposals) {
            if (counts.get(proposal.item.uid) != 1) continue;
            if (confirm(proposal.record, proposal.item, knownByFingerprint)) changed = true;
            claimed.set(proposal.item.uid, true);
        }
        // Missing/ambiguous records remain saved and are retried next scan.
        return changed;
    }

    static function candidates(record:Dynamic, current:Map<String, Dynamic>,
        claimed:Map<String, Bool>):Array<Dynamic> {
        var result:Array<Dynamic> = [];
        var known:Array<Dynamic> = record.known;
        for (candidate in current) {
            if (candidate.characterId != record.characterId || claimed.exists(candidate.uid)
                || !fingerprintMatches(record.fingerprint, candidate.fingerprint))
                continue;
            // Split-off/existing identical items cannot steal a live lock.
            if (record.restored == true && known != null && known.indexOf(candidate.uid) >= 0)
                continue;
            result.push(candidate);
        }
        return result;
    }

    static function confirm(record:Dynamic, item:Dynamic,
        knownByFingerprint:Map<String, Array<Dynamic>>):Bool {
        var changed = record.uid != item.uid || record.fingerprint != item.fingerprint
            || record.location != item.location || record.index != item.index;
        record.uid = item.uid;
        record.fingerprint = item.fingerprint;
        record.location = item.location;
        record.index = item.index;
        record.restored = true;
        record.item = item.item;
        record.known = knownByFingerprint.get(item.fingerprint);
        return changed;
    }

    public static function matchingUids(current:Map<String, Dynamic>, fingerprint:String,
        characterId:String):Array<Dynamic> {
        return [for (item in current)
            if (item.characterId == characterId && item.fingerprint == fingerprint) item.uid];
    }

    static function isSavedSlot(record:Dynamic, item:Dynamic):Bool {
        return record.location == item.location && record.index == item.index;
    }

    static function isDetailed(fingerprint:String):Bool {
        return fingerprint != null && (StringTools.startsWith(fingerprint, FINGERPRINT_VERSION)
            || StringTools.startsWith(fingerprint, "v2|")
            || StringTools.startsWith(fingerprint, "v3|"));
    }

    public static function fingerprintMatches(saved:String, current:String):Bool {
        if (saved == null || current == null) return false;
        if (saved == current) return true;
        if (StringTools.startsWith(saved, FINGERPRINT_VERSION)) return false;
        return legacyFingerprintMatchesEncoded(saved, current);
    }

    public static function legacyFingerprintMatchesEncoded(saved:String, encoded:String):Bool {
        if (saved == null || encoded == null) return false;
        try {
            if (!StringTools.startsWith(encoded, FINGERPRINT_VERSION)) return false;
            var currentParts:Array<Dynamic> = cast Json.parse(encoded.substr(FINGERPRINT_VERSION.length));
            if (currentParts == null || currentParts.length < 7) return false;
            if (StringTools.startsWith(saved, "v2|") || StringTools.startsWith(saved, "v3|")) {
                var savedParts:Array<Dynamic> = cast Json.parse(saved.substr(3));
                if (savedParts == null || savedParts.length < 7) return false;
                for (index in [0, 1, 3, 4, 5, 6])
                    if (Std.string(savedParts[index]) != Std.string(currentParts[index])) return false;
                if (StringTools.startsWith(saved, "v2|") && savedParts.length >= 8
                    && Std.string(savedParts[7]) != Std.string(currentParts[2])) return false;
                return true;
            }
            var separators = saved.split("|");
            return separators.length > 0 && separators[0] == Std.string(currentParts[0]);
        } catch (_:Dynamic) {
            return false;
        }
    }
}
