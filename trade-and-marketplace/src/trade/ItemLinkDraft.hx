package trade;

import haxe.ds.ObjectMap;
import trade.GameAccess as G;
import trade.ItemLinkDraftModel.DraftItemAtom;
import trade.TradeTypes;

private typedef DraftView = {code:Int,label:Dynamic,x:Float,y:Float,width:Float};
private typedef DraftState = {
    chat:Dynamic,input:Dynamic,model:ItemLinkDraftModel,sourceFont:Dynamic,font:Dynamic,measure:Dynamic,mask:Dynamic,
    widths:Map<Int,Float>,views:Array<DraftView>,text:String,enter:Dynamic,move:Dynamic,out:Dynamic,
    enterWrapper:Dynamic,moveWrapper:Dynamic,outWrapper:Dynamic,busy:Bool,hover:Int,limit:Int
};

/** Native text editing uses one glyph per link; rich labels share that glyph's exact width. */
class ItemLinkDraft {
    static var states:ObjectMap<Dynamic,DraftState> = new ObjectMap();
    static var enabled = true;

    public static function attach(chat:Dynamic):Void {
        if (!enabled || chat == null) return;
        var input = G.field(G.field(chat,"messageInput"),"input");
        if (input == null || states.exists(input)) return;
        var s:DraftState = {chat:chat,input:input,model:new ItemLinkDraftModel(),sourceFont:null,font:null,measure:null,mask:null,
            widths:[],views:[],text:null,enter:G.field(input,"onEnter"),move:G.field(input,"onMove"),out:G.field(input,"onOut"),
            enterWrapper:null,moveWrapper:null,outWrapper:null,busy:false,hover:-1,
            limit:Std.int(Math.min(ItemLinkCodec.MAX_MESSAGE,G.integer(G.field(input,"maxCharacters"),ItemLinkCodec.MAX_MESSAGE)))};
        s.enterWrapper = function():Void {
            var display = G.text(G.field(input,"text")), wire = s.model.expand(display);
            if (wire.length > s.limit) {error(s);return;}
            // Native onEnter reads text, clears the editor and sends through its normal path.
            // Expand only for that read; no alternate sending/network path is introduced.
            s.busy = true;G.set(input,"text",wire);
            try { if (s.enter != null) s.enter(); }
            catch (e:Dynamic) {
                G.call("h2d.TextInput","set_text",input,[display]);s.busy=false;changed(input);throw e;
            }
            if (G.text(G.field(input,"text")) == wire) G.set(input,"text",display);
            s.busy=false;changed(input);
        };
        s.moveWrapper = function(event:Dynamic):Void {
            if (s.move != null) s.move(event);
            try {
                var x=G.number(G.field(event,"relX")),y=G.number(G.field(event,"relY")),hit=-1;
                var scroll=G.number(G.field(input,"scrollX"));
                if (s.mask != null && x>=0 && x<G.number(G.field(s.mask,"width")) && y>=0 && y<G.number(G.field(s.mask,"height")))
                    for (view in s.views) if(x>=view.x-scroll && x<view.x-scroll+view.width && y>=view.y && y<view.y+G.number(G.field(s.sourceFont,"lineHeight"))) {hit=view.code;break;}
                if (s.hover != hit) {
                    s.hover=hit;
                    if(hit<0)ItemLinks.hideDraftTip(input);else ItemLinks.showDraftTip(input,s.model.atoms.get(hit).offer);
                }
            } catch(e:Dynamic) ItemLinks.report(e);
        };
        s.outWrapper = function(event:Dynamic):Void {
            s.hover=-1;ItemLinks.hideDraftTip(input);
            if(s.out!=null)s.out(event);
        };
        states.set(input,s);
        G.set(input,"onEnter",s.enterWrapper);G.set(input,"onMove",s.moveWrapper);G.set(input,"onOut",s.outWrapper);
        var original=G.text(G.field(input,"text")),collapsed=collapse(s,original);
        if(collapsed!=original)G.call("h2d.TextInput","set_text",input,[collapsed]);
        changed(input);
    }

    static function resolve(token:String):TradeItem {
        var offer=ItemLinkCodec.decode(token);
        if(offer==null)return null;
        var item=TradeTooltips.previewItem(offer);
        if(item==null)return null;
        var described=TradeInventory.describe(item,offer.count);
        offer.name=described.name;offer.color=described.color;
        return offer;
    }
    static function collapse(s:DraftState,text:String):String {
        var result=s.model.collapse(text,resolve);
        var visible=s.model.visible(result);
        if(visible.length>0) {
            ensureFont(s);
            for(entry in visible)glyph(s,entry.atom);
        }
        return result;
    }
    public static function wire(input:Dynamic,text:String):String {
        var s=states.get(input);
        return s==null?text:s.model.expand(text);
    }
    /** null means continue the native setter unchanged. */
    public static function rewrite(input:Dynamic,text:String):String {
        var s=states.get(input);
        if(s==null||s.busy||!enabled)return null;
        var result=collapse(s,text);
        return result==text?null:result;
    }
    /** True consumes an insertion that was transformed or exceeded the wire budget. */
    public static function insert(input:Dynamic,text:String):Bool {
        var s=states.get(input);
        if(s==null||s.busy||!enabled)return false;
        var value=collapse(s,text),current=G.text(G.field(input,"text")),selection=G.field(input,"selectionRange");
        var start=G.integer(G.field(input,"cursorIndex")),end=start;
        if(selection!=null) {start=G.integer(G.field(selection,"start"));end=start+G.integer(G.field(selection,"length"));}
        start=G.integer(G.call("h2d.TextInput","getTextPos",input,[start]));
        end=G.integer(G.call("h2d.TextInput","getTextPos",input,[end]));
        if(!s.model.fits(s.model.replace(current,start,end,value),s.limit)) {error(s);return true;}
        if(value==text)return false;
        s.busy=true;
        try G.call("h2d.TextInput","inputText",input,[value]) catch(e:Dynamic) {s.busy=false;throw e;}
        s.busy=false;changed(input);
        return true;
    }
    static function error(s:DraftState):Void
        G.call("ui.hud.ChatBox","chatError",s.chat,["Not enough room for the item link and message. Shorten your message first."]);

    static function label(s:DraftState,parent:Dynamic):Dynamic {
        var result=G.create("ui.comp.FmtText",["",parent]);
        // Item names are escaped below; bypass the game's [id]/$function substitutions.
        G.set(result,"formatText",function(text:String):String return text);
        G.call("ui.comp.FmtText","set_font",result,[s.sourceFont]);
        G.call("h2d.Text","set_textColor",result,[0xffffff]);
        G.call("ui.comp.FmtText","set_useEllipsis",result,[false]);
        G.call("ui.comp.FmtText","set_maxWidthText",result,[null]);
        G.call("ui.comp.FmtText","set_textMultiline",result,[false]);
        G.set(result,"dropShadow",G.field(s.input,"dropShadow"));
        return result;
    }
    static function markup(atom:DraftItemAtom):String
        return '<font color="#'+StringTools.hex(atom.offer.color&0xffffff,6)+'"><b>'+StringTools.htmlEscape(atom.offer.name)+'</b></font>';
    static function ensureFont(s:DraftState):Void {
        var current=G.field(s.input,"font");
        if(current==s.font && current!=null)return;
        if(current==null)throw "Chat input font unavailable";
        s.sourceFont=current;s.font=G.call("h2d.Font","clone",current);
        G.set(s.font,"subFonts",G.field(current,"subFonts"));
        s.widths=[];s.text=null;
        if(s.measure!=null)G.call("h2d.Object","remove",s.measure);
        s.measure=label(s,null);
        G.call("h2d.TextInput","set_font",s.input,[s.font]);
    }
    static function glyph(s:DraftState,atom:DraftItemAtom):Float {
        var width=s.widths.get(atom.code);
        if(width!=null)return width;
        G.call("ui.comp.FmtText","set_text",s.measure,[markup(atom)]);
        width=Math.ceil(G.number(G.call("h2d.Text","get_textWidth",s.measure)))+2;
        // Empty atlas tile reserves the full rich-label width without drawing a placeholder.
        var tile=G.call("h2d.Tile","clone",G.field(s.font,"tile"));
        G.set(tile,"width",0.0);G.set(tile,"height",0.0);
        var character=G.create("h2d.FontChar",[tile,width]);
        G.call("haxe.ds.IntMap","set",G.field(s.font,"glyphs"),[atom.code,character]);
        s.widths.set(atom.code,width);
        return width;
    }
    public static function changed(input:Dynamic):Void {
        var s=states.get(input);
        if(s==null||s.busy||!enabled)return;
        var text=G.text(G.field(input,"text"));
        if(text==s.text&&(s.font==null||G.field(input,"font")==s.font))return;
        var items=s.model.visible(text);
        if(items.length>0)ensureFont(s);
        if(text==s.text)return;
        s.text=text;s.hover=-1;ItemLinks.hideDraftTip(input);
        if(items.length>0 && s.mask==null)s.mask=G.create("h2d.Mask",[1,1,input]);
        while(s.views.length>items.length)G.call("h2d.Object","remove",s.views.pop().label);
        for(i in 0...items.length) {
            var item=items[i],width=glyph(s,item.atom),view:DraftView;
            if(i>=s.views.length) {view={code:-1,label:label(s,s.mask),x:0,y:0,width:0};s.views.push(view);}
            else view=s.views[i];
            G.call("ui.comp.FmtText","set_font",view.label,[s.sourceFont]);
            G.call("ui.comp.FmtText","set_text",view.label,[markup(item.atom)]);
            view.code=item.atom.code;view.width=width;
            view.x=G.number(G.call("h2d.Text","calcTextWidth",input,[text.substring(0,item.index)]));
            view.y=0;
        }
        G.set(input,"needsRebuild",true);G.set(input,"splitLines",null);
    }
    /** Called after native drawing has computed the final horizontal scroll offset. */
    public static function position(input:Dynamic):Void {
        var s=states.get(input);
        if(s==null||s.mask==null||s.views.length==0)return;
        var width=G.integer(G.call("h2d.TextInput","getInputWidth",input));
        if(width<0)width=Std.int(Math.ceil(G.number(G.field(G.field(input,"interactive"),"width"))));
        var height=G.integer(G.field(G.field(input,"interactive"),"height"),Std.int(G.number(G.field(s.sourceFont,"lineHeight"))));
        G.set(s.mask,"width",Std.int(Math.max(0,width)));G.set(s.mask,"height",Std.int(Math.max(0,height)));
        G.call("h2d.Object","calcAbsPos",s.mask);
        for(view in s.views) {
            G.call("h2d.Object","setPosition",view.label,[view.x-G.number(G.field(input,"scrollX")),view.y]);
            G.call("h2d.Object","calcAbsPos",view.label);
        }
    }
    public static function configure(value:Bool):Void {
        enabled=value;
        if(!value)for(s in [for(s in states)s])forget(s.chat);
    }
    public static function forget(object:Dynamic):Void {
        for(s in [for(s in states)if(s.chat==object||s.input==object)s]) {
            states.remove(s.input);ItemLinks.hideDraftTip(s.input);
            for(entry in [{key:"onEnter",wrapper:s.enterWrapper,original:s.enter},{key:"onMove",wrapper:s.moveWrapper,original:s.move},{key:"onOut",wrapper:s.outWrapper,original:s.out}])
                if(G.field(s.input,entry.key)==entry.wrapper)G.set(s.input,entry.key,entry.original);
            var display=G.text(G.field(s.input,"text")),wire=s.model.expand(display);
            if(wire!=display) {
                G.call("h2d.TextInput","set_text",s.input,[wire]);
                G.set(s.input,"selectionRange",null);G.set(s.input,"cursorIndex",G.call("h2d.TextInput","getTextLength",s.input));
            }
            // Undo entries can contain private glyphs even when the current draft is empty.
            if(s.model.atoms.keys().hasNext())G.call("h2d.TextInput","clearUndo",s.input);
            if(s.font!=null&&G.field(s.input,"font")==s.font)G.call("h2d.TextInput","set_font",s.input,[s.sourceFont]);
            if(s.mask!=null)G.call("h2d.Object","remove",s.mask);
            if(s.measure!=null)G.call("h2d.Object","remove",s.measure);
        }
    }
    public static function dispose():Void {for(s in [for(s in states)s])forget(s.chat);}
}
