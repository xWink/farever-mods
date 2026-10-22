package marketplace;

import trade.TradeInventory;

/** Single readable whisper; each local chat translates the stable item ID. */
class MarketWhisperMessage {
    public static inline var PREFIX="Hi! I'm interested in your marketplace listing: ";
    static var itemId=~/^[A-Za-z0-9_:.\-/]{1,120}$/;
    // Match only the plugin's exact readable message template.
    static var template=~/^([A-Za-z0-9_:.\-/]{1,120})( x([1-9][0-9]{0,4})(?: for ([1-9][0-9,]* Silver Trays?)\.| \(open to offers\)\.))$/;

    public static function message(listing:Dynamic):String {
        var item=listing==null?null:Reflect.field(listing,"item");
        var price=listing==null?null:Reflect.field(listing,"price");
        var kind=item==null?null:Reflect.field(item,"baseId");
        var quantity=item==null?null:Reflect.field(item,"quantity");
        if(!Std.isOfType(kind,String)||!itemId.match(kind)
            ||!trade.TradePreview.integer(quantity,1,10000)||price==null)
            throw "Cannot send an incomplete marketplace listing.";
        var mode=Reflect.field(price,"mode"),suffix="";
        if(mode=="offers")suffix=" (open to offers).";
        else {
            var trays=Reflect.field(price,"silverTrays");
            if(mode!="fixed"||!trade.TradePreview.integer(trays,1,200000))
                throw "Cannot send an invalid marketplace price.";
            suffix=" for "+MarketText.price(price)+".";
        }
        return PREFIX+kind+" x"+Std.string(quantity)+suffix;
    }

    public static function isMessage(text:String):Bool return text!=null&&text.length<=384
        &&StringTools.startsWith(text,PREFIX)&&template.match(text.substr(PREFIX.length));

    /** Unknown IDs and non-marketplace chat remain exactly as received. */
    public static function localize(text:String,resolve:String->String):Null<String> {
        if(resolve==null||!isMessage(text))return null;
        var body=text.substr(PREFIX.length);
        if(!template.match(body))return null;
        var kind=template.matched(1),name:Null<String>=null;
        try name=resolve(kind) catch(_:Dynamic)return null;
        if(name==null||name==""||name==kind||name.indexOf("::")>=0)return null;
        name=TradeInventory.clean(name,160);
        name=~/[\r\n\t]/g.replace(name," ");
        if(name=="")return null;
        return PREFIX+name+body.substr(kind.length);
    }
}
