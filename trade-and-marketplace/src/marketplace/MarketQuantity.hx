package marketplace;

/** Numeric-only input, bounded before parsing to avoid integer overflow on paste. */
class MarketQuantity {
    public static function valid(text:String,min:Int,max:Int):Bool {
        if(text==null||!~/^[0-9]+$/.match(text))return false;
        var value=Std.parseFloat(text);
        return value>=min&&value<=max;
    }
    /** Form prices are per unit; the API still receives whole-listing Silver Trays. */
    public static function totalPrice(quantity:String,unitTrays:String):Null<Int> {
        if(!valid(quantity,1,10000)||!valid(unitTrays,1,200000))return null;
        var total=Std.parseFloat(quantity)*Std.parseFloat(unitTrays);
        return total<=200000?Std.int(total):null;
    }
    public static function normalize(text:String,min:Int,max:Int,previous:String):String {
        if(text=="")return ""; // Allow replacing the whole number while editing.
        if(!~/^[0-9]+$/.match(text))return previous;
        var value=Std.parseFloat(text);
        return Std.string(Std.int(Math.max(min,Math.min(max,value))));
    }
    /** The minimum price's +10 step jumps to 10; other prices add ten. */
    public static function priceStep(current:Int,delta:Int,max:Int):Int {
        var next=current==1&&delta==10?10:current+delta;
        return Std.int(Math.max(1,Math.min(max,next)));
    }
}
