package dpsmeter;

/** Keep controller tests focused on party/chat timing, without an audio device. */
class ReadyCheckAudio {
    public function new() {}
    public function prepare():Void {}
    public function update(muted:Bool):Void {}
    public function dispose():Void {}
    public function playGo():Void {
        if (GameAccess.failAudio) throw "Simulated GO audio failure";
        GameAccess.sounds.push({event:"ready-check-go", source:null, params:null});
    }
}
