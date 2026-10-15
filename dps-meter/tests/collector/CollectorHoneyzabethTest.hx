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
        var objective = {kind:"KillBoss", target:HoneyObjectiveTarget.Unit("Cleodora")};
        var layer:Dynamic = {isRift:false, config:{activityID:"HoneyArena", difficulty:2},
            mainActivity:{kind:"HoneyArena", globalCtx:{objectives:{array:[objective]}}}};
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
            "The shared dungeon objective identifies Honeyzabeth without starting an idle player's timer");
        check(model.dungeonBoss.uid == "", "Missing replicated queen and unit definitions do not interrupt collection");
        layer.units = [queen, mini]; collector.update(app, 2);
        check(model.dungeonBoss.uid == "queen", "A late replicated queen fills in the dungeon encounter identity");
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
        Sys.println("Honeyzabeth client collector: " + checks + " checks passed");
    }
}
