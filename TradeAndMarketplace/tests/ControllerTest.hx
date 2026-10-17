import trade.*;

class ControllerTest {
    static var checks = 0;
    static var locked = false;
    static var nativeAllowed = true;
    static var gateCalls = 0;
    static var slot:Dynamic;
    static function check(value:Bool, message:String):Void { checks++; if (!value) throw message; }
    static function latestRed():Bool {
        var line = GameAccess.lines[GameAccess.lines.length - 1];
        return line != null && line.color == 0xEF5350 && line.style_color == 0xEF5350;
    }
    static function fixture():TradeController {
        locked = false; nativeAllowed = true; gateCalls = 0;
        GameAccess.lines = []; TradeChat.sent = [];
        var item:Dynamic = {__uid: "item", kind: "Copper", getName: () -> "Copper", maxStack: () -> 99};
        var inventory:Dynamic = {content: [{item: item, count: 4}], getFreeSize: () -> 10};
        // Models the hooked game's permission result (including Item Utilities locks).
        inventory.canRequestDropIndex = function(index:Int, manual:Bool, count:Null<Int>):Bool {
            gateCalls++; return index == 0 && manual && !locked && nativeAllowed;
        };
        var hero:Dynamic = {__uid: "hero", loadout: {inventory: inventory}, position: {x: 0, y: 0, z: 0}, isDead: () -> false};
        var peer:Dynamic = {uid: "peer", getName: () -> "Bob", hero: {position: {x: 0, y: 0, z: 0}, isDead: () -> false}};
        var me:Dynamic = {uid: "me", isMe: true, hero: hero, getName: () -> "Alice"};
        me.group = {players: {array: [me, peer]}}; GameAccess.app = {me: me};
        slot = {inventory: inventory, getIndex: () -> 0, dragCountOverride: 2};
        var controller = new TradeController(); controller.request("peer"); return controller;
    }
    static function offering(c:TradeController):Void {
        c.state.phase = "offering"; c.state.ack = c.state.revision; c.state.peerRevision = 0;
    }
    static function main() {
        var c = fixture(); c.update(GameAccess.app, haxe.Timer.stamp());
        check(TradeChat.sent.length == 1 && TradeChat.sent[0].to == "peer", "Invitation is whispered to the selected player");
        var text = TradeChat.sent[0].text;
        check(StringTools.startsWith(text, "Alice" + TradeWire.INVITE_TEXT), "Controller includes readable mod requirement in invitation");
        check(text.indexOf("If you can see this message, you need to install") >= 0, "Invitation explains why the reader sees it");
        var decoded = new TradeWire("T").receive("me", text, 0);
        check(decoded != null && decoded.op == "invite", "Readable invitation still decodes");
        offering(c); locked = true;
        check(c.addSlot(slot, false) && c.state.mine.length == 0 && gateCalls > 0, "Right-click cannot offer a locked item");
        check(latestRed() && GameAccess.lines[0].text == "This item is locked or cannot be dropped.", "Locked-item error is red in chat and CSS");
        check(c.addSlot(slot, true) && c.state.mine.length == 0, "Drag cannot offer a locked partial stack");
        locked = false; nativeAllowed = false;
        check(c.addSlot(slot, false) && c.state.mine.length == 0, "Native drop restrictions are also honored");
        nativeAllowed = true; c.addSlot(slot, true);
        check(c.state.mine.length == 1 && c.state.mine[0].count == 2, "Unlocked split stack can be offered");
        locked = true;
        check(c.inv.validate(c.state.mine).indexOf("locked") >= 0, "New lock is detected after offering");
        c.state.ack = c.state.revision; c.accept();
        check(!c.state.accepted && latestRed(), "Lock added before acceptance rejects with red error");
        c.update(GameAccess.app, haxe.Timer.stamp() + 1);
        check(c.state.phase == "cancelled" && !c.open && latestRed(), "Active validation cancels after locking");
        c = fixture(); offering(c); c.fail("test failure");
        check(!c.open && latestRed() && GameAccess.lines[0].text == "Trade stopped: test failure", "Runtime failure reports immediately in red");
        var count = GameAccess.lines.length; c.update(GameAccess.app, haxe.Timer.stamp());
        check(GameAccess.lines.length == count, "Cancellation is not reported twice");
        c = new TradeController(); c.fail("idle failure");
        check(latestRed(), "Runtime failure outside a session is visible");
        c.chat("Trade complete", true);
        var line = GameAccess.lines[GameAccess.lines.length - 1];
        check(line.color == 0x59DB70 && line.style_color == 0x59DB70, "Success remains green");
        Sys.println("Controller and inventory checks passed: " + checks);
    }
}
