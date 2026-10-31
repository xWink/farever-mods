package groupfinder;

import hlx.runtime.Bus;
import hlx.runtime.ModConfig;
import hlx.runtime.HlxPrefixResult;
import modinput.Hotkey;
import modinput.NativeHotkey;
import groupfinder.GameAccess as G;

typedef GroupConfig = {enabled:Bool,hotkey:Dynamic,x:Null<Float>,y:Null<Float>};

@:build(hlx.runtime.Mod.build())
class GroupFinderMod {
    @:hlx.config static var config:GroupConfig={enabled:true,hotkey:120,x:null,y:null};
    static var controller:GroupController;
    public static function enabled():Bool return config.enabled;
    public static function report(error:String):Void trace("[Group Finder] "+error);
    public static function position():{x:Null<Float>,y:Null<Float>} return {x:config.x,y:config.y};
    public static function moved(x:Float,y:Float):Void {
        if(config.x==x&&config.y==y)return;
        config.x=x;config.y=y;ModConfig.save(HlxRuntime.moduleName(),config);
    }
    static function main():Void {
        config.hotkey=Hotkey.normalize(config.hotkey,120);
        ModConfig.save(HlxRuntime.moduleName(),config);controller=new GroupController();
        Bus.subscribe("better-mod-settings/config-changed/"+HlxRuntime.moduleName(),(_)->{
            config=ModConfig.load(HlxRuntime.moduleName(),config);
            config.hotkey=Hotkey.normalize(config.hotkey,120);
        });
    }
    @:hlx.postfix(GameApp.update)
    static function update(instance:Dynamic,dt:Float,result:Void):Void {
        if(controller==null)return;
        try {
            controller.update(instance,haxe.Timer.stamp());
            if(enabled()&&controller.party!=null&&NativeHotkey.isPressed(config.hotkey)) {
                var ui=G.current("ui.BaseUI","current");
                if(ui!=null&&G.call("ui.BaseUI","getFocusedTextInput",ui)==null)controller.toggle();
            }
        } catch(error:Dynamic)controller.fail(error);
    }
    @:hlx.prefix(h2d.TextInput.inputText)
    static function limitTitle(instance:Dynamic,text:String):HlxPrefixResult<Void> {
        if(controller!=null&&controller.view.insertTitle(instance,text))return Skip;
        return Continue;
    }
    @:hlx.prefix(GameApp.connectTo)
    static function beginTravel(instance:Dynamic,connectionInfo:Dynamic):HlxPrefixResult<Void> {
        if(controller!=null)controller.beginTravel();return Continue;
    }
    @:hlx.postfix(GameApp.finishedLoading)
    static function finishTravel(instance:Dynamic,result:Void):Void {
        if(controller!=null)controller.finishTravel();
    }
    @:hlx.prefix(GameApp.leaveGame)
    static function leaveGame(instance:Dynamic,errorMessage:String):HlxPrefixResult<Void> {
        if(controller!=null)controller.endSession();return Continue;
    }
    @:hlx.prefix(st.player.ChatClient.localReceiveMessage)
    static function receiveLocal(instance:Dynamic,message:Dynamic):HlxPrefixResult<Void> return receive(instance,message);
    @:hlx.prefix(st.player.ChatClient.receiveMessage__impl)
    static function receiveRpc(instance:Dynamic,message:Dynamic):HlxPrefixResult<Void> return receive(instance,message);
    @:hlx.postfix(st.player.NetNotify.select)
    static function invitationSelected(instance:Dynamic,b:Bool,onDone:Dynamic,result:Dynamic):Void {
        if(controller!=null)try controller.invitationSelected(instance,b,result)catch(e:Dynamic)report("Invitation response: "+Std.string(e));
    }
    @:hlx.postfix(ui.hud.ChatBoxMessage.init)
    static function styleNotice(instance:Dynamic,result:Void):Void {
        try GroupNotices.decorate(instance)catch(e:Dynamic)report("Notification style: "+Std.string(e));
    }
    @:hlx.prefix(ui.hud.ChatBox.receiveMessage)
    static function receiveRow(instance:Dynamic,message:Dynamic):HlxPrefixResult<Void> return receive(G.field(instance,"chatClient"),message);
    static function receive(client:Dynamic,message:Dynamic):HlxPrefixResult<Void> {
        var text=G.text(G.field(message,"text"));if(!GroupWire.isPacket(text))return Continue;
        if(controller!=null)try controller.receive(client,message,text)catch(e:Dynamic)report("Group request: "+Std.string(e));
        G.set(message,"text","");return Skip;
    }
    @:hlx.prefix(GameApp.dispose)
    static function dispose(instance:Dynamic):HlxPrefixResult<Void> {if(controller!=null)controller.disconnect();return Continue;}
    @:hlx.prefix(ui.win.BaseWindow.autoDisplay)
    static function suppressAutoDisplay(instance:Dynamic):HlxPrefixResult<Void> return GroupFrame.constructing?Skip:Continue;
    @:hlx.prefix(ui.win.BaseWindow.onBack)
    static function back(instance:Dynamic):HlxPrefixResult<Bool> {
        if(controller!=null&&controller.view.owns(instance)){controller.close();return SkipWith(true);}return Continue;
    }
    @:hlx.prefix(ui.hud.ChatBox.handleCommand)
    static function command(instance:Dynamic,name:String,args:Dynamic):HlxPrefixResult<String> {
        if(name==null||["lfg","groupfinder"].indexOf(name.toLowerCase())<0)return Continue;
        if(controller!=null)controller.open();return SkipWith(null);
    }
}
