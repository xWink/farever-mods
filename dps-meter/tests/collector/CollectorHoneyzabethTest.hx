import dpsmeter.Collector;
import dpsmeter.MeterConfig;
import dpsmeter.GameAccess;

private enum HoneyObjectiveTarget { Unit(kind:String); }

class CollectorHoneyzabethTest {
    static var checks = 0;
    static function check(value:Bool, message:String):Void {
        checks++;
        if (!value) throw message;
    }
    static function main():Void {
        GameAccess.globals["activities"] = ["HoneyArena" => {types:["Dungeon"]}];
        var objective = {kind:"KillBoss", target:HoneyObjectiveTarget.Unit("Cleodora"), completed:false};
        var miniObjective = {kind:"KillBoss", target:HoneyObjectiveTarget.Unit("Cleodora_Champion2"), completed:false};
        var altObjective = {kind:"KillBossAlt", target:HoneyObjectiveTarget.Unit("Queenslayer"), completed:false};
        var layer:Dynamic = {isRift:false, config:{activityID:"HoneyArena", difficulty:2},
            mainActivity:{kind:"HoneyArena", bossId:"Cleodora", globalCtx:{objectives:{array:[miniObjective]}}}};
        var player:Dynamic = {isMe:true, heroData:{kind:"rogue"}};
        var hero:Dynamic = {__uid:"me", name:"Wink", player:player, layer:layer, isInCombat:false};
        var queen:Dynamic = {__uid:"queen", kind:"Cleodora", name:"Queen Honeyzabeth", layer:layer,
            phase:1, isInCombat:true, inf:{flags:0x10}, _level:20, foeId:9};
        var mini:Dynamic = {__uid:"mini", kind:"Cleodora_Champion2", name:"Miniboss", layer:layer,
            inf:{flags:0x10}, _level:20, foeId:10};
        layer.units = [mini];
        var app:Dynamic = {hero:hero};
        var collector = new Collector(MeterConfig.defaults());
        collector.update(app, 1);
        var model = collector.model;
        check(model.dungeonBoss != null && model.dungeonBoss.kind == "Cleodora" && model.current == null,
            "The replicated dungeon boss identifies Honeyzabeth before her objective or entity arrives");
        check(model.dungeonBoss.uid == "", "Missing replicated queen and unit definitions do not interrupt collection");
        layer.mainActivity.globalCtx.objectives.array = [miniObjective, objective, altObjective];
        layer.units = [queen, mini]; collector.update(app, 2);
        check(model.dungeonBoss.uid == "queen", "A late replicated queen fills in the dungeon encounter identity");
        layer.mainActivity.bossId = null; collector.update(app, 3);
        check(model.dungeonBoss != null && model.dungeonBoss.kind == "Cleodora",
            "Multiple boss objectives preserve the queen as encounter owner even without bossId");
        hero.isInCombat = true; collector.combatEnter("me", 10);
        check(model.current == null, "Native combat entry still waits for damage");
        var damage:Dynamic = {source:hero, weakSource:"me", skill:{kind:"Rogue_Attack"},
            _amount:100., _critical:false, _kill:false, effect:0, physical:true, magical:false};
        collector.damage(mini, damage, 11);
        var original = model.current;
        check(original != null && original.start == 11 && original.bossKind == "Cleodora"
            && original.bossUid == "queen" && original.bossName == "Queen Honeyzabeth",
            "Real collector damage to a miniboss starts the Honeyzabeth encounter");
        damage._kill = true; collector.damage(mini, damage, 12);
        miniObjective.completed = true;
        hero.isInCombat = false; collector.combatExit("me", 13); collector.update(app, 30);
        check(model.current == original && original.duration(30) == 19 && model.history.length == 0,
            "The replicated queen combat flag preserves the encounter between miniboss phases");
        queen.phase = 3; hero.isInCombat = true; collector.combatEnter("me", 31);
        damage._kill = false; damage._amount = 300.; collector.damage(queen, damage, 32);
        check(model.current == original && original.start == 11 && original.players["me"].damage == 500,
            "The attackable queen resumes the same timer and damage totals");
        damage._kill = true; damage._amount = 400.; collector.damage(queen, damage, 40);
        queen.dead = true; queen.isInCombat = false; hero.isInCombat = false;
        collector.combatExit("me", 40); collector.update(app, 41);
        check(model.history.length == 1 && model.history[0].outcome == "Victory"
            && model.history[0].duration() == 29 && model.history[0].players["me"].damage == 900,
            "The final boss death saves one complete encounter, including the miniboss damage");

        // Same layer can host a fresh attempt with a new boss entity.
        var nextQueen:Dynamic = {__uid:"next-queen", kind:"Cleodora", name:"Queen Honeyzabeth", layer:layer,
            isInCombat:true, inf:{flags:0x10}, _level:20, foeId:9};
        layer.units = [queen, nextQueen, mini]; collector.update(app, 45);
        check(model.dungeonBoss.uid == "next-queen", "A dead cached queen does not hide a new attempt's boss entity");
        hero.isInCombat = true; collector.combatEnter("me", 50);
        damage._kill = true; damage._amount = 25.; collector.damage(mini, damage, 51);
        hero.isInCombat = false; collector.combatExit("me", 52);
        nextQueen.isInCombat = false; collector.update(app, 53); collector.update(app, 54);
        check(model.current == null && model.history.length == 2 && model.history[1].outcome == "Defeat"
            && model.history[1].start == 51 && model.history[1].players["me"].damage == 25,
            "A queen reset closes an early wipe without importing damage from the prior attempt");

        hero.isInCombat = true; collector.combatEnter("me", 60);
        nextQueen.isInCombat = true;
        damage._kill = true; collector.damage(nextQueen, damage, 61);
        check(model.current.defeated == false, "Lethal-looking queen damage does not itself confirm her death");
        // isDead() includes removed entities in the real client. Unloading
        // must not turn a wipe into a win, even if other goals are completed.
        nextQueen.removed = true; altObjective.completed = true;
        hero.isInCombat = false; collector.update(app, 62); collector.update(app, 63);
        check(model.history.length == 3 && model.history[2].outcome == "Defeat",
            "An unloaded queen and completed miniboss/alternate goals cannot confirm victory");

        hero.isInCombat = true; collector.combatEnter("me", 70);
        damage._kill = true; collector.damage(mini, damage, 71);
        objective.completed = true; hero.isInCombat = false;
        collector.update(app, 72); collector.update(app, 73);
        check(model.history.length == 4 && model.history[3].outcome == "Victory",
            "The queen's own completed objective confirms death when her entity is no longer visible");
        Sys.println("Honeyzabeth client collector: " + checks + " checks passed");
    }
}
