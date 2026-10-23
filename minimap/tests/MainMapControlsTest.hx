import minimap.MainMapControls;
import minimap.MinimapSettings;
import minimap.GameAccess as G;
class MainMapControlsTest {
    static var checks = 0;
    static function eq(a:Dynamic,b:Dynamic,why:String):Void {
        checks++; if(a!=b) throw why+': expected $b, got $a';
    }
    // Shipped native predicate: map may allow keyboard but still block gamepad.
    static function blocks(w:Dynamic,pad:Bool=false):Bool return (w.windowFlags&2)!=0 && (pad || (w.windowFlags&4)==0);
    static function clamp(c:MainMapControls,w:Dynamic,s:MinimapSettings,z:Float):Float {
        w.targetZoom=z; c.beforeClamp(w,s); G.call('ui.win.MapWindow','clampTargetZoom',w); c.afterClamp(w); return w.targetZoom;
    }
    static function main():Void {
        var s:MinimapSettings=cast {mainMapEnabled:true,minimapEnabled:true,mainMapMovement:false};
        var c=new MainMapControls(), w:Dynamic={windowFlags:1034,targetZoom:1.}, other:Dynamic={windowFlags:10};
        c.update(w,s); eq(blocks(w),true,'Movement blocked by default');
        s.mainMapMovement=true; c.update(w,s);
        eq(blocks(w),false,'Native character movement/autorun can run'); eq(blocks(w,true),true,'Gamepad remains native');
        eq(blocks(other),true,'Other windows retain movement lock'); eq(w.windowFlags&8,8,'Skill blocking retained');
        eq(w.windowFlags&1024,1024,'Free mouse retained');
        c.beginInputs(w); var p:Dynamic={x:-1.,y:1.}; c.filterMove(p);
        eq(p.x,0.,'Keyboard no longer pans map X'); eq(p.y,0.,'Keyboard no longer pans map Y');
        c.endInputs(); p.x=-1.; p.y=1.; c.filterMove(p);
        eq(p.x,-1.,'Character direction remains native'); eq(p.y,1.,'Remapped movement remains native');
        G.globals['padActive']=true; c.beginInputs(w); c.filterMove(p); eq(p.x,-1.,'Controller map navigation retained');
        c.endInputs(); G.globals['padActive']=false;
        w.windowFlags|=128; s.mainMapMovement=false; c.update(w,s);
        eq(blocks(w),true,'Disable restores map lock'); eq(w.windowFlags&128,128,'Other flag edits preserved');
        s.mainMapMovement=true; var selector:Dynamic={windowFlags:10,selector:true}; c.update(selector,s);
        eq(selector.windowFlags,10,'Selection dialogs untouched');
        c.update(w,s); c.beginInputs(w); c.remove(w);
        eq(blocks(w),true,'Closing restores flags'); eq(c.suppressMapMovement,false,'Closing clears input scope');
        var allowed:Dynamic={windowFlags:14}; c.update(allowed,s); c.remove(allowed);
        eq(allowed.windowFlags,14,'Preexisting permission retained');
        eq(clamp(c,w,s,0.1),0.5,'Native minimum retained'); eq(clamp(c,w,s,1.5),1.5,'Normal zoom retained');
        eq(clamp(c,w,s,3.),3.,'Extra zoom works'); eq(clamp(c,w,s,20.),4.,'Maximum doubled');
        eq(clamp(c,w,s,3.5),3.5,'Zoom out from extra range works'); eq(clamp(c,selector,s,20.),2.,'Selector zoom unchanged');
        eq(clamp(c,selector,s,0.1),0.25,'Fast travel can zoom out to half the native minimum');
        eq(clamp(c,selector,s,0.35),0.35,'Fast travel retains intermediate zoom-out requests');
        eq(clamp(c,selector,s,1.5),1.5,'Fast travel normal zoom is unchanged');
        s.mainMapEnabled=false; c.update(selector,s);
        eq(clamp(c,selector,s,0.1),0.5,'Disabled mod restores fast-travel minimum');
        s.mainMapEnabled=true;
        Reflect.setField(s, 'overrideBigMapMarkers', false); c.update(w,s);
        eq(clamp(c,w,s,5.),4.,'Retired override preference cannot disable extra zoom');
        s.mainMapEnabled=false; c.update(w,s); eq(w.targetZoom,2.,'Disable mod restores normal range');
        eq(clamp(c,w,s,5.),2.,'Disabled mod uses native clamp');
        s.mainMapEnabled=false; c.update(w,s); eq(blocks(w),true,'Disable mod restores lock');
        s.mainMapEnabled=true; c.update(w,s); c.dispose(); eq(blocks(w),true,'Teardown restores flags');
        Sys.println('Main-map controls: $checks checks passed.');
    }
}
