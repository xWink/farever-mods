"""Produce the Vortex/manual-install tree for the self-contained HLX mod."""
from pathlib import Path
import shutil

project = Path(__file__).resolve().parents[1]
package = project / "package"
if package.exists():
    shutil.rmtree(package)
module = package / "hlx/mods/dps-meter"
module.mkdir(parents=True)
for source, target in [
    (project / "build/dps-meter/dps-meter.hl", module / "dps-meter.hl"),
    (project / "configFormats.json", module / "configFormats.json"),
    (project / "README.md", module / "README.md"),
]:
    shutil.copy2(source, target)
print("Packaged dps-meter.hl; no executable helper, launcher, DLL, or user config included")
