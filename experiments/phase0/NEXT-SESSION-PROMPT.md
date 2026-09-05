# Prompt for the next Codex session

Continue the World of Warcraft Retail Midnight 12.1 Better Gear Advisor work from the completed research package and Phase 0 evidence in:

```text
C:\projects\BetterGearCompare\docs\research\
C:\projects\BetterGearCompare\experiments\phase0\
```

Do not repeat the repository audit, web research, SimulationCraft experiment, or live fixture collection. Read the existing documents and measured artifacts first, especially:

```text
docs/research/RECOMMENDATION.md
experiments/phase0/PHASE0-VERDICT.md
experiments/phase0/A-upgrade-projection.md
experiments/phase0/B-simc-surrogate.md
experiments/phase0/C-tooltip-lifecycle.md
experiments/phase0/fixtures/upgrade/validation-report.json
experiments/phase0/fixtures/simc/model-benchmark.json
experiments/phase0/fixtures/simc/lua-runtime-benchmark.json
experiments/phase0/fixtures/tooltip/offline-lifecycle-report.json
experiments/phase0/fixtures/tooltip/live-lifecycle-report.json
```

## Established Phase 0 results

### Spike A — upgrade-rank projection: PASS

- Retail client/build: `12.1.0.69587`.
- All 8 mandatory live fixtures pass; no missing categories.
- 15 captured projection rows, representing 11 unique item/future-rank states across four unique current-season items.
- Tested Champion and Hero ordinary armor, neck, ring, and socketed cases.
- Projected item levels and structured vendor stat values matched at every tested future rank.
- A crafted item remained safely unprojected.
- A current Hero 6/6 item returned `currentlyUpgradeable=false` and no projection.
- Old-season item 249982, “Объятия изначального ядра,” had no active manifest track/rank, returned `currentlyUpgradeable=false`, and produced no projection.
- No localized tooltip text was used as the source of truth.

Important live bugs discovered and fixed in the experimental probe:

1. `C_Item.GetItemInventoryType` requires `ItemLocation`; link fallback is `C_Item.GetItemInventoryTypeByID`.
2. Cached item callbacks may run synchronously. Fan-out/pending counts must be initialized before subscriptions, and completion must be idempotent.
3. Lua's `condition and false or nil` collapses false to nil; eligibility must preserve explicit false.
4. Automatic `ShoppingTooltip1/2` callbacks can overwrite the primary hovered item unless source capture distinguishes `GameTooltip`/`ItemRefTooltip` from comparison tooltips.

### Spike B — offline SimulationCraft surrogate: PASS for the narrow hypothesis

- Spec/profile: one Retribution Paladin MID2 single-target archetype.
- Pinned SimulationCraft commit: `aa9de89aac3dd5ead4976db1f091483f462687b4`.
- 720 simulated states; 1,336 held-out item-like comparisons.
- Selected model: compact piecewise-additive response surface with pairwise interaction grids.
- Winner agreement: 99.49% for true differences over 1 percentage point; 98.88% over 0.5 points.
- Zero confident false-positive and false-negative recommendations in the held-out set.
- Deterministic uncertainty half-width: 1.4516 percentage points; the model abstains when the interval does not clear the 0.5-point materiality threshold.
- Generated Lua payload: about 5.2 KB; stock Lua 5.1 runtime about 10.36 microseconds/evaluation.
- Out-of-domain input fails closed.
- This does not validate other specs/builds, weapons, trinkets, special effects, tier changes, or dungeon/AoE profiles.

### Spike C — tooltip lifecycle: accepted PARTIAL

- Keep the evidence verdict as PARTIAL; do not relabel missing evidence as PASS.
- Offline state-machine evidence passes seven explicit regressions and 100,000 randomized transitions.
- Live build 69587 evidence covers:
  - bags;
  - character/equipped items;
  - chat links and `ItemRefTooltip`;
  - comparison tooltips and both `ShoppingTooltip` frames;
  - duplicate suppression;
  - equipment revision/refresh;
  - 46 balanced item load starts/readies;
  - no load failures;
  - no blocked or forbidden protected action.
- The taint log contains only normal attribution from the `SLASH_PHASE0...` globals, not a protected-action blockage.
- A genuinely uncached asynchronous completion and live stale-callback rejection were not observed because all tested item records resolved from cache.

Product decision from the user:

- Leave Spike C as PARTIAL.
- Do not require loot, merchant, or encounter-journal tooltip coverage for V1. These sources are deferred/nonessential.
- Do not spend another session trying to manufacture those sources.
- Treat the uncached/stale live case as a known technical risk covered by the revision/key design and offline stress tests, with a focused integration/regression check required before release—not as a blocker for architecture and implementation planning.

## Objective for the new session

Turn the completed research and Phase 0 evidence into a concrete implementation plan for a clean new addon. Do not migrate or refactor the old BetterGearCompare architecture. Do not reuse PopularSlotsAndChants' Archon/population-average approach.

First reconcile the product decision above with `PHASE0-VERDICT.md` while preserving factual evidence labels. Then propose the exact V1 implementation plan, including:

1. final V1 scope and explicit exclusions;
2. new project name/location and complete file layout;
3. production module boundaries and dependency direction;
4. domain data structures and public interfaces;
5. exact item-resolution and async state machine;
6. equipment-state comparison rules, including both ring slots;
7. current-season upgrade projection and active-manifest validation;
8. generated SimC model registry, domain checks, provenance, and confidence/abstention policy;
9. special/tier/trinket/weapon fail-closed classification;
10. tooltip presentation for the Blizzard default UI only;
11. offline build-time generation pipeline and release gates;
12. pure-Lua tests, live integration tests, fixtures, and regression cases for every bug found in Phase 0;
13. patch/season update procedure;
14. staged implementation sequence with acceptance criteria for each stage.

The smallest intended V1 should remain conservative:

- one supported Retribution Paladin single-target build archetype initially;
- ordinary stat-only armor, cloak, neck, and rings;
- compare valid complete equipment states, including both ring replacement alternatives;
- current and future legal ranks only when the item exactly matches the active build manifest and passes eligibility checks;
- `upgrade`, `downgrade`, `too_close`, `special`, `unsupported`, and `pending` outcomes with reason codes and provenance;
- default Blizzard tooltips for bags, equipped/character items, chat links, and comparison tooltips;
- no runtime network service;
- no Archon scraping or average-player stat weights;
- no weapons, trinkets/procs, tier-breakpoint changes, embellishments, crafted projections, hypothetical gem advice, dungeon/AoE profiles, or unsupported specs in initial V1.

Do not claim that a model score is a universal DPS prediction. Do not display directional advice when uncertainty overlaps the materiality boundary. Do not allow a stale item callback to mutate a newer tooltip. Do not infer current eligibility from a historical-looking bonus ID alone.

Produce an implementation-plan document in the repository, but do not implement production addon code until the user reviews and explicitly approves the plan.

