"""Produce the Vortex/manual-install tree; never run or contact the uploader."""
import hashlib
from pathlib import Path
import shutil

project = Path(__file__).resolve().parents[1]
binary = project / "vendor/uploader.exe"
expected = "a43f20e5e7014d7a6d18952a60b89515bd87c30fe99420cac1d753d7b8b03b33"
if hashlib.sha256(binary.read_bytes()).hexdigest() != expected:
    raise SystemExit("The original uploader.exe hash does not match")
package = project / "package"
if package.exists():
    shutil.rmtree(package)
module = package / "hlx/mods/dps-meter"
module.mkdir(parents=True)
for source, target in [
    (project / "build/dps-meter/dps-meter.hl", module / "dps-meter.hl"),
    (project / "configFormats.json", module / "configFormats.json"),
    (project / "tools/start-uploader.ps1", module / "start-uploader.ps1"),
    (project / "README.md", module / "README.md"),
    (project / "vendor/README.md", module / "UPLOADER-NOTICE.md"),
    (binary, module / "uploader.exe"),
]:
    shutil.copy2(source, target)
print("Packaged dps-meter.hl and the verified original uploader; no DLL or user config included")
