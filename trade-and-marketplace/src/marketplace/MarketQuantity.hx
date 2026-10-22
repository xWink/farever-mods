package marketplace;

/** Numeric-only input, bounded before parsing to avoid integer overflow on paste. */
class MarketQuantity {
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
