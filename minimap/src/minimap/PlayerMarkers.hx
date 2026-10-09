package minimap;

import minimap.GameAccess as G;

/** Party roster from the local player's group. Matching does not use display names. */
class PlayerMarkers {
    public static inline var COLOR:Int = 0xffc14a;

    public function new() {}

    /** True when `player.group` lists someone other than the local player. */
    public static function hasMembers(player:Dynamic):Bool {
        var group = G.field(player, "group");
        for (member in G.array(G.field(group, "players"), true)) {
            if (member == null || member == player || G.field(member, "isMe") == true) continue;
            return true;
        }
        return false;
    }

    /** Other heroes in `player.group`. The local hero is omitted. */
    public function roster(player:Dynamic, self:Dynamic):Array<Dynamic> {
        var heroes:Array<Dynamic> = [];
        var group = G.field(player, "group");
        for (member in G.array(G.field(group, "players"), true)) {
            if (member == player || G.field(member, "isMe") == true) continue;
            var hero = G.field(member, "hero");
            if (hero == null || hero == self || inParty(hero, heroes)) continue;
            heroes.push(hero);
        }
        return heroes;
    }

    public function inParty(unit:Dynamic, roster:Array<Dynamic>):Bool {
        if (unit == null) return false;
        var unitUid = heroUid(unit);
        for (hero in roster) {
            if (hero == unit) return true;
            var other = heroUid(hero);
            if (unitUid != "" && other == unitUid) return true;
        }
        return false;
    }

    /** On-map markers. Direction arrows are a separate option and can stay on. */
    public static function visible(showPlayers:Bool, hideNonParty:Bool, inParty:Bool):Bool
        return showPlayers && (inParty || !hideNonParty);

    public static function kind(inParty:Bool):String
        return inParty ? "party" : "player";

    /** Roster heroes the client can point toward. Removed and dying heroes are omitted. */
    public function directions(roster:Array<Dynamic>):Array<Dynamic> {
        var heroes:Array<Dynamic> = [];
        for (hero in roster) {
            if (hero == null || G.field(hero, "removed") == true || G.field(hero, "dying") == true) continue;
            var x = G.number(G.field(hero, "posx"), Math.NaN);
            var y = G.number(G.field(hero, "posy"), Math.NaN);
            if (!Math.isFinite(x) || !Math.isFinite(y) || inParty(hero, heroes)) continue;
            heroes.push(hero);
        }
        return heroes;
    }

    /** Same native group check the world UI uses. */
    public static function isPartyMember(hero:Dynamic, other:Dynamic):Bool {
        if (hero == null || other == null || hero == other || G.field(hero, "player") == null) return false;
        return G.call("ent.Hero", "isSameGroup", hero, [other]) == true;
    }

    /** Account friendship from the native friend list, not a display-name match. */
    public static function isFriend(hero:Dynamic, other:Dynamic):Bool {
        if (hero == null || other == null || hero == other) return false;
        var friends = G.field(G.field(hero, "player"), "friendList");
        var uid = G.field(G.field(other, "player"), "uid");
        // Lists can be unavailable briefly while a character is loading.
        if (friends == null || G.field(friends, "friends") == null || uid == null) return false;
        return G.call("st.FriendList", "isFriend", friends, [uid]) == true;
    }

    static function heroUid(value:Dynamic):String
        return G.text(G.field(value, "__uid"));
}
