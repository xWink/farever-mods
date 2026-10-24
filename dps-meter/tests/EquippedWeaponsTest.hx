import dpsmeter.Collector;
import dpsmeter.CombatModel;
import dpsmeter.EquippedWeapons;
import dpsmeter.FareverlyContract;
import dpsmeter.FightHistory;
import dpsmeter.GameAccess as G;
import dpsmeter.MeterConfig;
import dpsmeter.NativeWeapons;
import dpsmeter.RiftRecapHistory;
#if !hl
import dpsmeter.LogUploader;
import sys.FileSystem;
import sys.io.File;
#end

@:access(dpsmeter.Collector)
#if !hl
@:access(dpsmeter.LogUploader)
#end
class EquippedWeaponsTest {
    static var checks = 0;
    static function check(value:Bool, message:String):Void { checks++; if (!value) throw message; }
    static function item(kind:String, rarity:String, level:Int, upgrade:Int):Dynamic return {
        kind: kind, inf: {rarity: rarity, requiredLevel: level}, level: 999, upgradeLevel: upgrade
    };
    static function hero(uid:String, mine:Bool):Dynamic return {
        __uid: uid, name: uid, inf: {id: "Mage"}, player: {uid: "account-" + uid, isMe: mine},
        loadout: {equipment: {content: [], slots: {
            Slot_Weapon1: item(uid + "-primary", "Epic", 30, 3),
            Slot_OffhandWeapon: item(uid + "-secondary", "Rare", 25, 1),
            Slot_Weapon2: item(uid + "-arsenal", "Uncommon", 20, 2)
        }}}
    };
    static function event(uid:String, healing:Bool = false):DamageEvent return {
        time: 12, source: uid, amount: 100, critical: false, kill: false, effect: healing ? 1 : 0,
        skill: healing ? "Heal" : "Attack", target: "boss", bossKind: "Boss", bossFlags: 16,
        bossLevel: 30, bossFoeId: 1, damageType: "magical"
    };
    static function row(record:Dynamic, uid:String):Dynamic {
        for (p in (cast record.players:Array<Dynamic>)) if (p.uid == uid) return p;
        throw "Missing player " + uid;
    }
    #if !hl
    static function files(path:String):Array<String> {
        var out:Array<String> = [];
        for (name in FileSystem.readDirectory(path)) {
            var child = path + "/" + name;
            if (FileSystem.isDirectory(child)) out = out.concat(files(child)); else out.push(child);
        }
        return out;
    }
    static function remove(path:String):Void {
        if (FileSystem.isDirectory(path)) {
            for (name in FileSystem.readDirectory(path)) remove(path + "/" + name);
            FileSystem.deleteDirectory(path);
        } else FileSystem.deleteFile(path);
    }
    #end
    static function main():Void {
        var me = hero("me", true), other = hero("other", false), healer = hero("healer", false);
        me.weaponInHand = me.loadout.equipment.slots.Slot_Weapon2;
        other.weaponInHand = null; // Sheathed weapons must still be recorded.
        G.globals["GameApp"] = {hero: me, connectionInfo: {heroID: "9007199254740993"}};
        var collector = new Collector(MeterConfig.defaults());
        var mine = collector.profile(me), remote = collector.profile(other), healing = collector.profile(healer);
        for (info in [mine, remote, healing]) {
            var w = info.equippedWeapons;
            check(w != null && w.primary.kind == info.uid + "-primary"
                && w.secondary.kind == info.uid + "-secondary" && w.arsenal.kind == info.uid + "-arsenal",
                "Local and remote slots are captured independently of the held weapon");
            check(w.primary.rarity == "Epic" && w.primary.requiredLevel == 30 && w.primary.upgradeLevel == 3,
                "Rarity, equip requirement and upgrades use native metadata, not hidden level");
        }
        check(collector.profile(me) == mine, "Repeated hits reuse the 250 ms profile cache");
        var fight = new Fight(10, "0.3.0.test", "MAIN");
        fight.recordingComplete = true;
        fight.me = "me"; fight.startedAt = 100000; fight.closed = 20;
        fight.category = "World Bosses"; fight.bossKind = "Boss"; fight.bossName = "Boss"; fight.activityId = "BossActivity";
        fight.partySize = 3; fight.difficulty = -1; fight.outcome = "Victory";
        fight.add(event("me"), mine); fight.add(event("other"), remote); fight.add(event("healer", true), healing);
        var first = fight.players["me"].equippedWeapons;
        fight.add(event("me"), mine);
        check(first == fight.players["me"].equippedWeapons, "Each damage tick does not allocate another loadout snapshot");
        check(fight.players["healer"].equippedWeapons.arsenal.kind == "healer-arsenal"
            && fight.players["healer"].weapons.length == 0 && fight.players["healer"].hits == 0,
            "Healing-only players include every equipped slot without adding damage or weapons_seen");
        var record = FightHistory.encode(fight, "weapons-test");
        var json = haxe.Json.parse(haxe.Json.stringify(record));
        check(row(json, "other").equippedWeapons.arsenal.kind == "other-arsenal", "The actual saved JSON includes remote arsenal items");
        var uploadRecord = haxe.Json.parse(haxe.Json.stringify(record));
        uploadRecord.players = (cast uploadRecord.players:Array<Dynamic>).filter(p -> p.uid != "healer");
        uploadRecord.partySize = 2;
        var reason = FareverlyContract.validate(uploadRecord, 1000);
        check(reason == "", "The upload contract accepts weapon metadata: " + reason);
        #if !hl
        // Exercise disk/queue integration in the interpreter; the HL run also
        // checks native JSON/virtual-object conversions without media plugins.
        var root = "build/equipped-weapons-test-" + Std.random(0x3fffffff);
        var uploader = new LogUploader(root);
        uploader.archive(uploadRecord, true); uploader.flush();
        var saved = files(root).filter(path -> StringTools.endsWith(path, ".json") && !StringTools.endsWith(path, ".state.json"));
        var historyPath = "", queuePath = "";
        for (path in saved) {
            var data = haxe.Json.parse(File.getContent(path));
            if (data.id != "weapons-test") continue;
            if (path.indexOf("/fareverly/") >= 0) queuePath = path;
            else if (path.indexOf("/history/") >= 0) historyPath = path;
        }
        check(historyPath != "" && queuePath != "", "Both history and upload files are written");
        check(File.getContent(historyPath) == File.getContent(queuePath)
            && row(haxe.Json.parse(File.getContent(queuePath)), "other").equippedWeapons.secondary.kind == "other-secondary",
            "The complete equipped loadout reaches disk and the Fareverly queue unchanged");
        remove(root);
        #end
        var restored = FightHistory.decode(json);
        check(restored.players["me"].equippedWeapons.secondary.kind == "me-secondary", "Local history reload retains the slots");
        var recap = RiftRecapHistory.encode({gate: fight.copy(), boss: fight.copy()}, "recap");
        check(row(recap.gate, "me").equippedWeapons.primary.kind == "me-primary"
            && row(recap.boss, "other").equippedWeapons.arsenal.kind == "other-arsenal", "Both rift recap phases include weapons");

        var snapshot = fight.copy();
        me.loadout.equipment.slots.Slot_Weapon2 = item("replacement", "Rare", 40, 4);
        me.loadout.equipment.slots.Slot_OffhandWeapon = null;
        collector.profileRefresh["me"] = -1;
        var replacement = collector.profile(me);
        fight.recordCast(replacement, "Attack", 1);
        check(fight.players["me"].equippedWeapons.arsenal.kind == "replacement"
            && fight.players["me"].equippedWeapons.secondary == null, "Casts refresh changed arsenal and newly empty slots");
        check(snapshot.players["me"].equippedWeapons.arsenal.kind == "me-arsenal"
            && row(record, "me").equippedWeapons.arsenal.kind == "me-arsenal",
            "Changing equipment cannot rewrite a closed fight or a queued report");
        replacement.equippedWeapons.arsenal.kind = "mutated-profile";
        check(fight.players["me"].equippedWeapons.arsenal.kind == "replacement", "Fight snapshots own detached item records");
        row(json, "me").equippedWeapons.secondary.kind = "mutated-json";
        check(restored.players["me"].equippedWeapons.secondary.kind == "me-secondary", "Decoded history owns detached item records");

        me.loadout = null; collector.profileRefresh["me"] = -1;
        fight.add(event("me"), collector.profile(me));
        check(fight.players["me"].equippedWeapons.arsenal.kind == "replacement", "Missing replication preserves last observed equipment");
        var empty = hero("empty", false); empty.loadout.equipment.slots = {};
        var emptyLoadout = NativeWeapons.capture(empty);
        check(emptyLoadout != null && emptyLoadout.primary == null && emptyLoadout.secondary == null
            && emptyLoadout.arsenal == null, "Known empty slots are distinct from unavailable equipment");
        empty.loadout.equipment.unavailable = true;
        check(NativeWeapons.capture(empty) == null, "Native reads that fail do not fabricate empty slots or interrupt combat");
        empty.loadout.equipment.content = null;
        check(NativeWeapons.capture(empty) == null && NativeWeapons.capture(null) == null, "Unloaded equipment remains unknown");
        for (p in (cast json.players:Array<Dynamic>)) Reflect.deleteField(p, "equippedWeapons");
        check(FightHistory.decode(json).players["me"].equippedWeapons == null, "Older logs without equipment continue to load");
        var legacy = FightHistory.legacy(snapshot.json("now", 1), 200000, "legacy");
        check(FightHistory.decode(legacy).players["me"].equippedWeapons.arsenal.kind == "me-arsenal", "Legacy export/import preserves labeled slots");
        G.globals.remove("GameApp");
        Sys.println('Equipped weapon logs: $checks checks passed');
    }
}
