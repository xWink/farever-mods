package trade;

/** Resolve game-owned WindowFlags without assuming every enum value exists.
 * PTR and live releases may expose different native variants. */
class TradeWindowFlags {
    public static function resolve(names:Array<String>,lookup:String->Dynamic)
        :{mask:Int,found:Int,missing:Array<String>} {
        return modui.WindowFlags.resolve(names, lookup);
    }
}
