import dpsmeter.Collector;
import dpsmeter.MeterConfig;

@:access(dpsmeter.Collector)
class SummonCastsTest {
    static var checks = 0;
    static function check(value:Bool, why:String):Void { checks++; if (!value) throw why; }
    static function main():Void {
        var config = MeterConfig.defaults(), c = new Collector(config);
        var layer:Dynamic = {isRift:false};
        var me:Dynamic = {__uid:"me", name:"Local", layer:layer, player:{isMe:true}};
        var ally:Dynamic = {__uid:"ally", name:"Ally", layer:layer, player:{isMe:false}};
        c.hero = me; c.layer = layer; c.model.me = "me";
        c.model.party["me"] = true; c.model.party["ally"] = true;
        var passive:Dynamic = {__type:"st.skill.Skill", owner:me, kind:"HiveSwarm", inf:{nature:5}};
        var target:Dynamic = {__uid:"boss", kind:"Boss", inf:{flags:16}};
        var bee = (id:String, owner:Dynamic, skill:Dynamic) -> ({__uid:id, summonOwner:owner, summonSourceSkill:skill}:Dynamic);
        var attack = (unit:Dynamic) -> ({__type:"st.skill.Skill", owner:unit, kind:"BeeAttack"}:Dynamic);
        var hit = (unit:Dynamic, skill:Dynamic, time:Float) -> c.damage(target,
            {source:unit, skill:skill, _amount:100., effect:0}, time);
        var first = bee("bee-1", me, passive);
        c.skillUse(passive, null); c.summonCreated(first); c.summonCreated(first);
        check(c.model.activation("me", "HiveSwarm") == 1, "One summon counts once across source assignment and init");
        check(c.model.current == null && c.model.boss == null, "Summoning alone cannot start encounter timers");
        c.combatEnter("me", 10);
        hit(first, attack(first), 10);
        var fight = c.model.current, p = fight.players["me"];
        for (unit in [first, bee("bee-2", me, passive), bee("bee-3", me, passive)]) {
            c.summonCreated(unit); c.summonCreated(unit);
            var bite = attack(unit);
            c.skillUse(bite, null); hit(unit, bite, 11);
            c.skillUse(bite, null); hit(unit, bite, 12);
        }
        check(p.skills["HiveSwarm"].casts == 3 && p.skills["HiveSwarm"].hits == 7 && p.damage == 700,
            "Three passive bees count three casts; all seven attacks stay under the player's passive");
        check(!p.skills.exists("BeeAttack") && !fight.players.exists("bee-1"), "No separate bee player or attack entry");
        var before = fight.last;
        c.summonCreated(bee("no-hit", me, passive));
        check(p.skills["HiveSwarm"].casts == 4 && fight.last == before, "A summon with no damage counts without extending the timer");
        var dot:Dynamic = {__type:"st.skill.Status", __uid:"bee-dot", owner:target, instigator:first,
            kind:"BeePoison", instigatorSkill:attack(first), periodic:true};
        c.statusApplied(dot); c.statusApplied(dot, true); hit(first, dot, 13);
        check(p.skills["HiveSwarm"].casts == 4 && p.skills["HiveSwarm"].hits == 8,
            "A summon applying or refreshing a DoT cannot add casts to its passive");
        dot.instigator = me;
        c.statusApplied(dot, true);
        check(p.skills["HiveSwarm"].casts == 4, "The summon attack's owner still identifies a proxied status source");
        var independent:Dynamic = {__type:"st.skill.Skill", owner:me, kind:"IndependentPoison", inf:{nature:5}};
        dot.instigator = first; dot.instigatorSkill = independent;
        c.statusApplied(dot, true);
        check(c.model.activation("me", "IndependentPoison") == 1,
            "A separate passive proc triggered by a summon still counts its own application");
        var child:Dynamic = {__type:"st.skill.Skill", owner:me, kind:"SpawnBee", parent:passive};
        c.summonCreated(bee("child-skill", null, child));
        check(p.skills["HiveSwarm"].casts == 5, "Child spawn skills resolve the passive even before summonOwner arrives");
        c.summonCreated(bee("nested", first, attack(first)));
        check(p.skills["HiveSwarm"].casts == 6, "Nested summons resolve back to the player and original passive");
        var remote:Dynamic = {__type:"st.skill.Skill", owner:ally, kind:"HiveSwarm", inf:{nature:5}};
        var remoteBee = bee("remote", ally, remote);
        c.summonCreated(remoteBee); hit(remoteBee, attack(remoteBee), 14);
        check(fight.players["ally"].skills["HiveSwarm"].casts == 1 && p.skills["HiveSwarm"].casts == 6,
            "Party members' passive summons are counted separately");
        var active:Dynamic = {__type:"st.skill.Skill", owner:me, kind:"ActiveSummon"};
        c.skillUse(active, null);
        for (id in ["active-1", "active-2"]) {
            var unit = bee(id, me, active);
            c.summonCreated(unit); c.skillUse(attack(unit), null); hit(unit, attack(unit), 15);
        }
        check(p.skills["ActiveSummon"].casts == 1 && p.skills["ActiveSummon"].hits == 2,
            "An active ability summoning multiple units retains its one actual skill activation");
        var pending = bee("pending", null, null);
        c.summonCreated(pending); pending.summonSourceSkill = passive; c.summonCreated(pending);
        check(p.skills["HiveSwarm"].casts == 7, "Incomplete replication can be retried when its source arrives");
        var ignored = bee("ignored", me, passive);
        config.enabled = false; c.summonCreated(ignored); config.enabled = true;
        ignored.simulatingServer = true; c.summonCreated(ignored); ignored.simulatingServer = false;
        ignored.removed = true; c.summonCreated(ignored);
        c.summonCreated(bee("0", me, passive)); c.summonCreated(target);
        check(p.skills["HiveSwarm"].casts == 7, "Disabled, simulated, removed, invalid and ordinary foes add no casts");
        check(c.model.session.players["me"].skills["HiveSwarm"].casts == 7
            && c.model.boss.players["me"].skills["HiveSwarm"].casts == 7, "Summon casts propagate to all combat scopes");
        c.update({hero:null}, 20);
        check(!c.countedSummons.exists("bee-1"), "Character/zone reset clears summon tracking");
        Sys.println('Summon casts: $checks checks passed');
    }
}
