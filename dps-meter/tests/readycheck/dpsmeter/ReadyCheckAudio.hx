package dpsmeter;

/** Keep controller tests focused on party/chat timing, without an audio device. */
class ReadyCheckAudio {
    public static var voices:Array<Int> = [];
    public function new() {}
    public function prepare(voiceover:Bool = true, effects:Bool = true):Void {}
    public function update(muteVoice:Bool, muteEffects:Bool):Void {}
    public function dispose():Void {}
    public function playCountdown(index:Int):Void {
        if (GameAccess.failAudio) throw "Simulated voiceover failure";
        voices.push(index);
    }
    public function playGo():Void {
        if (GameAccess.failAudio) throw "Simulated GO audio failure";
        GameAccess.sounds.push({event:"ready-check-go", source:null, params:null});
    }
}
