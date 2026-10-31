package groupfinder;

import groupfinder.GroupTypes;

/** Simulates asynchronous Fareverly calls without HTTP, secrets, or whispers. */
class MockGroupService implements GroupService {
    public var revision(default,null)=0;
    public var now(default,null)=0.0;
    var sequence=0;
    var rows:Array<GroupListing>=[];
    var tasks:Array<{at:Float, run:Void->Void}>=[];
    var parties:Map<String,GroupParty>=[];
    var sessions:Map<String,Int>=[];
    var exampleRegions:Map<String,Bool>=[];
    var nextExpiry=0.0;
    public function new() {}
    function later(run:Void->Void):Void tasks.push({at:now+0.15,run:run});
    public function tick(time:Float):Void {
        now=time;
        if(now>=nextExpiry) {
            nextExpiry=now+1;
            var before=rows.length;
            rows=rows.filter(row->row.sample||row.expiresAt>now);
            if(before!=rows.length)revision++;
        }
        if(tasks.length==0)return;
        var ready=tasks.filter(task->task.at<=now);
        tasks=tasks.filter(task->task.at>now);
        for(task in ready)task.run();
    }
    public function list(region:String,done:GroupResult<Array<GroupListing>>->Void):Void later(()->{
        done({value:GroupRules.clone(rows.filter(row->row.region==region)),error:""});
    });
    public function save(party:GroupParty,id:Null<String>,title:String,category:String,done:GroupResult<GroupListing>->Void):Void {
        var expected=GroupRules.clone(party);
        var session=sessions.exists(expected.accountId)?sessions[expected.accountId]:0;
        later(()->{
            if(session!=(sessions.exists(expected.accountId)?sessions[expected.accountId]:0)) {
                done({value:null,error:"Your session changed. Please try again."});return;
            }
            // Recheck the latest observed party after simulated network latency.
            var current=parties[expected.accountId],error=GroupRules.partyError(current);
            if(error==""&&(current.partyId!=expected.partyId||current.region!=expected.region))error="Your party changed. Please try again.";
            if(error=="")error=GroupRules.titleError(title);
            if(error==""&&GroupRules.categories.indexOf(category)<0)error="Choose a content category.";
            var previous:Null<GroupListing>=null;
            for(row in rows) {
                if(row.id==id)previous=row;
                else if(row.ownerId==expected.accountId||
                    (row.region==expected.region&&row.partyId==expected.partyId))error="Your party already has a listing.";
            }
            if(error==""&&id!=null&&(previous==null||previous.ownerId!=expected.accountId))error="This listing is no longer available.";
            if(error!=""){done({value:null,error:error});return;}
            var row:GroupListing={id:id==null?"local-"+(++sequence):id,ownerId:current.accountId,
                partyId:current.partyId,region:current.region,category:category,title:StringTools.trim(title),
                members:GroupRules.clone(current.members),updatedAt:now,expiresAt:now+120,sample:false};
            if(previous!=null)rows.remove(previous);
            rows.unshift(row);revision++;
            done({value:GroupRules.clone(row),error:""});
        });
    }
    public function remove(accountId:String,id:String,done:GroupResult<Bool>->Void):Void later(()->{
        for(row in rows)if(row.id==id) {
            if(row.ownerId!=accountId){done({value:false,error:"Only the listing owner can close it."});return;}
            rows.remove(row);revision++;done({value:true,error:""});return;
        }
        done({value:true,error:""});
    });
    /** A party snapshot also models the owner's heartbeat, independently of the UI. */
    public function observe(party:GroupParty):Void {
        parties[party.accountId]=GroupRules.clone(party);
        for(row in rows.copy())if(row.ownerId==party.accountId) {
            if(GroupRules.partyError(party)!=""||row.partyId!=party.partyId||row.region!=party.region) {
                rows.remove(row);revision++;
            } else {
                if(haxe.Json.stringify(row.members)!=haxe.Json.stringify(party.members)) {
                    row.members=GroupRules.clone(party.members);row.updatedAt=now;revision++;
                }
                row.expiresAt=now+120;
            }
        }
    }
    public function disconnect(accountId:String):Void {
        sessions[accountId]=(sessions.exists(accountId)?sessions[accountId]:0)+1;
        parties.remove(accountId);
        var before=rows.length;rows=rows.filter(row->row.ownerId!=accountId);
        if(before!=rows.length)revision++;
    }
    public function find(id:String):Null<GroupListing> {
        for(row in rows)if(row.id==id)return GroupRules.clone(row);
        return null;
    }
    public function mine(accountId:String):Null<GroupListing> {
        for(row in rows)if(row.ownerId==accountId)return GroupRules.clone(row);
        return null;
    }
    public function examples(region:String,enabled:Bool):Void {
        if(region==""||exampleRegions[region]==enabled)return;
        exampleRegions[region]=enabled;
        rows=rows.filter(row->!row.sample||row.region!=region);
        if(enabled) {
            var names=["Bramble", "Mistral", "Ember", "Pebble"];
            var classes=["Warrior", "Mage", "Rogue", "Cleric"];
            var titles=["Heroic dungeon runs", "Learning run — all welcome", "One more for dungeons", "Relaxed dungeon clear", "Heroic boss practice", "First clear together", "Quick dungeon run", "Looking for a healer", "World events together", "Exploring world bosses", "Event hunt — all welcome", "Exploring and gathering", "New players welcome"];
            for(i in 0...titles.length) {
                var id="sample-"+region+"-"+i,n=1+i%3;
                var members=[for(j in 0...n){accountId:id+"-"+j,name:names[(i+j)%4],className:classes[(i+j)%4],level:25}];
                rows.push({id:id,ownerId:members[0].accountId,partyId:id,region:region,
                    category:i<8?"Dungeons":i<11?"World Events":"Other",title:titles[i],members:members,
                    updatedAt:now,expiresAt:now+120,sample:true});
            }
        }
        revision++;
    }
}
