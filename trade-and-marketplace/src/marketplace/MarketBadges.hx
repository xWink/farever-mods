package marketplace;

import trade.GameAccess as G;

/** Embedded player badges, shared by listing rows for the lifetime of a window. */
class MarketBadges {
    public static inline var SIZE=22;
    public static inline var GAP=4;
    final textures:Map<String,Dynamic>=[];
    final failed:Map<String,Bool>=[];
    var tip:Dynamic;
    var tipUi:Dynamic;
    var tipBadge:Dynamic;

    public function new() {}

    public function create(parent:Dynamic,id:String,nativeArray:Dynamic,row:Dynamic):Dynamic {
        var caption=switch(id) {
            case "supporter-bronze": "Bronze Supporter";
            case "supporter-silver": "Silver Supporter";
            case "supporter-gold": "Gold Supporter";
            case "supporter-ruby": "Ruby Supporter";
            case "supporter-emerald": "Emerald Supporter";
            case "supporter-diamond": "Diamond Supporter";
            case "fareverly-creator": "Fareverly Creator";
            default:return null;
        };
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
                // Average source artwork down in half-size passes, keeping a 2x final texture:
                // a single bilinear shrink skips fine edges instead of smoothing
                // them. Bake once per tier, as with the minimap icons.
                var passes:Array<Int>=[],sourceSize=G.integer(G.field(texture,"width"),SIZE*8);
                while(sourceSize>SIZE*8) {sourceSize=Std.int(Math.max(SIZE*8,Math.ceil(sourceSize/2)));passes.push(sourceSize);}
                passes.push(SIZE*4);passes.push(SIZE*2);
                for(i in 0...passes.length) {
                    var pixels=passes[i];
                    var source=G.staticCall("h2d.Tile","fromTexture",[texture]);
                    G.call("h2d.Tile","scaleToSize",source,[pixels*1.0,pixels*1.0]);
                    holder=G.create("h2d.Bitmap",[source,null]);released=false;
                    G.set(holder,"smooth",true);
                    // PNGs have straight alpha; render targets are premultiplied.
                    // Preserve the latter so soft borders do not get darkened.
                    if(i>0)G.set(holder,"blendMode",blend);
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
        bindHover(bitmap,row,caption);
        return bitmap;
    }

    function bindHover(bitmap:Dynamic,row:Dynamic,caption:String):Void {
        // Observe the listing's existing hit target. An interactive over the badge
        // would change native focus/hit-testing even if its events propagated.
        var input=G.field(row,"interactive");
        if(input==null)return;
        var hover=(event:Dynamic)->{
            var bounds=G.call("h2d.Object","getBounds",bitmap,[input,null]);
            var x=G.number(G.field(event,"relX"),Math.NaN),y=G.number(G.field(event,"relY"),Math.NaN);
            if(G.field(event,"cancel")!=true && x>=G.number(G.field(bounds,"xMin")) && x<G.number(G.field(bounds,"xMax"))
                && y>=G.number(G.field(bounds,"yMin")) && y<G.number(G.field(bounds,"yMax"))) {
                var ui=G.current("ui.BaseUI","current");
                if(ui==null || (tip!=null && tipBadge==bitmap && tipUi==ui && G.field(ui,"currentTip")==tip))return;
                hideTip();
                var content=G.create("ui.SimpleTip",[caption,null,null]);
                tip=G.call("ui.BaseUI","setTip",ui,[content,bitmap,null,null]);
                tipUi=ui;tipBadge=bitmap;
            } else hideTip(bitmap);
        };
        for(key in ["onOver","onMove","onCheck"]) {
            var previous=G.field(input,key);
            G.set(input,key,(event:Dynamic)->{
                if(previous!=null)previous(event);
                hover(event);
            });
        }
        var previousOut=G.field(input,"onOut");
        G.set(input,"onOut",(event:Dynamic)->{
            hideTip(bitmap);
            if(previousOut!=null)previousOut(event);
        });
    }

    public function hideTip(?badge:Dynamic):Void {
        if(badge!=null&&tipBadge!=badge)return;
        if(tip!=null&&tipUi!=null&&G.field(tipUi,"currentTip")==tip)
            G.call("ui.BaseUI","removeTip",tipUi,[null]);
        tip=tipUi=tipBadge=null;
    }

    public function dispose():Void {
        hideTip();
        for(texture in textures)G.call("h3d.mat.Texture","dispose",texture);
        textures.clear();failed.clear();
    }
}
