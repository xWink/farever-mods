package trade;

import trade.GameAccess as G;

/** Crop only the detached marketplace tile; never modify native shared art. */
class MarketArtTrim {
    static inline var ALPHA_THRESHOLD=8;
    // Texture.capturePixels synchronizes the GPU. Cache at most 64 MiB of
    // atlas readbacks, and never read back the same texture more than once.
    static inline var MAX_PIXELS=4096*4096;
    static var cachedPixels=0;
    static var atlases:Array<{texture:Dynamic,pixels:Dynamic}>=[];
    static var unavailable:Array<Dynamic>=[];
    static var bounds:Map<String,Dynamic>=[];

    /** Return the smallest content rectangle. Alpha 1..8 is a fringe. */
    public static function contentBounds(w:Int,h:Int,alpha:(Int,Int)->Int):Dynamic {
        if(w<=0||h<=0)return null;
        var x0=w,y0=h,x1=-1,y1=-1;
        for(y in 0...h)for(x in 0...w)if(alpha(x,y)>ALPHA_THRESHOLD) {
            if(x<x0)x0=x;if(y<y0)y0=y;
            if(x>x1)x1=x;if(y>y1)y1=y;
        }
        if(x1<0)return null;
        var cw=x1-x0+1,ch=y1-y0+1;
        // Fail safe on stray pixels which would otherwise be enlarged.
        if(cw<w*0.25||ch<h*0.25)return null;
        return {x:x0,y:y0,w:cw,h:ch};
    }

    static function readAtlas(texture:Dynamic):Dynamic {
        for(c in atlases)if(c.texture==texture)return c.pixels;
        for(t in unavailable)if(t==texture)return null;
        var w=G.integer(G.field(texture,"width")),h=G.integer(G.field(texture,"height"));
        if(w<=0||h<=0||w>4096||h>4096||w*h>MAX_PIXELS
            ||cachedPixels+w*h>MAX_PIXELS) {
            unavailable.push(texture);return null;
        }
        try {
            var pixels=G.call("h3d.mat.Texture","capturePixels",texture,[0,0,null]);
            if(pixels!=null&&G.integer(G.field(pixels,"width"))==w
                &&G.integer(G.field(pixels,"height"))==h) {
                atlases.push({texture:texture,pixels:pixels});
                cachedPixels+=w*h;
                return pixels;
            }
        } catch(_:Dynamic){}
        unavailable.push(texture);
        return null;
    }

    /** On unsupported textures keep the original tile and the old renderer. */
    public static function trim(tile:Dynamic):Dynamic {
        if(tile==null)return null;
        // Heaps Tile.getTexture is inline, so use the native field instead.
        var tex=G.field(tile,"innerTex");
        if(tex==null)return tile;
        var px=G.number(G.field(tile,"x")),py=G.number(G.field(tile,"y"));
        var tw=G.number(G.field(tile,"width")),th=G.number(G.field(tile,"height"));
        var x=Std.int(Math.round(px)),y=Std.int(Math.round(py));
        var w=Std.int(Math.round(tw)),h=Std.int(Math.round(th));
        if(Math.abs(px-x)>0.01||Math.abs(py-y)>0.01
            ||Math.abs(tw-w)>0.01||Math.abs(th-h)>0.01
            ||w<1||h<1||w>512||h>512||x<0||y<0)return tile;
        var pixels=readAtlas(tex);
        if(pixels==null||x+w>G.integer(G.field(pixels,"width"))
            ||y+h>G.integer(G.field(pixels,"height")))return tile;
        var i=0;
        for(j in 0...atlases.length)if(atlases[j].texture==tex){i=j;break;}
        var key=i+":"+x+":"+y+":"+w+":"+h;
        var boundsForTile:Dynamic;
        if(bounds.exists(key))boundsForTile=bounds[key];
        else {
            try {
                boundsForTile=contentBounds(w,h,(cx,cy)->{
                    // Pixels.getPixel always returns 0xAARRGGBB in Heaps.
                    var argb=G.integer(G.call("hxd.Pixels","getPixel",pixels,[x+cx,y+cy]));
                    return (argb>>>24)&255;
                });
                bounds[key]=boundsForTile==null?false:boundsForTile;
            } catch(e:Dynamic){trace("TRIM ERROR SCAN "+Std.string(e));return tile;}
        }
        if(boundsForTile==false||boundsForTile==null){trace("TRIM NO BOUNDS "+key);return tile;}
        if(boundsForTile.x==0&&boundsForTile.y==0&&boundsForTile.w==w
            &&boundsForTile.h==h&&G.number(G.field(tile,"dx"))==0
            &&G.number(G.field(tile,"dy"))==0)return tile;
        try {
            // sub() shares the native texture and resets the tile origin;
            // never mutate or dispose the source tile/texture.
            var cx:Float=boundsForTile.x,cy:Float=boundsForTile.y;
            var cw:Float=boundsForTile.w,ch:Float=boundsForTile.h;
            var zero:Float=0;
            var trimmed=G.call("h2d.Tile","sub",tile,[cx,cy,cw,ch,zero,zero]);
            return trimmed==null?tile:trimmed;
        } catch(e:Dynamic){trace("TRIM ERROR SUB "+Std.string(e));return tile;}
    }
}
