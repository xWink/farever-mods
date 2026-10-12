import itemutilities.InspectTargets as Targets;
import itemutilities.InspectCommand;

class InspectTargetsTest {
    static var checks = 0;
    static function check(value:Bool, why:String):Void {
        checks++;
        if (!value) throw why;
    }
    static function hero():Dynamic return {removed:false, loadout:{equipment:{content:[]}}};
    static function main():Void {
        var ui:Dynamic = {}, me:Dynamic = {uid:"me"};
        var remote:Dynamic = {uid:"friend", name:"Current hero", hero:hero()};
        for (info in [
            {uid:"friend", name:"Cached name", online:true, player:remote},
            {uid:"friend", name:"Friend in another zone", online:true, player:null},
            {uid:"friend", name:"Offline friend", online:false, player:null}
        ]) {
            var card:Dynamic = {type:"ui.win.PlayerCard", pInfo:info, me:me, ui:ui, removed:false};
            var button:Dynamic = {parent:{parent:card}};
            card.settingsBtn = button;
            var target = Targets.fromSocialButton(button);
            check(target != null && target.ui == ui && target.uid == "friend", "Every social list keeps the exact account UID");
            check(target.name == (info.player == null ? info.name : "Current hero"), "Use live hero name when available");
            check(target.fromSocialWindow, "Confirmed player gear menus allow the offline fallback");
            check(Targets.fromSocialButton({parent:button.parent}) == null, "Other controls on the same card are not player gear menus");
            card.removed = true;
            check(Targets.fromSocialButton(button) == null, "Removed rows cannot supply stale targets");
            card.removed = false;
            info.uid = "me";
            check(Targets.fromSocialButton(button) == null, "Do not add Inspect to the local player's own gear menu");
        }
        check(Targets.fromSocialButton({parent:{type:"ui.win.Inventory"}}) == null, "Unrelated context menus are untouched");
        check(Targets.fromSocialButton(null) == null, "Absent controls are harmless");
        var missing:Dynamic = {type:"ui.win.PlayerCard", pInfo:{name:"Unknown"}, me:me, ui:ui};
        var emptyButton:Dynamic = {parent:missing}; missing.settingsBtn = emptyButton;
        check(Targets.fromSocialButton(emptyButton) == null, "Never resolve an identity by display name alone");

        var local:Dynamic = {player:me};
        me.layer = {players:[remote]};
        me.group = {players:{array:[]}};
        check(Targets.remoteHero(local, "friend") == remote.hero, "Nearby players resolve without interaction distance");
        check(Targets.available(Targets.remoteHero(local, "friend")), "Loaded equipment is inspectable");
        check(Targets.remoteHero(local, "Current hero") == null, "A name is never treated as an account UID");
        me.layer.players = [];
        check(!Targets.available(Targets.remoteHero(local, "friend")), "An absent friend triggers unavailable feedback");
        me.group.players.array = [remote];
        check(Targets.remoteHero(local, "friend") == remote.hero, "Already replicated party equipment is usable");
        remote.hero.removed = true;
        check(Targets.remoteHero(local, "friend") == null, "Removed party heroes cannot be inspected");
        remote.hero = null;
        check(Targets.remoteHero(local, "friend") == null, "Party metadata alone is insufficient");
        remote.hero = hero(); remote.removed = true;
        check(Targets.remoteHero(local, "friend") == null, "Removed party records are rejected");
        remote.removed = false;
        remote.hero.loadout.equipment.content = null;
        check(!Targets.available(Targets.remoteHero(local, "friend")), "Partially loaded equipment is unavailable");
        check(!Targets.available(null), "Offline friends fail cleanly");
        check(!Targets.available({removed:false}), "Missing loadouts fail cleanly");
        check(Targets.remoteHero(null, "friend") == null, "Logging out before clicking is safe");
        check(Targets.remoteHero(local, "") == null, "Empty target UID is rejected");
        commandTargets();
        trace('Inspect targets: $checks checks passed');
    }

    static function commandTargets():Void {
        var ui:Dynamic = {};
        var ally:Dynamic = {uid:"ally", name:"Player Name", hero:hero(), removed:false};
        var me:Dynamic = {uid:"me", name:"My Hero", group:{players:{array:[ally]}},
            layer:{players:{array:[ally]}}, friendList:{friends:[
                {uid:"ally", metadata:{heroName:"Old Name"}},
                {uid:"offline", metadata:{heroName:"Offline Friend"}}
            ]}};
        for (name in ["Player Name", "  pLaYeR nAmE  ", '"Player Name"']) {
            var result = InspectCommand.resolve(ui, me, name);
            check(result.error == "" && result.target.uid == "ally", "Full case-insensitive names resolve with optional quotes");
            check(result.target.ui == ui && result.target.name == "Player Name", "Preserve native UI and live display name");
            check(Targets.remoteHero({player:me}, result.target.uid) == ally.hero, "Command target reaches the existing inspect equipment lookup");
        }
        check(Targets.byName(ui, me, "Player Name").length == 1, "Friend, party and area records deduplicate by account UID");
        check(InspectCommand.resolve(ui, me, "Old Name").target == null, "Cached friend names cannot override live character names");
        check(InspectCommand.resolve(ui, me, "Player").target == null, "Partial names cannot inspect the wrong player");
        check(InspectCommand.resolve(ui, me, "Missing Player").error.indexOf("Player not found") == 0, "Unknown names explain lookup limits");
        for (name in ["", "  ", '""', '"Player Name', '"Player Name" extra'])
            check(InspectCommand.resolve(ui, me, name).error.indexOf("Usage:") == 0, "Missing or malformed arguments show usage");
        check(InspectCommand.resolve(ui, me, "my hero").target == null, "Command follows menu's other-player restriction");
        check(InspectCommand.resolve(null, me, "Player Name").target == null, "Absent UI cannot queue a window");
        check(InspectCommand.resolve(ui, null, "Player Name").target == null, "Absent local player fails cleanly");

        var duplicate:Dynamic = {uid:"other", name:"PLAYER NAME", hero:hero()};
        me.layer.players.array.push(duplicate);
        var ambiguous = InspectCommand.resolve(ui, me, "Player Name");
        check(ambiguous.target == null && ambiguous.error.indexOf("More than one") == 0, "Different accounts with the same name are never guessed");
        duplicate.removed = true;
        check(InspectCommand.resolve(ui, me, "Player Name").target.uid == "ally", "Removed players cannot create false ambiguity");

        var offline = InspectCommand.resolve(ui, me, "Offline Friend");
        check(offline.target.uid == "offline", "Known unavailable friends use the same target as their Social menu");
        check(!Targets.available(Targets.remoteHero({player:me}, offline.target.uid)), "Known identity does not imply equipment is loaded");
        me.layer.players.array = []; me.group.players.array = [];
        check(InspectCommand.resolve(ui, me, "Player Name").target == null, "Previous area names are not retained across commands");
        me.group.players.array = [ally];
        check(InspectCommand.resolve(ui, me, "Player Name").target.uid == "ally", "Party lookup works without a nearby-player record");
        me.group = null; me.layer.players.array = [ally];
        check(InspectCommand.resolve(ui, me, "Player Name").target.uid == "ally", "Nearby-player lookup works without a party");
    }
}
