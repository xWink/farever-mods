import trade.ItemLinks;
import trade.ItemLinkCodec;
import trade.GameAccess as G;

class ItemLinkUiTest {
    static var checks=0;
    static function check(value:Bool,message:String):Void {checks++;if(!value)throw message;}
    static function event(button=0):Dynamic return {button:button,cancel:false,propagate:true};
    static function openBubble(bubble:Dynamic,message:Dynamic):Void {
        ItemLinks.prepareBubble(bubble,message);
        var text=G.text(message.text);
        bubble.timer=bubble.countdown;
        if(text.length>100)text=text.substr(0,100)+"...";
        G.call("ui.comp.FmtText","set_text",bubble.messageText,[G.staticCall("HText","cleanPlayerText",[text])]);
        bubble.visible=true;
    }
    static function main():Void {
        for (entry in ["item:Sword","item:CorruptedGift","rarity:Epic","skill:Warrior_Smash","skill:Rogue_Poison","attribute:Power"])
            G.definitions.set(entry,{id:entry.split(":")[1]});
        var offer=ItemLinkTest.fixture();
        var input:Dynamic={text:"Selling café",maxCharacters:250,cursorIndex:0,selectionRange:{start:0,length:4},changes:0,font:G.font(),interactive:{width:600,height:20}};
        G.ui={nativeType:"ui.GameUI",chat:{messageInput:{input:input}},currentTip:null};
        var pushes=0,releases=0;
        var originalPush:Dynamic=(e:Dynamic)->{pushes++;};
        var originalRelease:Dynamic=(e:Dynamic)->{releases++;};
        var interactive:Dynamic={onPush:originalPush,onRelease:originalRelease,mouseDownButton:0};
        var slot:Dynamic={nativeType:"ui.win.InventorySlot",item:{nativeType:"st.item.Weapon",kind:"Sword",preview:offer.preview},count:2,interactive:interactive};
        ItemLinks.install(slot);ItemLinks.install(slot);
        interactive.onPush(event());interactive.onRelease(event());
        check(pushes==1&&releases==1&&input.changes==0,"Ordinary left click retains native actions exactly once");
        G.alt=true;interactive.onPush(event(1));interactive.onRelease(event(1));
        check(pushes==2&&releases==2&&input.changes==0,"Alt-right click retains native behaviour");
        var click=event();interactive.onPush(click);
        check(pushes==2&&input.changes==1&&G.focused==1,"Alt-left click appends and focuses without triggering the item's action");
        check(!click.propagate&&!click.cancel&&interactive.mouseDownButton==-1,"Click and drag cannot propagate to inventory handlers");
        check(StringTools.startsWith(input.text,"Selling café ")&&StringTools.endsWith(input.text," "),"Existing text survives and the cursor can continue after the link");
        check(input.selectionRange==null,"An existing selection is not replaced");
        G.alt=false;interactive.onRelease(event());
        check(releases==2,"Releasing Alt before the mouse does not run the native release action");
        // The scene blurs chat after the item click, before deferred focus runs.
        input.cursorIndex=-1;input.focused=false;input.selectionRange={start:0,length:4};
        G.runNextFrame();
        check(input.focused==true&&input.cursorIndex==G.text(input.text).length,"Caret lands after the link once native deferred focus completes");
        check(input.selectionRange==null,"Deferred focus leaves no selected text to overwrite");
        var linkedDraft=G.text(input.text);
        G.call("h2d.TextInput","inputText",input,["selling"]);
        check(input.text==linkedDraft+"selling","Typing immediately continues after the complete link");
        var token=ItemLinkCodec.tokens(StringTools.trim(trade.ItemLinkDraft.wire(input,input.text)))[0];
        check(ItemLinkCodec.decode(token).count==2,"The selected stack is serialized");
        var full=StringTools.lpad("x","x",250);input.text=full;G.alt=true;
        interactive.onPush(event());interactive.onRelease(event());
        check(input.text==full&&G.errors.length==1&&pushes==2,"Full chat drafts fail without partial links or item actions");
        input.text="";ItemLinks.configure(false);interactive.onPush(event());interactive.onRelease(event());
        check(pushes==3&&releases==3&&input.text=="","Disabled mod leaves item input alone");
        ItemLinks.configure(true);
        var custom:Dynamic={interactive:{onPush:originalPush,onRelease:originalRelease}};
        ItemLinks.bind(custom,offer);custom.interactive.onPush(event());custom.interactive.onRelease(event());
        check(ItemLinkCodec.tokens(StringTools.trim(trade.ItemLinkDraft.wire(input,input.text))).length==1,"Custom trade and Marketplace icons link their exact snapshot");
        input.text="";slot.count=7;interactive.onPush(event());interactive.onRelease(event());
        check(ItemLinkCodec.decode(ItemLinkCodec.tokens(StringTools.trim(trade.ItemLinkDraft.wire(input,input.text)))[0]).count==7,"Reused inventory slots link their current quantity");
        var catalog:Dynamic={nativeType:"ui.comp.ItemButton",inf:{id:"Sword"},interactive:{onPush:originalPush,onRelease:originalRelease}};
        input.text="";ItemLinks.install(catalog);catalog.interactive.onPush(event());catalog.interactive.onRelease(event());
        check(ItemLinkCodec.decode(ItemLinkCodec.tokens(StringTools.trim(trade.ItemLinkDraft.wire(input,input.text)))[0]).kind=="Sword","Definition-only recipe and shop item buttons can be linked");
        var decorative:Dynamic={nativeType:"ui.comp.ItemButton",parent:custom,item:slot.item,interactive:{onPush:originalPush,onRelease:originalRelease}};
        input.text="";ItemLinks.install(decorative);decorative.interactive.onPush(event());decorative.interactive.onRelease(event());
        check(ItemLinkCodec.decode(ItemLinkCodec.tokens(StringTools.trim(trade.ItemLinkDraft.wire(input,input.text)))[0]).count==2,"Decorative children use their custom parent's exact snapshot");
        var row:Dynamic={message:{text:"Before "+token+" after",notify:null},msgText:{prevUnformatted:"[12:34] Player: Before "+token+" after",
            text:"",formatText:(text:String)->text,onOverHyperlink:null,onOutHyperlink:null,onHyperlink:null}};
        var foreign=0;row.msgText.onHyperlink=(href:String)->{foreign++;};
        row.msgText.onOverHyperlink=(href:String)->{foreign++;};row.msgText.onOutHyperlink=(href:String)->{foreign++;};
        ItemLinks.attach(row);
        var label:Dynamic=row.msgText;
        check(G.text(label.text).indexOf('<font color="#AABBCC"><b>Épée du test</b>')>=0,"Receiver uses its localized native name and rarity");
        check(StringTools.startsWith(label.text,"[12:34] Player: Before ")&&StringTools.endsWith(label.text," after"),"Timestamp, sender and surrounding text keep their formatting");
        check(G.text(row.message.text).indexOf(token)>=0&&G.text(label.prevUnformatted).indexOf(token)>=0,"Original chat and unformatted text remain intact");
        label.onOverHyperlink("wink-item:0");
        check(G.ui.currentTip!=null&&G.ui.currentTip.content.realItem.level==30,"Hover reconstructs the original item tooltip");
        check(G.ui.currentTip.content.realItem.__host==null&&G.ui.currentTip.content.realItem.__uid==null,"Tooltip items have no network host or borrowed UID");
        var linkedTip:Dynamic=G.ui.currentTip;
        linkedTip.scene={width:1280,height:720};linkedTip.parent={x:20,y:10,scale:1.5};
        linkedTip.bounds={xMin:-180,yMin:-12,xMax:320,yMax:388};linkedTip.scale=1;
        function contained():Bool {
            var p=linkedTip.parent,b=linkedTip.bounds,s=G.number(linkedTip.scale);
            return (G.number(linkedTip.x)+G.number(b.xMin)*s)*p.scale+p.x>=7.999
                &&(G.number(linkedTip.y)+G.number(b.yMin)*s)*p.scale+p.y>=7.999
                &&(G.number(linkedTip.x)+G.number(b.xMax)*s)*p.scale+p.x<=linkedTip.scene.width-7.999
                &&(G.number(linkedTip.y)+G.number(b.yMax)*s)*p.scale+p.y<=linkedTip.scene.height-7.999;
        }
        for (corner in [{x:-500,y:-500},{x:1500,y:-500},{x:-500,y:1500},{x:1500,y:1500}]) {
            linkedTip.x=corner.x;linkedTip.y=corner.y;ItemLinks.fitTooltip(linkedTip);
            check(contained()&&linkedTip.scale==1,"Linked tooltip and comparisons stay inside each edge with scaled UI");
        }
        linkedTip.bounds.yMax=1200;ItemLinks.fitTooltip(linkedTip);
        check(contained()&&linkedTip.scale<1,"Oversized linked tooltip scales to fit the window");
        var fittedX=linkedTip.x,fittedY=linkedTip.y,fittedScale=linkedTip.scale;
        ItemLinks.fitTooltip(linkedTip);
        check(linkedTip.x==fittedX&&linkedTip.y==fittedY&&linkedTip.scale==fittedScale,"Repeated layout does not shrink or drift the tooltip");
        linkedTip.scene.width=900;linkedTip.scene.height=540;ItemLinks.fitTooltip(linkedTip);
        check(contained(),"Resizing the game window refits the active tooltip");
        linkedTip.bounds.yMax=388;linkedTip.scene.width=1280;linkedTip.scene.height=720;ItemLinks.fitTooltip(linkedTip);
        check(contained()&&linkedTip.scale==1,"Tooltip returns to normal size when it fits");
        var unrelated:Dynamic={x:-500,y:-500,scale:1};ItemLinks.fitTooltip(unrelated);
        check(unrelated.x==-500&&unrelated.y==-500&&unrelated.scale==1,"Other tooltips keep their native positioning");
        label.onOutHyperlink("wink-item:0");check(G.ui.currentTip==null,"Moving off the item hides its tooltip");
        label.onHyperlink("wink-item:0");check(foreign==0,"Item links do not invoke website or player-name actions");
        label.onHyperlink("native-link");label.onOverHyperlink("native-link");label.onOutHyperlink("native-link");
        check(foreign==3,"Unrelated native hyperlinks retain all handlers");
        G.call("ui.comp.FmtText","set_text",label,["[12:35] "+row.message.text]);
        check(G.text(label.text).indexOf("Épée du test")>=0&&StringTools.startsWith(label.text,"[12:35] "),"Timestamp changes reformat links without duplication");
        ItemLinks.configure(false);check(G.text(label.text).indexOf(token)>=0&&G.text(label.text).indexOf("wink-item:")<0,"Disabling restores original text");
        ItemLinks.configure(true);check(G.text(label.text).indexOf(token)<0,"Re-enabling restores item formatting");
        label.onOverHyperlink("wink-item:0");var foreignTip:Dynamic={};G.ui.currentTip=foreignTip;label.onOutHyperlink("wink-item:0");
        check(G.ui.currentTip==foreignTip,"Leaving a link cannot dismiss another UI's tooltip");
        label.onOverHyperlink("wink-item:0");ItemLinks.forget(row);
        check(G.ui.currentTip==null,"Removing a chat row cleans its tooltip and handlers");
        var second=ItemLinkTest.fixture();second.count=4;
        second.preview={flags:0,level:0,upgrade:0,rarity:"",infusion:"",bonus:"",mastery:"",slots:[],effects:[]};
        var secondToken=ItemLinkCodec.encode(second);
        row.message.text=token+" and "+secondToken;label.prevUnformatted=row.message.text;
        ItemLinks.attach(row);
        check(G.text(label.text).indexOf('wink-item:0')>=0&&G.text(label.text).indexOf('wink-item:1')>=0,"Each distinct linked item gets its own hover region");
        label.onOverHyperlink("wink-item:1");
        check(G.ui.currentTip!=null,"A second link in a message can display its tooltip");
        ItemLinks.attach(row);
        check(G.ui.currentTip==null&&G.text(label.text).indexOf('wink-item:1')>=0,"Reinitializing a row clears old hover state and avoids stacked handlers");
        var nativeFormat:Dynamic=(text:String)->"native:"+text;
        var nativeHover:Dynamic=(href:String)->{foreign++;};
        var ownBubble:Dynamic={timer:0,countdown:5,messageText:{text:"",prevUnformatted:null,formatText:nativeFormat,onOverHyperlink:nativeHover}};
        var remoteBubble:Dynamic={timer:0,countdown:5,messageText:{text:"",prevUnformatted:null,formatText:nativeFormat,onOverHyperlink:nativeHover}};
        var bubbleMessage:Dynamic={text:"Selling "+token+" today",notify:null,sender:{isMe:true}};
        openBubble(ownBubble,bubbleMessage);
        check(ownBubble.messageText.text=='native:Selling <font color="#AABBCC"><b>Épée du test</b></font> today',"Self bubble displays the colored localized name even when the wire token exceeds the native 100-character cap");
        check(bubbleMessage.text=="Selling "+token+" today","Bubble presentation leaves shared chat history and wire data intact");
        check(G.text(ownBubble.messageText.text).indexOf("<a ")<0&&ownBubble.messageText.onOverHyperlink==nativeHover,"Bubble names do not add interactive links or hover handlers");
        check(ownBubble.timer==5&&ownBubble.visible==true,"Native bubble visibility and countdown still run");
        bubbleMessage.sender={isMe:false};openBubble(remoteBubble,bubbleMessage);
        check(remoteBubble.messageText.text==ownBubble.messageText.text,"Other players' bubbles use the same formatting");
        openBubble(ownBubble,bubbleMessage);
        check(ownBubble.messageText.text==remoteBubble.messageText.text,"Repeated bubble messages refresh without stacking formatters");
        ItemLinks.configure(false);
        check(G.text(ownBubble.messageText.text).indexOf("~i1:")>=0,"Disabling restores native bubble text");
        ItemLinks.configure(true);
        check(G.text(ownBubble.messageText.text).indexOf("~i1:")<0,"Re-enabling restores the readable bubble name");
        bubbleMessage.text=StringTools.lpad("","x",80)+" "+token+" "+StringTools.lpad("","y",30);
        openBubble(ownBubble,bubbleMessage);
        var readable=~/<[^>]*>/g.replace(G.text(ownBubble.messageText.text).substr(7),"");
        check(readable.length==103&&StringTools.endsWith(readable,"...")&&readable.indexOf("Épée du test")>=0,"Bubble truncation counts visible names and keeps valid markup");
        bubbleMessage.text=StringTools.lpad("","x",96)+token;openBubble(ownBubble,bubbleMessage);
        check(StringTools.endsWith(G.text(ownBubble.messageText.text),'<b>Épée</b></font>...'),"The visible limit may shorten a name without exposing a partial encoded token or breaking its color tag");
        bubbleMessage.text="<evil> ~wink-bubble-0~ "+token;openBubble(ownBubble,bubbleMessage);
        check(G.text(ownBubble.messageText.text).indexOf("&lt;evil&gt; ~wink-bubble-0~ ")>=0,"Native escaping and literal text resembling internal placeholders are preserved");
        bubbleMessage.text="Ordinary message";openBubble(ownBubble,bubbleMessage);
        check(ownBubble.messageText.text=="native:Ordinary message"&&ownBubble.messageText.formatText==nativeFormat,"Reusing a bubble for ordinary text restores its native formatter");
        ItemLinks.forget(remoteBubble);
        check(remoteBubble.messageText.formatText==nativeFormat,"Removing a bubble releases its formatter");
        var malformed:Dynamic={message:{text:"before ~i1:AAAA~ after",notify:null},msgText:{prevUnformatted:"unchanged",text:"unchanged"}};
        ItemLinks.attach(malformed);check(malformed.msgText.text=="unchanged","Malformed links never replace ordinary text");
        offer.kind="MissingItem";var unknownToken=ItemLinkCodec.encode(offer);
        malformed.message.text=unknownToken;ItemLinks.attach(malformed);
        check(malformed.msgText.text=="unchanged","Unknown game IDs remain plain text");
        ItemLinks.forget(slot);check(interactive.onPush==originalPush&&interactive.onRelease==originalRelease,"Removed item widgets release their wrapper callbacks");
        ItemLinks.dispose();check(custom.interactive.onPush==originalPush,"Disconnect restores remaining item handlers");
        Sys.println("Item link UI checks passed: "+checks);
    }
}
