package trade;

import haxe.ds.ObjectMap;
import trade.GameAccess as G;
import trade.TradeTypes;

private typedef LinkInteraction = {
    owner:Dynamic, interactive:Dynamic, push:Dynamic, release:Dynamic,
    wrappedPush:Dynamic, wrappedRelease:Dynamic, captured:Bool
};
private typedef LinkEntry = {token:String, offer:TradeItem};
private typedef LinkBubble = {label:Dynamic, format:Dynamic, wrapper:Dynamic};
private typedef LinkRow = {
    row:Dynamic, label:Dynamic, entries:Array<LinkEntry>, format:Dynamic,
    over:Dynamic, out:Dynamic, click:Dynamic,
    wrappedFormat:Dynamic, wrappedOver:Dynamic, wrappedOut:Dynamic, wrappedClick:Dynamic
};

/** Item links are presentation-only; message history and outgoing text stay intact. */
class ItemLinks {
    static var enabled = true;
    static var offers:ObjectMap<Dynamic, TradeItem> = new ObjectMap();
    static var interactions:ObjectMap<Dynamic, LinkInteraction> = new ObjectMap();
    static var rows:ObjectMap<Dynamic, LinkRow> = new ObjectMap();
    static var bubbles:ObjectMap<Dynamic, LinkBubble> = new ObjectMap();
    static var tipRow:Dynamic;
    static var tipUi:Dynamic;
    static var tip:Dynamic;
    static var reported = false;

    public static function configure(value:Bool):Void {
        if (enabled == value) return;
        enabled = value;
        ItemLinkDraft.configure(value);
        if (!value) hideTip();
        for (row in rows) refresh(row.label);
        for (bubble in bubbles) refresh(bubble.label);
    }

    /** Register custom Marketplace/trade icons whose parent owns their snapshot. */
    public static function bind(object:Dynamic, offer:TradeItem):Void {
        if (object == null || offer == null) return;
        offers.set(object, offer);
        install(object);
    }

    public static function install(object:Dynamic):Void {
        if (object == null || (!offers.exists(object) && !G.isA(object, "ui.comp.ItemButton")
            && !G.isA(object, "ui.comp.ItemSlot") && !G.isA(object, "ui.comp.ItemSlotCost")
            && !G.isA(object, "ui.win.InventorySlot"))) return;
        var interactive = G.field(object, "interactive");
        if (interactive == null) return;
        var old = interactions.get(object);
        if (old != null && old.interactive == interactive && G.field(interactive, "onPush") == old.wrappedPush) return;
        if (old != null) restoreInteraction(old);
        var binding:LinkInteraction = {owner:object, interactive:interactive,
            push:G.field(interactive,"onPush"), release:G.field(interactive,"onRelease"),
            wrappedPush:null, wrappedRelease:null, captured:false};
        binding.wrappedPush = function(event:Dynamic):Void {
            binding.captured = false;
            if (enabled && G.integer(G.field(event,"button"), -1) == 0
                && G.staticCall("hxd.Key","isDown",[18]) == true) {
                try {
                    var offer = resolve(object);
                    if (offer != null) {
                        // Native hit-testing/clipping has already accepted this event.
                        // Consume before onPushInteractive, inventory actions or dragging.
                        binding.captured = true;
                        G.call("h2d.Interactive","preventClick",interactive);
                        G.set(event,"propagate",false); G.set(event,"cancel",false);
                        append(offer);
                        return;
                    }
                } catch (error:Dynamic) {
                    report(error);
                    if (binding.captured) return;
                }
            }
            if (binding.push != null) binding.push(event);
        };
        binding.wrappedRelease = function(event:Dynamic):Void {
            if (binding.captured && G.integer(G.field(event,"button"), -1) == 0) {
                binding.captured = false;
                G.call("h2d.Interactive","preventClick",interactive);
                G.set(event,"propagate",false); G.set(event,"cancel",false);
                return;
            }
            if (binding.release != null) binding.release(event);
        };
        G.set(interactive,"onPush",binding.wrappedPush);
        G.set(interactive,"onRelease",binding.wrappedRelease);
        interactions.set(object,binding);
    }

    static function resolve(object:Dynamic):TradeItem {
        // Prefer an explicit snapshot over decorative native children.
        var current = object;
        for (_ in 0...24) {
            if (current == null) break;
            var offer = offers.get(current);
            if (offer != null) return offer;
            current = G.field(current,"parent");
        }
        current = object;
        for (_ in 0...24) {
            if (current == null) break;
            var stack = G.field(current,"stack"), item = G.field(current,"item");
            if (!G.isA(item,"st.Item")) item = G.field(stack,"item");
            if (G.isA(item,"st.Item")) return TradeInventory.describe(item,
                Std.int(Math.max(1,G.integer(G.field(stack,"count"),G.integer(G.field(current,"count"),1)))));
            current = G.field(current,"parent");
        }
        // Recipe ingredients and shop/catalog buttons may expose only an item definition.
        var inf = G.field(object,"inf"), kind = G.text(G.field(inf,"id"));
        if (kind == "" || TradeInventory.definition(kind) == null) return null;
        var item = G.staticCall("st.Item","create",[kind,null]);
        return item == null || G.field(item,"__host") != null ? null : TradeInventory.describe(item,1);
    }

    static function append(offer:TradeItem):Void {
        var ui = G.current("ui.BaseUI","current");
        if (ui == null || !G.isA(ui,"ui.GameUI")) return;
        var chat = G.call("ui.GameUI","get_chat",ui);
        var input = G.field(G.field(chat,"messageInput"),"input");
        if (input == null) return;
        ItemLinkDraft.attach(chat);
        var token = ItemLinkCodec.encode(offer);
        var draft = ItemLinkDraft.wire(input,G.text(G.field(input,"text")));
        var next = ItemLinkCodec.append(draft,token,G.integer(G.field(input,"maxCharacters"),ItemLinkCodec.MAX_MESSAGE));
        if (next == null) {
            G.call("ui.hud.ChatBox","chatError",chat,[token == null
                ? "This item's details are too large for one chat message."
                : "Not enough room for the item link. Shorten your chat message first."]);
            return;
        }
        G.set(input,"selectionRange",null);
        G.set(input,"cursorIndex",G.call("h2d.TextInput","getTextLength",input));
        G.call("h2d.TextInput","inputText",input,[next.substr(draft.length)]);
        var displayNext = G.text(G.field(input,"text"));
        G.call("ui.hud.ChatBox","focus",chat);
        // Chat focus is deferred; the item click can blur the input and reset
        // its cursor before that focus completes. Finish placement afterwards.
        G.call("ui.UIElement","waitNextFrame",chat,[function():Void {
            try {
                if (!enabled || G.current("ui.BaseUI","current") != ui || G.field(chat,"removed") == true
                    || G.field(G.field(chat,"messageInput"),"input") != input || G.text(G.field(input,"text")) != displayNext) return;
                G.call("h2d.TextInput","focus",input,[null]);
                G.set(input,"selectionRange",null);
                G.set(input,"cursorIndex",G.call("h2d.TextInput","getTextLength",input));
            } catch (error:Dynamic) report(error);
        }]);
    }

    static function entriesFor(text:String):Array<LinkEntry> {
        var entries:Array<LinkEntry> = [];
        for (token in ItemLinkCodec.tokens(text)) {
            var offer = ItemLinkCodec.decode(token);
            if (offer == null) continue;
            // Known database IDs and detached reconstruction are checked before rendering.
            var item = TradeTooltips.previewItem(offer);
            if (item == null) continue;
            var described = TradeInventory.describe(item,offer.count);
            offer.name = described.name; offer.color = described.color;
            entries.push({token:token,offer:offer});
        }
        return entries;
    }

    public static function attach(row:Dynamic):Void {
        var label = G.field(row,"msgText"), message = G.field(row,"message");
        if (label == null || message == null || G.field(message,"notify") != null) return;
        forgetRow(row);
        var entries = entriesFor(G.text(G.field(message,"text")));
        if (entries.length == 0) return;
        var state:LinkRow = {row:row,label:label,entries:entries,format:G.field(label,"formatText"),
            over:G.field(label,"onOverHyperlink"),out:G.field(label,"onOutHyperlink"),click:G.field(label,"onHyperlink"),
            wrappedFormat:null,wrappedOver:null,wrappedOut:null,wrappedClick:null};
        state.wrappedFormat = function(text:String):String {
            if (state.format != null) text = state.format(text);
            if (enabled && text != null) for (i in 0...entries.length)
                text = StringTools.replace(text,entries[i].token,ItemLinkCodec.markup(entries[i].offer.name,entries[i].offer.color,i));
            return text;
        };
        state.wrappedOver = function(href:String):Void {
            var index = linkIndex(href,entries.length);
            if (enabled && index >= 0) {
                try showTip(state,entries[index].offer) catch (error:Dynamic) report(error);
            } else if (state.over != null) state.over(href);
        };
        state.wrappedOut = function(href:String):Void {
            if (linkIndex(href,entries.length) >= 0) { if (tipRow == row) hideTip(); }
            else if (state.out != null) state.out(href);
        };
        state.wrappedClick = function(href:String):Void {
            if (linkIndex(href,entries.length) < 0 && state.click != null) state.click(href);
        };
        rows.set(row,state);
        G.set(label,"formatText",state.wrappedFormat);
        G.set(label,"onOverHyperlink",state.wrappedOver);
        G.set(label,"onOutHyperlink",state.wrappedOut);
        G.set(label,"onHyperlink",state.wrappedClick);
        refresh(label);
    }

    /** Native bubbles cut raw text to 100 characters before formatting. Read the
        complete message and apply that limit to readable names, never encoded tokens. */
    public static function prepareBubble(bubble:Dynamic,message:Dynamic):Void {
        forgetBubble(bubble);
        if (!enabled || message == null || G.field(message,"notify") != null) return;
        var label=G.field(bubble,"messageText"),text=G.text(G.field(message,"text"));
        if (label == null) return;
        var entries=entriesFor(text);
        if (entries.length==0) return;
        var prefix="~wink-bubble-";
        while(text.indexOf(prefix)>=0)prefix+="x";
        var source="",offset=0,visible=0,shortened=false;
        var replacements:Array<{key:String,markup:String}>=[];
        while(offset<text.length && visible<100) {
            var found:LinkEntry=null;
            for(entry in entries) if(text.substr(offset,entry.token.length)==entry.token) {found=entry;break;}
            if(found==null) {source+=text.charAt(offset++);visible++;continue;}
            var name=found.offer.name.substr(0,100-visible),key=prefix+replacements.length+"~";
            replacements.push({key:key,markup:ItemLinkCodec.nameMarkup(name,found.offer.color)});
            source+=key;visible+=name.length;offset+=found.token.length;
            if(name.length<found.offer.name.length) {shortened=true;break;}
        }
        if(shortened||offset<text.length)source+="...";
        // Keep native player-text sanitizing and formatting. Insert only our escaped
        // item-name markup afterwards; bubbles have no links or hover callbacks.
        var clean=G.text(G.staticCall("HText","cleanPlayerText",[source]));
        var state:LinkBubble={label:label,format:G.field(label,"formatText"),wrapper:null};
        state.wrapper=function(nativeText:String):String {
            var result=enabled?clean:nativeText;
            if(state.format!=null)result=state.format(result);
            if(enabled && result!=null)for(replacement in replacements)
                result=StringTools.replace(result,replacement.key,replacement.markup);
            return result;
        };
        bubbles.set(bubble,state);
        G.set(label,"formatText",state.wrapper);
        G.set(label,"prevUnformatted",null);
    }

    static function forgetBubble(bubble:Dynamic):Void {
        var state=bubbles.get(bubble);
        if(state==null)return;
        if(G.field(state.label,"formatText")==state.wrapper)G.set(state.label,"formatText",state.format);
        G.set(state.label,"prevUnformatted",null);
        bubbles.remove(bubble);
    }

    static function linkIndex(href:String, length:Int):Int {
        if (href == null || !~/^wink-item:[0-9]+$/.match(href)) return -1;
        var index = Std.parseInt(href.substr(10));
        return index != null && index >= 0 && index < length ? index : -1;
    }
    static function refresh(label:Dynamic):Void {
        var raw = G.field(label,"prevUnformatted");
        if (raw == null) raw = G.field(label,"text");
        G.set(label,"prevUnformatted",null);
        G.call("ui.comp.FmtText","set_text",label,[raw]);
    }
    static function showTip(row:LinkRow, offer:TradeItem):Void {
        showItemTip(row.row,row.label,offer);
    }
    public static function showDraftTip(input:Dynamic,offer:TradeItem):Void showItemTip(input,input,offer);
    public static function hideDraftTip(input:Dynamic):Void {if(tipRow==input)hideTip();}
    static function showItemTip(owner:Dynamic,anchor:Dynamic,offer:TradeItem):Void {
        hideTip();
        var ui = G.current("ui.BaseUI","current"), element = TradeTooltips.create(offer,null);
        if (ui == null || element == null) return;
        tip = G.call("ui.BaseUI","setTip",ui,[element,anchor,null,null]);
        tipRow = owner; tipUi = ui;
    }
    /** Run after native layout so wrapping and comparison panels are included. */
    public static function fitTooltip(object:Dynamic):Void {
        if (object == null || object != tip || tipUi == null || G.field(tipUi,"currentTip") != object) return;
        var parent = G.field(object,"parent"), scene = G.call("h2d.Object","getScene",object);
        if (parent == null || scene == null) return;
        var bounds = G.call("h2d.Object","getBounds",object,[object,null]);
        // Convert screen edges into the tooltip parent's coordinates, including UI scale.
        var top = G.call("h2d.Object","globalToLocal",parent,[G.point(8,8)]);
        var bottom = G.call("h2d.Object","globalToLocal",parent,[G.point(
            G.number(G.field(scene,"width"))-8,G.number(G.field(scene,"height"))-8)]);
        var fit = TradeTooltipPlacement.fit(G.number(G.field(object,"x")),G.number(G.field(object,"y")),{
            xMin:G.number(G.field(bounds,"xMin")),yMin:G.number(G.field(bounds,"yMin")),
            xMax:G.number(G.field(bounds,"xMax")),yMax:G.number(G.field(bounds,"yMax"))
        },{xMin:G.number(G.field(top,"x")),yMin:G.number(G.field(top,"y")),
            xMax:G.number(G.field(bottom,"x")),yMax:G.number(G.field(bottom,"y"))});
        G.call("h2d.Object","setScale",object,[fit.scale]);
        G.call("h2d.Object","setPosition",object,[fit.x,fit.y]);
    }
    static function hideTip():Void {
        var ui = tipUi, old = tip;
        tipRow = null; tipUi = null; tip = null;
        if (ui != null && old != null && G.field(ui,"currentTip") == old)
            G.call("ui.BaseUI","removeTip",ui,[null]);
    }
    static function restoreInteraction(binding:LinkInteraction):Void {
        if (G.field(binding.interactive,"onPush") == binding.wrappedPush) G.set(binding.interactive,"onPush",binding.push);
        if (G.field(binding.interactive,"onRelease") == binding.wrappedRelease) G.set(binding.interactive,"onRelease",binding.release);
    }
    static function forgetRow(row:Dynamic):Void {
        if (tipRow == row) hideTip();
        var state = rows.get(row);
        if (state == null) return;
        for (entry in [{key:"formatText",current:state.wrappedFormat,original:state.format},
            {key:"onOverHyperlink",current:state.wrappedOver,original:state.over},
            {key:"onOutHyperlink",current:state.wrappedOut,original:state.out},
            {key:"onHyperlink",current:state.wrappedClick,original:state.click}])
            if (G.field(state.label,entry.key) == entry.current) G.set(state.label,entry.key,entry.original);
        rows.remove(row);
    }
    public static function forget(object:Dynamic):Void {
        ItemLinkDraft.forget(object);
        offers.remove(object);
        var binding = interactions.get(object);
        if (binding != null) { restoreInteraction(binding); interactions.remove(object); }
        forgetRow(object);
        forgetBubble(object);
    }
    public static function dispose():Void {
        ItemLinkDraft.dispose();
        hideTip();
        for (binding in interactions) restoreInteraction(binding);
        for (row in [for (row in rows.keys()) row]) forgetRow(row);
        for (bubble in [for (bubble in bubbles.keys()) bubble]) forgetBubble(bubble);
        offers = new ObjectMap(); interactions = new ObjectMap(); rows = new ObjectMap(); bubbles = new ObjectMap();
    }
    public static function report(error:Dynamic):Void {
        if (!reported) { reported = true; TradeDiagnostics.log("Item links: "+Std.string(error)); }
    }
}
