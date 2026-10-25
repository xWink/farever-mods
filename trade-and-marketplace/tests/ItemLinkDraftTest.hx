import trade.ItemLinkDraft;
import trade.ItemLinkDraftModel;
import trade.ItemLinkCodec;
import trade.ItemLinks;
import trade.GameAccess as G;

class ItemLinkDraftTest {
    static var checks=0;
    static function check(value:Bool,message:String):Void {checks++;if(!value)throw message;}
    static function main():Void {
        for(entry in ["item:Sword","item:CorruptedGift","rarity:Epic","skill:Warrior_Smash","skill:Rogue_Poison","attribute:Power"])
            G.definitions.set(entry,{id:entry.split(":")[1]});
        var token=ItemLinkCodec.encode(ItemLinkTest.fixture());
        var model=new ItemLinkDraftModel();
        var compact=model.collapse("Before "+token+" after",ItemLinkCodec.decode),atom=model.visible(compact)[0];
        check(compact.length=="Before  after".length+1,"A complete item occupies one editable character");
        check(model.expand(compact)=="Before "+token+" after","Wire expansion retains the exact snapshot and surrounding text");
        check(model.expand(model.replace(compact,atom.index,atom.index+1,""))=="Before  after","Backspace/Delete remove the entire item atom");
        check(model.expand(model.replace(compact,0,atom.index+1,"new"))=="new after","Selections spanning an item replace its whole snapshot");
        check(model.collapse(token,ItemLinkCodec.decode)==compact.charAt(atom.index),"Repeated identical links reuse their atom");
        check(model.expand(compact.charAt(atom.index))==token,"Copying a link exports the complete token");
        var simple=ItemLinkTest.fixture();simple.count=1;simple.preview={flags:0,level:0,upgrade:0,rarity:"",infusion:"",bonus:"",mastery:"",slots:[],effects:[]};
        var other=ItemLinkCodec.encode(simple),pair=model.collapse(token+" "+other,ItemLinkCodec.decode);
        check(model.visible(pair).length==2&&model.expand(pair)==token+" "+other,"Two distinct item snapshots survive together");
        check(model.fits(compact.charAt(atom.index)+StringTools.lpad("","x",250-token.length)),"The encoded message can use exactly 250 characters");
        check(!model.fits(compact.charAt(atom.index)+StringTools.lpad("","x",251-token.length)),"Visible short names cannot bypass the wire limit");
        check(model.collapse("bad ~i1:AAAA~",ItemLinkCodec.decode)=="bad ~i1:AAAA~","Malformed tokens stay ordinary text");

        var input:Dynamic={text:"Selling ",font:G.font(),maxCharacters:250,cursorIndex:8,selectionRange:null,changes:0,scrollX:0,interactive:{width:180,height:20}};
        var chat:Dynamic={messageInput:{input:input}},sent="",moves=0,outs=0;
        input.onEnter=function():Void {sent=G.text(input.text);G.call("h2d.TextInput","set_text",input,[""]);};
        var nativeEnter:Dynamic=input.onEnter;
        input.onMove=(e:Dynamic)->{moves++;};input.onOut=(e:Dynamic)->{outs++;};
        G.ui={nativeType:"ui.GameUI",chat:chat,currentTip:null};
        ItemLinkDraft.attach(chat);var wrapped=input.onEnter;ItemLinkDraft.attach(chat);
        check(input.onEnter==wrapped,"Repeated chat focus does not stack wrappers");
        G.call("h2d.TextInput","inputText",input,[token+" "]);
        var display=G.text(input.text);
        check(display.length==10&&display.indexOf("~i1:")<0,"The native draft contains a single link unit instead of encoded text");
        check(ItemLinkDraft.wire(input,display)=="Selling "+token+" ","Outgoing draft content retains every encoded field");
        check(input.cursorIndex==display.length,"Insertion leaves the caret after the link and separator");
        var mask=G.created.filter(o->o.nativeType=="h2d.Mask"&&o.parent==input)[0];
        var labels:Array<Dynamic>=mask.children;
        check(labels.length==1&&G.text(labels[0].text).indexOf('<font color="#AABBCC"><b>Épée du test</b>')>=0,"Draft renders the localized name in bold and its native rarity color");
        var sourceGlyph=input.font.glyphs.get(display.charCodeAt(8));
        check(sourceGlyph.t.width==0&&sourceGlyph.t.height==0&&sourceGlyph.width>0,"An invisible glyph reserves exactly the rich name's width");
        var plainFont=G.font();
        var plainGlyphs:Map<Int,Dynamic>=plainFont.glyphs;
        check(!plainGlyphs.exists(display.charCodeAt(8)),"Other UI fonts are unaffected");
        ItemLinkDraft.position(input);
        check(mask.width==180&&mask.height==20&&labels[0].x==64,"The label aligns to the prefix and is clipped to the draft field");
        input.scrollX=30;ItemLinkDraft.position(input);
        check(labels[0].x==34,"Rich labels follow native horizontal scrolling");
        input.onMove({relX:35,relY:5});
        check(moves==1&&G.ui.currentTip!=null&&G.ui.currentTip.content.realItem.level==30,"Hovering the draft link shows its original tooltip and preserves native movement handling");
        input.onOut({});check(outs==1&&G.ui.currentTip==null,"Leaving the draft hides only its own tooltip");

        // Native Backspace removes the separator, then one character for the complete link.
        G.call("h2d.TextInput","set_text",input,[display.substr(0,display.length-1)]);input.cursorIndex=9;
        var beforeDelete=G.text(input.text);
        G.call("h2d.TextInput","set_text",input,[beforeDelete.substr(0,8)]);input.cursorIndex=8;
        check(ItemLinkDraft.wire(input,input.text)=="Selling "&&mask.children.length==0,"Deleting a link removes its entire encoded payload and its label");
        G.call("h2d.TextInput","set_text",input,[beforeDelete]);input.cursorIndex=9;
        check(ItemLinkDraft.wire(input,input.text)=="Selling "+token&&mask.children.length==1,"Undo can restore the complete link and rich label");
        input.selectionRange={start:8,length:1};G.call("h2d.TextInput","inputText",input,["ordinary"]);
        check(input.text=="Selling ordinary"&&mask.children.length==0,"Typing over a selected link replaces it atomically");

        G.call("h2d.TextInput","set_text",input,["History "+token]);input.cursorIndex=G.text(input.text).length;
        check(G.text(input.text).length==9&&mask.children.length==1,"Chat history and pasted wire text become rich links again");
        var history=G.text(input.text);
        input.onEnter();
        check(sent=="History "+token&&input.text==""&&mask.children.length==0,"Native Enter sends full encoded data and clears the draft normally");
        G.call("h2d.TextInput","set_text",input,[history]);input.cursorIndex=G.text(input.text).length;
        input.font=G.font();ItemLinkDraft.changed(input);
        var themedGlyphs:Map<Int,Dynamic>=input.font.glyphs;
        check(themedGlyphs.exists(history.charCodeAt(8)),"Theme/font changes rebuild link metrics");
        var current=G.text(input.text);G.call("h2d.TextInput","inputText",input,[StringTools.lpad("","x",250)]);
        check(input.text==current&&G.errors.length==1,"Overlong insertions preserve the existing draft and encoded item");
        var third=ItemLinkTest.fixture();third.kind="UnknownItem";
        var unknown=ItemLinkCodec.encode(third);G.call("h2d.TextInput","set_text",input,[unknown]);
        check(input.text==unknown,"Unknown item definitions remain literal draft text");
        G.call("h2d.TextInput","set_text",input,[history]);ItemLinkDraft.configure(false);
        check(input.text=="History "+token&&input.onEnter==nativeEnter&&mask.parent==null,"Disabling restores wire text, original handlers and removes draft rendering");
        check(input.undo.length==0,"Disabling discards native undo entries that reference private glyphs");
        ItemLinkDraft.configure(true);ItemLinkDraft.attach(chat);
        check(G.text(input.text).length==9,"Re-enabling can reconstruct an existing encoded draft");
        ItemLinks.dispose();
        check(input.text=="History "+token&&input.onEnter==nativeEnter,"Disconnect cleans up draft links and restores native editing");
        Sys.println("Item link draft checks passed: "+checks);
    }
}
