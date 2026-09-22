import itemutilities.PresetSlots;
import itemutilities.OverlayRect;
import itemutilities.SkillPresetLayout;
import itemutilities.SkillPresetPlan;
import itemutilities.SkillPresetPlan.SavedSkillSlot;
import itemutilities.SkillPresetPlan.SkillPresetState;
import itemutilities.SkillPresetPlan.SkillPresetRules;
import itemutilities.SkillPresetTransfer;
import itemutilities.UiOverlayGeometry;

class SkillPresetTest {
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
    static function rules(maxRunes:Int = 1):SkillPresetRules return {
        skills: ["A" => ["A1", "A2", "A3"], "B" => ["B1", "B2"], "C" => [], "D" => ["D1"]],
        unlockedSlots: [true, true, true, true], maxRunes: maxRunes
    };
    static function owners():Map<String, String> return [
        "A1" => "A", "A2" => "A", "A3" => "A", "B1" => "B", "B2" => "B", "D1" => "D", "X1" => "X"
    ];
    static function saved(skills:Array<String>, runes:Array<String>):Array<SavedSkillSlot> {
        return SkillPresetPlan.saved({slots: skills, runes: runes}, owners());
    }
    static function jsonSlots(value:Dynamic):Array<SavedSkillSlot> {
        return SkillPresetPlan.decode(haxe.Json.parse(haxe.Json.stringify(value)));
    }
    static function main():Void {
        var current:SkillPresetState = {slots: ["A", "B", "C", "D"], runes: ["A1", "B1", "D1", "X1"]};
        var target = saved(["B", "C", "D", "A"], ["A2", "B2", "D1"]);
        var plan = SkillPresetPlan.build(current, target, rules(), owners());
        check(plan.length > 0, "different skills and runes produce a plan");
        var state = SkillPresetPlan.copy(current);
        for (change in plan) {
            if (change.slot >= 0) state.slots[change.slot] = change.skill;
            else if (change.enable) state.runes.push(change.rune);
            else state.runes.remove(change.rune);
            check(SkillPresetPlan.same(state, change.after), "expected state matches independent server operation");
            var seen:Array<String> = [];
            for (skill in state.slots) {
                if (skill == null) continue;
                check(seen.indexOf(skill) < 0, "swapping never temporarily equips a skill twice");
                seen.push(skill);
            }
            for (skill in ["A", "B", "C", "D"])
                check([for (r in state.runes) if (owners().get(r) == skill) r].length <= 1,
                    "remove old rune before adding its replacement");
        }
        check(SkillPresetPlan.same(state, {slots: ["B", "C", "D", "A"], runes: ["A2", "B2", "D1", "X1"]}),
            "exact saved order and runes restored; unrelated skill rune retained");
        check(current.slots[0] == "A" && current.runes.indexOf("A1") >= 0, "planning does not mutate input");
        check(SkillPresetPlan.build(state, target, rules(), owners()).length == 0, "already-active preset sends nothing");

        for (runes in [[], ["A1"], ["A1", "A2"]]) {
            var value = jsonSlots(saved(["A", null, null, null], runes));
            check(value[0].runes.join(",") == runes.join(","), "zero, one, and multiple runes round-trip exactly");
            check(value[1].skill == null && value[1].runes.length == 0, "empty slots remain empty in JSON");
            SkillPresetPlan.validate(value, rules(2));
        }
        var oneRune = jsonSlots(saved(["A", null, null, null], ["A1"]));
        var twoCurrent:SkillPresetState = {slots: ["A", null, null, null], runes: ["A1", "A2", "X1"]};
        var removeExtra = SkillPresetPlan.build(twoCurrent, oneRune, rules(2), owners());
        check(removeExtra.length == 1 && removeExtra[0].rune == "A2" && !removeExtra[0].enable,
            "one-rune preset removes the extra rune even when skill is already equipped");
        var noRunes = saved(["A", null, null, null], []);
        var clearRunes = SkillPresetPlan.build(twoCurrent, noRunes, rules(2), owners());
        check(clearRunes.length == 2 && clearRunes[1].after.runes.join(",") == "X1", "saved no-rune choice clears that skill only");
        var empty = saved([null, null, null, null], []);
        var clearSlots = SkillPresetPlan.build(current, empty, rules(), owners());
        check(clearSlots.length == 4 && [for (s in clearSlots[3].after.slots) if (s != null) s].length == 0,
            "empty preset clears all four slots");
        check(clearSlots[3].after.runes.length == current.runes.length, "clearing slots leaves unequipped skill rune preferences alone");
        var partial = SkillPresetPlan.build(current, saved(["D", null, "A", null], ["A1", "D1"]), rules(), owners());
        check(SkillPresetPlan.same(partial[partial.length - 1].after,
            {slots: ["D", null, "A", null], runes: current.runes}), "partial preset preserves gaps and slot order");
        var multi = SkillPresetPlan.build(twoCurrent, saved(["A", null, null, null], ["A2", "A3"]), rules(2), owners());
        check(multi.length == 2 && !multi[0].enable && multi[1].enable, "future two-rune swaps preserve shared rune");

        rejects(function() SkillPresetPlan.decode(null), "missing preset is not an empty build");
        rejects(function() SkillPresetPlan.decode([]), "missing slots rejected");
        rejects(function() SkillPresetPlan.decode([{skill: "A", runes: ["A1", "A1"]}, empty[1], empty[2], empty[3]]), "duplicate rune rejected");
        rejects(function() SkillPresetPlan.decode([{skill: "A"}, empty[1], empty[2], empty[3]]), "missing rune selection rejected");
        rejects(function() SkillPresetPlan.decode([{skill: null, runes: ["A1"]}, empty[1], empty[2], empty[3]]), "runes on empty slot rejected");
        rejects(function() SkillPresetPlan.decode([{skill: 5, runes: []}, empty[1], empty[2], empty[3]]), "malformed skill ID rejected");
        rejects(function() SkillPresetPlan.build(current, saved(["A", "A", null, null], []), rules(), owners()), "duplicate skills rejected before changes");
        rejects(function() SkillPresetPlan.build(current, saved(["unknown", null, null, null], []), rules(), owners()), "unknown or locked skill rejected before changes");
        var wrongRune = oneRune.copy();
        wrongRune[0] = {skill: "A", runes: ["B1"]};
        rejects(function() SkillPresetPlan.build(current, wrongRune, rules(), owners()), "rune from different skill rejected");
        var unlearned = rules();
        unlearned.skills.set("A", ["A2"]);
        rejects(function() SkillPresetPlan.build(current, oneRune, unlearned, owners()), "unlearned rune rejected before any slot changes");
        rejects(function() SkillPresetPlan.build(current, saved(["A", null, null, null], ["A1", "A2"]), rules(), owners()), "current one-rune cap enforced");
        var lockedSlot = rules();
        lockedSlot.unlockedSlots[0] = false;
        rejects(function() SkillPresetPlan.build(current, oneRune, lockedSlot, owners()), "locked destination slot rejected");

        var transfer = new SkillPresetTransfer();
        var session = {};
        check(transfer.start(session, current, plan), "start sequence");
        state = SkillPresetPlan.copy(current);
        var time = 0.0;
        var sent = 0;
        while (transfer.active) {
            var change = transfer.next(session, time, state);
            if (change == null) break;
            sent++;
            check(transfer.next(session, time + 0.01, state) == null, "only one request in flight");
            if (change.slot < 0) {
                check(!transfer.needsState(), "no array scan while waiting for rune reply");
                check(transfer.next(session, time + 0.02, change.after) == null, "rune replication does not replace RPC reply");
                transfer.acknowledge(transfer.requestId, true);
                check(transfer.next(session, time + 0.03, state) == null, "rune reply does not replace replicated data");
            } else check(transfer.needsState(), "slot RPC without callback waits for authoritative data");
            state = SkillPresetPlan.copy(change.after);
            time += 0.1;
        }
        check(sent == plan.length && !transfer.active && transfer.error == "", "all skill and rune changes confirmed");

        transfer.start(session, current, plan);
        transfer.next(session, 0, current);
        check(!transfer.start(session, current, plan), "repeated hotkeys do not overlap sequences");
        check(transfer.next(session, 5, current) == null && !transfer.active, "slot replication timeout stops without retries");
        transfer.start(session, current, plan);
        transfer.next(session, 0, current);
        check(transfer.next({}, 0.1, current) == null && !transfer.active, "character switch stops pending slots");
        transfer.start(session, current, plan);
        check(transfer.next(session, 0, state) == null && !transfer.active, "manual changes before request cancel sequence");
        transfer.start(session, twoCurrent, removeExtra);
        transfer.next(session, 0, twoCurrent);
        var oldId = transfer.requestId;
        transfer.acknowledge(oldId, false);
        check(!transfer.active && transfer.error != "", "rune rejection stops sequence");
        transfer.start(session, twoCurrent, removeExtra);
        transfer.next(session, 0, twoCurrent);
        transfer.acknowledge(oldId, true);
        check(!transfer.needsState(), "old reply cannot acknowledge a new request");
        check(transfer.next(session, 5, null) == null && !transfer.active, "missing rune reply times out");
        transfer.acknowledge(transfer.requestId, true);
        check(!transfer.active, "late reply cannot restart timed-out sequence");
        transfer.start(session, twoCurrent, removeExtra);
        transfer.next(session, 0, twoCurrent);
        transfer.acknowledge(transfer.requestId, true);
        check(transfer.next(session, 5, twoCurrent) == null && !transfer.active, "rune replication timeout stops sequence");
        transfer.start(session, twoCurrent, removeExtra);
        transfer.next(session, 0, twoCurrent);
        transfer.acknowledge(transfer.requestId, true);
        check(transfer.next(session, 0.1, current) == null && !transfer.active, "unexpected manual change after reply cancels sequence");
        transfer.start(session, current, plan);
        transfer.cancel("Entered combat");
        check(transfer.next(session, 0, current) == null, "combat or disabled mod cancellation prevents later requests");

        for (scale in [0.625, 0.75, 1.0, 1.5, 2.0]) {
            var transform = new UiOverlayGeometry(scale, 0, 0, scale, 100, 50);
            var footer = transform.rect(8, 648, 1185, 94);
            var texts = transform.rect(342, 674, 190, 43);
            var controls = transform.rect(0, 0, PresetSlots.CONTROLS_WIDTH, 36);
            var rect = SkillPresetLayout.place(footer, texts, controls);
            near(rect.left, 100 + 975 * scale, "right-aligned preset bar");
            near(rect.top, 50 + 677 * scale, "vertically centered in white footer");
            near(footer.right - rect.right, 16 * scale, "scaled right padding");
            near(rect.width, PresetSlots.CONTROLS_WIDTH * scale, "matching equipment and talent width");
            near(rect.height, 36 * scale, "matching equipment and talent height");
        }
        var narrow = SkillPresetLayout.place(new OverlayRect(0, 0, 600, 90), new OverlayRect(100, 10, 400, 70), new OverlayRect(0, 0, PresetSlots.CONTROLS_WIDTH, 36));
        check(narrow.left > 400 && narrow.right < 600 && narrow.width < PresetSlots.CONTROLS_WIDTH, "narrow footer fits controls without overlapping counts");
        check(SkillPresetLayout.place(null, null, null) == null, "missing anchors hide the bar");
        trace('Skill presets: $checks checks passed');
    }
}
