import dpsmeter.Collector;
import dpsmeter.MeterConfig;

@:access(dpsmeter.Collector)
class CollectorHealingTest {
    static var checks = 0;
    static function check(value:Bool, message:String):Void { checks++; if (!value) throw message; }
    static function main():Void {
        var config = MeterConfig.defaults(), c = new Collector(config);
        var layer:Dynamic = {isRift: false};
        var me:Dynamic = {__uid: "me", name: "Local", layer: layer, player: {isMe: true}};
        var other:Dynamic = {__uid: "healer", name: "Healer", layer: layer, player: {isMe: false}};
        c.hero = me; c.layer = layer; c.model.me = "me";
        c.model.party["me"] = true; c.model.party["healer"] = true;
        c.combatEnter("me", 10);
        c.damage({__uid: "boss", inf: {flags: 16}, kind: "Boss"},
            {source: me, skill: {kind: "Priest_Attack"}, _amount: 100., effect: 0}, 10);
        var target:Dynamic = {__uid: "me", health: 200., maxHealth: 200.};
        var attributes:Dynamic = {unit: target, health: 100., __host: {isSyncingProperty: 26}};
        var heal:Dynamic = {source: other, weakSource: "healer", skill: {kind: "Priest_Heal"},
            _amount: 500., _critical: true, effect: 1};
        c.healthChanged(attributes, 200);
        c.healing(target, heal, 11);
        var p = c.model.current.players["healer"];
        check(p != null && p.heal == 500 && p.healing.actual == 100, "Remote healing is attributed to the healer, not its target");
        check(p.hits == 0 && p.crits == 0 && p.healingSkills["Priest_Heal"].crits == 1, "Collector separates critical heals from damage");
        c.healing(target, heal, 11.2);
        check(p.heal == 1000 && p.healing.actual == 100 && p.healing.measuredHits == 2, "Repeated full overheal has no reused health delta");
        target.health = 50.; attributes.__host.isSyncingProperty = -1;
        c.healthChanged(attributes, 200); c.healing(target, heal, 12);
        check(p.heal == 1500 && p.healing.actual == 100 && !p.healing.complete(), "Local prediction is not counted as restored health");
        config.enabled = false; c.healing(target, heal, 13);
        check(p.heal == 1500, "Disabled meter collects neither healing nor damage");
        config.enabled = true; target.simulatingServer = true; c.healing(target, heal, 14);
        check(p.heal == 1500, "Simulated server notifications do not duplicate client heals");
        check(c.model.current.players["me"].damage == 100 && c.model.current.players["me"].heal == 0,
            "Receiving a heal does not inflate the recipient's healing output");
        Sys.println('Healing client collector: $checks checks passed');
    }
}
