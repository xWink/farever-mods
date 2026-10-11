# Ready Check GO

`ready-check-go.ogg` is the user's selected `BoomSound.m4a` (provided October 11,
2026), transcoded to Ogg Vorbis for the game's native decoder. It retains
the original stereo channels, sample rate, and volume; no trimming or gain
adjustment was applied. The implementation embeds it through `compile.hxml`,
decodes to PCM16, and plays through the desktop plugin's XAudio2 voice. The game's
Heaps audio output is compiled as a no-op; only its Ogg decoder is used.
Playback applies a 0.8 gain to the boom in addition to the game's master/UI
volume, including live volume updates.

Conversion:

```sh
ffmpeg -i BoomSound.m4a -map_metadata -1 -c:a libvorbis -q:a 6 ready-check-go.ogg
```

# Countdown voiceover

`ready-check-countdown.ogg` is the user's `CountDown.m4a` (provided October 11,
2026), converted at its original 48 kHz stereo rate without changing gain.
It is embedded alongside the boom. Each spoken number occupies one second of
the recording (5 at 0–1 s, 4 at 1–2 s, down to 1 at 4 s through the end).
The runtime decodes once and slices at those boundaries, all of which fall
inside the recording's pauses. It plays each slice on the matching ordered
leader chat echo, so a stalled countdown does not leave the voice ahead of chat.

```sh
ffmpeg -i CountDown.m4a -map 0:a:0 -c:a libvorbis -q:a 6 -map_metadata -1 ready-check-countdown.ogg
```
