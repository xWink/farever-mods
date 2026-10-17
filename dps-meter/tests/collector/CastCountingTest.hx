import dpsmeter.Collector;
import dpsmeter.MeterConfig;

@:access(dpsmeter.Collector)
class CastCountingTest {
    static var checks = 0;
    static function check(value:Bool, why:String):Void { checks++; if (!value) throw why; }
    static function main():Void {
        var config = MeterConfig.defaults(), c = new Collector(config);
        var layer:Dynamic = {isRift:false};
        var me:Dynamic = {__uid:"me", name:"Local", layer:layer, player:{isMe:true}};
        var ally:Dynamic = {__uid:"ally", name:"Ally", layer:layer, player:{isMe:false}};
        c.hero = me; c.layer = layer; c.model.me = "me";
        c.model.party["me"] = true; c.model.party["ally"] = true;
        var leap:Dynamic = {__type:"st.skill.Skill", __uid:"leap", owner:me, kind:"BroodLeap"};
        var pulse:Dynamic = {__type:"st.skill.Skill", __uid:"pulse", owner:me, kind:"BroodLeapExplosion", origin:leap};
        var target:Dynamic = {__uid:"boss", kind:"Boss", inf:{flags:16}};
        var hit = (skill:Dynamic, owner:Dynamic, time:Float) -> c.damage(target,
            {source:owner, skill:skill, _amount:100., effect:0}, time);
        c.skillUse(leap, null);
        check(c.model.current == null && c.model.boss == null, "A skill start cannot start encounter timers");
        c.combatEnter("me", 10);
        hit(leap, me, 10);
        for (time in [11., 12., 15.]) { c.skillUse(pulse, {skill:leap}); hit(pulse, me, time); }
        var fight = c.model.current, p = fight.players["me"];
        check(fight.start == 10 && p.skills["BroodLeap"].casts == 1 && p.skills["BroodLeap"].hits == 4,
            "Opening activation counts once; delayed explosions add hits, not casts");
        check(p.damage == 400 && !p.skills.exists("BroodLeapExplosion"), "Child damage stays under its originating skill");
        check(c.model.boss.players["me"].skills["BroodLeap"].casts == 1
            && c.model.session.players["me"].skills["BroodLeap"].casts == 1, "All scopes use activation counts");
        c.skillUse(leap, null); c.skillUse(leap, null);
        check(p.skills["BroodLeap"].casts == 3 && fight.last == 15,
            "Rapid starts and starts with no hit count independently without extending the timer");
        hit(pulse, me, 15.1); hit(pulse, me, 19.);
        check(p.skills["BroodLeap"].casts == 3 && p.skills["BroodLeap"].hits == 6,
            "Overlapping delayed effects cannot add casts after a recast");
        var status:Dynamic = {__type:"st.skill.Status", owner:target, instigator:me, kind:"Burn", origin:leap};
        hit(status, me, 21);
        check(p.skills["BroodLeap"].casts == 3 && p.skills["BroodLeap"].hits == 7,
            "Status damage resolves its instigator skill without starting another cast");
        c.skillUse(pulse, null);
        leap.simulatingServer = true; c.skillUse(leap, null); leap.simulatingServer = false;
        config.enabled = false; c.skillUse(leap, null); config.enabled = true;
        check(p.skills["BroodLeap"].casts == 3, "Child, server-simulation and disabled starts do not double count");
        var remote:Dynamic = {__type:"st.skill.Skill", owner:ally, kind:"BroodLeap"};
        c.skillUse(remote, null); hit(remote, ally, 22); hit(remote, ally, 24);
        check(fight.players["ally"].skills["BroodLeap"].casts == 1 && p.skills["BroodLeap"].casts == 3,
            "Remote activations are independent for each player");
        var heal:Dynamic = {__type:"st.skill.Status", __uid:"heal", owner:me, instigator:me, kind:"BroodHeal", origin:leap};
        for (time in [25., 26.]) c.healing(me,
            {source:me, target:ally, skill:heal, _amount:50., effect:1, stepIdx:0}, time);
        c.healingCapture.flush(30, true);
        check(p.healingSkills["BroodLeap"].casts == 3 && p.healingSkills["BroodLeap"].hits == 2
            && p.healingSkills["BroodLeap"].output == 100 && p.healing.casts == 3,
            "Mixed damage/healing shares actual activations while retaining separate output and hits");
        var copy = fight.copy();
        copy.add({time:31., source:"me", amount:20., critical:false, kill:false, effect:0, skill:"BroodLeap",
            activation:c.model.activation("me", "BroodLeap"), target:"boss", bossKind:"Boss", bossFlags:16, bossLevel:1, bossFoeId:1}, p.info);
        check(copy.players["me"].skills["BroodLeap"].casts == 3, "Resumed snapshots retain cast deduplication state");
        var unknown:Dynamic = {__type:"st.skill.Skill", owner:me, kind:"Unobserved"};
        hit(unknown, me, 32); hit(unknown, me, 35);
        check(p.skills["Unobserved"].casts == 0 && p.skills["Unobserved"].hits == 2,
            "Missing activation evidence preserves hits without guessing casts");
        c.model.reset(40);
        check(c.model.activation("me", "BroodLeap") == 0, "Zone/character resets clear activation state");
        Sys.println('Cast counting: $checks checks passed');
    }
}
