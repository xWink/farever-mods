import dpsmeter.Collector;
import dpsmeter.MeterConfig;

@:access(dpsmeter.Collector)
class CollectorHealingTest {
    static var checks = 0;
    static function check(value:Bool, message:String):Void { checks++; if (!value) throw message; }
    static function main():Void {
        var config = MeterConfig.defaults(), c = new Collector(config);
        var layer:Dynamic = {isRift: false};
        var me:Dynamic = {__uid: "me", name: "Local", layer: layer, player: {isMe: true}, health: 200., maxHealth: 200.};
        var other:Dynamic = {__uid: "healer", name: "Healer", layer: layer, player: {isMe: false}, health: 300., maxHealth: 500.};
        c.hero = me; c.layer = layer; c.model.me = "me";
        c.model.party["me"] = true; c.model.party["healer"] = true;
        c.combatEnter("me", 10);
        c.damage({__uid: "boss", inf: {flags: 16}, kind: "Boss"},
            {source: me, skill: {kind: "Priest_Attack"}, _amount: 100., effect: 0}, 10);
        var attributes:Dynamic = {unit: me, health: 100., __host: {isSyncingProperty: 26}};
        var skill:Dynamic = {kind: "Priest_Heal", owner: other, __uid: "healSkill"};
        var heal:Dynamic = {source: other, weakSource: "healer", target: me, skill: skill,
            _amount: 500., _critical: true, effect: 1, stepIdx: 0};
        var hit:Dynamic = {skill: skill, ctx: {skill: skill}, step: {index: 0, baseSkill: skill,
            inf: {effects: [{effect: 1, estimate: 250.}, {effect: 0, estimate: 9999.}]}}};
        c.healthChanged(attributes, 200, 11);
        c.healingFX(me, hit, 11); c.healing(other, heal, 11); c.healingCapture.flush(13);
        var p = c.model.current.players["healer"];
        check(p != null && p.heal == 500 && p.healing.actual == 100, "Remote healing is attributed to the healer, not target or RPC receiver");
        check(p.hits == 0 && p.crits == 0 && p.healingSkills["Priest_Heal"].crits == 1, "Critical healing never alters damage statistics");
        check(p.healing.hits == 1 && p.healing.estimatedHits == 0, "FX and exact RPC for the same native skill/step deduplicate");
        c.healing(other, heal, 15); c.healingCapture.flush(17);
        check(p.heal == 1000 && p.healing.actual == 100 && p.healing.measuredHits == 2, "A later full overheal does not reuse HP");
        me.health = 50.; attributes.__host.isSyncingProperty = -1;
        c.healthChanged(attributes, 200, 19); c.healing(other, heal, 19); c.healingCapture.flush(21);
        check(p.heal == 1500 && p.healing.actual == 100 && !p.healing.complete(), "Prediction is not counted as restored health");
        config.enabled = false; c.healing(other, heal, 23); c.healingFX(me, hit, 23); c.healingCapture.flush(25);
        check(p.heal == 1500, "Disabled meter collects neither healing channel");
        config.enabled = true; other.simulatingServer = true; c.healing(other, heal, 27); c.healingCapture.flush(29);
        check(p.heal == 1500, "Server simulation does not duplicate a client notification"); other.simulatingServer = false;
        check(c.model.current.players["me"].damage == 100 && c.model.current.players["me"].heal == 0,
            "Receiving a sourced heal does not inflate the recipient's output");

        attributes.unit = other; attributes.health = 100.; attributes.__host.isSyncingProperty = 26;
        c.healthChanged(attributes, 300, 31); c.healingFX(other, hit, 31.01); c.healingCapture.flush(33);
        check(p.heal == 1750 && p.healing.actual == 300 && p.healing.estimatedHits == 1 && p.healing.knownCritHits == 3,
            "Remote self-healing is captured without its owner-only RPC, with unknown crit and estimated output");
        check(p.healingSkills["Priest_Heal"].output == 1750, "Only healing effects are evaluated, never the damage/RNG path");

        var third:Dynamic = {__uid: "third", name: "Third", player: {isMe: false}, layer: layer, health: 150., maxHealth: 500.};
        c.model.party["third"] = true; c.profile(third);
        attributes.unit = third; attributes.health = 50.;
        c.healthChanged(attributes, 150, 35); c.healingFX(third, hit, 35); c.healingCapture.flush(37);
        check(p.heal == 2000 && p.healing.actual == 400 && !c.model.current.players.exists("third"),
            "Other-player to other-player healing is credited to caster, never both caster and recipient");

        var status:Dynamic = {__type: "st.skill.Status", kind: "Priest_Regrowth", __uid: "hot", owner: me, instigator: other};
        hit.skill = status; hit.ctx.skill = status; hit.step.baseSkill = status;
        attributes.unit = me; attributes.health = 50.; me.health = 150.;
        c.healthChanged(attributes, 150, 39); c.healingFX(me, hit, 39); c.healingCapture.flush(41);
        check(p.healingSkills["Priest_Regrowth"].output == 250 && c.model.current.players["me"].heal == 0,
            "A status owned by the recipient retains its original healer via ScriptHitData.get_source");

        var origin:Dynamic = {__type: "st.skill.BaseSkill", kind: "Priest_Summon", owner: other};
        var summon:Dynamic = {summonOwner: other, summonSourceSkill: origin};
        skill.owner = summon; hit.skill = skill; hit.ctx.skill = skill; hit.step.baseSkill = skill;
        c.healingFX(me, hit, 43); c.healingCapture.flush(45);
        check(p.healingSkills["Priest_Summon"].output == 250, "A healing summon is credited to its player and summoning ability");

        attributes.unit = third; attributes.health = 150.;
        c.healthChanged(attributes, 200, 47); c.healingCapture.flush(49);
        check(c.model.current.players["third"].healingSkills["Regen / unattributed"].actual == 50,
            "Unmatched replicated player recovery is visible without inventing a spell or caster");
        check(c.model.current.players["me"].damage == 100 && c.model.current.pendingHealing == 0,
            "All channels preserve damage and release pending archive holds");
        Sys.println('Healing client collector: $checks checks passed');
    }
}
