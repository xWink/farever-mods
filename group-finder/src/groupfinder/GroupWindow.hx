package groupfinder;

import groupfinder.GameAccess as G;
import groupfinder.GroupTypes;
import groupfinder.GroupUi.*;
import groupfinder.GroupFrame.*;

/** Native, movable Group Finder window. Only dirty data rebuilds the contents. */
class GroupWindow {
    static inline var INK=0x5B4334;
    static inline var MUTED=0x897360;
    static inline var GREEN=0x527F40;
    static inline var LEADER=0xD6A516;
    public var dirty=true;
    var c:GroupController;
    var frame:GroupFrame;
    var viewport:Dynamic;
    var scrollbar:GroupScrollbar;
    var scroll=0.0;
    var scrollKey="";
    var sequence=0;
    var inputBox:Dynamic;
    var countLabel:Dynamic;
    var validation:Dynamic;
    var saveButton:Dynamic;
    var categoryButtons:Array<{category:String,button:Dynamic}>=[];
    final badges=new GroupBadges();
    public function new(controller:GroupController)c=controller;
    public function owns(window:Dynamic):Bool return frame!=null&&frame.window==window;
    public function resetScroll():Void {scroll=0;scrollKey="";viewport=null;}
    public function update(opened:Bool):Void {
        var ui=G.current("ui.BaseUI","current");
        if(!opened||ui==null){dispose();return;}
        if(frame!=null&&(frame.ui!=ui||!frame.intact())){dispose();c.opened=false;return;}
        if(frame==null) {
            frame=new GroupFrame(ui,"Group Finder",1040,760,c.close);
            var pos=GroupFinderMod.position();frame.x=pos.x;frame.y=pos.y;frame.onMoved=GroupFinderMod.moved;
            dirty=true;
        }
        if(dirty){dirty=false;render();}
        frame.layout();if(scrollbar!=null)scrollbar.update();
    }
    public function dispose():Void {
        badges.dispose();
        if(frame!=null)frame.dispose();frame=null;viewport=null;scrollbar=null;inputBox=null;dirty=true;
    }
    function text(parent:Dynamic,value:String,x:Int,y:Int,w:Int,bold=false,color=INK,multiline=false):Dynamic {
        var obj=textAt(parent,value,x,y,w,bold);ink(obj,color);
        if(multiline) {
            G.call("ui.comp.FmtText","set_textMultiline",obj,[true]);
            G.call("ui.comp.FmtText","set_maxWidthText",obj,[null]);
            G.call("h2d.Text","set_maxWidth",obj,[w*1.0]);
        } else {
            G.call("h2d.Text","set_lineBreak",obj,[false]);style(obj,"line-break",false);
            G.call("ui.comp.FmtText","set_useEllipsis",obj,[true]);
        }
        return obj;
    }
    function filtered(parent:Dynamic,value:String,x:Int,y:Int,w:Int,bold=false):Dynamic {
        var obj=text(parent,"",x,y,w,bold);
        G.call("ui.comp.FmtText","set_text",obj,[GroupGame.filtered(value)]);return obj;
    }
    function button(parent:Dynamic,label:String,x:Int,y:Int,w:Int,action:Void->Void,kind="",enabled=true,selected=false):Dynamic {
        var obj=frame.button(label,x,y,w,()->{if(enabled&&!c.busy)action();},kind);
        if(parent!=frame.container){G.call("h2d.Object","addChild",parent,[obj]);absolute(parent,obj);position(obj,x,y);}
        G.call("ui.UIElement","set_enable",obj,[enabled&&!c.busy]);
        G.call("ui.UIElement","set_selected",obj,[selected]);return obj;
    }
    function panel(parent:Dynamic,x:Int,y:Int,w:Int,h:Int,color=0xEFE3D1):Dynamic {
        var obj=G.field(node("element",G.field(parent,"dom"),[],"groupCard"+(sequence++)),"obj");
        absolute(parent,obj);padding(obj,0);size(obj,w,h);position(obj,x,y);
        var g=graphic(obj);rounded(g,0,0,w,h,5,0xCBB496);rounded(g,1,1,w-2,h-2,4,color);return obj;
    }
    function render():Void {
        badges.hideTip();
        var key=c.page+":"+c.category;
        if(viewport!=null&&key==scrollKey)scroll=G.number(G.field(viewport,"scrollPosY"));
        else if(key!=scrollKey)scroll=0;
        scrollKey=key;
        var root=frame.container;
        for(child in children(root))G.call("h2d.Object","remove",child);
        viewport=null;scrollbar=null;inputBox=null;countLabel=null;validation=null;saveButton=null;categoryButtons=[];
        var sidebar=panel(root,12,12,204,668,0xE7D8C2);
        text(sidebar,"FIND A GROUP",14,18,176,true);
        text(sidebar,GroupGame.regionName(c.party==null?"":c.party.region),14,46,176,false,MUTED);
        for(i in 0...GroupRules.categories.length) {
            var category=GroupRules.categories[i],count=c.visibleListings(category).length;
            button(sidebar,category+"  ("+count+")",12,86+i*46,180,()->c.choose(category),"",true,c.page=="browse"&&c.category==category);
        }
        var mine=c.mine();
        var pending=mine==null?0:c.requests.incoming(mine.id).filter(r->r.state=="pending").length;
        button(sidebar,"Requests"+(pending>0?"  ("+pending+")":""),12,574,180,c.showRequests,"",mine!=null,c.page=="requests");
        button(sidebar,mine==null?"Create listing":"My listing",12,620,180,()->{
            if(c.page!="edit")c.edit(mine);
        },mine==null?"accept":"",mine!=null||GroupRules.partyError(c.party)=="",c.page=="edit");
        switch(c.page) {
            case "edit": editor(root);
            case "requests": requests(root);
            default: listings(root);
        }
        if(c.message!="")text(root,c.message,234,644,774,false,INK,true);
    }
    function listings(root:Dynamic):Void {
        text(root,c.category,234,20,360,true);
        button(root,"Refresh",890,18,112,c.refresh);
        var data=c.visibleListings(c.category);
        var content=scroller(root,data.length*110,70);
        if(data.length==0) {
            text(content,"No groups listed yet",24,68,680,true);
            text(content,"Create a listing to start a group for "+c.category.toLowerCase()+".",24,102,680,false,MUTED,true);
        }
        for(i in 0...data.length)listing(content,data[i],i*110);
        var error=GroupRules.partyError(c.party);
        if(error!=""&&c.message=="")text(root,error,234,644,774,false,MUTED,true);
    }
    function listing(parent:Dynamic,row:GroupListing,y:Int):Void {
        var own=c.party!=null&&row.ownerId==c.party.accountId;
        var card=panel(parent,0,y,750,100,own?0xE3E5D0:0xEADDC8);
        // Scale a containing element so FmtText's own ellipsis/reflow cannot
        // reset the heading size. The 16px native font displays at 20px.
        var headingBox=G.field(node("element",G.field(card,"dom"),[],"groupHeading"+(sequence++)),"obj");
        absolute(card,headingBox);padding(headingBox,0);size(headingBox,424,26);position(headingBox,16,7);
        G.call("h2d.Object","setScale",headingBox,[1.25]);
        var heading=filtered(headingBox,row.title,0,0,424,true);
        G.call("domkit.Properties","removeClass",G.field(heading,"dom"),["bold-14"]);
        G.call("domkit.Properties","addClass",G.field(heading,"dom"),["bold-16"]);
        ink(heading,INK);
        text(card,row.members.length+" / "+GroupRules.CAPACITY+" members",570,14,164,true,MUTED);
        for(i in 0...row.members.length)memberChip(card,row.members[i],16+i*176,44,168,row.members[i].accountId==row.ownerId);
        if(own) {
            if(c.pendingDelete==row.id) {
                button(card,"Confirm",570,50,78,()->c.remove(row.id),"cancel");
                button(card,"Cancel",656,50,78,()->{c.pendingDelete=null;dirty=true;});
            } else {
                button(card,"Edit",570,50,78,()->c.edit(row));
                button(card,"Close",656,50,78,()->c.remove(row.id),"cancel");
            }
        } else {
            var request=c.requests.outgoing(row.id);
            if(request!=null&&request.state=="pending") {
                button(card,"Cancel request",570,42,164,()->c.cancel(request));
                var status=G.field(node("element",G.field(card,"dom"),[],"groupRequestStatus"+(sequence++)),"obj");
                absolute(card,status);padding(status,0);size(status,218,22);position(status,570,78);
                G.call("h2d.Object","setScale",status,[0.75]);
                text(status,"Request pending",0,0,218,false,GREEN);
            } else button(card,"Request to join",570,42,164,()->c.request(row),"",c.requestError()=="");
        }
    }
    function memberChip(parent:Dynamic,member:GroupMember,x:Int,y:Int,w:Int,leader:Bool):Void {
        memberName(parent,member,x,y,w,leader);
        memberDetails(parent,member,x,y+22,w);
    }
    function memberName(parent:Dynamic,member:GroupMember,x:Int,y:Int,w:Int,leader=false):Void {
        var box=G.field(node("element",G.field(parent,"dom"),[],"groupMemberName"+(sequence++)),"obj");
        absolute(parent,box);padding(box,0);size(box,w,22);position(box,x,y);
        // Let hover tooltips share the name row without consuming clicks or scrolling.
        G.call("h2d.Flow","set_enableInteractive",box,[true]);
        G.set(G.field(box,"interactive"),"propagateEvents",true);
        var badge:Dynamic=null;
        try badge=badges.create(box,member.badge,G.field(frame.ui,"windows"),box)
        catch(error:Dynamic)GroupFinderMod.report("Member badge: "+Std.string(error));
        var available=w-(badge==null?0:GroupBadges.SIZE+GroupBadges.GAP)-(leader?20:0);
        var caption=filtered(box,member.name,0,0,available,true);
        var star=leader?text(box,"★",0,0,16,true,LEADER):null;
        if(badge!=null||star!=null) {
            var align=()->{
                // Resolve native font scaling before measuring visible glyphs.
                for(label in [caption,star])if(label!=null&&G.field(label,"needUpdateScale")==true) {
                    G.call("ui.comp.FmtText","updateScale",label);G.set(label,"needUpdateScale",false);
                }
                var bounds=G.call("h2d.Object","getBounds",caption,[caption,null]);
                var sx=G.number(G.field(caption,"scaleX"),1),sy=G.number(G.field(caption,"scaleY"),1);
                var right=Math.min(available,Math.ceil(G.number(G.field(bounds,"xMax"))*sx));
                var center=(G.number(G.field(bounds,"yMin"))+G.number(G.field(bounds,"yMax")))*sy/2;
                if(badge!=null) {
                    position(badge,right+GroupBadges.GAP,Math.round(center-GroupBadges.SIZE/2));
                    right+=GroupBadges.GAP+GroupBadges.SIZE;
                    var input=G.field(box,"interactive"),top=Math.min(0,G.number(G.field(badge,"y")));
                    // Keep the hover area over the entire badge if its top sits
                    // above the text's origin after centering on a small font.
                    G.set(input,"y",top);G.set(input,"height",Math.max(22,G.number(G.field(badge,"y"))+GroupBadges.SIZE)-top);
                }
                if(star!=null) {
                    var b=G.call("h2d.Object","getBounds",star,[star,null]);
                    position(star,right+4-G.number(G.field(b,"xMin"))*G.number(G.field(star,"scaleX"),1),
                        center-(G.number(G.field(b,"yMin"))+G.number(G.field(b,"yMax")))*G.number(G.field(star,"scaleY"),1)/2);
                }
            };
            G.set(box,"onAfterReflow",align);align();
        }
    }
    function memberDetails(parent:Dynamic,member:GroupMember,x:Int,y:Int,w:Int):Void {
        var box=G.field(node("element",G.field(parent,"dom"),[],"groupMemberDetails"+(sequence++)),"obj");
        absolute(parent,box);padding(box,0);size(box,w,28);position(box,x,y);
        var tile=GroupGame.classBanner(member.className),offset=0;
        var iconHeight=0.0;
        if(tile!=null) {
            var icon=G.field(node("bitmap",G.field(box,"dom"),[],"groupClass"+(sequence++)),"obj");
            absolute(box,icon);G.call("h2d.Bitmap","set_tile",icon,[tile]);
            // Preserve the tall pennant's proportions, including any tile offset.
            var scale=Math.min(20/Math.max(1,G.number(G.field(tile,"width"))),28/Math.max(1,G.number(G.field(tile,"height"))));
            G.call("h2d.Object","setScale",icon,[scale]);
            position(icon,(20-G.number(G.field(tile,"width"))*scale)/2-G.number(G.field(tile,"dx"))*scale,-G.number(G.field(tile,"dy"))*scale);
            G.set(icon,"smooth",true);
            iconHeight=G.number(G.field(tile,"height"))*scale;
            offset=26;
        }
        var level=text(box,member.level>0?"Lv. "+member.level:"Level unavailable",offset,0,w-offset,false,MUTED);
        if(tile!=null) {
            var align=()->{
                if(G.field(level,"needUpdateScale")==true) {
                    G.call("ui.comp.FmtText","updateScale",level);G.set(level,"needUpdateScale",false);
                }
                var bounds=G.call("h2d.Object","getBounds",level,[level,null]);
                var center=(G.number(G.field(bounds,"yMin"))+G.number(G.field(bounds,"yMax")))*G.number(G.field(level,"scaleY"),1)/2;
                position(level,offset,iconHeight/2-center);
            };
            G.set(box,"onAfterReflow",align);align();
        }
    }
    function selectDraftCategory(value:String):Void {
        c.draftCategory=value;
        for(entry in categoryButtons)G.call("ui.UIElement","set_selected",entry.button,[entry.category==value]);
    }
    function editor(root:Dynamic):Void {
        text(root,c.editingId==null?"Create a listing":"Edit your listing",234,20,550,true);
        button(root,"Back to groups",818,18,184,()->c.choose(c.category));
        var card=panel(root,234,86,768,302);
        text(card,"Category",20,20,720,true);
        for(i in 0...3) {
            var category=GroupRules.categories[i];
            var control=button(card,category,20+i*244,48,232,()->selectDraftCategory(category),"",true,c.draftCategory==category);
            categoryButtons.push({category:category,button:control});
        }
        text(card,"Listing title",20,114,560,true);
        countLabel=text(card,"",646,114,96,false,MUTED);
        inputBox=G.field(node("input-box",G.field(card,"dom"),[],"groupTitleInput"),"obj");
        absolute(card,inputBox);padding(inputBox,0);size(inputBox,728,40);position(inputBox,20,145);
        var input=G.field(inputBox,"input");
        style(input,"width",700);style(input,"color",0xF5F0E8);
        G.call("ui.comp.InputBox","set_hintText",inputBox,["What would you like to do?"]);
        style(G.field(inputBox,"inputHint"),"color",0xE0D8CD);
        G.call("h2d.TextInput","set_text",input,[c.draftTitle]);
        for(t in [input,G.field(inputBox,"inputHint")]) {
            absolute(G.field(t,"parent"),t);G.call("h2d.Text","set_maxWidth",t,[700.0]);
        }
        var align=()->{
            for(t in [input,G.field(inputBox,"inputHint")]) {
                var b=G.call("h2d.Object","getSize",t,[null]);
                position(t,12-G.number(G.field(b,"xMin")),Math.floor((40-G.number(G.field(b,"yMax"))+G.number(G.field(b,"yMin")))/2)-G.number(G.field(b,"yMin")));
            }
        };
        var previous=G.field(inputBox,"onAfterReflow");G.set(inputBox,"onAfterReflow",()->{if(previous!=null)Reflect.callMethod(inputBox,previous,[]);align();});align();
        G.set(inputBox,"onChange",()->{c.draftTitle=G.text(G.field(input,"text"));updateDraft();});
        G.set(input,"ignoreEnter",true);G.set(input,"onEnter",()->c.save());
        validation=text(card,"",20,199,728,false,MUTED);
        saveButton=button(card,c.busy?"Saving…":c.editingId==null?"Create listing":"Save changes",20,246,232,c.save,"accept");
        button(card,"Cancel",264,246,160,()->c.choose(c.category));
        if(c.editingId!=null) {
            var id=c.editingId;
            button(card,c.pendingDelete==id?"Confirm close":"Close listing",516,246,232,()->c.remove(id),"cancel");
        }
        updateDraft();
    }
    function updateDraft():Void {
        if(countLabel==null)return;
        var count=GroupRules.count(c.draftTitle);
        setText(countLabel,count+" / "+GroupRules.MAX_TITLE_LENGTH);ink(countLabel,count>GroupRules.MAX_TITLE_LENGTH?0xB8443A:MUTED);
        var error=GroupRules.partyError(c.party);
        if(error=="")error=GroupRules.titleError(c.draftTitle);
        setText(validation,error==""?"Up to "+GroupRules.MAX_TITLE_LENGTH+" characters.":error);
        if(saveButton!=null)G.call("ui.UIElement","set_enable",saveButton,[error==""&&!c.busy]);
    }
    function requests(root:Dynamic):Void {
        text(root,"Join requests",234,20,460,true);
        text(root,"Review requests to join your group.",234,51,768,false,MUTED);
        button(root,"Add sample request",790,18,212,c.previewRequest,"",c.mine()!=null);
        var mine=c.mine(),rows=mine==null?[]:c.requests.incoming(mine.id);
        var content=scroller(root,rows.length*126);
        if(rows.length==0) {
            text(content,"No requests yet",24,68,680,true);
            text(content,"New requests to join your group will appear here.",24,102,680,false,MUTED,true);
        }
        for(i in 0...rows.length) {
            var request=rows[i],listing=c.mock.find(request.listingId),card=panel(content,0,i*126,750,116,0xEADDC8);
            if(request.incoming)memberName(card,request.member,16,12,516);
            else filtered(card,listing==null?"Your join request":listing.title,16,12,516,true);
            memberDetails(card,request.member,16,40,516);
            text(card,stateLabel(request.state),16,77,516,true,request.state=="invited"?GREEN:MUTED);
            if(request.state=="pending") {
                if(request.incoming) {
                    button(card,"Accept",564,15,168,()->c.answer(request,true),"accept");
                    button(card,"Decline",564,65,168,()->c.answer(request,false),"cancel");
                } else button(card,"Cancel request",564,65,168,()->c.cancel(request));
            }
        }
    }
    static function stateLabel(state:String):String return switch(state) {
        case "pending": "Request pending";
        case "invited": "Invitation sent (preview)";
        case "declined": "Request declined";
        case "cancelled": "Request cancelled";
        case "closed": "Listing closed";
        case "expired": "Request expired";
        default: state;
    };
    function scroller(root:Dynamic,height:Int,topY=112):Dynamic {
        viewport=G.field(node("flow",G.field(root,"dom"),[],"groupViewport"+(sequence++),"vertical"),"obj");
        absolute(root,viewport);padding(viewport,0);size(viewport,774,628-topY);position(viewport,234,topY);
        var vertical=G.enumeration("h2d.FlowLayout","Vertical"),overflow=G.enumeration("h2d.FlowOverflow","Scroll");
        G.call("h2d.Flow","set_layout",viewport,[vertical]);style(viewport,"layout",vertical);
        G.call("h2d.Flow","set_multiline",viewport,[false]);style(viewport,"multiline",false);
        G.call("h2d.Flow","set_overflow",viewport,[overflow]);style(viewport,"overflow",overflow);
        var content=G.field(node("element",G.field(viewport,"dom"),[],"groupRows"+(sequence++)),"obj");
        padding(content,0);size(content,750,Std.int(Math.max(160,height)));
        var top=G.enumeration("h2d.FlowAlign","Top"),left=G.enumeration("h2d.FlowAlign","Left");
        G.call("h2d.Flow","set_verticalAlign",viewport,[top]);G.call("h2d.Flow","set_horizontalAlign",viewport,[left]);
        style(viewport,"content-valign",top);style(viewport,"content-halign",left);
        var layout=G.call("h2d.Flow","getProperties",viewport,[content]);
        G.call("h2d.FlowProperties","set_isAbsolute",layout,[false]);style(content,"position",false);
        G.set(layout,"verticalAlign",top);G.set(layout,"horizontalAlign",left);style(content,"valign",top);style(content,"halign",left);
        var bar=G.field(viewport,"scrollBar"),cursor=G.field(viewport,"scrollBarCursor");
        if(bar!=null&&cursor!=null){absolute(viewport,bar);padding(bar,0);size(bar,10);size(cursor,10);position(bar,760,0);}
        scrollbar=new GroupScrollbar(root);scrollbar.bind(viewport,content);
        var restored=false,saved=scroll,old=G.field(viewport,"onAfterReflow"),target=viewport;
        G.set(target,"onAfterReflow",()->{
            if(old!=null)Reflect.callMethod(target,old,[]);
            if(!restored){restored=true;G.call("h2d.Flow","set_scrollPosY",target,[saved]);}
        });
        return content;
    }
}
