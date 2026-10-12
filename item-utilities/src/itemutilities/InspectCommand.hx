package itemutilities;

import itemutilities.InspectAccess as G;
import itemutilities.InspectMenuContext.InspectTarget;

/** Resolve a name to the same account-based target used by the Inspect menus. */
class InspectCommand {
    public static function resolve(ui:Dynamic, me:Dynamic, args:String):{target:InspectTarget, error:String} {
        var name = StringTools.trim(args);
        if (StringTools.startsWith(name, '"')) {
            if (name.length < 2 || name.indexOf('"', 1) != name.length - 1)
                return {target:null, error:'Usage: /inspect <name> (or /inspect "Player Name")'};
            name = StringTools.trim(name.substring(1, name.length - 1));
        }
        if (name == "") return {target:null, error:"Usage: /inspect <name>"};
        if (ui == null || me == null) return {target:null, error:"Inspect is not available yet."};
        var matches = InspectTargets.byName(ui, me, name);
        if (matches.length != 1) return {target:null, error:matches.length > 1
            ? "More than one player has that name. Use their Inspect menu to choose them."
            : 'Player not found: $name. They must be in your area, party, or friends list.'};
        var target = matches[0];
        if (target.uid == G.text(G.field(me, "uid"))) return {target:null, error:"Choose another player to inspect."};
        return {target:target, error:""};
    }
}
