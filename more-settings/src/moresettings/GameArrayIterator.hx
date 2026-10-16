package moresettings;

/** Reads ArrayObj/ArrayDyn through their native reader, with one argument buffer per traversal. */
class GameArrayIterator {
    public static final empty:Iterator<Dynamic> = new GameArrayIterator(null, 0, null);
    var value:Dynamic;
    var limit:Int;
    var index:Int = 0;
    var read:Array<Dynamic>->Dynamic;
    var args:Array<Dynamic>;

    public function new(value:Dynamic, limit:Int, read:Array<Dynamic>->Dynamic) {
        this.value = value;
        this.limit = limit;
        this.read = read;
        if (limit > 0) args = [value, 0];
    }

    // A game array can shrink between frames. Appends wait for the next sweep,
    // so a growing scene cannot make a discovery pass run indefinitely.
    public function hasNext():Bool
        return index < limit && index < GameAccess.integer(GameAccess.field(value, "length"));

    public function next():Dynamic {
        args[1] = index++;
        return read(args);
    }
}
