"""Build the pinned HashLink fmt ZLIB section for isolated item-link tests.

This is upstream native compression code, without unrelated image/audio SDKs.
It is never packaged: Farever already ships these fmt primitives.
"""
from pathlib import Path
import re
import subprocess
import sys

runtime = Path(sys.argv[1]).resolve()
source = (runtime / "libs/fmt/fmt.c").read_text()
section = re.search(r"/\* -+ ZLIB -+ \*/(.*?)/\* -+ SOUND : OGG -+ \*/", source, re.S)
if section is None:
    raise SystemExit("Pinned HashLink fmt ZLIB section not found")
target = runtime / "item-link-fmt.c"
target.write_text('#define HL_NAME(n) fmt_##n\n#include <hl.h>\n#include <zlib.h>\n' + section[1])
subprocess.run(["cc", "-shared", "-fPIC", "-I", str(runtime / "src"), str(target),
                "-L", str(runtime), "-lhl", "-lz", "-o", str(runtime / "fmt.hdll")], check=True)
