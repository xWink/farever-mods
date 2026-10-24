package marketplace;

import trade.GameAccess as G;

/** Embedded player badges, shared by listing rows for the lifetime of a window. */
class MarketBadges {
    public static inline var SIZE=22;
    public static inline var GAP=4;
    final textures:Map<String,Dynamic>=[];
    final failed:Map<String,Bool>=[];

    public function new() {}

    public function create(parent:Dynamic,id:String,nativeArray:Dynamic):Dynamic {
        switch(id) {
            case "supporter-bronze", "supporter-silver", "supporter-gold",
                 "supporter-ruby", "supporter-emerald", "supporter-diamond", "fareverly-creator":
            default:return null;
        }
        if(failed.exists(id))return null;
        var texture=textures.get(id);
        if(texture==null) {
            var targets:Array<Dynamic>=[],holder:Dynamic=null,released=true;
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
                texture=G.call("hxd.res.Any","toTexture",resource);targets.push(texture);
                var flags=G.call("hl.types.ArrayObj","slice",nativeArray,[0,0]);
                G.call("hl.types.ArrayObj","pushDyn",flags,[G.current("h3d.mat.TextureFlags","Target")]);
                var format=G.current("hxd.PixelFormat","RGBA"),blend=G.current("h2d.BlendMode","AlphaAdd");
                // The supplied artwork is embedded at 8x the displayed size.
                // Average down in half-size passes, keeping a 2x final texture:
                // a single bilinear shrink skips fine edges instead of smoothing
                // them. Bake once per tier, as with the minimap icons.
                for(pixels in [SIZE*4,SIZE*2]) {
                    var source=G.staticCall("h2d.Tile","fromTexture",[texture]);
                    G.call("h2d.Tile","scaleToSize",source,[pixels*1.0,pixels*1.0]);
                    holder=G.create("h2d.Bitmap",[source,null]);released=false;
                    G.set(holder,"smooth",true);
                    // PNGs have straight alpha; render targets are premultiplied.
                    // Preserve the latter so soft borders do not get darkened.
                    if(pixels==SIZE*2)G.set(holder,"blendMode",blend);
                    texture=G.create("h3d.mat.Texture",[pixels,pixels,flags,format]);targets.push(texture);
                    G.call("h3d.mat.Texture","clear",texture,[0,0.0,null]);
                    G.call("h2d.Object","drawTo",holder,[texture]);released=true;
                }
                G.call("h3d.mat.Texture","preventAutoDispose",texture);
                textures.set(id,texture);
            } catch(error:Dynamic) {
                failed.set(id,true);
                if(holder!=null&&!released)try G.call("h2d.Object","onRemove",holder)catch(_:Dynamic){}
                for(target in targets)try G.call("h3d.mat.Texture","dispose",target)catch(_:Dynamic){}
                throw error;
            }
            for(target in targets)if(target!=texture)G.call("h3d.mat.Texture","dispose",target);
        }
        var tile=G.staticCall("h2d.Tile","fromTexture",[texture]);
        G.call("h2d.Tile","scaleToSize",tile,[SIZE*1.0,SIZE*1.0]);
        var bitmap=G.create("h2d.Bitmap",[tile,parent]);
        G.set(bitmap,"smooth",true);G.set(bitmap,"blendMode",G.current("h2d.BlendMode","AlphaAdd"));
        trade.TradeUi.absolute(parent,bitmap);
        return bitmap;
    }

    public function dispose():Void {
        for(texture in textures)G.call("h3d.mat.Texture","dispose",texture);
        textures.clear();failed.clear();
    }
}
