package trade;
import trade.GameAccess as G;
class TradeMovement {
    var hero:Dynamic;
    var nativeController:Dynamic;
    var sessionId = "";
    var target:Dynamic;
    var targetSince = -1.0;
    var gatherSince = -1.0;
    var gathered = false;
    var nextMove = 0.0;
    var lastDrive = -1.0;
    public var status = "";
    public function new() {}
    public function ready(now:Float):Bool return hero != null && now-lastDrive <= 0.25;
    public function holding(controller:Dynamic,hero:Dynamic,session:TradeSession):Bool return this.hero != null && this.hero == hero
        && nativeController == controller && controller != null && session != null && sessionId == session.id
        && G.field(controller,"unit") == hero && G.field(controller,"overrideController") == null && G.field(controller,"currentJobFunc") == null && G.field(hero,"removed") != true;
    public function drive(controller:Dynamic,hero:Dynamic,peer:Dynamic,session:TradeSession,collection:Dynamic,now:Float):String {
        if (controller == null || G.field(controller,"unit") != hero || G.field(controller,"overrideController") != null) return "The local character controller is unavailable.";
        if (G.field(controller,"currentJobFunc") != null) return "Finish your current action before trading.";
        if (hero == null || G.field(hero,"removed") == true) return "Your character is unavailable.";
        if (this.hero != hero || nativeController != controller || sessionId != session.id) {
            release(); this.hero = hero; nativeController = controller; sessionId = session.id;
            G.call("client.PlayerController","leaveLock",controller); G.set(controller,"autoForward",false);
            G.set(controller,"requestAttack",-1.0);
            for (key in ["requestedSkillInput","requestedSkillKind","requestedSkillType"]) G.set(controller,key,null);
            for (key in ["requestedSkillTime","requestJumpTime","requestGlideTime"]) G.set(controller,key,-1.0);
        }
        lastDrive = now; G.call("client.UnitController","stopMoveInputs",controller); G.call("ent.Unit","set_sprinting",hero,[false]); status = "";
        if (session.phase == "offering" && !session.leader && !gathered && peer != null) {
            if (gatherSince < 0) gatherSince = now;
            var a = G.field(hero,"position"), b = G.field(peer,"position");
            var x = G.number(G.field(a,"x"))-G.number(G.field(b,"x")), y = G.number(G.field(a,"y"))-G.number(G.field(b,"y"));
            if (x*x+y*y <= 0.25 || now-gatherSince >= 5) gathered = true;
            else { status = "Moving together..."; walkTo(peer,now); }
            return "";
        }
        if (session.phase != "exchanging" || collection == null || G.field(collection,"removed") == true) {
            target = null; targetSince = -1; stop(); return "";
        }
        if (target != collection) { target = collection; targetSince = now; nextMove = 0; }
        if (now-targetSince >= 5) return "Could not reach the offered item within 5 seconds. Check the items on the ground.";
        var range = G.number(G.call("ent.interactible.LootDrop","getInteractRange",collection),5);
        if (TradeInventory.distance(hero,collection) <= Math.max(0.1,range-0.35)) { stop(); return ""; }
        return walkTo(collection,now);
    }
    function walkTo(destination:Dynamic,now:Float):String {
        var p = G.field(destination,"position"), x = G.number(G.field(p,"x"),Math.NaN), y = G.number(G.field(p,"y"),Math.NaN), z = G.number(G.field(p,"z"),Math.NaN);
        if (!Math.isFinite(x) || !Math.isFinite(y) || !Math.isFinite(z)) return "The trade destination is unavailable.";
        var mode = G.enumName(G.call("ent.Unit","get_moveMode",hero));
        if (G.field(hero,"inCutscene") == true || G.field(hero,"gliding") == true || G.call("ent.Hero","isMounted",hero) == true
            || G.call("ent.Unit","isUsingVehicle",hero) == true) return "Cannot walk to the offered item right now.";
        if (["Relative","Stop","Point"].indexOf(mode) < 0 || G.call("ent.Unit","canMove",hero) != true) return "";
        if (now >= nextMove) { nextMove = now+0.25; G.call("ent.Unit","requestMoveTo",hero,[G.vector(x,y,z),null]); }
        return "";
    }
    function stop():Void {
        var mode = G.enumName(G.call("ent.Unit","get_moveMode",hero));
        if (mode == "Relative" || mode == "Point") G.call("ent.Unit","requestMoveMode",hero,[G.enumeration("ent.MoveMode","Stop")]);
    }
    public function release():Void {
        var oldHero = hero, oldController = nativeController;
        hero = nativeController = target = null; sessionId = ""; targetSince = gatherSince = lastDrive = -1; gathered = false; nextMove = 0; status = "";
        if (oldHero != null && G.field(oldHero,"removed") != true) {
            if (oldController != null && G.field(oldController,"unit") == oldHero) G.call("client.UnitController","stopMoveInputs",oldController);
            var mode = G.enumName(G.call("ent.Unit","get_moveMode",oldHero));
            if (mode == "Point" || mode == "Stop") G.call("ent.Unit","requestMoveMode",oldHero,[G.enumeration("ent.MoveMode","Relative")]);
        }
    }
}
