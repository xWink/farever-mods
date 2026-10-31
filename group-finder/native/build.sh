#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/native
x86_64-w64-mingw32-g++ -std=c++17 -O2 -Wall -Wextra -Werror -shared -static -static-libgcc -static-libstdc++ native/desktop.cpp -o build/native/group_finder_desktop.hdll -lole32 -lshell32 -lbcrypt -ladvapi32
x86_64-w64-mingw32-objdump -p build/native/group_finder_desktop.hdll > build/native/exports.txt
for primitive in hlp_secure_random hlp_write_credential hlp_open_url; do
  grep -q "$primitive" build/native/exports.txt
done
