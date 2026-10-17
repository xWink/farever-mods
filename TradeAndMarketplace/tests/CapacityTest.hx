import trade.TradeCapacity;
class CapacityTest {
    static var checks = 0;
    static function check(b:Bool, message:String):Void { checks++; if (!b) throw message; }
    static function s(item:String,count:Int,max=99):CapacityStack return {item:item,count:count,max:max};
    static function fits(own:Array<CapacityStack>,incoming:Array<CapacityStack>,free:Int):Bool
        return TradeCapacity.fits(own,incoming,free,(a,b)->a==b);
    static function main() {
        check(fits([s("ore",90)],[s("ore",9)],0),"Existing stack exact fit");
        check(!fits([s("ore",90)],[s("ore",10)],0),"Existing stack overflow");
        check(fits([s("ore",90)],[s("ore",10)],1),"Overflow uses a free slot");
        check(!fits([s("ore",90)],[s("ore",6),s("ore",4)],0),"Two offers cannot reuse the same space");
        check(fits([],[s("ore",50),s("ore",49)],1),"Two incoming stacks share a newly allocated slot");
        check(!fits([],[s("ore",50),s("ore",50)],1),"Newly allocated stack overflow rejected");
        check(!fits([s("ore-bound",1)],[s("ore",1)],0),"Different native item identity does not merge");
        check(!fits([],[s("sword",1,1),s("sword",1,1)],1),"Equipment needs separate slots");
        check(fits([s("ore",90),s("ore",90)],[s("ore",18)],0),"Multiple existing stacks contribute capacity");
        var own = [s("ore",90)]; fits(own,[s("ore",9)],0);
        check(own[0].count == 90,"Capacity simulation never changes inventory");
        check(fits([],[s("ore",200)],3) && !fits([],[s("ore",200)],2),"Large counts respect stack limits");
        check(fits([s("ore",99)],[],0),"No incoming items need no space");
        Sys.println("Capacity checks passed: "+checks);
    }
}
