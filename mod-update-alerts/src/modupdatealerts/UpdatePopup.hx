package modupdatealerts;

import modupdatealerts.UpdateModel.AvailableUpdate;
import modupdatealerts.GameAccess as G;
import modupdatealerts.NativeUi.*;

/** Native title window with the same X and checkbox controls as the game's Options. */
class UpdatePopup {
    public static var constructing=false;
    public var owner(default,null):Dynamic;
    public var stage(default,null)="creating window";
    var window:Dynamic;
    var root:Dynamic;
    var body:Dynamic;
    var container:Dynamic;
    var title:Dynamic;
    var headingStyle:Dynamic;
    var updates:Array<AvailableUpdate>;
    var onDismiss:Bool->Void;
    var ignore=false;
    var page=0;
    var rows:Array<Array<Dynamic>>=[];
    var columns:Array<Dynamic>=[];
    var changes:Array<Dynamic>=[];
    var detailIndex=-1;
    var back:Dynamic;
    var detailTitle:Dynamic;
    var notesPanel:Dynamic;
    var notesText:Dynamic;
    var pageText:Dynamic;
    var previous:Dynamic;
    var next:Dynamic;
    var checkbox:Dynamic;
    static inline var PAGE_SIZE=6;
    public function new() {}

    public static function ready(ui:Dynamic):Bool {
        var root=G.field(ui,"root"), scene=G.field(ui,"s2d");
        // These are the resources needed to render, not a particular screen,
        // gameplay layer, character, or splash animation state.
        return root!=null && G.field(root,"parent")!=null && G.field(ui,"style")!=null
            && G.number(G.field(scene,"width"))>0 && G.number(G.field(scene,"height"))>0
            && G.field(G.current("Data","icon"),"byId")!=null;
    }

    public function open(ui:Dynamic, updates:Array<AvailableUpdate>, onDismiss:Bool->Void, onPreference:Bool->Void, selected:Bool):Void {
        this.owner=ui; this.updates=updates; this.onDismiss=onDismiss; this.ignore=selected;
        constructing=true;
        try window=G.create("ui.win.TitleWindow",["Options",null])
        catch (e:Dynamic) { constructing=false; throw e; }
        constructing=false;
        if(window==null) throw "Native title window was not created";
        initializeWindow();
        stage="registering window";
        root=G.field(ui,"root");
        G.call("h2d.Flow","addChildAt",root,[window,G.call("h2d.Object","get_numChildren",root)]);
        // Attaching alone bypasses the native window manager and cursor handling.
        // As in Fight History, BaseUIRoot is a Flow, not a displayWindow parent.
        G.call("ui.BaseUI","displayWindow",ui,[window,null]);
        absolute(root,window);
        stage="building header";
        var dom=G.field(window,"dom");
        G.set(dom,"component",G.staticCall("domkit.Component","get",["options-window",null]));
        var content=G.field(dom,"contentRoot");
        if(content==null) throw "Native title window content was not initialized";
        size(window,760,490);
        for (child in children(window)) if (G.field(child,"bgMask")!=null) {
            absolute(window,child); padding(child,0); size(child,760,490); position(child,0,0);
        }
        var header=G.field(window,"header");
        padding(window,0); padding(header,0); padding(content,0);
        absolute(window,header); size(header,758,60); position(header,0,0);
        G.set(header,"headText","Mod updates available");
        show(G.field(header,"headerTitle"),false);
        var close=G.field(header,"closeBtn");
        show(close,true); absolute(header,close); size(close,36,36); position(close,708,12);
        G.call("ui.UIElement","set_onClick",close,[dismiss]);
        absolute(window,content); size(content,744,422); position(content,8,60);

        stage="building update list";
        body=node("options-content",dom,[0],"modUpdaterBody");
        var bodyObject=G.field(body,"obj");
        container=prepareChartBody(body);
        var options=G.field(bodyObject,"optionsList");
        for (object in [bodyObject,options,container]) {
            padding(object,0); size(object,744,422);
            var limit=G.enumeration("h2d.FlowOverflow","Limit");
            G.call("h2d.Flow","set_overflow",object,[limit]); style(object,"overflow",limit);
        }
        absolute(content,bodyObject); position(bodyObject,0,0);
        absolute(bodyObject,options); position(options,0,0);
        absolute(options,container); position(container,0,0);
        var parent=G.field(container,"dom");
        // Use Fight History's bold native font and enlarged heading, retaining
        // a style reference because DOM fonts may settle after the first frame.
        headingStyle=label(parent,"");
        G.call("domkit.Properties","addClass",G.field(headingStyle,"dom"),["bold-14"]);
        show(headingStyle,false);
        title=G.create("h2d.Text",[G.field(headingStyle,"font"),header]);
        absolute(header,title);
        G.call("h2d.Text","set_text",title,["Mod updates available"]);
        G.call("h2d.Text","set_textColor",title,[0x8A5F46]);
        G.call("h2d.Text","set_textAlign",title,[G.enumeration("h2d.Align","Left")]);
        G.call("h2d.Text","set_lineBreak",title,[false]);
        text(parent,"Close the game and open Vortex to update these mods.",16,8,712);
        columns=[text(parent,"Mod",16,56,310),text(parent,"Installed",340,56,106),
            text(parent,"Available",468,56,116)];
        for (item in columns)
            G.call("domkit.Properties","addClass",G.field(item,"dom"),["bold-14"]);
        for (i in 0...PAGE_SIZE) {
            rows.push([text(parent,"",16,88+i*31,310),text(parent,"",340,88+i*31,106),text(parent,"",468,88+i*31,116)]);
            var slot=i;
            var action=button(parent,"Changes","modUpdaterChanges"+i,()->openChangelog(page*PAGE_SIZE+slot));
            absolute(container,action);size(action,116,28);position(action,612,84+i*31);
            changes.push(action);
        }
        previous=button(parent,"Previous","modUpdaterPrevious",()->{ if(page>0){page--;refresh();} });
        next=button(parent,"Next","modUpdaterNext",()->{ if((page+1)*PAGE_SIZE<this.updates.length){page++;refresh();} });
        for (item in [previous,next]) { absolute(container,item); size(item,110,32); }
        position(previous,16,307); position(next,618,307);
        pageText=text(parent,"",300,313,200);
        back=button(parent,"Back","modUpdaterBack",()->{detailIndex=-1;refresh();});
        absolute(container,back);size(back,92,32);position(back,16,48);
        detailTitle=text(parent,"",124,56,604);
        G.call("domkit.Properties","addClass",G.field(detailTitle,"dom"),["bold-14"]);
        var notes=node("flow",parent,[],"modUpdaterChangelog","vertical");
        notesPanel=G.field(notes,"obj");
        absolute(container,notesPanel);padding(notesPanel,8);size(notesPanel,712,246);position(notesPanel,16,92);
        var scroll=G.enumeration("h2d.FlowOverflow","Scroll");
        flow(notes,"set_overflow",scroll);style(notesPanel,"overflow",scroll);
        notesText=label(notes,"");
        G.call("ui.comp.FmtText","set_maxWidthText",notesText,[668]);
        stage="building reminder checkbox";
        checkbox=G.field(node("check-box",parent,["Don't remind me again about these versions"],"modUpdaterIgnore"),"obj");
        absolute(container,checkbox); size(checkbox,712,38); position(checkbox,16,355);
        G.call("h2d.Flow","set_paddingLeft",checkbox,[12]); style(checkbox,"padding-left",12);
        G.call("ui.comp.CheckBox","set_selected",checkbox,[selected]);
        G.set(checkbox,"onValueChange",function(value:Bool):Void {ignore=value;onPreference(value);});
        refresh();
        if(!update(ui)) throw "Native popup was removed before it could be displayed";
    }
    function initializeWindow():Void {
        stage="initializing native window";
        var flags=0;
        for(name in ["PreventCloseOther","FreeCursor","AutoRegisterLayer","BlockInputs","BlockSkills"]) {
            var flag=G.enumeration("ui.win.WindowFlags",name);
            if(flag==null) throw "Window flag unavailable: "+name;
            flags|=1 << Type.enumIndex(flag);
        }
        G.call("ui.win.BaseWindow","set_windowFlags",window,[flags]);
        // TitleWindow defaults to NeedLayer. At the title/menu screens its
        // constructor therefore skips rebuilding the entire DOM. Changing flags
        // alone doesn't initialize it: rebuild now, without requiring gameplay.
        G.call("ui.win.BaseWindow","rebuild",window);
    }
    public function replaceUpdates(nextUpdates:Array<AvailableUpdate>,selected:Bool):Void {
        var shown=detailIndex>=0 ? updates[detailIndex] : null;
        updates=nextUpdates;
        if(shown!=null) {
            detailIndex=-1;
            for(i in 0...updates.length) {
                var entry=updates[i];
                if(entry.domain==shown.domain && entry.modId==shown.modId && entry.latest==shown.latest) {
                    detailIndex=i;
                    break;
                }
            }
        }
        page=Std.int(Math.min(page,Math.max(0,Math.ceil(updates.length/PAGE_SIZE)-1)));
        ignore=selected;
        G.call("ui.comp.CheckBox","set_selected",checkbox,[selected]);
        // Leave an open changelog and its scroll position in place while the
        // background check adds/reorders rows in the table.
        refresh();
    }
    function text(parent:Dynamic,value:String,x:Int,y:Int,width:Int):Dynamic {
        var item=label(parent,value);
        absolute(container,item); position(item,x,y);
        G.call("ui.comp.FmtText","set_maxWidthText",item,[width]);
        return item;
    }
    function refresh():Void {
        var details=detailIndex>=0;
        for (item in columns) show(item,!details);
        for (item in [back,detailTitle,notesPanel]) show(item,details);
        for (i in 0...rows.length) {
            var index=page*PAGE_SIZE+i, visible=!details && index<updates.length;
            for (item in rows[i]) show(item,visible);
            show(changes[i],visible);
            if (!visible) continue;
            var update=updates[index];
            setText(rows[i][0],update.name); setText(rows[i][1],update.current); setText(rows[i][2],update.latest);
        }
        show(previous,!details && page>0); show(next,!details && (page+1)*PAGE_SIZE<updates.length);
        show(pageText,!details);
        setText(pageText,"Page "+(page+1)+" / "+Std.int(Math.ceil(updates.length/PAGE_SIZE)));
    }
    function openChangelog(index:Int):Void {
        if(index<0 || index>=updates.length) return;
        detailIndex=index;
        var entry=updates[index];
        setText(detailTitle,entry.name+" "+entry.latest);
        setText(notesText,entry.changelog==null || entry.changelog==""
            ? "No changelog was provided for this release on Nexus Mods." : entry.changelog);
        G.set(notesPanel,"scrollPosY",0.0);
        refresh();
    }
    public function update(ui:Dynamic):Bool {
        stage="positioning window";
        if (window==null || owner!=ui || G.field(window,"removed")==true || !chartBodyIntact(body,container)) {
            dispose(); return false;
        }
        var scene=G.field(ui,"s2d");
        var top=local(0,0), bottom=local(G.number(G.field(scene,"width"),1920),G.number(G.field(scene,"height"),1080));
        var scale=Math.min(1,Math.min((bottom.x-top.x-32)/760,(bottom.y-top.y-32)/490));
        scale=Math.max(0.25,scale);
        G.call("h2d.Object","setScale",window,[scale]);
        position(window,top.x+(bottom.x-top.x-760*scale)/2,top.y+(bottom.y-top.y-490*scale)/2);
        alignTitle();
        stage="updating window";
        return true;
    }
    function alignTitle():Void {
        G.call("ui.comp.FmtText","updateScale",headingStyle);
        var font=G.field(headingStyle,"font");
        if(font!=null && font!=G.field(title,"font")) G.call("h2d.Text","set_font",title,[font]);
        var width=G.number(G.call("h2d.Text","get_textWidth",title));
        var scale=Math.min(G.number(G.field(headingStyle,"scaleX"),1)*1.75,668/Math.max(1,width));
        G.call("h2d.Object","setScale",title,[scale]);
        var height=G.number(G.call("h2d.Text","get_textHeight",title))*scale;
        position(title,24,(60-height)/2);
    }
    function local(x:Float,y:Float):{x:Float,y:Float} {
        var point=HlxRuntime.allocInstance(HlxRuntime.resolveType("h2d.col.PointImpl"));
        G.set(point,"x",x);G.set(point,"y",y);
        var result=G.call("h2d.Object","globalToLocal",root,[point]);
        return {x:G.number(G.field(result,"x")),y:G.number(G.field(result,"y"))};
    }
    public function dismiss():Void {
        var callback=onDismiss, selected=ignore;
        dispose();
        if(callback!=null)callback(selected);
    }
    public function dispose():Void {
        if(window!=null) {
            var old=window;window=null;
            // Removing only the display object leaves a modal window registered
            // and blocks game controls. Unregister from the actual owning UI.
            if(owner!=null) G.call("ui.BaseUI","removeWindow",owner,[old]);
            else G.call("h2d.Object","remove",old);
        }
        owner=null;body=null;container=null;title=null;headingStyle=null;rows=[];columns=[];changes=[];
        back=null;detailTitle=null;notesPanel=null;notesText=null;detailIndex=-1;checkbox=null;
        onDismiss=null;ignore=false;page=0;
    }
}
