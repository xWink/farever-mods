package trade;
import trade.GameAccess as G;
import trade.TradeUi.*;
class TradeInventoryMarks {
    var nextUpdate = 0.0;
    var marks:haxe.ds.ObjectMap<Dynamic,{graphic:Dynamic,label:Dynamic,count:Int,width:Float,height:Float}> = new haxe.ds.ObjectMap();
    public function new() {}
    public function update(window:Dynamic,inv:TradeInventory,state:TradeSession):Void {
        var now = haxe.Timer.stamp(); if (now < nextUpdate) return; nextUpdate = now+0.1;
        var list = G.field(G.field(window,"inventoryComp"),"slotList");
        if (list == null || inv == null || !state.active()) { clear(); return; }
        var offers:Map<String,Int> = [], slots:Map<Int,String> = [], seen = new haxe.ds.ObjectMap<Dynamic,Bool>();
        for (i in state.mine) offers[i.uid] = i.count;
        for (s in inv.stacks()) slots[s.index] = G.uid(s.item);
        for (slot in children(list)) {
            if (!G.isA(slot,"ui.win.InventorySlot") || G.field(slot,"inventory") != inv.inventory) continue;
            var uid = slots[G.integer(G.call("ui.win.InventorySlot","getIndex",slot),-1)];
            if (uid == null || !offers.exists(uid) || G.uid(G.field(slot,"item")) != uid) continue;
            seen.set(slot,true); var mark = marks.get(slot);
            if (mark == null || G.field(mark.graphic,"parent") != slot || G.field(mark.label,"parent") != slot) {
                if (mark != null) remove(mark);
                var graphic = TradeFrame.graphic(slot), label = TradeUi.label(G.field(slot,"dom"),"");
                absolute(slot,label); position(label,6,4); TradeFrame.ink(label,3943447);
                mark = {graphic:graphic,label:label,count:-1,width:0,height:0}; marks.set(slot,mark);
            }
            var w = G.number(G.call("h2d.Flow","get_outerWidth",slot),64), h = G.number(G.call("h2d.Flow","get_outerHeight",slot),64);
            if (w < 16 || h < 16 || (mark.count == offers[uid] && mark.width == w && mark.height == h)) continue;
            mark.count = offers[uid]; mark.width = w; mark.height = h; setText(mark.label,"TRADE x"+mark.count);
            G.call("ui.comp.FmtText","updateScale",mark.label);
            var tw = G.number(G.call("h2d.Text","get_textWidth",mark.label),1), th = G.number(G.call("h2d.Text","get_textHeight",mark.label),1);
            G.call("h2d.Object","setScale",mark.label,[Math.min(0.55,Math.min((w-12)/Math.max(1,tw),11/Math.max(1,th)))]);
            G.call("h2d.Graphics","clear",mark.graphic);
            for (r in [[2.0,2.0,w-4,15.0],[2.0,h-4,w-4,2.0],[2.0,2.0,2.0,h-4],[w-4,2.0,2.0,h-4]])
                TradeFrame.rounded(mark.graphic,r[0],r[1],r[2],r[3],0,15252301);
        }
        for (slot in [for(s in marks.keys()) s]) if (!seen.exists(slot)) { remove(marks.get(slot)); marks.remove(slot); }
    }
    function remove(mark:{graphic:Dynamic,label:Dynamic,count:Int,width:Float,height:Float}):Void {
        for (o in [mark.graphic,mark.label]) if (G.field(o,"parent") != null) G.call("h2d.Object","remove",o);
    }
    public function clear():Void { for (m in marks) remove(m); marks.clear(); nextUpdate = 0; }
}
