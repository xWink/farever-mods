import dpsmeter.Collector;
import dpsmeter.CombatModel;
import dpsmeter.FightHistory;
import dpsmeter.GameAccess as G;
import dpsmeter.MeterConfig;
import dpsmeter.NativePlayerIdentity;

class PlayerIdentityTest {
    static var checks = 0;
    static function check(value:Bool, message:String):Void { checks++; if (!value) throw message; }
    static function hero(entity:String, account:String, mine:Bool):Dynamic return {
        __uid: entity, name: "Same name", inf: {id: "Mage"}, player: {uid: account, isMe: mine}
    };
    static function main():Void {
        var me = hero("entity-1", "account-a", true);
        var other = hero("entity-2", "account-b", false);
        var character = "9007199254740993"; // Above JavaScript's exact integer range.
        var app:Dynamic = {hero: me, connectionInfo: {heroID: character}};
        G.globals["GameApp"] = app;
        var config = MeterConfig.defaults(); config.me = "Same name";
        var collector = new Collector(config);
        var mine = collector.profile(me), remote = collector.profile(other);
        check(mine.accountId == "account-a" && remote.accountId == "account-b",
            "Same-name players export their own replicated account IDs");
        check(mine.characterId == character && remote.characterId == null,
            "The name override cannot give a remote player the local character ID");
        check(mine.uid == "entity-1" && remote.uid == "entity-2",
            "Persistent identity does not replace combat attribution IDs");

        var stats = new PlayerStats(mine);
        var report = haxe.Json.parse(haxe.Json.stringify(stats.json(10)));
        check(report.account_id == "account-a" && report.character_id == character,
            "Uploaded IDs are lossless strings, including 64-bit character IDs");
        var unknown = haxe.Json.parse(haxe.Json.stringify(new PlayerStats(remote).json(10)));
        check(Reflect.hasField(unknown, "character_id") && unknown.character_id == null,
            "Unavailable remote character IDs are explicitly null");

        var fight = new Fight(1); fight.startedAt = 1000; fight.last = 11; fight.closed = 11;
        fight.players[mine.uid] = stats;
        fight.players[remote.uid] = new PlayerStats(remote);
        fight.me = mine.uid;
        var record = FightHistory.encode(fight, "identity-test");
        var restored = FightHistory.decode(haxe.Json.parse(haxe.Json.stringify(record)));
        check(restored.players[mine.uid].info.characterId == character
            && restored.players[mine.uid].info.accountId == "account-a"
            && restored.players[remote.uid].info.characterId == null,
            "Local history preserves known and unavailable identities");
        var imported = FightHistory.decode(FightHistory.legacy(fight.json("now", 1), 20000, "import-test"));
        check(imported.players[mine.uid].info.characterId == character
            && imported.players[remote.uid].info.accountId == "account-b",
            "Importing upload reports preserves persistent IDs");
        for (p in (cast record.players:Array<Dynamic>)) {
            Reflect.deleteField(p, "accountId"); Reflect.deleteField(p, "characterId");
        }
        var legacy = FightHistory.decode(record);
        check(legacy.players[mine.uid].info.accountId == null && legacy.players[mine.uid].info.characterId == null,
            "Old logs load without promoting entity IDs or names into persistent IDs");

        var respawn = hero("entity-3", "account-a", true); respawn.name = "Renamed"; app.hero = respawn;
        check(collector.profile(respawn).characterId == character && collector.profile(respawn).accountId == "account-a",
            "Renames and replacement hero entities keep the account and character identity");
        check(NativePlayerIdentity.characterId(me) == null,
            "An old hero object cannot borrow the current connection's character ID");
        var alt = hero("entity-4", "account-a", true); app.hero = alt; app.connectionInfo.heroID = "9007199254740995";
        var altInfo = collector.profile(alt);
        check(altInfo.accountId == mine.accountId && altInfo.characterId != mine.characterId,
            "Alts on the same account remain separate characters");
        check(report.character_id == character && restored.players[mine.uid].info.characterId == character,
            "Switching characters cannot rewrite a previously captured report");
        app.connectionInfo.heroID = 0;
        check(NativePlayerIdentity.characterId(alt) == null, "An unavailable zero heroID remains null");
        app.connectionInfo = null;
        check(NativePlayerIdentity.characterId(alt) == null, "Missing connection metadata remains null");
        check(NativePlayerIdentity.accountId(hero("entity-5", null, false)) == null,
            "A missing account ID never falls back to the character name or entity ID");
        G.globals.remove("GameApp");
        Sys.println('Persistent player identities: $checks checks passed');
    }
}
