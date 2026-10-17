import trade.*;
import trade.TradeTypes;

class TooltipTest {
    static var checks = 0;
    static function check(value:Bool,message:String):Void { checks++; if (!value) throw message; }
    static function main() {
        // Native ID tokens deliberately differ from the serialized string IDs.
        GameAccess.definitions.set("item:Sword",{id:{text:"Sword"}});
        GameAccess.definitions.set("item:CorruptedGift",{id:{text:"CorruptedGift"},value:17});
        var offer:TradeItem = {uid:"weapon",kind:"Sword",name:"Sword",detail:"",color:0,count:1,fingerprint:"accepted",
            preview:{flags:0,level:30,upgrade:2,rarity:"",infusion:"",bonus:"",mastery:"",slots:["CorruptedGift",""],effects:[]}};
        var tip = TradeTooltips.create(offer,null);
        check(tip.stats.length == 1 && tip.stats[0] == 17,"Remote preview resolves corrupted-gift values through native ID keys");
        check(tip.realItem.slots.array.values[1] == null,"Empty socket remains empty");
        check(tip.realItem.level == 30 && tip.realItem.upgradeLevel == 2,"Preview retains level and upgrades");
        check(tip.realItem.__host == null && GameAccess.field(tip.realItem,"__uid") == null,"Preview has no network host or borrowed UID");
        offer.preview.flags = 1;
        tip = TradeTooltips.create(offer,null);
        check(tip.stats[0] == 34,"Original weapon flags reach the native gift-value calculation");
        var actual = tip.realItem; actual.fingerprint = offer.fingerprint;
        var created = GameAccess.creations;
        tip = TradeTooltips.create(offer,new TradeInventory(actual));
        check(tip.realItem == actual && GameAccess.creations == created,"Matching replicated item remains the preferred tooltip source");
        actual.fingerprint = "changed";
        tip = TradeTooltips.create(offer,new TradeInventory(actual));
        check(tip.realItem != actual && tip.stats[0] == 34,"Changed replicated item falls back to the offered snapshot");
        offer.preview.slots = ["UnknownGift"];
        check(TradeTooltips.previewItem(offer) == null,"Unknown gift IDs are rejected before native construction");
        offer.preview.slots = ["CorruptedGift"]; GameAccess.networked = true;
        check(TradeTooltips.previewItem(offer) == null,"Network-attached objects cannot become preview items");
        Sys.println("Tooltip preview checks passed: "+checks);
    }
}
