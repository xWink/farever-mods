package trade;
import trade.GameAccess as G;
import trade.TradeUi.*;
class TradeRequestPopup {
    var controller:TradeController;
    var frame:TradeFrame;
    var countdown:Dynamic;
    public function new(controller:TradeController) this.controller = controller;
    public function ownsWindow(window:Dynamic):Bool return frame != null && frame.window == window;
    public function closeFromBack(window:Dynamic):Bool {
        if (!ownsWindow(window)) return false; controller.cancel("Trade request declined."); return true;
    }
    public function update(now:Float):Void {
        var ui = G.current("ui.BaseUI","current");
        if (frame != null && (frame.ui != ui || !frame.intact())) { controller.cancel("Trade request closed."); return; }
        if (ui == null || !G.isA(ui,"ui.GameUI")) return;
        if (frame == null) {
            frame = new TradeFrame(ui,"Trade request",440,200,()->controller.cancel("Trade request declined."),false);
            show(frame.closeButton,false);
            var p = TradeMod.requestPosition(); frame.x = p.x; frame.y = p.y; frame.onMoved = TradeMod.saveRequestPosition;
            countdown = TradeFrame.textAt(frame.header,"45s",372,17,50,true);
            TradeFrame.textAt(frame.container,controller.peerName,20,16,384,true);
            TradeFrame.textAt(frame.container,"would like to trade with you.",20,42,384);
            frame.button("Decline",14,96,128,()->controller.cancel("Trade request declined."),"cancel");
            frame.button("Accept request",216,96,194,controller.join,"accept");
        }
        setText(countdown,Math.max(0,Math.ceil(controller.state.deadline-now))+"s"); frame.layout();
    }
    public function dispose():Void { var old = frame; frame = null; if (old != null) old.dispose(); countdown = null; }
}
