import fareverly.Protocol;
import groupfinder.GroupPresence;
import groupfinder.GroupProtocol;
import marketplace.MarketPresence;
import marketplace.MarketPresenceRefresh;

/** Run under HashLink in separate TZ processes. Epoch expectations are independent
    of Date: its local-time conversion is the source of the DST regression. */
class FareverlyTimeTest {
    static var checks=0;
    static function check(ok:Bool,why:String):Void {checks++;if(!ok)throw why;}
    static function equal(actual:Float,expected:Float,why:String):Void
        check(Math.isFinite(actual)&&Math.abs(actual-expected)<0.0001,why+': $actual != $expected');
    static function main():Void {
        timestamps();presence();retryAfter();
        Sys.println('Fareverly UTC checks passed: $checks (TZ='+Sys.getEnv("TZ")+")");
    }
    static function timestamps():Void {
        var cases=[
            {iso:"2026-11-01T00:44:10.000Z",epoch:1793493850.0},
            {iso:"2026-10-31T23:44:10.374Z",epoch:1793490250.374},
            {iso:"2026-11-01T00:44:10.374Z",epoch:1793493850.374},
            {iso:"2026-11-01T01:30:00Z",epoch:1793496600.0},
            {iso:"2026-11-01T08:59:59Z",epoch:1793523599.0},
            {iso:"2026-11-01T09:00:00Z",epoch:1793523600.0},
            {iso:"2026-11-02T00:44:10.374Z",epoch:1793580250.374},
            {iso:"2026-03-07T23:59:59Z",epoch:1772927999.0},
            {iso:"2026-03-08T00:44:10.374Z",epoch:1772930650.374},
            {iso:"2026-03-08T02:30:00Z",epoch:1772937000.0},
            {iso:"2026-03-08T09:59:59Z",epoch:1772963999.0},
            {iso:"2026-03-08T10:00:00Z",epoch:1772964000.0},
            {iso:"2026-10-25T00:30:00Z",epoch:1792888200.0},
            {iso:"1970-01-01T00:00:00.125Z",epoch:0.125},
            {iso:"2000-02-29T12:34:56Z",epoch:951827696.0},
            {iso:"2028-02-29T12:00:00Z",epoch:1835438400.0},
            {iso:"2100-03-01T00:00:00Z",epoch:4107542400.0},
            {iso:"2400-02-29T00:00:00Z",epoch:13574563200.0},
            {iso:"9999-12-31T23:59:59.999Z",epoch:253402300799.999}
        ];
        for(c in cases)equal(Protocol.expiry(c.iso),c.epoch,c.iso);
        for(value in [null,"","invalid","2026-11-01T00:44:10+00:00","2026-11-01T00:44:10",
            "2026-11-01T00:44:10.12Z","2026-11-01T00:44:10.1234Z","2026-11-01T00:44:10Z trailing",
            "2026-00-01T00:00:00Z","2026-13-01T00:00:00Z","2026-01-00T00:00:00Z",
            "2026-04-31T00:00:00Z","2026-02-29T00:00:00Z","2100-02-29T00:00:00Z",
            "2026-11-01T24:00:00Z","2026-11-01T00:60:00Z","2026-11-01T00:00:60Z",
            "2026-02-30T00:00:00.500Z"])
            equal(Protocol.expiry(value),0,"Invalid timestamp fails closed: "+value);
    }
    static function presence():Void {
        // Live API timestamp from the reported outage. All three deadlines must
        // remain future times even on a client whose timezone changes that night.
        var now=1793493731.0,until=1793493850.374,iso="2026-11-01T00:44:10.374Z";
        var body=haxe.Json.stringify({server:"north-america",busy:false,onlineUntil:iso});
        equal(MarketPresence.deadline(200,body,""),until,"Own Marketplace heartbeat retains its UTC deadline");
        equal(GroupPresence.deadline(200,body,""),until,"Own Group Finder heartbeat retains its UTC deadline");
        check(MarketPresence.deadline(200,body,"")>now,"Worker accepts a fresh own heartbeat");
        var row:Dynamic={id:"listing",server:"north-america",seller:{accountId:"peer",online:true,busy:true,onlineUntil:iso}};
        var peers=new MarketPresenceRefresh();peers.observe({listings:[row]},10);
        equal(peers.deadline(row),until,"Peer listing uses the same UTC deadline");
        check(peers.deadline(row)>now&&peers.busy(row)==true,"Online and Busy survive the DST transition");
        check(!(peers.deadline(row)>until),"Presence still expires at the actual deadline");
        row.seller.online=false;peers.observe(row,11);
        equal(peers.deadline(row),0,"Explicit offline remains offline");
        for(status in [0,401,403,429,503]) {
            equal(MarketPresence.deadline(status,body,""),0,"Failed Marketplace heartbeat cannot extend presence");
            equal(GroupPresence.deadline(status,body,""),0,"Failed Group Finder heartbeat cannot extend presence");
        }
        var listing=GroupProtocol.listing({id:"00000000-0000-4000-8000-000000000001",revision:1,
            leaderAccountId:"peer",partyId:"solo-peer",server:"north-america",category:"dungeons",subcategory:"dungeons",
            title:"Heroic runs",members:[{accountId:"peer",name:"Peer",className:"Mage",level:25}],
            updatedAt:"2026-11-01T00:42:11Z",onlineUntil:iso});
        equal(listing.expiresAt,until,"Group Finder listing retains its UTC presence expiry");
        equal(listing.updatedAt,now,"Group Finder update timestamp is UTC too");
        check(listing.expiresAt>now,"An active group is not hidden as expired");
    }
    static function retryAfter():Void {
        var now=1793493731.0;
        equal(Protocol.retryAfter("Sun, 01 Nov 2026 00:44:10 GMT",now),119,"HTTP-date retry delay is timezone independent");
        equal(Protocol.retryAfter("Sat, 31 Oct 2026 23:44:10 GMT",now),0,"Past HTTP-date does not delay retries");
        equal(Protocol.retryAfter("Sun, 08 Mar 2026 02:30:00 GMT",1772936880),120,"Spring-forward HTTP-date is not a local clock gap");
        equal(Protocol.retryAfter(" 60 ",now),60,"Numeric retry delay is unchanged");
        for(value in [null,"","invalid","-1","1.5","Sun, 01 Nov 2026 24:00:00 GMT",
            "Sun, 01 Bog 2026 00:44:10 GMT","Sun, 31 Nov 2026 00:44:10 GMT"])
            equal(Protocol.retryAfter(value,now),0,"Invalid retry delay: "+value);
    }
}
