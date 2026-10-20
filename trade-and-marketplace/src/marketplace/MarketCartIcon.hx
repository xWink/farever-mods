package marketplace;
import trade.GameAccess as G;
import trade.TradeUi.*;
import trade.TradeFrame.*;

/** A single cached, supersampled cart; no per-frame blur or mipmap generation. */
class MarketCartIcon {
    public var bitmap:Dynamic;
    var texture:Dynamic;
    public function new(parent:Dynamic,nativeArray:Dynamic) {
        var targets:Array<Dynamic>=[],holder:Dynamic=null,released=true;
        var flags=G.call("hl.types.ArrayObj","slice",nativeArray,[0,0]);
        G.call("hl.types.ArrayObj","pushDyn",flags,[G.current("h3d.mat.TextureFlags","Target")]);
        var format=G.current("hxd.PixelFormat","RGBA"),blend=G.current("h2d.BlendMode","AlphaAdd");
        try {
            holder=G.create("h2d.Object",[null]);released=false;
            var g=G.create("h2d.Graphics",[holder]);
            rounded(g,2,3,5,2,1,0xFFFFFF);
            for(points in [
                [5.,4.,7.,4.,12.,23.,10.,23.],
                [7.,8.,28.,8.,27.2,10.5,7.8,10.5],
                [25.5,9.,28.,9.,24.,20.,21.5,20.],
                [9.,15.5,25.6,15.5,24.,20.,10.4,20.],
                [14.,10.,16.5,10.,17.6,16.,15.1,16.],
                [21.,10.,23.5,10.,22.1,16.,19.6,16.]])polygon(g,points);
            rounded(g,11,22,14,2,1,0xFFFFFF);rounded(g,11,26,4,4,2,0xFFFFFF);rounded(g,22,26,4,4,2,0xFFFFFF);
            G.call("h2d.Object","setScale",g,[8.0]);
            texture=G.create("h3d.mat.Texture",[256,256,flags,format]);targets.push(texture);
            G.call("h3d.mat.Texture","clear",texture,[0,0.0,null]);
            G.call("h2d.Object","drawTo",holder,[texture]);released=true;
            for(pixels in [128,64]) {
                var source=G.staticCall("h2d.Tile","fromTexture",[texture]);
                G.call("h2d.Tile","scaleToSize",source,[pixels*1.0,pixels*1.0]);
                holder=G.create("h2d.Bitmap",[source,null]);released=false;
                G.set(holder,"smooth",true);G.set(holder,"blendMode",blend);
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
        // Keep the title's hue, mixed slightly toward the warm header background.
        for(i in 0...3) {
            var shift=16-i*8,channel=((color>>shift)&255)*0.8+((0xEFE3D1>>shift)&255)*0.2;
            G.set(vector,["x","y","z"][i],channel/255.0);
        }
    }
    public function dispose():Void {
        if(bitmap!=null)G.call("h2d.Object","remove",bitmap);
        if(texture!=null)G.call("h3d.mat.Texture","dispose",texture);
        bitmap=texture=null;
    }
    static function polygon(g:Dynamic,points:Array<Float>):Void {
        var tint=0xFFFFFF,opacity=1.0;
        #if hl
        var color:hl.Ref<Int>=tint,alpha:hl.Ref<Float>=opacity;
        #else
        var color=tint,alpha=opacity;
        #end
        G.call("h2d.Graphics","beginFill",g,[color,alpha]);
        G.call("h2d.Graphics","moveTo",g,[points[0],points[1]]);
        for(i in 1...Std.int(points.length/2))G.call("h2d.Graphics","lineTo",g,[points[i*2],points[i*2+1]]);
        G.call("h2d.Graphics","lineTo",g,[points[0],points[1]]);G.call("h2d.Graphics","endFill",g);
    }
}
