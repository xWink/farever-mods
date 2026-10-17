# Ready Check audio

These assets were supplied by the user on October 11, 2026 and converted to Ogg Vorbis for the game's decoder:

- `ready-check-go.ogg`: `BoomSound.m4a`, preserving the original stereo channels, sample rate, and gain. Playback applies 0.8 gain in addition to the game's master/UI volume.
- `ready-check-countdown.ogg`: the corrected `CountDown(1).m4a`, preserving 48 kHz stereo and gain. The recording contains one-second segments from 5 down to 1.

Both are embedded through `compile.hxml` and played through the bundled desktop plugin.

## Conversion

```sh
ffmpeg -i BoomSound.m4a -map_metadata -1 -c:a libvorbis -q:a 6 ready-check-go.ogg
ffmpeg -i 'CountDown(1).m4a' -map 0:a:0 -c:a libvorbis -q:a 6 -map_metadata -1 ready-check-countdown.ogg
```
