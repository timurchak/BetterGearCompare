from __future__ import annotations

from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[2]
ADDON = ROOT / "BetterGearAdvisor"
TOC = ADDON / "BetterGearAdvisor.toc"


def fail(message: str) -> None:
    print(f"FAIL {message}")
    raise SystemExit(1)


def lua_files() -> list[Path]:
    return sorted(ADDON.rglob("*.lua"))


if not TOC.is_file():
    fail("missing BetterGearAdvisor.toc")

toc_lines = [line.strip() for line in TOC.read_text(encoding="utf-8-sig").splitlines()]
loaded = [line for line in toc_lines if line and not line.startswith("##")]
if len(loaded) != len(set(loaded)):
    fail("TOC contains duplicate load entries")

for relative in loaded:
    if not (ADDON / Path(relative.replace("\\", "/"))).is_file():
        fail(f"TOC entry does not exist: {relative}")

loaded_paths = {Path(relative.replace("\\", "/")).as_posix() for relative in loaded}
source_paths = {path.relative_to(ADDON).as_posix() for path in lua_files()}
if loaded_paths != source_paths:
    fail(f"TOC/source allowlist mismatch: missing={sorted(source_paths - loaded_paths)}, extra={sorted(loaded_paths - source_paths)}")

all_source = "\n".join(path.read_text(encoding="utf-8-sig") for path in lua_files())
for forbidden in ("BetterGearCompare", "Baganator", "Syndicator", "PopularSlotsAndChants", "Archon", "Wowhead"):
    if forbidden in all_source:
        fail(f"new addon references forbidden legacy/external source: {forbidden}")

domain_source = "\n".join(
    path.read_text(encoding="utf-8-sig") for path in sorted((ADDON / "Domain").glob("*.lua"))
)
for forbidden in ("C_Item", "C_Container", "GameTooltip", "TooltipDataProcessor", "CreateFrame", "RegisterEvent"):
    if re.search(rf"\b{re.escape(forbidden)}\b", domain_source):
        fail(f"Domain references Blizzard/UI API: {forbidden}")

if all_source.count("TooltipDataProcessor.AddTooltipPostCall") != 1:
    fail("production addon must contain exactly one TooltipDataProcessor item post-call registration")

saved_variable_lines = [line for line in toc_lines if line.startswith("## SavedVariables")]
if saved_variable_lines != ["## SavedVariables: BetterGearAdvisorDB"]:
    fail("unexpected SavedVariables declaration")

print(f"PASS boundary check: {len(lua_files())} Lua files, {len(loaded)} TOC entries")
sys.exit(0)
