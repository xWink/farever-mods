package marketplace;
import trade.GameAccess as G;
import trade.TradeUi.*;

/** The supplied cart artwork, smoothed once and tinted to the native title. */
class MarketCartIcon {
    public var bitmap:Dynamic;
    var texture:Dynamic;
    public function new(parent:Dynamic,nativeArray:Dynamic) {
        var targets:Array<Dynamic>=[],holder:Dynamic=null,released=true;
        var flags=G.call("hl.types.ArrayObj","slice",nativeArray,[0,0]);
        G.call("hl.types.ArrayObj","pushDyn",flags,[G.current("h3d.mat.TextureFlags","Target")]);
        var format=G.current("hxd.PixelFormat","RGBA"),blend=G.current("h2d.BlendMode","AlphaAdd");
        try {
            var bytes=haxe.Resource.getBytes("trade-and-marketplace/cart.png");
            if(bytes==null)throw "Embedded marketplace cart is missing.";
            #if hl
            var raw:hl.Bytes=@:privateAccess bytes.b;
            #else
            var raw=bytes.getData();
            #end
            var nativeBytes=G.create("haxe.io.Bytes",[raw,bytes.length]);
            var resource=G.staticCall("hxd.res.Any","fromBytes",["marketplace-cart.png",nativeBytes]);
            texture=G.call("hxd.res.Any","toTexture",resource);targets.push(texture);
            // Finish near the displayed 28px size: jumping from 64px directly
            // to 28px skips source samples and leaves the thin diagonals jagged.
            for(pixels in [256,128,64,32]) {
                var source=G.staticCall("h2d.Tile","fromTexture",[texture]);
                G.call("h2d.Tile","scaleToSize",source,[pixels*1.0,pixels*1.0]);
                holder=G.create("h2d.Bitmap",[source,null]);released=false;
                G.set(holder,"smooth",true);
                // The PNG is a black alpha mask. Make it white before tinting;
                // subsequent passes retain the render target's premultiplied alpha.
                if(pixels==256)G.call("h2d.Drawable","set_colorAdd",holder,[G.create("h3d.VectorImpl",[1.0,1.0,1.0])]);
                else G.set(holder,"blendMode",blend);
                texture=G.create("h3d.mat.Texture",[pixels,pixels,flags,format]);targets.push(texture);
                G.call("h3d.mat.Texture","clear",texture,[0,0.0,null]);
                G.call("h2d.Object","drawTo",holder,[texture]);released=true;
            }
            var tile=G.staticCall("h2d.Tile","fromTexture",[texture]);
            G.call("h2d.Tile","scaleToSize",tile,[28.0,28.0]);
            bitmap=G.create("h2d.Bitmap",[tile,parent]);absolute(parent,bitmap);
            G.set(bitmap,"smooth",true);G.set(bitmap,"blendMode",blend);
            G.call("h3d.mat.Texture","preventAutoDispose",texture);
        } catch(error:Dynamic) {
            if(holder!=null&&!released)try G.call("h2d.Object","onRemove",holder)catch(_:Dynamic){}
            if(bitmap!=null)try G.call("h2d.Object","remove",bitmap)catch(_:Dynamic){}
            for(target in targets)try G.call("h3d.mat.Texture","dispose",target)catch(_:Dynamic){}
            texture=null;throw error;
        }
        for(target in targets)if(target!=texture)G.call("h3d.mat.Texture","dispose",target);
    }
    public function tint(color:Int):Void {
        var vector=G.field(bitmap,"color");
        for(i in 0...3) {
            var shift=16-i*8,channel=(color>>shift)&255;
            G.set(vector,["x","y","z"][i],channel/255.0);
        }
    }
    public function dispose():Void {
        if(bitmap!=null)G.call("h2d.Object","remove",bitmap);
        if(texture!=null)G.call("h3d.mat.Texture","dispose",texture);
        bitmap=texture=null;
    }
}
