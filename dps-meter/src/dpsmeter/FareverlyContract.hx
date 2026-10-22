package dpsmeter;

/** Validate detached fight JSON before queueing or sending it. */
class FareverlyContract {
    public static function category(value:String):String return switch (value) {
        case "boss-dungeons": "Boss Dungeons";
        case "classic-dungeons": "Classic Dungeons";
        case "world-bosses": "World Bosses";
        default: "";
    };
    public static function candidate(record:Dynamic):Bool return record != null && GameBranch.recordMayUpload(record) && record.outcome == "Victory"
        && record.targetDummy != true && record.kind != "rift-recap" && Std.isOfType(record.id, String) && record.id != ""
        && Std.isOfType(record.bossKind, String) && StringTools.trim(record.bossKind) != ""
        && ["Classic Dungeons", "Boss Dungeons", "World Bosses"].indexOf(record.category) >= 0;

    public static function validate(record:Dynamic, now:Float):String {
        try {
            if (!candidate(record)) throw "Only completed boss victories qualify.";
            if (record.version != 1 || record.categoryVersion != 2) throw "Unsupported fight/category version.";
            text(record.id, "id", 128);
            for (field in ["name", "gameVersion", "activityId", "bossKind"]) text(Reflect.field(record, field), field);
            for (field in ["me", "meName", "phase"]) if (Reflect.hasField(record, field)) text(Reflect.field(record, field), field, 256, true);
            number(record.startedAt, "startedAt", 8640000000000000.0, true);
            number(record.duration, "duration", 86400);
            if (record.startedAt <= 0 || record.duration <= 0 || record.startedAt + record.duration * 1000 > now * 1000 + 300000)
                throw "Invalid fight start or duration.";
            number(record.partySize, "partySize", 100, true);
            if (record.partySize < 1 || (record.category != "World Bosses" && record.partySize > 4)) throw "Invalid party size.";
            if (record.difficulty != 0 && record.difficulty != 1 && record.difficulty != 2
                && !(record.category == "World Bosses" && record.difficulty == -1)) throw "Missing or unsupported difficulty.";
            var players = list(record.players, "players", 100);
            if (players.length == 0 || (record.category != "World Bosses" && players.length != record.partySize))
                throw "Dungeon logs must include the complete party.";
            var ids:Map<String, Bool> = [], characters:Map<String, Bool> = [];
            var uploaders = 0, total = 0.0;
            for (i in 0...players.length) {
                var player:Dynamic = players[i], path = "players." + i;
                if (player == null) throw path + ": missing player.";
                text(player.uid, path + ".uid"); text(player.name, path + ".name");
                if (ids.exists(player.uid)) throw path + ": duplicate player."; ids[player.uid] = true;
                if (Reflect.hasField(player, "className")) text(player.className, path + ".className", 256, true);
                if (Reflect.hasField(player, "isMe") && !Std.isOfType(player.isMe, Bool)) throw path + ": invalid isMe.";
                for (field in ["accountId", "characterId"]) if (Reflect.field(player, field) != null)
                    text(Reflect.field(player, field), path + "." + field, 128, true);
                if (player.isMe == true || player.uid == record.me) {
                    uploaders++; text(player.accountId, path + ".accountId", 128); text(player.characterId, path + ".characterId", 128);
                }
                if (player.accountId != null && player.accountId != "" && player.characterId != null && player.characterId != "") {
                    var key = haxe.Json.stringify([player.accountId, player.characterId]);
                    if (characters.exists(key)) throw path + ": duplicate character."; characters[key] = true;
                }
                number(player.damage, path + ".damage"); total += player.damage;
                if (Reflect.hasField(player, "heal")) number(player.heal, path + ".heal");
                counts(player, path, ["hits", "crits"], ["kills"]);
                if (player.crits > player.hits) throw path + ": critical hits exceed hits.";
                breakdown(player.damageBreakdown, player.damage, path + ".damageBreakdown");
                var skills = list(player.skills, path + ".skills", 512);
                var skillIds:Map<String, Bool> = [];
                var damage = 0.0, hits = 0.0, crits = 0.0;
                for (j in 0...skills.length) {
                    var skill:Dynamic = skills[j], location = path + ".skills." + j;
                    if (skill == null) throw location + ": missing skill.";
                    text(skill.id, location + ".id", 128);
                    if (skillIds.exists(skill.id)) throw location + ": duplicate skill."; skillIds[skill.id] = true;
                    number(skill.damage, location + ".damage"); counts(skill, location, ["hits", "crits"], ["casts"]);
                    if (skill.crits > skill.hits || (skill.damage > 0 && skill.hits == 0)) throw location + ": invalid hit counts.";
                    if (Reflect.hasField(skill, "damageBreakdown")) breakdown(skill.damageBreakdown, skill.damage, location + ".damageBreakdown");
                    damage += skill.damage; hits += skill.hits; crits += skill.crits;
                }
                equal(damage, player.damage, path + ".skills");
                if (hits != player.hits || crits != player.crits) throw path + ": skill hit counts do not match player totals.";
                if (Reflect.hasField(player, "dps")) {
                    number(player.dps, path + ".dps");
                    if (Math.abs(player.dps - player.damage / record.duration) > Math.max(0.5, player.damage / record.duration * 1e-6))
                        throw path + ": DPS does not use the full fight duration.";
                }
                if (Reflect.hasField(player, "healing")) {
                    var location = path + ".healing", heal:Dynamic = player.healing;
                    healing(heal, location);
                    var output = 0.0;
                    for (skill in list(heal.skills, location + ".skills", 512)) {
                        healing(skill, location + ".skills"); text(skill.id, location + ".skills.id", 128); output += skill.output;
                    }
                    equal(output, heal.output, location + ".skills");
                    if (heal.knownCritHits != null && heal.crits > heal.knownCritHits) throw location + ": critical hits exceed known hits.";
                }
            }
            if (uploaders != 1) throw "The fight needs exactly one identifiable uploader.";
            if (total <= 0) throw "A ranked victory must record damage.";
            return "";
        } catch (error:Dynamic) return "Not eligible: " + Std.string(error);
    }
    static function text(value:Dynamic, path:String, max:Int = 256, empty:Bool = false):Void {
        if (!Std.isOfType(value, String) || (cast value:String).length > max || (!empty && StringTools.trim(value) == ""))
            throw path + ": missing or invalid text.";
    }
    static function number(value:Dynamic, path:String, max:Float = 1e15, integer:Bool = false):Void {
        if (!(Std.isOfType(value, Int) || Std.isOfType(value, Float)) || !Math.isFinite(value)
            || value < 0 || value > max || (integer && value % 1 != 0)) throw path + ": invalid number.";
    }
    static function list(value:Dynamic, path:String, max:Int):Array<Dynamic> {
        if (!Std.isOfType(value, Array) || (cast value:Array<Dynamic>).length > max) throw path + ": invalid list.";
        return value;
    }
    static function counts(value:Dynamic, path:String, required:Array<String>, optional:Array<String>):Void {
        for (field in required) number(Reflect.field(value, field), path + "." + field, 1e9, true);
        for (field in optional) if (Reflect.hasField(value, field)) number(Reflect.field(value, field), path + "." + field, 1e9, true);
    }
    static function equal(a:Float, b:Float, path:String):Void {
        if (Math.abs(a - b) > Math.max(0.01, Math.max(Math.abs(a), Math.abs(b)) * 1e-6))
            throw path + ": recorded breakdown does not match its total (" + a + " vs " + b + ").";
    }
    static function breakdown(value:Dynamic, total:Float, path:String):Void {
        if (value == null) throw path + ": missing damage-type breakdown.";
        var sum = 0.0;
        for (kind in ["physical", "magical", "raw", "unclassified"]) if (Reflect.hasField(value, kind)) {
            var bucket:Dynamic = Reflect.field(value, kind);
            if (bucket == null) throw path + "." + kind + ": missing bucket.";
            number(bucket.damage, path + "." + kind); counts(bucket, path + "." + kind, [], ["hits", "crits"]); sum += bucket.damage;
        }
        equal(sum, total, path);
    }
    static function healing(value:Dynamic, path:String):Void {
        if (value == null) throw path + ": healing must be omitted when unrecorded.";
        number(value.output, path + ".output");
        counts(value, path, ["hits", "crits", "casts"], ["knownCritHits", "estimatedHits", "unknownOutputHits"]);
        if (Reflect.hasField(value, "distribution")) {
            var dist:Dynamic = value.distribution;
            if (dist == null) throw path + ": missing healing distribution.";
            for (field in ["self", "team", "unattributed"]) number(Reflect.field(dist, field), path + ".distribution." + field);
            equal(dist.self + dist.team + dist.unattributed, value.output, path + ".distribution");
        }
    }
}
