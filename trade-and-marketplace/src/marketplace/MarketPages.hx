package marketplace;

typedef MarketPage = {rows:Array<Dynamic>, next:Null<String>, fetched:Float};

/** One query's previous/current/next pages. Cursors are retained for back navigation. */
class MarketPages {
    public static inline var MAX_AGE = 60.0;
    public final path:String;
    public final limit:Int;
    public var current=1;
    public var selectedId="";
    public var cursors:Array<String>=[null];
    final data:Map<Int,MarketPage>=[];
    public function new(path:String,limit:Int) {this.path=path;this.limit=limit;}
    public function url(page:Int):String return path+(page>1?"&cursor="+StringTools.urlEncode(cursors[page-1]):"");
    public function get(page:Int,now:Float):MarketPage {
        var value=data[page];return value!=null&&now-value.fetched<MAX_AGE?value:null;
    }
    public function put(page:Int,value:Dynamic,now:Float):MarketPage {
        if(!Std.isOfType(value.listings,Array)||(cast value.listings:Array<Dynamic>).length>limit
            ||(value.nextCursor!=null&&!Std.isOfType(value.nextCursor,String)))throw "Invalid listings";
        var result:MarketPage={rows:value.listings,next:value.nextCursor,fetched:now};
        // A changed boundary invalidates every subsequent cursor and cached page.
        if(cursors[page]!=result.next)invalidateAfter(page);
        cursors[page]=result.next;data[page]=result;trim();return result;
    }
    public function invalidateAfter(page:Int):Void {
        cursors=cursors.slice(0,page+1);
        for(p in [for(p in data.keys())p])if(p>page)data.remove(p);
    }
    public function forget(page:Int):Void {data.remove(page);invalidateAfter(page);}
    public function trim():Void {
        for(p in [for(p in data.keys())p])if(p<current-1||p>current+1)data.remove(p);
    }
}
