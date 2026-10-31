import groupfinder.GroupController;
import groupfinder.GroupBadges;
import groupfinder.GameAccess as G;

/** Exercise the real badge renderer against the native UI adapter. */
class GroupBadgeTest {
    static var checks=0;
    static function check(ok:Bool,why:String):Void {checks++;if(!ok)throw why;}
    static function boxes():Array<Dynamic> return G.nodes.filter(n->StringTools.startsWith(n.id,"groupMemberName"));
    static function images(box:Dynamic):Array<Dynamic> return (cast box.children:Array<Dynamic>).filter(n->G.field(n,"nativeType")=="h2d.Bitmap");
    public static function run(c:GroupController):Void {
        var ids=["supporter-bronze","supporter-silver","supporter-gold","supporter-ruby","supporter-emerald","supporter-diamond","fareverly-creator"];
        var captions=["Bronze Supporter","Silver Supporter","Gold Supporter","Ruby Supporter","Emerald Supporter","Diamond Supporter","Fareverly Creator"];
        for(i in 0...ids.length) {
            var matches=boxes().filter(b->images(b).filter(icon->icon.tile.texture.resourceName==ids[i]+".png").length>0);
            check(matches.length>0,"Sample listings demonstrate "+ids[i]);
            check(G.pngLoads.filter(s->s==ids[i]+".png").length==1,"Each badge texture loads once per window");
            var box=matches[0],badge=images(box)[0];
            var label=(cast box.children:Array<Dynamic>).filter(n->G.field(n,"testLabel")==true)[0];
            check(label.maxWidthText+GroupBadges.SIZE+GroupBadges.GAP==box.width,"Badge space is reserved within the member column");
            check(badge.x==Math.min(label.maxWidthText,G.text(label.text).length*8)+4&&badge.x+22<=box.width,"Badge follows the displayed name and stays inside its column");
            check(badge.tile.texture.width==44&&badge.tile.texture.sourceTexture.width==88&&badge.smooth,"Badge retains Marketplace's smooth 2x texture");
            check(badge.blendMode=="AlphaAdd"&&G.field(badge,"interactive")==null&&box.interactive.propagateEvents,"Badge hover does not consume clicks or scrolling");
            box.interactive.onOver({relX:badge.x+11,relY:11.,cancel:false});
            check(G.ui.currentTip.content.text==captions[i],"Badge tooltip identifies the tier");
            box.interactive.onOut({});check(G.ui.currentTip==null,"Leaving the member clears its tooltip");
        }
        var listing=c.rows.filter(r->r.category=="Dungeons")[0],member=listing.members[0];
        var originalName=member.name,originalBadge=member.badge;
        member.name="A long member name that must leave space for its badge";member.badge="supporter-gold";
        c.view.dirty=true;c.view.update(true);
        var longBox=boxes()[0],badge=images(longBox)[0];
        var label=(cast longBox.children:Array<Dynamic>).filter(n->G.field(n,"testLabel")==true)[0];
        check(label.useEllipsis&&badge.x+22==longBox.width,"Long names truncate before the badge");
        for(id in [null,"","unknown","../supporter-gold"]) {
            member.badge=id;c.view.dirty=true;c.view.update(true);
            var box=boxes()[0];
            var name=(cast box.children:Array<Dynamic>).filter(n->G.field(n,"testLabel")==true)[0];
            check(images(box).length==0&&name.maxWidthText==box.width,"Unknown or absent badges reserve no blank space");
        }
        member.name=originalName;member.badge=originalBadge;c.view.dirty=true;c.view.update(true);
        check(G.pngLoads.length==ids.length,"Refreshes reuse badge textures");
        trace('Group Finder badges passed ($checks checks)');
    }
}
