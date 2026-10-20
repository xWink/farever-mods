import dpsmeter.CombatTimeline;
import dpsmeter.NativeTimeline;
import dpsmeter.MeterConfig;
import dpsmeter.HealingCapture;
import dpsmeter.GameAccess as G;

class NativeTimelineTest {
    static var checks = 0;
    static var events:Array<TimelineEvent> = [];
    static var journal:CombatTimeline;
    static function check(value:Bool, message:String):Void { checks++; if (!value) throw message; }
    static function rows(kind:String):Array<TimelineEvent> {
        journal.flush(haxe.Timer.stamp());
        return events.filter(e -> e.kind == kind);
    }
    static function main():Void {
        var definitions:Map<String, Dynamic> = [
            "Barrier" => {id:"Barrier", flags:0, props:{status:{types:[]}}},
            "Poison" => {id:"Poison", flags:0, props:{status:{types:[{type:"Debuff"}]}}},
            "Dose" => {id:"Dose", flags:4096, props:{status:{types:[{type:"Debuff"}]}}}
        ];
        G.globals["Data.skill"] = {byId:definitions, all:[for (inf in definitions) inf]};
        G.globals["skillRefs"] = new Map<String, Dynamic>();
        var now = haxe.Timer.stamp();
        journal = new CombatTimeline("native", now, b -> { for (e in b.events) events.push(e); });
        var config = MeterConfig.defaults();
        var recorder = new NativeTimeline(config, journal);
        var hero:Dynamic = {__uid:"me", name:"Mage", statuses:{array:[]}, weaponSkills:[], skills:[], attr:{health:900.}};
        var boss:Dynamic = {__uid:"boss", name:"Boss"};
        var ally:Dynamic = {__uid:"ally", name:"Healer"};
        var skill:Dynamic = {__uid:"skill", __type:"st.skill.Skill", kind:"AimedShot", owner:hero, charges:.75};
        var dash:Dynamic = {__uid:"dash", __type:"st.skill.Skill", kind:"RogueDash", owner:hero};
        var block:Dynamic = {__uid:"block", __type:"st.skill.Skill", kind:"Block", owner:hero, isBlock:true};
        hero.dashSkill = dash;
        recorder.update(hero, now);
        recorder.use(hero, dash); recorder.use(hero, block);
        check(rows("dodge_use").length == 1 && rows("block_use").length == 1, "Dodge and block use need no incoming attack");
        check(rows("block_success").length == 0, "A block use does not invent a successful block");
        recorder.block(block, true);
        check(rows("block_success")[0].outcome == "Perfect block", "Successful defenses are separate outcomes");
        recorder.highlight(skill, true); recorder.highlight(skill, true);
        recorder.use(hero, skill); recorder.highlight(skill, true);
        check(rows("proc_available").length == 1 && rows("proc_used").length == 1, "A used proc does not reappear during delayed glow removal");
        recorder.highlight(skill, false); recorder.highlight(skill, true);
        check(rows("proc_available").length == 2, "A newly acquired proc can be recorded after use");
        recorder.charges(skill, .75);
        check(rows("charge_update").length == 0, "Fractional charges are never compared with a floored integer");
        recorder.charges(skill, 1);
        check(rows("charge_update")[0].before == .75 && rows("charge_update")[0].after == 1,
            "Server charge changes retain precise values without guessing the cause");
        var quick:Dynamic = {__uid:"quick", __type:"st.skill.Skill", kind:"Pyroclasm", owner:hero, highlight:true};
        recorder.use(hero, quick);
        check(rows("proc_available").length == 3 && rows("proc_used").length == 2,
            "A proc acquired and used between polling frames is observed at the start boundary");
        quick.simulatingServer = true; recorder.use(hero, quick); quick.simulatingServer = false;
        check(rows("proc_used").length == 2, "A simulated server skill start cannot duplicate use");
        var hit:Dynamic = {source:hero, target:boss, skill:skill, _amount:100., _critical:true, _hitCount:1, magical:true};
        recorder.damage(boss, hit, now + 1); recorder.damage(boss, hit, now + 1);
        check(rows("damage").length == 2, "Distinct equal-valued native notifications are not heuristically merged");
        boss.simulatingServer = true; recorder.damage(boss, hit, now + 1); boss.simulatingServer = false;
        check(rows("damage").length == 2, "Server simulation is excluded from client observations");
        hit.blocker = "DamageDodge"; recorder.damage(boss, hit, now + 2); hit.blocker = null;
        check(rows("avoided")[0].amount == 0, "An avoided hit does not count its calculated damage as inflicted");
        var dot:Dynamic = {__uid:"dot", __type:"st.skill.Status", kind:"GapingWoundTick", owner:boss, instigator:hero, origin:skill,
            stacks:1, duration:20., shieldAmount:0.};
        hit.source = null; hit.skill = dot; recorder.damage(boss, hit, now + 2);
        check(rows("damage")[2].skill == "GapingWoundTick" && rows("damage")[2].origin == "AimedShot",
            "DoT ticks preserve both effect and origin identity");
        hit.source = boss; hit.target = hero; hit.skill = skill; recorder.damage(hero, hit, now + 3);
        check(rows("damage")[3].source == "boss" && rows("damage")[3].target == "me", "Incoming attacks retain their attacker");
        hit.source = ally; hit.target = boss; recorder.damage(boss, hit, now + 3);
        check(rows("damage").length == 4, "Unrelated other-player combat is excluded");
        var attr:Dynamic = {unit:hero, health:900., __host:{isSyncingProperty:26}};
        recorder.health(attr, 950); check(rows("health_loss").length == 0, "Passive health regeneration creates no healing timeline row");
        recorder.health(attr, 800);
        check(rows("health_loss")[0].amount == 100 && rows("health_loss")[0].skill == "", "Replicated HP loss is retained without invented skill attribution");
        attr.__host.isSyncingProperty = -1; recorder.health(attr, 700);
        check(rows("health_loss").length == 1, "Predicted health writes cannot duplicate replicated HP losses");
        var healing = HealingCapture.event(now + 3, "ally", "me", "Potion", 80);
        healing.timeline = recorder.prepareHeal(ally, hero, skill, now + 3);
        recorder.healed(healing);
        check(rows("heal").length == 1 && rows("heal")[0].amount == 80, "Sourced healing records normal output");
        check(rows("heal")[0].source == "ally" && rows("heal")[0].target == "me", "Another player's healing retains their identity in the personal timeline");
        healing.unattributedHealing = true; recorder.healed(healing);
        check(rows("heal").length == 1, "Unattributed regeneration does not enter the detailed report");
        var cubeGfx:Dynamic = {file:"spark-cube.png", size:256, x:0, y:0};
        G.globals["Data.item"] = {byId:["SparkCube" => {texts:{name:"Spark Cube"}, gfx:cubeGfx},
            "TestPotion" => {texts:{name:"Test Potion"}}]};
        var consume:Dynamic = {__uid:"consume", __type:"st.skill.Skill", kind:"ConsumeItem", owner:hero, originItem:{kind:"SparkCube"}};
        recorder.use(hero, consume);
        var itemUses = rows("skill_use").filter(e -> e.skill == "ConsumeItem");
        check(itemUses[0].item == "SparkCube" && itemUses[0].itemName == "Spark Cube", "Generic consume uses capture the actual source item before execution");
        check(dpsmeter.NativeCombatMetadata.itemIcon("SparkCube") == cubeGfx, "Consumed items use their item portrait");
        var cubeEffect:Dynamic = {__uid:"cube-effect", __type:"st.skill.Status", kind:"CubeEffect", owner:boss,
            instigator:hero, instigatorSkill:consume};
        var cubeHit=recorder.hit("damage", hero, boss, cubeEffect);
        check(cubeHit.item == "SparkCube" && cubeHit.itemName == "Spark Cube",
            "An item's child effect retains its item name and portrait in detailed reports");
        consume.originItem = {kind:"TestPotion"}; recorder.use(hero, consume);
        consume.originItem = null; recorder.use(hero, consume);
        itemUses = rows("skill_use").filter(e -> e.skill == "ConsumeItem");
        check(itemUses[0].item == "SparkCube" && itemUses[1].item == "TestPotion" && itemUses[1].itemName == "Test Potion",
            "Reused generic skills preserve each distinct consumable without relabeling other items as Spark Cube");
        check(itemUses[2].item == null, "An unavailable source item stays unknown");
        consume.origin = {originItem:{kind:"SparkCube"}}; recorder.use(hero, consume);
        itemUses = rows("skill_use").filter(e -> e.skill == "ConsumeItem");
        check(itemUses[3].item == "SparkCube", "Native source-item resolution also follows an originating skill");
        var shield:Dynamic = {__uid:"shield", __type:"st.skill.Status", kind:"Barrier", owner:hero, instigator:ally,
            stacks:1, duration:10., shieldAmount:150.};
        recorder.statusChanged(shield, "status_applied"); recorder.statusChanged(shield, "status_applied");
        check(rows("status_applied").length == 1 && rows("shield_applied")[0].amount == 150, "New shield application is counted once");
        check(rows("status_applied")[0].source == "ally" && rows("shield_applied")[0].source == "ally",
            "Buffs and shielding received from another player preserve their source");
        recorder.statusChanged(shield, "status_stacks"); shield.stacks = 2; recorder.statusChanged(shield, "status_stacks");
        check(rows("status_stacks").length == 1, "Unchanged stack setters do not produce fake stack events");
        recorder.statusChanged(shield, "status_refreshed"); recorder.shieldChanged(shield, 150, 100);
        check(rows("status_refreshed").length == 1 && rows("shield_changed")[0].amount == 50, "Refreshes and shield changes remain distinct");
        recorder.statusRpc(shield);
        check(rows("status_duration").length == 0, "Unrelated status RPCs do not invent duration changes");
        shield.duration += 5; recorder.statusRpc(shield); recorder.statusRpc(shield);
        check(rows("status_duration").length == 1 && rows("status_duration")[0].duration == 15,
            "Duration extensions are observed once through the patchable network dispatcher");
        shield.duration += 5; recorder.statusChanged(shield, "status_refreshed"); recorder.statusRpc(shield);
        check(rows("status_duration").length == 1, "A refresh captured inside RPC dispatch is not duplicated afterwards");
        shield.duration = 0; recorder.statusRemoved(shield, "End"); recorder.statusRemoved(shield);
        check(rows("status_removed").length == 1 && rows("status_removed")[0].outcome == "Expired", "Known expiration is labeled once despite later removal");
        check(rows("status_applied")[0].statusType == "buff", "Recorded buffs preserve the native status category");
        var catalog = dpsmeter.NativeCombatMetadata.statusCatalog();
        check(catalog["Poison"].kind == "debuff" && catalog["Dose"].hidden && catalog["Barrier"].kind == "buff", "Metadata distinguishes native debuffs and hidden internal effects");
        var castSkill:Dynamic = {__uid:"cast", __type:"st.skill.Skill", kind:"Cast", owner:hero, runningCtx:null};
        recorder.use(hero, castSkill, TimelineTarget.Target(boss));
        var firstUse = rows("skill_use").filter(e -> e.skill == "Cast")[0];
        check(firstUse.target == "boss", "Explicit skill-start targets are captured before damage");
        var firstContext:Dynamic = {aimTarget:boss}; castSkill.runningCtx = firstContext; recorder.started(castSkill, firstContext);
        recorder.use(hero, castSkill); // Native start stops the previous context before assigning a new one.
        recorder.stopped(castSkill, "Start");
        var secondContext:Dynamic = {aimTarget:ally}; castSkill.runningCtx = secondContext; recorder.started(castSkill, secondContext);
        recorder.stopped(castSkill, "End");
        var uses = rows("skill_use").filter(e -> e.skill == "Cast"), ends = rows("skill_end").filter(e -> e.skill == "Cast");
        check(ends.length == 2 && ends[0].related == uses[0].seq && ends[1].related == uses[1].seq,
            "Restarting a skill closes the previous use, not the new one");
        check(ends[0].useDuration >= 0 && ends[1].useDuration >= 0, "Completed uses record elapsed duration");
        var contexts = rows("skill_context").filter(e -> e.skill == "Cast");
        check(contexts[1].related == uses[1].seq && contexts[1].target == "ally", "Post-start observations preserve resolved targeting");
        castSkill.runningCtx = null; recorder.use(hero, castSkill);
        var instantContext:Dynamic = {aimTarget:boss}; castSkill.runningCtx = instantContext;
        recorder.stopped(castSkill, "End"); recorder.started(castSkill, instantContext);
        uses = rows("skill_use").filter(e -> e.skill == "Cast"); ends = rows("skill_end").filter(e -> e.skill == "Cast");
        check(ends[2].related == uses[2].seq, "Instant skills ending inside start retain their use duration");
        var joinedSkill:Dynamic = {__uid:"joined", __type:"st.skill.Skill", kind:"Joined", owner:hero, runningCtx:{aimTarget:boss}};
        recorder.use(hero, joinedSkill); recorder.stopped(joinedSkill, "Start");
        check(rows("skill_end").filter(e -> e.skill == "Joined").length == 0,
            "An unobserved previous use cannot lend its ending to the new use");
        var totem:Dynamic = {__uid:"totem1", name:"Totem de maree", kind:"Totem_Tidal"};
        var firstTotem = recorder.hit("damage", hero, totem, skill);
        totem.__uid = "totem2";
        var nextTotem = recorder.hit("damage", hero, totem, skill);
        check(firstTotem.target == "totem1" && nextTotem.target == "totem2"
            && firstTotem.targetKind == "Totem_Tidal" && nextTotem.targetKind == "Totem_Tidal",
            "Native recording keeps each summon UID and its shared unit kind independently of the translated name");
        var emptyTarget = recorder.hit("skill_use", hero, null, skill);
        check(emptyTarget.target == "" && emptyTarget.targetKind == null, "Unresolved targets do not invent a unit kind");
        hero.statuses.array = [shield]; shield.duration = 10; shield.shieldAmount = 100;
        config.detailedCombatLogs = false; recorder.update(hero, now + 4);
        recorder.use(hero, dash); check(rows("dodge_use").length == 1, "Disabled detailed recording emits no actions");
        config.detailedCombatLogs = true; recorder.update(hero, now + 5);
        check(rows("status_present").length == 1 && rows("shield_present").length == 1, "Resume seeds actual current buffs and shields");
        check(rows("shield_applied").length == 1, "Resuming does not pretend an existing shield was newly granted");
        recorder.update(null, now + 6);
        var paused = rows("recording_stopped");
        check(paused.length == 2 && paused[1].source == "me", "Disconnect records the old player identity before clearing it");
        check(rows("recording_gap").length == 0, "Supported native boundaries did not fail silently");
        Sys.println('Native detailed recorder: $checks checks passed');
    }
}

private enum TimelineTarget { Target(value:Dynamic); Point(value:Dynamic); }
