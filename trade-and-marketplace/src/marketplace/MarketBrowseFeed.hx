package marketplace;

/** Accumulated server-filtered Browse results and the cursor for the next batch. */
class MarketBrowseFeed {
    public static inline var LIMIT=24;
    public static inline var MAX_AGE=60.0;
    public final path:String;
    public var selectedId="";
    public var scroll={offset:0.0};
    public var rows:Array<Dynamic>=[];
    public var next:Null<String>=null;
    public var complete=false;
    public var loaded=false;
    public var failed=false;
    public var fetchedAt=0.0;
    var seen:Map<String,Bool>=[];
    var ids:Map<String,Bool>=[];

    public function new(path:String)this.path=path;
    public function stale(now:Float):Bool return loaded&&now-fetchedAt>=MAX_AGE;
    public function url():String return path+(next==null?"":"&cursor="+StringTools.urlEncode(next));
    public function append(value:Dynamic,now:Float):Void {
        if(!Std.isOfType(Reflect.field(value,"listings"),Array)
            ||(cast value.listings:Array<Dynamic>).length>LIMIT
            ||(value.nextCursor!=null&&!Std.isOfType(value.nextCursor,String)))throw "Invalid listings";
        var cursor:Null<String>=value.nextCursor;
        if(cursor!=null&&(cursor==""||cursor.length>2048||seen.exists(cursor)))throw "Invalid listings cursor";
        // Validate the whole batch before changing rows/cursors, so a failed
        // response can be retried without losing or partially appending items.
        for(row in (cast value.listings:Array<Dynamic>))
            if(row==null||!Std.isOfType(Reflect.field(row,"id"),String)||row.id=="")throw "Invalid listing";
        for(row in (cast value.listings:Array<Dynamic>)) {
            if(ids.exists(row.id))continue;
            ids[row.id]=true;rows.push(row);
        }
        if(cursor!=null)seen[cursor]=true;
        loaded=true;failed=false;fetchedAt=now;next=cursor;complete=next==null;
    }
}
