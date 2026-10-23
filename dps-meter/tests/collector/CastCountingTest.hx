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
        for (id in ["Rogue_Talent_LethalPoison", "Rogue_Talent_VirulentMagic", "Infusion_Bee_DPS"]) {
            var passive:Dynamic = {__type:"st.skill.Skill", owner:me, kind:id, inf:{nature:5}};
            var dot:Dynamic = {__type:"st.skill.Status", __uid:id+"-dot", owner:target, instigator:me,
                kind:id+"_Status", instigatorSkill:passive, periodic:true};
            c.skillUse(passive, null);
            check(c.model.activation("me", id) == 0, "Equipping a passive is not applying its effect");
            c.statusApplied(dot); c.statusApplied(dot);
            hit(dot, me, 36); hit(dot, me, 37);
            check(p.skills[id].casts == 1 && p.skills[id].hits == 2,
                id+": one application counts once, duplicate init and damage ticks do not");
            c.statusApplied(dot, true); hit(dot, me, 38); hit(dot, me, 39);
            check(p.skills[id].casts == 2 && p.skills[id].hits == 4,
                id+": reapplication counts independently of ticks");
            var other:Dynamic = {__type:"st.skill.Status", __uid:id+"-other", owner:{__uid:"add"}, instigator:me,
                kind:id+"_Status", instigatorSkill:passive, periodic:true};
            c.statusApplied(other);
            check(p.skills[id].casts == 3, "Applications on another target count too");
            c.statusRemoved(dot); c.statusRemoved(other);
            check(!c.appliedStatuses.exists(dot.__uid), "Removed status instances are released");
        }
        status.__uid="leap-dot";status.periodic=true;
        c.statusApplied(status); c.statusApplied(status, true); hit(status, me, 39.1);
        check(p.skills["BroodLeap"].casts == 3, "An active skill's periodic status does not add another cast");
        var independent:Dynamic = {__type:"st.skill.Status", __uid:"independent", owner:target,
            instigator:ally, kind:"IndependentDot", periodic:true};
        c.statusApplied(independent); hit(independent, ally, 39.2);
        check(fight.players["ally"].skills["IndependentDot"].casts == 1,
            "Standalone status applications belong to their instigator, not the target");
        var statusProc:Dynamic = {__type:"st.skill.Status", kind:"StatusProc", inf:{nature:4}, instigator:me};
        var procDot:Dynamic = {__type:"st.skill.Status", __uid:"proc-dot", owner:target, instigator:me,
            kind:"ProcDot", instigatorSkill:statusProc, periodic:true};
        c.statusApplied(procDot);hit(procDot, me, 39.25);
        check(p.skills["StatusProc"].casts == 1, "Periodic procs from persistent statuses count applications too");
        // Passive infusion/enchant executions are replicated via client
        // play-step messages rather than direct Skill.start activations.
        // Confirm two-step bomblet bursts count once, not one cast per hit.
        for (id in ["Infusion_Kobold_DPS", "Infusion_Crimson_Support", "Enchant_FlamingWeapon"]) {
            var passiveProc:Dynamic = {__type:"st.skill.Skill", __uid:id, owner:me,
                kind:id, inf:{nature:5}};
            var before=c.model.activation("me",id);
            c.skillUse(passiveProc,null);
            check(c.model.activation("me",id)==before,id+": equipping passive is not a cast");
            var now=haxe.Timer.stamp();
            c.procStep(passiveProc,now);
            c.procStep(passiveProc,now+0.01);
            c.procStep(passiveProc,now+0.04);
            check(c.model.activation("me",id)==before+1,
                id+": several replicated steps in one burst count once");
            hit(passiveProc,me,39.26);hit(passiveProc,me,39.27);
            check(p.skills[id].casts==before+1&&p.skills[id].hits==2,
                id+": damage hits never create extra casts");
            c.procStep(passiveProc,now+0.21);
            check(p.skills[id].casts==before+2,
                id+": a later independent proc increments the count");
            passiveProc.simulatingServer=true;
            c.procStep(passiveProc,now+0.5);passiveProc.simulatingServer=false;
            config.enabled=false;c.procStep(passiveProc,now+0.5);config.enabled=true;
            check(p.skills[id].casts==before+2,id+": simulated and disabled callbacks excluded");
        }
        var activeInfusion:Dynamic={__type:"st.skill.Skill", owner:me,
            kind:"Infusion_Manfish_DPS_Ultimate",inf:{nature:2}};
        c.skillUse(activeInfusion,null);
        c.procStep(activeInfusion,haxe.Timer.stamp());
        check(c.model.activation("me","Infusion_Manfish_DPS_Ultimate")==1,
            "Active infusions count only their real Skill.start, not their steps");
        var otherProc:Dynamic={__type:"st.skill.Skill", owner:ally,
            kind:"Enchant_FlamingWeapon",inf:{nature:5}};
        c.procStep(otherProc,haxe.Timer.stamp());
        check(c.model.activation("ally","Enchant_FlamingWeapon")==1,
            "Remote player procs have independent owners");
        var coupled:Dynamic={__type:"st.skill.Skill",owner:me,
            kind:"Infusion_MixedStatus",inf:{nature:5}};
        var coupledStatus:Dynamic={__type:"st.skill.Status",__uid:"mixed-status",owner:target,
            instigator:me,kind:"MixedStatusDot",instigatorSkill:coupled,periodic:true};
        var procTime=haxe.Timer.stamp();
        c.procStep(coupled,procTime);
        c.statusApplied(coupledStatus);
        check(c.model.activation("me","Infusion_MixedStatus")==1,
            "A periodic status created by a proc step is not another cast");
        var statusFirst:Dynamic={__type:"st.skill.Skill",owner:me,
            kind:"Enchant_StatusFirst",inf:{nature:5}};
        var priorStatus:Dynamic={__type:"st.skill.Status",__uid:"status-first",owner:target,
            instigator:me,kind:"StatusFirstDot",instigatorSkill:statusFirst,periodic:true};
        c.statusApplied(priorStatus);
        c.procStep(statusFirst,haxe.Timer.stamp());
        check(c.model.activation("me","Enchant_StatusFirst")==1,
            "A proc step following a counted status is not duplicated");
        var fakeTalent:Dynamic={__type:"st.skill.Skill",owner:me,
            kind:"Rogue_Talent_Proc",inf:{nature:5}};
        c.procStep(fakeTalent,haxe.Timer.stamp());
        check(c.model.activation("me","Rogue_Talent_Proc")==0,
            "Non-infusion/enchant passives are not inferred from proc steps");
        var cube:Dynamic = {__type:"st.skill.Skill", owner:me, kind:"ConsumeItem", originItem:{kind:"SparkCube"}};
        c.skillUse(cube, null); hit(cube, me, 39.3); hit(cube, me, 39.4);
        check(p.skills["SparkCube"].casts == 1 && p.skills["SparkCube"].hits == 2 && !p.skills.exists("ConsumeItem"),
            "Spark Cube damage and casts retain the item identity");
        cube.originItem={kind:"OtherConsumable"};c.skillUse(cube, null);hit(cube, me, 39.5);
        check(p.skills["OtherConsumable"].casts == 1 && p.skills["SparkCube"].hits == 2,
            "Different consumables do not merge under ConsumeItem or Spark Cube");
        independent.simulatingServer=true;c.statusApplied(independent, true);
        independent.simulatingServer=false;config.enabled=false;c.statusApplied(independent, true);config.enabled=true;
        check(fight.players["ally"].skills["IndependentDot"].casts == 1, "Disabled and simulated applications are ignored");
        c.model.reset(40);
        check(c.model.activation("me", "BroodLeap") == 0, "Zone/character resets clear activation state");
        c.model.me="me";c.model.party["me"]=true;
        var opener:Dynamic = {__type:"st.skill.Status", __uid:"opener", owner:target, instigator:me,
            kind:"OpeningDot", periodic:true};
        c.statusApplied(opener);
        check(c.model.current == null, "Applying a status alone never starts the encounter timer");
        c.combatEnter("me", 41);hit(opener, me, 41);hit(opener, me, 42);
        check(c.model.current.players["me"].skills["OpeningDot"].casts == 1,
            "A status applied before the opening damage keeps its application count");
        Sys.println('Cast counting: $checks checks passed');
    }
}
