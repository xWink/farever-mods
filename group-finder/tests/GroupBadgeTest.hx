import groupfinder.GroupController;
import groupfinder.GroupBadges;
import groupfinder.GameAccess as G;

/** Exercise the real badge renderer against the native UI adapter. */
class GroupBadgeTest {
    static var checks=0;
    static function check(ok:Bool,why:String):Void {checks++;if(!ok)throw why;}
    static function boxes():Array<Dynamic> return G.nodes.filter(n->StringTools.startsWith(n.id,"groupMemberName"));
    static function images(box:Dynamic):Array<Dynamic> return (cast box.children:Array<Dynamic>).filter(n->G.field(n,"nativeType")=="h2d.Bitmap");
    static function labels(box:Dynamic):Array<Dynamic> return (cast box.children:Array<Dynamic>).filter(n->G.field(n,"testLabel")==true);
    public static function run(c:GroupController):Void {
        var ids=["supporter-bronze","supporter-silver","supporter-gold","supporter-ruby","supporter-emerald","supporter-diamond","fareverly-creator"];
        var captions=["Bronze Supporter","Silver Supporter","Gold Supporter","Ruby Supporter","Emerald Supporter","Diamond Supporter","Fareverly Creator"];
        var members=[for(row in c.rows)for(member in row.members)member];
        check(members.filter(m->m.badge!=null).length==5&&members.length==25,"Only one in five sample members has a badge");
        check([for(i in 0...35)groupfinder.MockGroupService.sampleBadge(i)].filter(b->b!=null).length==7,"Sample requests use the same sparse badge distribution");
        var listing=c.rows.filter(r->r.category=="Dungeons")[0],member=listing.members[0];
        var originalName=member.name,originalBadge=member.badge;
        for(i in 0...ids.length) {
            // Exercise every tier without cluttering the user-facing examples.
            member.badge=ids[i];c.view.dirty=true;c.view.update(true);
            var box=boxes()[0],badge=images(box)[0],label=labels(box)[0],star=labels(box)[1];
            check(badge.tile.texture.resourceName==ids[i]+".png","Correct badge artwork");
            check(G.pngLoads.filter(s->s==ids[i]+".png").length==1,"Each badge texture loads once per window");
            check(label.text==member.name&&star.text=="★"&&star.textColor==0xD6A516,"Yellow leader star is separate from the player name");
            check(label.maxWidthText+GroupBadges.SIZE+GroupBadges.GAP+20==box.width,"Badge and star space is reserved within the member column");
            check(badge.x==Math.min(label.maxWidthText,G.text(label.text).length*8)+4&&star.x==badge.x+26&&star.x+16<=box.width,"Name, badge, and leader star remain in order inside the column");
            check(Math.abs(badge.y+11-13*label.scaleY)<=0.5,"Badge center matches visible name glyphs");
            check(badge.tile.texture.width==44&&badge.tile.texture.sourceTexture.width==88&&badge.smooth,"Badge retains Marketplace's smooth 2x texture");
            check(badge.blendMode=="AlphaAdd"&&G.field(badge,"interactive")==null&&box.interactive.propagateEvents,"Badge hover does not consume clicks or scrolling");
            box.interactive.onOver({relX:badge.x+11,relY:badge.y+11-box.interactive.y,cancel:false});
            check(G.ui.currentTip.content.text==captions[i],"Badge tooltip identifies the tier");
            box.interactive.onOut({});check(G.ui.currentTip==null,"Leaving the member clears its tooltip");
            // Simulate a smaller native font with a different glyph offset.
            label.inkBounds={xMin:0.,xMax:60.,yMin:2.,yMax:20.};label.nativeScale=0.6;label.needUpdateScale=true;
            star.inkBounds={xMin:1.,xMax:13.,yMin:3.,yMax:19.};star.nativeScale=0.75;star.needUpdateScale=true;
            box.onAfterReflow();var center=11*0.6;
            check(Math.abs(badge.y+11-center)<=0.5&&Math.abs(star.y+11*0.75-center)<0.001,"Font reflow vertically aligns the badge and leader star to the name");
            check(box.interactive.y<=badge.y&&box.interactive.y+box.interactive.height>=badge.y+22,"Raised badge remains fully hoverable");
            var badgeY=badge.y,starY=star.y;box.onAfterReflow();
            check(badge.y==badgeY&&star.y==starY,"Repeated layout does not accumulate offsets");
            box.interactive.onOver({relX:badge.x+11,relY:badge.y-box.interactive.y+1,cancel:false});
            check(G.ui.currentTip.content.text==captions[i],"Top of a raised badge still shows its tooltip");
            box.interactive.onOut({});
        }
        member.name="A long member name that must leave space for its badge";member.badge="supporter-gold";
        c.view.dirty=true;c.view.update(true);
        var longBox=boxes()[0],badge=images(longBox)[0],label=labels(longBox)[0],star=labels(longBox)[1];
        check(label.useEllipsis&&badge.x+22+20==longBox.width&&star.x+16==longBox.width,"Long names truncate before the badge and leader star");
        for(id in [null,"","unknown","../supporter-gold"]) {
            member.badge=id;c.view.dirty=true;c.view.update(true);
            var box=boxes()[0],name=labels(box)[0],star=labels(box)[1];
            check(images(box).length==0&&name.maxWidthText+20==box.width&&star.x+16==box.width,"Unknown or absent badges leave only the leader-star space");
        }
        member.name=originalName;member.badge=originalBadge;c.view.dirty=true;c.view.update(true);
        check(G.pngLoads.length==ids.length,"Refreshes reuse badge textures");
        trace('Group Finder badges passed ($checks checks)');
    }
}
