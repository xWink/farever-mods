package trade;

/** Resolve game-owned WindowFlags without assuming every enum value exists.
 * PTR and live releases may expose different native variants. */
class TradeWindowFlags {
    public static function resolve(names:Array<String>,lookup:String->Dynamic)
        :{mask:Int,found:Int,missing:Array<String>} {
        var mask=0,found=0,missing:Array<String>=[];
        for(name in names) {
            var flag:Dynamic=null;
            try flag=lookup(name) catch(_:Dynamic){}
            if(flag==null){missing.push(name);continue;}
            var index=-1;
            try index=Type.enumIndex(flag) catch(_:Dynamic){}
            if(index<0||index>=31){missing.push(name);continue;}
            mask|=1<<index;
            found++;
        }
        return {mask:mask,found:found,missing:missing};
    }
}
