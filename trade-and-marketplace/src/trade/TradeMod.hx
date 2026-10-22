package trade;
import hlx.runtime.HlxPrefixResult;
import hlx.runtime.ModConfig;
import hlx.runtime.Bus;
import trade.GameAccess as G;
import modinput.Hotkey;
import modinput.NativeHotkey;
typedef TradeConfig = {enabled:Bool,rejectAllRequests:Bool,marketplaceHotkey:Dynamic,requestX:Null<Float>,requestY:Null<Float>,tradeX:Null<Float>,tradeY:Null<Float>,?marketHideMine:Bool,?marketOnlineOnly:Bool};
@:build(hlx.runtime.Mod.build())
class TradeMod {
    @:hlx.config static var config:TradeConfig = {enabled:true,rejectAllRequests:false,marketplaceHotkey:118,requestX:null,requestY:null,tradeX:null,tradeY:null,marketHideMine:false,marketOnlineOnly:false};
    static var controller:TradeController;
    static var market:marketplace.MarketController;
    static var menuUi:Dynamic;
    static var menuUid:String;
    static var stoppingDrag = false;
    public static function chatError(message:String):Void {if(controller!=null)controller.chat(message);}
    public static function enabled():Bool return config.enabled;
    public static function rejectsRequests():Bool return config.rejectAllRequests;
    public static function requestPosition():{x:Null<Float>,y:Null<Float>} return {x:config.requestX,y:config.requestY};
    public static function saveRequestPosition(x:Float,y:Float):Void { if (config.requestX == x && config.requestY == y) return; config.requestX = x; config.requestY = y; ModConfig.save(HlxRuntime.moduleName(),config); }
    public static function tradePosition():{x:Null<Float>,y:Null<Float>} return {x:config.tradeX,y:config.tradeY};
    public static function saveTradePosition(x:Float,y:Float):Void {
        if (config.tradeX == x && config.tradeY == y) return;
        config.tradeX = x; config.tradeY = y; ModConfig.save(HlxRuntime.moduleName(),config);
    }
    public static function marketplaceFilters():{hideMine:Bool,onlineOnly:Bool}
        return {hideMine:config.marketHideMine==true,onlineOnly:config.marketOnlineOnly==true};
    public static function saveMarketplaceFilters(hideMine:Bool,onlineOnly:Bool):Void {
        if(config.marketHideMine==hideMine&&config.marketOnlineOnly==onlineOnly)return;
        config.marketHideMine=hideMine;config.marketOnlineOnly=onlineOnly;
        ModConfig.save(HlxRuntime.moduleName(),config);
    }
    static function main():Void {
        config.marketplaceHotkey = Hotkey.normalize(config.marketplaceHotkey,118);
        ModConfig.save(HlxRuntime.moduleName(),config); controller = new TradeController(); market = new marketplace.MarketController();
        Bus.subscribe("better-mod-settings/config-changed/"+HlxRuntime.moduleName(),(_)->{
            config = ModConfig.load(HlxRuntime.moduleName(),config);
            config.marketplaceHotkey = Hotkey.normalize(config.marketplaceHotkey,118);
        });
    }
    @:hlx.postfix(GameApp.update)
    static function afterFrame(instance:Dynamic,dt:Float,result:Void):Void {
        if (controller != null) try {
            controller.update(instance,haxe.Timer.stamp());
        } catch(e:Dynamic) controller.fail(e);
        if (market != null) try {
            market.update(instance,haxe.Timer.stamp());
            if (enabled() && market.player != null && NativeHotkey.isPressed(config.marketplaceHotkey)) {
                var ui=G.current("ui.BaseUI","current");
                if(ui!=null && (market.view.isOpen() || G.call("ui.BaseUI","getFocusedTextInput",ui)==null))market.toggle();
            }
        } catch (error:Dynamic) market.fail(error);
    }
    @:hlx.postfix(ui.Tooltip.sync)
    static function fitTradeTooltip(instance:Dynamic,engine:Dynamic,result:Void):Void {
        if (controller != null && controller.view.shown()) controller.view.fitTooltip(instance);
    }
    @:hlx.prefix(client.UnitController.isInputBlocked)
    static function blockTradeInputs(instance:Dynamic):HlxPrefixResult<Bool> return controller != null && controller.controlsLocked(instance) ? SkipWith(true) : Continue;
    @:hlx.prefix(client.PlayerController.tryResolveSkillRequests)
    static function blockQueuedSkills(instance:Dynamic):HlxPrefixResult<Bool> return controller != null && controller.controlsLocked(instance) ? SkipWith(false) : Continue;
    @:hlx.postfix(client.PlayerController.update)
    static function positionForTrade(instance:Dynamic,dt:Float,result:Void):Void {
        if (controller != null) try controller.driveMovement(instance) catch(e:Dynamic) controller.fail(e);
    }
    @:hlx.prefix(ent.Interactible.checkRequestInteraction)
    static function blockManualPickup(instance:Dynamic,uid:hl.I64):HlxPrefixResult<Dynamic> {
        return controller != null && controller.blocksPickup(instance,Std.string(uid))
            ? SkipWith(G.enumValue("EReason","Custom",["Finish or cancel the trade before picking up items."])) : Continue;
    }
    @:hlx.prefix(GameApp.dispose)
    static function beforeDispose(instance:Dynamic):HlxPrefixResult<Void> {
        if (market != null) market.disconnect();
        if (controller != null) controller.dispose(); menuUi = null; menuUid = null; return Continue;
    }
    @:hlx.prefix(ui.win.BaseWindow.autoDisplay)
    static function suppressAutoDisplay(instance:Dynamic):HlxPrefixResult<Void> return TradeFrame.constructing ? Skip : Continue;
    @:hlx.prefix(ui.win.BaseWindow.onBack)
    static function back(instance:Dynamic):HlxPrefixResult<Bool> return controller != null
        && ((market != null && market.view.closeFromBack(instance)) || controller.view.closeFromBack(instance) || controller.requestPopup.closeFromBack(instance)) ? SkipWith(true) : Continue;
    @:hlx.prefix(ui.win.BaseWindow.closeOtherOnOpen)
    static function keepOtherWindows(instance:Dynamic,other:Dynamic):HlxPrefixResult<Bool> return controller != null && controller.requestPopup.ownsWindow(instance) ? SkipWith(false) : Continue;
    @:hlx.prefix(ui.win.BaseWindow.closeSelfOnOpen)
    static function keepRequest(instance:Dynamic,other:Dynamic):HlxPrefixResult<Bool> return controller != null
        && (controller.requestPopup.ownsWindow(instance) || controller.view.blocksClosing(instance)) ? SkipWith(false) : Continue;
    @:hlx.prefix(ui.win.BaseWindow.canClose)
    static function preventExchangeClose(instance:Dynamic):HlxPrefixResult<Bool> return controller != null && controller.view.blocksClosing(instance) ? SkipWith(false) : Continue;
    @:hlx.prefix(ui.BaseUI.removeWindow)
    static function keepExchangeWindow(instance:Dynamic,window:Dynamic):HlxPrefixResult<Void> return controller != null && controller.view.blocksClosing(window) ? Skip : Continue;
    @:hlx.prefix(GameApp.toggleCharacterUIViewMode)
    static function openBackpack(instance:Dynamic,mode:Dynamic):HlxPrefixResult<Dynamic> {
        if (controller == null || !controller.view.shown() || (mode != null && G.enumName(mode) != "Character")) return Continue;
        try controller.view.showInventory() catch(e:Dynamic) controller.fail(e); return SkipWith(null);
    }
    @:hlx.prefix(ui.hud.ChatBox.handleCommand)
    static function command(instance:Dynamic,name:String,args:Dynamic):HlxPrefixResult<String> {
        if (name != null && ["market","marketplace"].indexOf(name.toLowerCase()) >= 0) {
            if (market != null) market.open(); return SkipWith(null);
        }
        if (name == null || name.toLowerCase() != "trade") return Continue;
        if (controller != null) try {
            if (!enabled()) controller.chat("Enable Trade + Marketplace in Better Mod Settings first.");
            else controller.requestName([for(a in G.array(args)) G.text(a)].join(" "));
        } catch(e:Dynamic) controller.fail(e);
        return SkipWith(null);
    }
    @:hlx.prefix(st.player.ChatClient.localReceiveMessage)
    static function receive(instance:Dynamic,message:Dynamic):HlxPrefixResult<Void> return receiveTrade(instance,message);
    @:hlx.prefix(st.player.ChatClient.receiveMessage__impl)
    static function receiveRpc(instance:Dynamic,message:Dynamic):HlxPrefixResult<Void> return receiveTrade(instance,message);
    @:hlx.prefix(ui.hud.ChatBox.receiveMessage)
    static function receiveChatRow(instance:Dynamic,message:Dynamic):HlxPrefixResult<Void> return receiveTrade(G.field(instance,"chatClient"),message);
    static function receiveTrade(client:Dynamic,message:Dynamic):HlxPrefixResult<Void> {
        var text = G.text(G.field(message,"text")); if (!TradeWire.isPacket(text)) return Continue;
        if (controller != null) try controller.receive(client,message,text) catch(e:Dynamic) controller.fail(e);
        G.set(message,"text",""); return Skip;
    }
    @:hlx.prefix(ui.UIElement.tryRightClick)
    static function rightClick(instance:Dynamic):HlxPrefixResult<Bool> {
        if (controller == null || controller.state == null || !controller.view.shown()) return Continue;
        var slot = inventorySlot(instance);
        if (slot == null || G.field(slot,"inventory") != controller.inv.inventory) return Continue;
        try controller.addSlot(slot,false) catch(e:Dynamic) controller.fail(e); return SkipWith(true);
    }
    @:hlx.postfix(ui.win.InventorySlot.canBeDraggedTo)
    static function canOffer(instance:Dynamic,target:Dynamic,result:Bool):Bool {
        return controller != null && controller.state != null && controller.state.editable() && controller.view.owns(target)
            && G.field(instance,"inventory") == controller.inv.inventory ? true : result;
    }
    @:hlx.prefix(ui.UIElement.stopDrag)
    static function endDrag(instance:Dynamic,cancel:hl.Ref<Bool>):HlxPrefixResult<Void> {
        if (stoppingDrag || (cancel != null && cancel.get()) || controller == null || controller.state == null
            || !controller.view.shown() || !G.isA(instance,"ui.win.InventorySlot")) return Continue;
        try {
            if (!controller.view.dropTarget()) return Continue;
            controller.addSlot(instance,true); stopNativeDrag(instance); return Skip;
        } catch(e:Dynamic) { controller.fail(e); try stopNativeDrag(instance) catch(_:Dynamic) {} return Skip; }
    }
    static function stopNativeDrag(instance:Dynamic):Void {
        stoppingDrag = true; var value = true; var cancel:hl.Ref<Bool> = value;
        try G.call("ui.UIElement","stopDrag",instance,[cancel]) catch(e:Dynamic) { stoppingDrag = false; throw e; }
        stoppingDrag = false;
    }
    static function inventorySlot(object:Dynamic):Dynamic {
        while (object != null) { if (G.isA(object,"ui.win.InventorySlot")) return object; object = G.field(object,"parent"); } return null;
    }
    @:hlx.prefix(ui.GameUI.openPlayerInteractionMenu)
    static function beginMenu(instance:Dynamic,uid:String,name:String,position:Dynamic):HlxPrefixResult<Dynamic> {
        menuUi = enabled() ? instance : null; menuUid = G.text(uid); return Continue;
    }
    @:hlx.postfix(ui.GameUI.openPlayerInteractionMenu)
    static function finishMenu(instance:Dynamic,uid:String,name:String,position:Dynamic,result:Dynamic):Dynamic { menuUi = null; menuUid = null; return result; }
    @:hlx.prefix(ui.BaseUI.displayContextMenu)
    static function extendMenu(instance:Dynamic,entries:Dynamic,position:Dynamic):HlxPrefixResult<Dynamic> {
        if (instance != menuUi || menuUid == null || controller == null) return Continue;
        var uid = menuUid; menuUi = null; menuUid = null;
        try {
            var me = G.field(G.staticCall("GameApp","get",[]),"me");
            if (controller.ensure(me) && uid != controller.state.self && controller.nearbyPlayer(uid) != null)
                G.call("hl.types.ArrayObj","pushDyn",entries,[{label:"Trade",onClick:()->controller.request(uid)}]);
        } catch(e:Dynamic) controller.fail(e);
        return Continue;
    }
}
