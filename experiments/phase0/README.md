# Better Gear Advisor Phase 0

This directory contains isolated validation spikes for the architecture proposed in [`docs/research/RECOMMENDATION.md`](../../docs/research/RECOMMENDATION.md). Nothing here is loaded by `BetterGearCompare.toc` or changes production addon behavior.

## Evidence states

- `PASS`: the stated gate was exercised on the required environment and all criteria passed.
- `PARTIAL`: executable evidence supports part of the assumption, but a required environment or representative fixture is missing.
- `FAIL`: measured evidence contradicts the assumption or violates a gate.

The Retail client was later located at a non-standard installation path and live 12.1.0.69587 sessions produced upgrade and tooltip fixtures. Spike A now passes every required current-season, crafted, max-rank-ineligible, and old-season category. Spike C covers bags, character/equipment, chat links, comparison tooltips, equipment refresh, and a clean protected-action result; live uncached/stale callbacks and three optional sources remain missing.

## Layout

```text
phase0/
  addons/
    Phase0UpgradeProbe/       exact-item/rank diagnostic addon
    Phase0TooltipProbe/       default-tooltip lifecycle diagnostic addon
  fixtures/
    upgrade/                  generated manifest and imported client captures
    simc/                     sampled states, SimC output, splits, model reports
    tooltip/                  offline lifecycle stress report and client captures
  tools/
    upgrade/                  manifest and fixture validators
    simc/                     dataset, simulation, fitting, and Lua export
    tooltip/                  lifecycle state-machine stress harness
  A-upgrade-projection.md
  B-simc-surrogate.md
  C-tooltip-lifecycle.md
  PHASE0-VERDICT.md
```

## Reproduction

Use the bundled Python runtime or Python 3.10+ with NumPy. No web scraper is used.

```powershell
$python = 'C:\Users\timur\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'

& $python experiments\phase0\tools\upgrade\fetch_manifest.py
& $python experiments\phase0\tools\upgrade\validate_fixtures.py

& $python experiments\phase0\tools\simc\generate_samples.py
& $python experiments\phase0\tools\simc\run_simc.py --simc D:\codex-phase0-simc-build-clang\simc.exe --simc-source D:\codex-phase0-simc-src --train-iterations 400 --test-iterations 2000 --max-time 300 --vary-combat-length 0.2
& $python experiments\phase0\tools\simc\benchmark_models.py
& $python experiments\phase0\tools\simc\verify_lua_payload.py --lua D:\codex-phase0-lua-5.1.5\src\lua

& $python experiments\phase0\tools\tooltip\stress_lifecycle.py
```

The SimulationCraft source is pinned by [`simc.lock.json`](tools/simc/simc.lock.json). `run_simc.py` refuses a different commit/build unless the lock is deliberately updated.

## Live client capture

Copy each probe directory under `World of Warcraft/_retail_/Interface/AddOns`, enable only Blizzard UI plus the probe, and follow the command checklist in the corresponding report. SavedVariables are written to:

```text
WTF/Account/<account>/SavedVariables/Phase0UpgradeProbe.lua
WTF/Account/<account>/SavedVariables/Phase0TooltipProbe.lua
```

Copy those files into the relevant fixture directory and run the validator. Do not replace missing evidence with hand-authored “successful” fixtures.
