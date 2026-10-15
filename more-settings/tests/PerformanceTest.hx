import moresettings.FeedBacklog;
import moresettings.SettingsData;
import moresettings.GameAccess as G;

class PerformanceTest {
    static var checks = 0;
    static function eq(a:Dynamic, b:Dynamic, message:String):Void {
        checks++;
        if (a != b) throw '$message: expected $b, got $a';
    }
    static function nativeArray(items:Array<Dynamic>):Dynamic return {items: items, length: items.length};
    static function push(array:Dynamic, value:Dynamic):Void {
        array.items.push(value); array.length = array.items.length;
    }
    static function main():Void {
        eq(SettingsData.defaults().performanceOptimization, false, "existing installations stay opt-in");
        feed();
        Sys.println('Performance optimization: $checks checks passed.');
    }

    static function row(kind:String, elapsed:Float):Dynamic return {
        elapsed: elapsed, elt: {parent: {}, dom: {classes: [kind]}}
    };

    static function addNative(feed:Dynamic, kind:String):Dynamic {
        FeedBacklog.trim(feed);
        var elapsed = 0.0;
        for (line in (cast feed.activeLines.items:Array<Dynamic>))
            elapsed = Math.min(elapsed, line.elapsed - 0.15);
        var line = row(kind, elapsed);
        push(feed.activeLines, line);
        return line;
    }

    static function feed():Void {
        var feed:Dynamic = {activeLines: nativeArray([])};
        var notification = addNative(feed, "game-beat");
        var transition = addNative(feed, "combat");
        G.removedElements = 0;
        for (i in 0...1000) addNative(feed, i % 2 == 0 ? "damage" : "heal");
        eq(feed.activeLines.length, 32, "large burst cannot accumulate numeric rows indefinitely");
        eq(notification.elt.parent != null, true, "game-beat notification preserved");
        eq(transition.elt.parent != null, true, "combat transition preserved");
        eq(G.removedElements, 970, "removed numeric elements leave the scene graph");
        var min = 0.0;
        for (line in (cast feed.activeLines.items:Array<Dynamic>)) min = Math.min(min, line.elapsed);
        eq(min >= -4.66, true, "tail delay is bounded, not 150 seconds after 1000 hits");

        var important = [for (_ in 0...40) row("game-beat", 0)];
        var messages:Dynamic = {activeLines: nativeArray(important)};
        for (_ in 0...50) addNative(messages, "damage");
        eq(messages.activeLines.length, 41, "message-only overflow is preserved; numeric rows remain bounded");
        for (line in important) eq(line.elt.parent != null, true, "important message never dropped");

        var low = row("damage", -0.3);
        var normal:Dynamic = {activeLines: nativeArray([low])};
        FeedBacklog.trim(normal);
        eq(low.elapsed, -0.3, "ordinary feed timing stays native");
        eq(low.elt.parent != null, true, "ordinary feed elements stay attached");

        // Enabling with an existing backlog requires no prior tracking state.
        var backlog = [for (i in 0...100) row("damage", -0.15 * i)];
        var existing:Dynamic = {activeLines: nativeArray(backlog)};
        FeedBacklog.trim(existing);
        eq(existing.activeLines.length, 31, "existing backlog makes room for next native line");
        eq(existing.activeLines.items[30].elapsed >= -4.51, true, "existing delayed tail catches up");
    }
}
