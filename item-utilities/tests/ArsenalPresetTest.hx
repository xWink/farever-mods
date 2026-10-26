import itemutilities.ArsenalPresetPlan as Plan;
import itemutilities.ArsenalPresetTransfer;
import itemutilities.NativeArsenal;
import itemutilities.InspectAccess as G;

class ArsenalPresetTest {
    static var checks = 0;
    static function check(value:Bool, message:String):Void {
        checks++;
        if (!value) throw message;
    }
    static function rejects(action:Void->Void, message:String):Void {
        var rejected = false;
        try action() catch (_:Dynamic) rejected = true;
        check(rejected, message);
    }
    static function main():Void {
        var choices = [{weapon:"Bow", skills:["Shot", "BowPassive"]}, {weapon:"Sword", skills:[]}];
        var saved = Plan.saved(choices);
        var restored = Plan.fromPreset(haxe.Json.parse(haxe.Json.stringify({arsenals:saved})));
        check(restored[0].weapon == "Bow" && Plan.same(restored[0].skills, ["Shot", "BowPassive"]),
            "Active and passive choices survive save/reload in slot order");
        check(restored[1].skills.length == 0, "Empty native selection is preserved");
        check(Plan.fromPreset({weapons:[]}).length == 0, "Legacy presets leave arsenal preferences alone");
        choices[0].skills[0] = "Other";
        check(saved[0].skills[0] == "Shot", "Saving never retains mutable game arrays");
        rejects(() -> Plan.fromPreset({arsenals:null}), "Malformed new data is not mistaken for a legacy preset");
        rejects(() -> Plan.decode([{weapon:"Bow", skills:["Shot", "Shot"]}]), "Duplicate skills rejected");
        rejects(() -> Plan.decode([saved[0], saved[0]]), "Duplicate weapons rejected");
        rejects(() -> Plan.decode([{weapon:"Bow", skills:[null]}]), "Missing IDs rejected");
        rejects(() -> Plan.decode([{weapon:{bytes:"Bow"}, skills:[]}]), "Corrupt object IDs rejected");
        check(!Plan.same(["Shot", "BowPassive"], ["BowPassive", "Shot"]), "Order is meaningful for skill slots");

        var context:Dynamic = {};
        var transfer = new ArsenalPresetTransfer();
        transfer.start(context, saved);
        check(transfer.weapon() == "Bow", "First weapon restored first");
        var change = transfer.next(context, 0, ["Old"]);
        check(change != null && change.weapon == "Bow", "Different choices request an update");
        check(transfer.next(context, 0.05, ["Old"]) == null && transfer.active,
            "No second request before replicated confirmation");
        check(transfer.next(context, 0.1, ["Shot", "BowPassive"]) == null && transfer.weapon() == "Sword",
            "Confirmed selection advances to the next weapon");
        check(transfer.next(context, 0.15, ["SwordPassive"]).skills.length == 0,
            "Explicit empty selection restores the native default");
        transfer.next(context, 0.2, []);
        check(!transfer.active && transfer.error == "", "Completion waits for the last replicated selection");
        transfer.start(context, [saved[0]]);
        check(transfer.next(context, 1, saved[0].skills) == null && !transfer.active,
            "An already matching preset sends no request");
        transfer.start(context, saved);
        transfer.next(context, 1, ["Old"]);
        transfer.next(context, 6, ["Old"]);
        check(!transfer.active && transfer.error != "", "Unconfirmed/rejected RPC times out");
        transfer.start(context, saved);
        transfer.next(context, 1, ["Old"]);
        transfer.next(context, 2, ["ManualChoice"]);
        check(!transfer.active && transfer.error != "", "Manual changes stop the queue");
        transfer.start(context, saved);
        check(transfer.next({}, 1, []) == null && !transfer.active, "Character/session changes stop the queue");
        transfer.start(context, saved); transfer.cancel();
        check(transfer.next(context, 1, []) == null, "Reset never resumes cancelled requests");

        var bow:Dynamic = {id:"Bow", valid:["Shot", "BowPassive"], skills:[{skill:"Shot"}, {skill:"BowPassive"}]};
        var offhand:Dynamic = {id:"Shield", valid:[], skills:[{skill:"Block"}]};
        G.data = {item:{byId:(["Bow" => bow, "Shield" => offhand]:Map<String, Dynamic>)},
            skill:{byId:(["Shot" => {id:"Shot"}, "BowPassive" => {id:"BowPassive"}]:Map<String, Dynamic>)}};
        var nativeSelection = ["BowPassive"];
        var specialization:Dynamic = {arsenals:(["Bow" => nativeSelection]:Map<String, Dynamic>)};
        var hero:Dynamic = {specialization:specialization, limit:2};
        var item:Dynamic = {type:"st.item.Weapon", kind:"Bow", inf:bow};
        var captured = NativeArsenal.capture(hero, [item, item,
            {type:"st.item.Weapon", kind:"Shield", inf:offhand}, {type:"st.item.Armor"}]);
        check(captured.length == 1 && Plan.same(captured[0].skills, ["BowPassive"]),
            "Capture deduplicates equipped weapon kinds and excludes non-arsenal equipment");
        rejects(() -> NativeArsenal.validate(hero, [{weapon:"Missing", skills:[]}]), "Removed weapons rejected");
        rejects(() -> NativeArsenal.validate(hero, [{weapon:"Bow", skills:["Block"]}]), "Foreign skills rejected");
        hero.limit = 1;
        rejects(() -> NativeArsenal.validate(hero, saved.slice(0, 1)), "Native slot unlock limit respected");
        hero.limit = 2;
        NativeArsenal.apply(hero, saved[0]);
        check(Plan.same(nativeSelection, ["BowPassive"]), "Preparing an RPC never mutates replicated state");
        check(specialization.request.weapon == "Bow" && Plan.same(specialization.request.skills, saved[0].skills),
            "Native setter receives both active and passive selections in order");
        check(specialization.request.skills != nativeSelection, "RPC receives a separate native array");
        check(G.calls[G.calls.length - 1].name == "setArsenalSkills", "Only the public native RPC is invoked");
        Sys.println('Arsenal presets: $checks checks passed.');
    }
}
