import itemutilities.InspectTargets as Targets;

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
        var stackGear:Dynamic = {stacks:[]};
        var stackHero:Dynamic = {loadout:{equipment:stackGear}};
        check(Targets.available(stackHero), "Replicated stack-based equipment remains inspectable");
        check(Targets.equipment(stackHero) == stackGear, "Inspect uses the same stack-based equipment as the menu check");
        var nativeGear:Dynamic = {content:[]};
        var nativeHero:Dynamic = {equipment:nativeGear};
        check(Targets.available(nativeHero), "The native equipment accessor remains an Inspect fallback");
        check(Targets.equipment(nativeHero) == nativeGear, "Inspect reads the equipment accepted by the menu check");
        check(Targets.available({weapon1:{kind:"Sword"}}), "A replicated main weapon can open Inspect");
        check(Targets.available({weapon2:{kind:"Bow"}}), "A replicated arsenal weapon can open Inspect");
        check(!Targets.available({removed:true, equipment:nativeGear, weapon1:{kind:"Sword"}}),
            "Removed heroes stay unavailable even with cached equipment");
        check(!Targets.available(null), "Offline friends fail cleanly");
        check(!Targets.available({removed:false}), "Missing loadouts fail cleanly");
        check(Targets.remoteHero(null, "friend") == null, "Logging out before clicking is safe");
        check(Targets.remoteHero(local, "") == null, "Empty target UID is rejected");
        trace('Inspect targets: $checks checks passed');
    }
}
