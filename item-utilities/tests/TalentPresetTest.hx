import itemutilities.PresetSlots;
import itemutilities.OverlayRect;
import itemutilities.TalentPresetLayout;
import itemutilities.TalentPresetPlan;
import itemutilities.TalentPresetPlan.TalentRule;
import itemutilities.TalentPresetTransfer;
import itemutilities.UiOverlayGeometry;

class TalentPresetTest {
    static var checks = 0;

    static function check(value:Bool, message:String):Void {
        checks++;
        if (!value) throw message;
    }

    static function near(value:Float, expected:Float, message:String):Void {
        check(Math.abs(value - expected) < 0.00001, message + ': expected $expected, got $value');
    }

    static function rejects(action:Void->Void, message:String):Void {
        var rejected = false;
        try action() catch (_:Dynamic) rejected = true;
        check(rejected, message);
    }

    static function rules():Array<TalentRule> {
        // The live/PTR tree shape: shared root, three branches, thresholds
        // [0, 1, 2, 4, 8], and up to two ranks in the middle tiers.
        var result:Array<TalentRule> = [
            {skill: "root", root: "root", tier: 0, branch: 0, maxRank: 1, threshold: 0}
        ];
        for (branch in 1...4) {
            for (tier in 1...5) {
                var count = [0, 1, 2, 3, 1][tier];
                for (i in 0...count)
                    result.push({skill: 'b${branch}t${tier}n$i', root: "root",
                        branch: branch, tier: tier, maxRank: tier == 2 || tier == 3 ? 2 : 1,
                        threshold: [0, 1, 2, 4, 8][tier]});
            }
        }
        return result;
    }

    static function build(branch:Int):Map<String, Int> {
        return ["root" => 1, 'b${branch}t1n0' => 1, 'b${branch}t2n0' => 2,
            'b${branch}t2n1' => 2, 'b${branch}t3n0' => 2, 'b${branch}t3n1' => 2,
            'b${branch}t4n0' => 1];
    }

    static function main():Void {
        var tree = rules();
        var current = build(1);
        var target = build(3);
        var commands = TalentPresetPlan.build(tree, current, target, 15);
        check(commands.length == 8, "one refund request plus one request per desired talent");
        check(commands[0].skill == "root" && commands[0].rank == 0, "refund through the root talent");
        check(!commands[0].after.keys().hasNext(), "root removal refunds all dependent tiers");
        var lastTier = -1;
        for (i in 1...commands.length) {
            var command = commands[i];
            var rule = [for (rule in tree) if (rule.skill == command.skill) rule][0];
            check(rule.tier >= lastTier, "apply prerequisites before dependent tiers");
            lastTier = rule.tier;
            TalentPresetPlan.validate(tree, command.after, 15);
            checks++;
        }
        check(TalentPresetPlan.same(commands[commands.length - 1].after, target), "plan reaches the exact saved build");
        check(TalentPresetPlan.same(current, build(1)), "planning does not change current talents");
        check(TalentPresetPlan.build(tree, current, current, 15).length == 0, "already-active preset sends no requests");
        check(TalentPresetPlan.build(tree, current, new Map(), 15).length == 1, "saved empty build refunds points");
        check(TalentPresetPlan.build(tree, new Map(), target, 15).length == 7, "empty current build needs no refund");
        check(TalentPresetPlan.same(TalentPresetPlan.decode(TalentPresetPlan.encode(target)), target), "JSON records round-trip");
        var json = haxe.Json.stringify(TalentPresetPlan.encode(target));
        check(TalentPresetPlan.same(TalentPresetPlan.decode(haxe.Json.parse(json)), target), "config JSON round-trip");
        rejects(function() TalentPresetPlan.decode(null), "missing saved build is not an empty build");
        rejects(function() TalentPresetPlan.decode([{skill: "root", rank: 1}, {skill: "root", rank: 1}]), "duplicate ranks rejected");
        rejects(function() TalentPresetPlan.decode([{skill: "root", rank: 0.5}]), "fractional ranks rejected");
        rejects(function() TalentPresetPlan.decode([{skill: "root", rank: -1}]), "negative ranks rejected");
        rejects(function() TalentPresetPlan.decode([{skill: "root", rank: "1"}]), "string ranks rejected");
        rejects(function() TalentPresetPlan.build(tree, current, target, 5), "insufficient points rejected before refund");
        var unknown = target.copy();
        unknown.set("removed-talent", 1);
        rejects(function() TalentPresetPlan.build(tree, current, unknown, 20), "outdated talent rejected before refund");
        var excessive = target.copy();
        excessive.set("b3t2n0", 3);
        rejects(function() TalentPresetPlan.build(tree, current, excessive, 20), "rank cap enforced");
        var missingRoot = target.copy();
        missingRoot.remove("root");
        rejects(function() TalentPresetPlan.build(tree, current, missingRoot, 20), "root prerequisite enforced");
        var wrongBranch = build(1);
        wrongBranch.set("b3t4n0", 1);
        rejects(function() TalentPresetPlan.build(tree, current, wrongBranch, 20), "other branches do not satisfy prerequisites");
        var multipleTrees = tree.copy();
        multipleTrees.push({skill: "root2", root: "root2", tier: 0, branch: 0, maxRank: 1, threshold: 0});
        var both = target.copy();
        both.set("root2", 1);
        rejects(function() TalentPresetPlan.build(multipleTrees, current, both, 20), "multiple active trees rejected");

        var session = {};
        var transfer = new TalentPresetTransfer();
        check(transfer.start(session, current, commands), "start transfer");
        var state = current.copy();
        var time = 0.0;
        var sent = 0;
        while (transfer.active) {
            var next = transfer.next(session, time, state);
            if (next == null) break;
            sent++;
            var id = transfer.requestId;
            check(!transfer.needsRanks(), "no rank scans while waiting for reply");
            check(transfer.next(session, time + 0.01, null) == null, "only one request in flight");
            transfer.acknowledge(id, true);
            check(transfer.needsRanks(), "replication must be observed after acknowledgement");
            check(transfer.next(session, time + 0.02, state) == null, "reply alone cannot advance before replicated ranks");
            state = next.after.copy();
            time += 0.1;
        }
        check(sent == commands.length && !transfer.active && transfer.error == "", "complete serialized transfer");
        check(TalentPresetPlan.same(state, target), "confirmed server state matches target");

        transfer.start(session, current, commands);
        var first = transfer.next(session, 0, current);
        var oldId = transfer.requestId;
        check(transfer.next(session, 0.1, first.after) == null, "replication alone does not replace acknowledgement");
        check(!transfer.start(session, current, commands), "repeated hotkey cannot start a concurrent transfer");
        transfer.acknowledge(oldId, false);
        check(!transfer.active && transfer.error != "", "server rejection stops immediately");

        transfer.start(session, current, commands);
        transfer.next(session, 0, current);
        transfer.acknowledge(oldId, true);
        check(!transfer.needsRanks(), "late callback from prior transfer ignored");
        check(transfer.next(session, 5, null) == null && !transfer.active, "missing reply times out without retries");
        transfer.acknowledge(transfer.requestId, true);
        check(!transfer.active, "reply after timeout cannot restart transfer");

        transfer.start(session, current, commands);
        transfer.next(session, 0, current);
        check(transfer.next({}, 0.1, null) == null && !transfer.active, "character/session change cancels pending work");
        transfer.start(session, current, commands);
        check(transfer.next(session, 0, target) == null && !transfer.active, "manual changes before sending cancel work");
        transfer.start(session, current, commands);
        transfer.next(session, 0, current);
        transfer.acknowledge(transfer.requestId, true);
        check(transfer.next(session, 0.1, target) == null && !transfer.active, "unexpected ranks after reply cancel work");
        transfer.start(session, current, commands);
        transfer.next(session, 0, current);
        transfer.acknowledge(transfer.requestId, true);
        check(transfer.next(session, 5, current) == null && !transfer.active, "missing replicated state times out");
        transfer.start(session, current, commands);
        transfer.cancel();
        check(transfer.next(session, 0, current) == null, "disabled mod sends no further requests");

        // Screenshot anchors, then the same layout after scaling and moving.
        for (scale in [0.625, 0.75, 1.0, 1.5, 2.0]) {
            var projection = new UiOverlayGeometry(scale, 0, 0, scale, 100, 50);
            var points = projection.rect(56, 85, 241, 39);
            var root = projection.rect(338, 56, 106, 107);
            var treeRect = projection.rect(5, 35, 771, 700);
            var controls = projection.rect(0, 0, PresetSlots.CONTROLS_WIDTH, 36);
            var placed = TalentPresetLayout.place(points, root, treeRect, controls);
            near(placed.left, 100 + 509 * scale, "horizontal placement");
            near(placed.top, 50 + 86.5 * scale, "points-row alignment");
            near(placed.width, PresetSlots.CONTROLS_WIDTH * scale, "equipment-matching width");
            near(placed.height, 36 * scale, "equipment-matching height");
            near((placed.left + placed.right) / 2, (root.right + treeRect.right) / 2,
                "centered between top talent and description");
        }
        var narrow = TalentPresetLayout.place(new OverlayRect(0, 20, 100, 60),
            new OverlayRect(100, 0, 200, 100), new OverlayRect(0, 0, 350, 600),
            new OverlayRect(0, 0, PresetSlots.CONTROLS_WIDTH, 36));
        check(narrow.left > 200 && narrow.right < 350, "narrow panels fit without overlapping talent/description");
        check(TalentPresetLayout.place(null, null, null, null) == null, "missing anchors do not draw detached UI");
        trace('Talent presets: $checks checks passed');
    }
}
