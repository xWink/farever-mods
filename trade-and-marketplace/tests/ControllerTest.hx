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
        return line != null && line.color == 0xB9443A && line.style_color == 0xB9443A;
    }
    static function fixture(start = true):TradeController {
        locked = false; nativeAllowed = true; gateCalls = 0;
        TradeMod.resetPresence();
        GameAccess.lines = []; TradeChat.sent = []; TradeChat.delivered = true; TradeMod.rejectAllRequests = false;
        GameAccess.ui = {windows: [], get_chat: function() return {messages: {}}};
        var item:Dynamic = {__uid: "item", kind: "Copper", getName: () -> "Copper", maxStack: () -> 99, canStack: (other:Dynamic) -> other.kind == "Copper"};
        var inventory:Dynamic = {content: [{item: item, count: 4}], getFreeSize: () -> 10};
        // Models the hooked game's permission result (including Item Utilities locks).
        inventory.canRequestDropIndex = function(index:Int, manual:Bool, count:Null<Int>):Bool {
            gateCalls++; return index == 0 && manual && !locked && nativeAllowed;
        };
        inventory.checkRequestDropIndex = function(index:Int, manual:Bool, count:Null<Int>):String {
            return index == 0 && manual && nativeAllowed ? "Ok" : "NotAllowed_";
        };
        var hero:Dynamic = {__uid: "hero", loadout: {inventory: inventory}, position: {x: 0, y: 0, z: 0}, isDead: () -> false};
        var peer:Dynamic = {uid: "peer", getName: () -> "Bob", hero: {position: {x: 0, y: 0, z: 0}, isDead: () -> false}};
        var me:Dynamic = {uid: "me", isMe: true, hero: hero, getName: () -> "Alice"};
        me.group = {players: {array: [me, peer]}}; GameAccess.app = {me: me, isInCutscene: () -> false};
        slot = {inventory: inventory, getIndex: () -> 0, dragCountOverride: 2};
        var controller = new TradeController();
        if (start) {controller.request("peer");controller.update(GameAccess.app,haxe.Timer.stamp());} else controller.ensure(me);
        return controller;
    }
    static var inviteSequence = 0;
    static function invite(c:TradeController,id = "request",to = "me",sender = "peer"):Void {
        var encoder = new TradeWire("I"+(++inviteSequence));
        for (text in encoder.encode({id:id,to:to,op:"invite"},"Bob")) c.receive(null,{sender:sender},text);
    }
    static function sentPackets(includeReceipts=false):Array<Dynamic> {
        var decoder = new TradeWire("R"), packets:Array<Dynamic> = [];
        for (message in TradeChat.sent) {
            var packet = decoder.receive("me",message.text,0);
            if (packet != null && (includeReceipts || packet.op!="received")) packets.push(packet);
        }
        return packets;
    }
    static function rejection(c:TradeController,reason:String):Void {
        invite(c); c.update(GameAccess.app,haxe.Timer.stamp());
        var packets = sentPackets();
        check(c.state.phase == "idle" && !c.open && GameAccess.lines.length == 0, "Auto-reject leaves the receiver undisturbed");
        check(packets.length == 1 && packets[0].op == "cancel" && packets[0].id == "request"
            && packets[0].to == "peer" && packets[0].reason == reason, "Rejection carries the exact reason to the requester");
    }
    static function requestChecks():Void {
        var timed=fixture(),start=haxe.Timer.stamp();timed.update(GameAccess.app,start);
        timed.update(GameAccess.app,start+1);
        timed.update(GameAccess.app,start+10);
        check(timed.open&&timed.state.phase=="inviting"&&GameAccess.lines.length==0,"No receipt from an older mod does not close trade or report an error");
        for(text in new TradeWire("OLD").encode({id:timed.state.id,to:"me",op:"join"}))
            timed.receive(null,{sender:"peer"},text);
        timed.update(GameAccess.app,start+11);
        check(timed.open&&timed.state.phase=="offering","Older mod can accept without sending a receipt");
        var acknowledged=fixture(),now=haxe.Timer.stamp();acknowledged.update(GameAccess.app,now);
        for(text in new TradeWire("ACK").encode({id:acknowledged.state.id,to:"me",op:"received"}))
            acknowledged.receive(null,{sender:"peer"},text);
        acknowledged.update(GameAccess.app,now+1);
        check(acknowledged.open&&acknowledged.state.phase=="inviting"&&acknowledged.state.requestReceived,"Receipt is still read without accepting the trade");
        var c = fixture(false); invite(c);
        check(c.state.phase == "invited" && !c.open, "An available player receives a request without opening trade");
        invite(c); c.update(GameAccess.app,haxe.Timer.stamp());
        check(c.state.phase == "invited" && sentPackets().length == 0 && sentPackets(true).length == 1 && sentPackets(true)[0].op=="received", "Repeated delivery does not reject the accepted invitation");
        c = fixture(false); c.inv.hero.isInCombat = true;
        rejection(c,"Player is busy.");
        c.inv.hero.isInCombat = false; invite(c); c.update(GameAccess.app,haxe.Timer.stamp()+1);
        check(sentPackets().length == 1 && c.state.phase == "idle", "Rejected invitation is not replayed after combat ends");
        for (kind in ["InventoryUI","Options","DialogBar","BigMap"]) {
            c = fixture(false); GameAccess.ui.windows = [{kind:kind,parent:{},removed:false,visible:true}];
            rejection(c,"Player is busy.");
        }
        c = fixture(false); GameAccess.ui.contextMenu = {removed:false}; rejection(c,"Player is busy.");
        c = fixture(false); GameAccess.app.isInCutscene = () -> true; rejection(c,"Player is busy.");
        c = fixture(false);
        GameAccess.ui.windows = [{parent:{},removed:true},{parent:null},{parent:{},visible:false}];
        invite(c); check(c.state.phase == "invited", "Removed, detached and hidden windows do not mark the player busy");
        c = fixture(false); TradeMod.rejectAllRequests = true; c.inv.hero.isInCombat = true;
        rejection(c,"Player is not accepting trade requests.");
        c = fixture(false); TradeMod.rejectAllRequests = true;
        invite(c,"wrong-recipient","someone-else"); invite(c,"","me"); invite(c,"outsider","me","outsider");
        c.update(GameAccess.app,haxe.Timer.stamp());
        check(TradeChat.sent.length == 0, "Invalid, misaddressed and non-party invitations receive no reply");
        c = fixture(); offering(c);
        c.update(GameAccess.app,haxe.Timer.stamp()); TradeChat.sent = [];
        var id = c.state.id, peer = c.state.peer;
        c.player.group.players.array.push({uid:"other",getName:()->"Charlie"});
        invite(c,"other-request","me","other"); c.update(GameAccess.app,haxe.Timer.stamp()+1);
        var packets = sentPackets();
        check(c.state.id == id && c.state.peer == peer && c.state.phase == "offering" && c.open,
            "Rejecting another request preserves the active trade");
        check(packets.length == 1 && packets[0].id == "other-request" && packets[0].to == "other" && packets[0].reason == "Player is busy.",
            "Busy rejection belongs to the incoming request, not the active trade");
        TradeChat.delivered = false; invite(c,"undelivered"); c.update(GameAccess.app,haxe.Timer.stamp()+2);
        check(c.state.phase == "offering", "Failed rejection delivery cannot cancel the active trade");
        TradeChat.delivered = true; TradeChat.sent = [];
        invite(c,"queued-rejection"); c.cancelByUser();
        c.update(GameAccess.app,haxe.Timer.stamp()+3); c.update(GameAccess.app,haxe.Timer.stamp()+4);
        packets = sentPackets();
        check(packets.length == 2 && packets[0].id == "queued-rejection" && packets[1].id == id,
            "Cancelling the active trade preserves its separate queued rejection reply");
        c = fixture(); var requestId = c.state.id;
        for (text in new TradeWire("P").encode({id:requestId,to:"me",op:"cancel",reason:"Player is busy."}))
            c.receive(null,{sender:"peer"},text);
        c.update(GameAccess.app,haxe.Timer.stamp());
        check(!c.open && c.state.phase == "cancelled" && latestRed() && GameAccess.lines[0].text == "Player is busy.",
            "Requester sees the rejection in red and their trade closes");
        c = fixture(false); TradeMod.rejectAllRequests = true; c.request("peer");
        c.update(GameAccess.app,haxe.Timer.stamp());
        check(c.state.phase == "inviting", "Reject-all preference still allows initiating outgoing requests");
    }
    static function offering(c:TradeController):Void {
        c.state.phase = "offering"; c.state.ack = c.state.revision; c.state.peerRevision = 0;
    }
    static function main() {
        InfusionNamesTest.main();

        var c = fixture(); c.update(GameAccess.app, haxe.Timer.stamp());
        check(TradeChat.sent.length == 1 && TradeChat.sent[0].to == "peer", "Invitation is whispered to the selected player");
        var text = TradeChat.sent[0].text;
        check(StringTools.startsWith(text, "Alice" + TradeWire.INVITE_TEXT), "Controller includes readable mod requirement in invitation");
        check(text.indexOf("If you can see this message, you need to install") >= 0, "Invitation explains why the reader sees it");
        var decoded = new TradeWire("T").receive("me", text, 0);
        check(decoded != null && decoded.op == "invite", "Readable invitation still decodes");
        offering(c); locked = true;
        check(marketplace.MarketInventory.locked(c.inv,c.inv.stacks()[0]),"Display can identify an otherwise tradable locked item");
        check(c.addSlot(slot, false) && c.state.mine.length == 0 && gateCalls > 0, "Right-click cannot offer a locked item");
        check(latestRed() && GameAccess.lines[0].text == "This item is locked or cannot be dropped.", "Locked-item error is red in chat and CSS");
        check(c.addSlot(slot, true) && c.state.mine.length == 0, "Drag cannot offer a locked partial stack");
        locked = false; nativeAllowed = false;
        check(!marketplace.MarketInventory.locked(c.inv,c.inv.stacks()[0]),"Native restrictions are not mislabeled as item locks");
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
        var shadowAlpha:Float=line.dropShadow.alpha,shadowDx:Float=line.dropShadow.dx;
        check(line.dropShadow.color == 0 && shadowAlpha > 0 && shadowDx == 1.0, "Success has a dark drop shadow");
        c = fixture(); offering(c);
        c.inv.inventory.getFreeSize = () -> 0;
        var incoming = TradeInventory.describe(c.inv.stacks()[0].item, 95); incoming.uid = "peer-item";
        c.state.theirs = [incoming];
        check(c.inventorySpaceReason() == "", "Full backpack accepts items that fit the existing stack exactly");
        var built = TradeTooltips.builds; c.inventorySpaceReason();
        check(TradeTooltips.builds == built, "Native item descriptions are reused between frames");
        c.state.theirs[0].count = 96;
        check(c.inventorySpaceReason() == "Not enough inventory space.", "Overflow uses the requested error text");
        c.addSlot(slot, true);
        check(c.inventorySpaceReason() == "", "Partial outgoing stack creates matching stack capacity");
        c.state.theirs[0].count = 5;
        var second = TradeOffer.copy(c.state.theirs)[0]; second.uid = "second"; second.count = 7; c.state.theirs.push(second);
        check(c.completionText() == "Trade complete - received 12 items.", "Completion totals all stack quantities");
        c.state.theirs = [];
        check(c.completionText() == "Trade complete - received 0 items.", "One-sided gift sender receives zero");
        c.state.theirs = [second]; second.count = 1;
        check(c.completionText() == "Trade complete - received 1 item.", "Singular item count");
        c.fail("shadow check");
        check(latestRed() && GameAccess.lines[0].dropShadow.color == 0, "Error red also has a shadow");
        requestChecks();
        TradePresenceTest.run();
        Sys.println("Controller and inventory checks passed: " + checks);
    }
}
