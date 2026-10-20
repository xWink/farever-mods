package marketplace;

/** Mirrors Fareverly marketplace-policy.ts; quantity, price and character are not identity. */
class MarketItemIdentity {
    static function field(value:Dynamic,name:String):Dynamic return value==null?null:Reflect.field(value,name);
    static function array(value:Dynamic):Array<Dynamic> return Std.isOfType(value,Array)?cast value:[];
    static function sorted(values:Array<String>):Array<String> {values.sort(Reflect.compare);return values;}
    static function stats(value:Dynamic):Array<String> return sorted([for(s in array(value))
        haxe.Json.stringify([field(s,"attributeId"),field(s,"value"),field(s,"unit")])]);
    public static function key(item:Dynamic):String {
        if(item==null||field(item,"baseId")==null)throw "Missing listing item";
        var values:Array<Dynamic>=[field(item,"baseId"),field(item,"rarity"),field(item,"requiredLevel"),field(item,"itemLevel"),
            field(item,"upgradeLevel"),field(item,"prismatic"),field(item,"flawless"),stats(field(item,"stats")),
            sorted([for(m in array(field(item,"modifiers")))haxe.Json.stringify([
                field(m,"kind"),field(field(m,"source"),"type"),field(field(m,"source"),"id"),field(m,"rank"),stats(field(m,"stats"))])])];
        var native=field(item,"native");
        if(native!=null)values.push([field(native,"flags"),field(native,"level"),field(native,"upgrade"),field(native,"rarity"),
            field(native,"infusion"),field(native,"bonus"),field(native,"mastery"),field(native,"slots"),
            sorted([for(e in array(field(native,"effects")))haxe.Json.stringify([field(e,"skill"),field(e,"source")])])]);
        return haxe.Json.stringify(values);
    }
}
