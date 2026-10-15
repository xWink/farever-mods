#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/native
x86_64-w64-mingw32-g++ -std=c++17 -O2 -Wall -Wextra -Werror -shared -static \
  -static-libgcc -static-libstdc++ native/desktop.cpp \
  -o build/native/dps_meter_desktop.hdll -lole32 -lshell32 -luuid -luser32 -lbcrypt -ladvapi32
x86_64-w64-mingw32-objdump -p build/native/dps_meter_desktop.hdll > build/native/exports.txt
for primitive in hlp_open_folder hlp_recycle_file hlp_copy_image hlp_prepare_audio hlp_play_audio hlp_update_audio hlp_stop_audio hlp_dispose_audio hlp_secure_random hlp_write_credential; do
  grep -q "$primitive" build/native/exports.txt
done
