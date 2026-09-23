import itemutilities.InspectMenuContext;

class InspectMenuContextTest {
    static var checks = 0;
    static function check(value:Bool, message:String):Void {
        checks++;
        if (!value) throw message;
    }
    static function main():Void {
        var context = new InspectMenuContext();
        var gameUI:Dynamic = {}, anotherUI:Dynamic = {};
        check(context.take(gameUI) == null, "ordinary item context menus must not get Inspect");
        context.begin(gameUI, "player-A", "Alice", true);
        check(context.take(anotherUI) == null, "another UI cannot consume a social-menu target");
        var target = context.take(gameUI);
        check(target != null && target.uid == "player-A" && target.name == "Alice", "Inspect keeps the selected player's identity");
        check(context.take(gameUI) == null, "nested/subsequent menus do not receive duplicate Inspect entries");
        context.begin(gameUI, "player-A", "Alice", true);
        context.clear();
        check(context.take(gameUI) == null, "a social menu that returns early cannot leak into the next context menu");
        context.begin(gameUI, "player-A", "Alice", true);
        context.begin(gameUI, "player-B", "Bob", true);
        check(context.take(gameUI).uid == "player-B", "switching targets cannot inspect the previous player");
        for (uid in [null, ""]) {
            context.begin(gameUI, uid, "Alice", true);
            check(context.take(gameUI) == null, "a name alone cannot identify an inspect target");
        }
        context.begin(gameUI, "player-A", "Alice", false);
        check(context.take(gameUI) == null, "disabling Item Utilities suppresses Inspect");
        for (send in ["Send message", "Envoyer un message", "Enviar mensaje", "メッセージを送信"]) {
            check(InspectMenuContext.insertionIndex([send, "Add friend", "Invite to group"], send) == 1,
                "Inspect follows Send message in every game language");
            check(InspectMenuContext.insertionIndex(["Duel", send, "Ignore"], send) == 2,
                "insertion follows the real action if native ordering changes");
        }
        check(InspectMenuContext.insertionIndex(["Sell", "Drop"], "Send message") == -1,
            "never insert into unrelated context menus");
        check(InspectMenuContext.insertionIndex(["", "Send message"], "") == -1,
            "missing localization must not match a blank separator");
        trace('Inspect menu: $checks checks passed');
    }
}
