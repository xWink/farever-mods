package marketplace;

/**
 * An ordered stream of raw marketplace API pages. Display pages use eight
 * visible listings, not eight raw listings: owner filtering can skip entries
 * without leaving gaps or losing the server's opaque next cursor.
 */
class MarketBrowseFeed {
    public static inline var LIMIT=8;
    public static inline var MAX_BATCHES=48;
    public final path:String;
    public var current=1;
    public var selectedId="";
    public var rows:Array<Dynamic>=[];
    public var next:Null<String>=null;
    public var complete=false;
    public var fetchedAt=0.0;
    var batches=0;
    var seen:Map<String,Bool>=[];
    var ids:Map<String,Bool>=[];

    public function new(path:String)this.path=path;
    public function stale(now:Float):Bool return batches>0&&now-fetchedAt>=MarketPages.MAX_AGE;
    public function url():String return path+(next==null?"":"&cursor="+StringTools.urlEncode(next));
    public function append(value:Dynamic,now:Float):Void {
        if(!Std.isOfType(Reflect.field(value,"listings"),Array)
            ||(cast value.listings:Array<Dynamic>).length>LIMIT
            ||(value.nextCursor!=null&&!Std.isOfType(value.nextCursor,String)))throw "Invalid listings";
        for(row in (cast value.listings:Array<Dynamic>)) {
            var id=Reflect.field(row,"id");
            if(id!=null&&Std.isOfType(id,String)) {
                if(ids.exists(id))continue;
                ids[id]=true;
            }
            rows.push(row);
        }
        batches++;fetchedAt=now;
        var cursor:Null<String>=value.nextCursor;
        if(cursor!=null&&(cursor==""||cursor.length>2048||seen.exists(cursor)))throw "Invalid listings cursor";
        if(cursor!=null)seen[cursor]=true;
        next=cursor;
        complete=next==null||batches>=MAX_BATCHES;
    }
}
