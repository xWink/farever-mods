package marketplace;

import trade.GameAccess as G;

/** Embedded supporter artwork, shared by listing rows for the lifetime of a window. */
class MarketBadges {
    public static inline var SIZE=22;
    public static inline var GAP=4;
    final textures:Map<String,Dynamic>=[];
    final failed:Map<String,Bool>=[];

    public function new() {}

    public function create(parent:Dynamic,id:String):Dynamic {
        switch(id) {
            case "supporter-bronze", "supporter-silver", "supporter-gold",
                 "supporter-ruby", "supporter-emerald", "supporter-diamond":
            default:return null;
        }
        if(failed.exists(id))return null;
        var texture=textures.get(id);
        if(texture==null) {
            try {
                var bytes=haxe.Resource.getBytes("trade-and-marketplace/badges/"+id+".png");
                if(bytes==null)throw "Embedded marketplace badge is missing: "+id;
                #if hl
                var raw:hl.Bytes=@:privateAccess bytes.b;
                #else
                var raw=bytes.getData();
                #end
                var nativeBytes=G.create("haxe.io.Bytes",[raw,bytes.length]);
                var resource=G.staticCall("hxd.res.Any","fromBytes",[id+".png",nativeBytes]);
                texture=G.call("hxd.res.Any","toTexture",resource);
                G.call("h3d.mat.Texture","preventAutoDispose",texture);
                textures.set(id,texture);
            } catch(error:Dynamic) {
                failed.set(id,true);
                if(texture!=null)G.call("h3d.mat.Texture","dispose",texture);
                throw error;
            }
        }
        var tile=G.staticCall("h2d.Tile","fromTexture",[texture]);
        G.call("h2d.Tile","scaleToSize",tile,[SIZE*1.0,SIZE*1.0]);
        var bitmap=G.create("h2d.Bitmap",[tile,parent]);
        G.set(bitmap,"smooth",true);
        trade.TradeUi.absolute(parent,bitmap);
        return bitmap;
    }

    public function dispose():Void {
        for(texture in textures)G.call("h3d.mat.Texture","dispose",texture);
        textures.clear();failed.clear();
    }
}
