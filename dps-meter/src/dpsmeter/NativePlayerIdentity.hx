package dpsmeter;

import dpsmeter.GameAccess as G;

/** Persistent IDs are separate from the spawned hero's hxbit __uid. */
class NativePlayerIdentity {
    public static function accountId(hero:Dynamic):Null<String> {
        // Player.__constructor__ copies HeroData.accountID into this replicated field.
        return identifier(G.field(G.field(hero, "player"), "uid"));
    }

    public static function characterId(hero:Dynamic):Null<String> {
        // HeroData is server-only. FriendList.setFriendMeta explicitly clears
        // metadata.heroId to zero; neither is a reliable remote character source.
        // Never substitute a name, account ID, or network entity ID for a heroID.
        if (hero == null || G.field(G.field(hero, "player"), "isMe") != true) return null;
        try {
            var app = G.staticCall("GameApp", "get", []);
            if (hero != G.field(app, "hero")) return null;
            return identifier(G.field(G.field(app, "connectionInfo"), "heroID"));
        } catch (_:Dynamic) return null;
    }

    static function identifier(value:Dynamic):Null<String> {
        // Format I64 directly, without a Float/Int conversion or lost precision.
        var id = G.text(value);
        return id == "" || id == "0" ? null : id;
    }
}
