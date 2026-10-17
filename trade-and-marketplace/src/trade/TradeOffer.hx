package trade;
import trade.TradeTypes;
class TradeOffer {
    public static function str(v:Dynamic,max:Int):Bool return Std.isOfType(v,String) && (cast v:String).length <= max;
    public static function valid(items:Dynamic):Bool {
        if (!Std.isOfType(items,Array)) return false;
        var list:Array<Dynamic> = items;
        if (list.length > 6) return false;
        var ids:Map<String,Bool> = [];
        for (i in list) {
            if (i == null || !Reflect.isObject(i) || Std.isOfType(i,String) || Std.isOfType(i,Array)) return false;
            if (!str(i.uid,48) || i.uid == "" || ids.exists(i.uid) || !str(i.kind,120) || i.kind == ""
                || !str(i.name,160) || !str(i.detail,1024) || !str(i.fingerprint,768) || i.fingerprint == ""
                || !TradePreview.integer(i.count,1,1000000) || !TradePreview.integer(i.color,0,0xffffff)
                || !TradePreview.valid(i.preview)) return false;
            ids[i.uid] = true;
        }
        return haxe.io.Bytes.ofString(haxe.Json.stringify(copy(cast items))).length <= 12000;
    }
    public static function copy(items:Array<TradeItem>):Array<TradeItem> return [for(i in items) {
        uid:i.uid,kind:i.kind,count:i.count,name:i.name,detail:i.detail,color:i.color,fingerprint:i.fingerprint,preview:TradePreview.copy(i.preview)
    }];
    public static function hash(items:Array<TradeItem>):String {
        var rows:Array<Dynamic> = [];
        for (i in items) {
            var row:Array<Dynamic> = [i.uid,i.kind,Std.string(i.count),i.name,i.detail,Std.string(i.color),i.fingerprint];
            if (i.preview != null) row.push(TradePreview.canonical(i.preview));
            rows.push(row);
        }
        return haxe.crypto.Sha256.encode(haxe.Json.stringify(rows));
    }
}
