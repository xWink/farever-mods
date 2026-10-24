import marketplace.MarketWindow;
import marketplace.MarketController;
import trade.GameAccess as G;

class MarketplaceBadgeTest {
 static var checks=0;
 static function check(value:Bool,context:String):Void {
  checks++;if(!value)throw "Marketplace badge assertion: "+context;
 }
 static function captions():Array<Dynamic> return G.labels.filter(l->StringTools.startsWith(G.text(l.text),"Seller: "));
 static function icons(box:Dynamic):Array<Dynamic> return (cast box.children:Array<Dynamic>).filter(n->n.nativeType=="h2d.Bitmap");
 static function dot(box:Dynamic):Dynamic return (cast box.children:Array<Dynamic>).filter(n->n.shapes!=null)[0];
 static function loads():Int return G.pngLoads.filter(s->StringTools.startsWith(s,"supporter-")||s=="fareverly-creator.png").length;

 public static function run(fixture:Dynamic):Void {
  var ids=["supporter-bronze","supporter-silver","supporter-gold","supporter-ruby","supporter-emerald","supporter-diamond","fareverly-creator"];
  var c=new MarketController();
  c.rows=[for(id in ids){
   var row=haxe.Json.parse(haxe.Json.stringify(fixture));
   row.id=id;row.seller.characterName="Tester";row.seller.badge=id;
   row.seller.onlineUntil="2099-01-01T00:00:00.000Z";
   row;
  }];
  var initialLoads=loads(),textureStart=G.textures.length;
  var view=new MarketWindow(c);c.view=view;view.open();view.update();
  var sellers=captions();
  check(sellers.length==ids.length&&loads()==initialLoads+ids.length,"all supported badges load once");
  for(i in 0...ids.length) {
   var caption=sellers[i],box=caption.parent,images=icons(box);
   check(images.length==1,"one badge per seller");
   var badge=images[0],presence=dot(box);
   check(badge.tile.texture.resourceName==ids[i]+".png","correct badge artwork");
   check(badge.smooth&&badge.tile.width==22&&badge.tile.height==22,"small smooth icon");
   var texture=badge.tile.texture;
   check(texture.width==44&&texture.sourceTexture.width==88,
    "smoothing retains a 2x final texture");
   var target:Dynamic=texture,passes=0;
   while(target.sourceTexture!=null) {
    var source:Dynamic=target.sourceTexture;
    check(target.clearAlpha==0&&(source.sourcePng?target.drawnBlend==null:target.drawnBlend=="AlphaAdd"),
     "every smoothing pass preserves transparent premultiplied edges");
    check(source.disposed&&target.width>=Math.floor(source.width/2),"source is released after a gradual downsample");
    passes++;target=source;
   }
   check(passes==(ids[i]=="supporter-diamond"?5:2)&&texture.disposed!=true&&badge.blendMode=="AlphaAdd",
    "full resolution diamond uses extra smoothing passes");
   check(badge.x==14*8+4&&badge.y==1&&presence.x==badge.x+22+6,"badge follows name before presence");
   check(caption.maxWidthText==234&&caption.useEllipsis&&box.width==350&&box.height==24,"space reserved inside existing line");
   check(badge.flowProperties.isAbsolute&&badge.interactive==null&&badge.action==null&&badge.getTip==null,"badge cannot capture clicks or change flow");
  }
  var first=sellers[0],box=first.parent,badge=icons(box)[0],presence=dot(box);
  first.inkBounds={xMin:2.,yMin:5.,xMax:202.,yMax:29.};first.scaleX=.75;first.scaleY=.75;
  box.onAfterReflow();
  check(badge.x==154&&presence.x==182&&first.y+29*.75<=24,"native font bounds and scale position the badge");
  c.presenceOverride=false;@:privateAccess view.presenceCheckAt=0;view.update();
  check(presence.shapes[0].color==0x888888&&icons(box)[0]==badge,"presence changes preserve badge");
  box.parent.action();check(c.selected==c.rows[0],"row still selects the original listing");
  view.update();
  check(loads()==initialLoads+ids.length,"redrawing reuses badge textures");
  c.tab="My listings";view.dirty=true;view.update();
  check(captions().length==ids.length&&icons(captions()[ids.length-1].parent).length==1,"own listings include supporter and creator badges");
  check(loads()==initialLoads+ids.length,"tab changes reuse textures");
  // The native FmtText ellipsis is given less width, while all row columns stay put.
  c.rows[0].seller.characterName="A very long seller name that fills the available name space";
  view.dirty=true;view.update();
  first=captions()[0];box=first.parent;badge=icons(box)[0];
  check(first.maxWidthText==234&&first.lineBreak==false&&first.useEllipsis,"long names retain native ellipsis");
  first.inkBounds={xMin:0.,yMin:4.,xMax:234.,yMax:22.};box.onAfterReflow();
  presence=dot(box);
  var status=G.labels.filter(l->l.parent==box&&l.text=="Offline")[0];
  check(badge.x==238&&presence.x==266&&status.x==282&&status.x+7*8<=box.width,"long name, badge and offline status fit");
  for(missing in [null,"","supporter-unknown","../supporter-gold"]) {
   c.rows[0].seller.badge=missing;c.rows[0].seller.characterName="Tester";
   view.dirty=true;view.update();first=captions()[0];box=first.parent;
   check(icons(box).length==0&&first.maxWidthText==260&&dot(box).x==118,"absent or unsupported badge leaves no gap");
  }
  check(loads()==initialLoads+ids.length,"unsupported IDs do not load resources");
  view.close();
  check(G.textures.slice(textureStart).filter(t->t.disposed!=true).length==0,"closing releases every texture");
  // A bad optional image must leave the listing selectable, and should not be
  // decoded again on every row/refresh. Reopening allows a fresh load.
  c.rows=[];c.selected=null;view.open();view.update(); // Load the header artwork first.
  c.rows=[haxe.Json.parse(haxe.Json.stringify(fixture))];
  c.rows[0].seller.badge="supporter-silver";c.rows[0].seller.characterName="Tester";
  G.failNextPng=true;view.dirty=true;view.update();
  first=captions()[0];box=first.parent;
  check(icons(box).length==0&&first.maxWidthText==260,"decode failure preserves normal seller layout");
  box.parent.action();check(c.selected==c.rows[0],"decode failure preserves listing action");
  var failedLoads=loads();view.update();check(loads()==failedLoads,"failed resource is not retried during redraw");
  view.close();view.open();view.update();
  check(icons(captions()[0].parent).length==1&&loads()==failedLoads+1,"reopening can load a previously failed image");
  view.close();
  check(G.textures.slice(textureStart).filter(t->t.disposed!=true).length==0,"reopening and failures release textures");
  Sys.println("Marketplace badge checks passed: "+checks);
 }
}
