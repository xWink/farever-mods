package trade;

typedef CapacityStack = {item:Dynamic, count:Int, max:Int};

/** Simulates receipt without changing native inventories or counting the same space twice. */
class TradeCapacity {
    public static function fits(existing:Array<CapacityStack>, incoming:Array<CapacityStack>, free:Int,
        matches:Dynamic->Dynamic->Bool):Bool {
        var slots = [for (s in existing) {item:s.item, count:s.count, max:s.max}];
        for (offer in incoming) {
            var remaining = offer.count;
            for (slot in slots) {
                if (remaining <= 0) break;
                if (slot.count >= slot.max || slot.item == null || offer.item == null || !matches(slot.item,offer.item)) continue;
                var take = Std.int(Math.min(remaining,slot.max-slot.count));
                slot.count += take; remaining -= take;
            }
            if (remaining > 0) {
                if (offer.max <= 0) return false;
                var needed = Math.ceil(remaining/offer.max);
                if (needed > free) return false;
                free -= needed;
                // Only the last newly allocated stack can have spare capacity.
                var last = remaining%offer.max;
                slots.push({item:offer.item,count:last == 0 ? offer.max : last,max:offer.max});
            }
        }
        return true;
    }
}
