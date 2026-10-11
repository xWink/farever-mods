# Ready Check GO

`ready-check-go.ogg` is the user's selected `BoomSound.m4a` (provided October 11,
2026), transcoded to Ogg Vorbis for the game's native sound loader. It retains
the original stereo channels, sample rate, and volume; no trimming or gain
adjustment was applied. The implementation embeds it through `compile.hxml`.

Conversion:

```sh
ffmpeg -i BoomSound.m4a -map_metadata -1 -c:a libvorbis -q:a 6 ready-check-go.ogg
```
