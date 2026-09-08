package dpsmeter;

import dpsmeter.MeterConfig.MeterSettings;
import dpsmeter.GameAccess as G;

/** Observe the local character's saved counters, including shared kill credit. */
class KillNotifications {
    var config:MeterSettings;
    var popups:NativeKillPopups;
    var hero:Dynamic;
    var layer:Dynamic;
    var progress:Dynamic;
    var counts:Map<String, Int> = [];
    var ready:Bool = false;
    var dirty:Bool = true;
    var nextRead:Float = 0;

    public function new(config:MeterSettings) {
        this.config = config;
        popups = new NativeKillPopups(config);
    }

    public function synced(object:Dynamic):Void {
        if (object == progress) dirty = true;
    }

    public function update(app:Dynamic, now:Float):Void {
        var nextHero = G.field(app, "hero");
        var nextLayer = G.field(nextHero, "layer");
        var nextProgress = G.field(G.field(nextHero, "player"), "progress");
        if (nextHero != hero || nextLayer != layer || nextProgress != progress) {
            hero = nextHero; layer = nextLayer; progress = nextProgress;
            ready = false; dirty = true; counts = []; nextRead = 0;
            popups.clear();
        }
        popups.update(hero != null && config.enabled, now);
        if (hero == null || progress == null || (!dirty && ready) || now < nextRead) return;
        var map = G.field(G.field(progress, "unitsProgress"), "map");
        if (map == null) return;
        nextRead = now + 0.2;
        var snapshot:Map<String, Int> = [];
        var keys = G.call("haxe.ds.StringMap", "keys", map);
        var iteratorType = "haxe.ds._StringMap.StringMapKeysIterator";
        while (G.call(iteratorType, "hasNext", keys) == true) {
            var id = G.text(G.call(iteratorType, "next", keys));
            var data = G.call("haxe.ds.StringMap", "get", map, [id]);
            snapshot[id] = G.integer(G.field(data, "killCount"));
        }
        var previous = counts;
        counts = snapshot; dirty = false;
        // Loading a character or instance establishes history without replaying it.
        if (!ready) { ready = true; return; }
        if (!config.enabled) return;
        for (id => count in snapshot) {
            var before = previous.exists(id) ? previous[id] : 0;
            if (count > before) try show(id, before, count, now) catch (_:Dynamic) {}
        }
    }

    function show(id:String, before:Int, count:Int, now:Float):Void {
        var units = G.field(G.current("Data", "unit"), "byId");
        var unit = G.call("haxe.ds.StringMap", "get", units, [id]);
        if (unit == null) return;
        var boss = (G.integer(G.field(unit, "flags")) & 0x38) != 0;
        var category = "boss";
        var goal = 0;
        if (boss) {
            if (!config.showBossKills) return;
        } else {
            if (G.staticCall("data.CodexData", "isInCodex", [unit]) != true) return;
            var thresholds = G.array(G.staticCall("st.player.Progress", "getUnitProgressThreshold", [unit]));
            var rewardIndex = G.integer(G.field(G.current("Const", "Codex"), "FoeXPRewardThresholdIndex")) - 1;
            if (rewardIndex < 0 || rewardIndex >= thresholds.length) return;
            goal = G.integer(thresholds[rewardIndex]);
            if (goal <= 0) return;
            // Include the rewarding kill in incomplete-entry notifications.
            // Later Codex ranks do not change whether the XP reward was earned.
            category = before < goal ? "incomplete" : "completed";
            if (count > goal && config.showCompletedCodexKills) category = "completed";
            if (category == "incomplete" ? !config.showIncompleteCodexKills : !config.showCompletedCodexKills) return;
        }
        var name = G.text(G.staticCall("HText", "unit", [unit, null]), id);
        var total = category == "incomplete" ? Std.int(Math.min(count, goal)) + " / " + goal : Std.string(count);
        popups.show(id, name + ": " + total + (count == 1 && category != "incomplete" ? " kill" : " kills"),
            category, count, goal, now);
    }
}
