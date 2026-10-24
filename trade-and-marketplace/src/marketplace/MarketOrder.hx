package marketplace;

/** Omitted order types are legacy sell listings. */
class MarketOrder {
    public static function isBuy(listing:Dynamic):Bool {
        if(listing==null)return false;
        var type=Reflect.field(listing,"orderType");
        if(type==null) {
            var original=Reflect.field(listing,"export");
            if(original!=null)type=Reflect.field(original,"orderType");
        }
        return type=="buy";
    }
    public static function prefix(listing:Dynamic):String return isBuy(listing)?"B> ":"S> ";
    public static function ownerLabel(listing:Dynamic):String return isBuy(listing)?"Buyer":"Seller";
    public static function anyLevel(listing:Dynamic):Bool {
        if(!isBuy(listing))return false;
        var item=Reflect.field(listing,"item");if(item==null)return false;
        var native=Reflect.field(item,"native");
        return item!=null&&Reflect.field(item,"requiredLevel")==null&&native!=null&&Reflect.field(native,"level")==0
            &&["Weapon","Armor","Accessory"].indexOf(Reflect.field(item,"category"))>=0;
    }
}
