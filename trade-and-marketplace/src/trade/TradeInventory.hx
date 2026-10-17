package trade;
import trade.GameAccess as G;
import trade.TradeTypes;
typedef TradeStack = {index:Int,item:Dynamic,count:Int};
class TradeInventory {
    public var player:Dynamic;
    public var hero:Dynamic;
    public var inventory:Dynamic;
    var incomingKey = "";
    var incoming:Array<trade.TradeCapacity.CapacityStack> = [];
    public function new(player:Dynamic) {
        this.player = player; hero = G.field(player,"hero"); inventory = G.field(G.field(hero,"loadout"),"inventory");
    }
    public static function fingerprint(item:Dynamic):String {
        var values:Array<Dynamic> = [G.typeName(item),G.text(G.field(item,"kind")),G.text(G.field(G.field(item,"flags"),"value")),
            G.text(G.field(item,"level")),G.text(G.field(item,"upgradeLevel")),G.text(G.field(item,"rarity")),
            G.text(G.field(G.field(item,"inf"),"rarity")),G.text(G.field(item,"infusion")),G.text(G.field(item,"infusionBonusStat")),
            [for(s in G.array(G.field(item,"slots"),true)) G.text(s)],
            [for(e in G.array(G.field(item,"effects"),true)) [G.text(G.field(e,"skill")),G.text(G.field(e,"source"))]]];
        return haxe.crypto.Sha256.encode(haxe.Json.stringify(values));
    }
    public static function definition(kind:String):Dynamic {
        var table = G.field(G.current("Data","item"),"byId");
        return table == null ? null : G.call("haxe.ds.StringMap","get",table,[kind]);
    }
    public static function itemName(kind:String):String {
        var d = definition(kind); return d == null ? kind : clean(G.text(G.staticCall("HItem","getName",[d])),160);
    }
    public static function clean(text:String,max:Int):String return ~/<[^>]*>/g.replace(text,"").substr(0,max);
    public static function describe(item:Dynamic,count:Int):TradeItem {
        var rarity = G.staticCall("HItem","getRarity",[G.field(item,"inf")]), detail:Array<String> = [];
        var name = G.text(G.field(rarity,"name"),G.text(G.field(rarity,"id")));
        if (name != "") detail.push(clean(name,80));
        if (G.isA(item,"st.item.Gear")) {
            detail.push("Level "+G.text(G.field(item,"level"))+"  |  Upgrade +"+G.text(G.field(item,"upgradeLevel"),"0"));
            var info = G.call("st.item.Gear","getDetailedInfos",item);
            for (s in G.array(G.field(info,"stats"))) detail.push(clean(G.text(s),100));
        }
        var infusion = G.text(G.field(item,"infusion"));
        if (infusion != "") {
            var table = G.field(G.current("Data","infusion"),"byId");
            var data = table == null ? null : G.call("haxe.ds.StringMap","get",table,[infusion]);
            detail.push("Infusion: "+clean(G.text(G.field(data,"name"),infusion),120));
        }
        var bonus = G.text(G.field(item,"infusionBonusStat"));
        if (bonus != "") detail.push("Infusion bonus: "+bonus);
        for (s in G.array(G.field(item,"slots"),true)) if (s != null && G.text(s) != "") detail.push(itemName(G.text(s)));
        for (e in G.array(G.field(item,"effects"),true)) {
            var skill = G.text(G.field(e,"skill"));
            if (skill != "") detail.push("Effect: "+skill+" ("+G.text(G.field(e,"source"))+")");
        }
        return {uid:G.uid(item),kind:G.text(G.field(item,"kind")),count:count,
            name:clean(G.text(G.call("st.Item","getName",item)),160),detail:detail.join("\n").substr(0,1024),
            color:G.integer(G.field(rarity,"color"),7623481)&0xffffff,fingerprint:fingerprint(item),preview:preview(item)};
    }
    public static function preview(item:Dynamic):TradeItemPreview return {
        flags:G.integer(G.field(G.field(item,"flags"),"value")),level:G.integer(G.field(item,"level")),
        upgrade:G.integer(G.field(item,"upgradeLevel")),rarity:G.text(G.field(item,"rarity")),
        infusion:G.text(G.field(item,"infusion")),bonus:G.text(G.field(item,"infusionBonusStat")),mastery:G.text(G.field(item,"mastery")),
        slots:[for(s in G.array(G.field(item,"slots"),true)) G.text(s)],
        effects:[for(e in G.array(G.field(item,"effects"),true)) {skill:G.text(G.field(e,"skill")),source:G.enumName(G.field(e,"source"))}]
    };
    public static function distance(a:Dynamic,b:Dynamic):Float {
        var pa = G.field(a,"position"), pb = G.field(b,"position");
        if (pa == null || pb == null) return Math.POSITIVE_INFINITY;
        var sum = 0.0;
        for (axis in ["x","y","z"]) {
            var d = G.number(G.field(pa,axis),Math.NaN)-G.number(G.field(pb,axis),Math.NaN);
            if (!Math.isFinite(d)) return Math.POSITIVE_INFINITY;
            sum += d*d;
        }
        return Math.sqrt(sum);
    }
    public function stacks():Array<TradeStack> {
        var content = G.array(G.field(inventory,"content"));
        return [for(i in 0...content.length) if (G.field(content[i],"item") != null)
            {index:i,item:G.field(content[i],"item"),count:G.integer(G.field(content[i],"count"))}];
    }
    public function find(uid:String):TradeStack { for (s in stacks()) if (G.uid(s.item) == uid) return s; return null; }
    public function fromSlot(slot:Dynamic):TradeStack {
        if (G.field(slot,"inventory") != inventory) return null;
        var index = G.integer(G.call("ui.win.InventorySlot","getIndex",slot),-1);
        for (s in stacks()) if (s.index == index) return s; return null;
    }
    // Use the hooked game permission check so Item Utilities locks apply too.
    // Reused when offering, validating the offer, and immediately before a drop.
    public function canDrop(s:TradeStack,count:Int):Bool return s != null && count > 0 && count <= s.count
        && count <= G.integer(G.call("st.Item","maxStack",s.item),1)
        && G.call("st.Inventory","canRequestDropIndex",inventory,[s.index,true,count]) == true;
    public function validate(items:Array<TradeItem>):String {
        for (i in items) {
            var s = find(i.uid);
            if (s == null || fingerprint(s.item) != i.fingerprint || s.count < i.count) return "An offered item changed or is no longer in your backpack.";
            if (!canDrop(s,i.count)) return "An offered item is locked or cannot be dropped.";
        }
        return "";
    }
    public function freeSlots():Int return G.integer(G.call("st.Inventory","getFreeSize",inventory));
    public function canReceive(mine:Array<TradeItem>, theirs:Array<TradeItem>):Bool {
        if (theirs.length == 0) return true;
        var free = freeSlots(), slots:Array<trade.TradeCapacity.CapacityStack> = [];
        for (stack in stacks()) {
            var remaining = stack.count;
            for (offer in mine) if (offer.uid == G.uid(stack.item) && fingerprint(stack.item) == offer.fingerprint) {
                remaining -= offer.count; break;
            }
            if (remaining <= 0) { free++; continue; }
            slots.push({item:stack.item,count:remaining,max:G.integer(G.call("st.Item","maxStack",stack.item),1)});
        }
        var key = TradeOffer.hash(theirs);
        if (key != incomingKey) {
            var next:Array<trade.TradeCapacity.CapacityStack> = [];
            for (offer in theirs) {
                // Cache detached native item descriptions until the partner edits their offer.
                // These objects never receive a UID, network host or inventory membership.
                var item = TradeTooltips.previewItem(offer);
                next.push({item:item,count:offer.count,max:item == null ? 1 : G.integer(G.call("st.Item","maxStack",item),1)});
            }
            incoming = next; incomingKey = key;
        }
        return TradeCapacity.fits(slots,incoming,free,(a,b)->
            G.call("st.Item","canStack",a,[b]) == true && G.call("st.Item","canStack",b,[a]) == true);
    }
    public function drops():Array<Dynamic> return [for(d in G.array(G.field(player,"lootDrops"),true))
        if (d != null && G.field(d,"removed") != true && G.isA(d,"ent.interactible.LootDrop")) d];
    public function totals():Map<String,Int> {
        var out:Map<String,Int> = [];
        for (s in stacks()) { var f = fingerprint(s.item); out[f] = (out.exists(f) ? out[f] : 0)+s.count; }
        return out;
    }
}
