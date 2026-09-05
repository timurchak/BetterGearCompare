# Product and user experience

## Product promise

Answer one question in plain language: **what happens to my supported, legal equipped state if I use this item now or after verified upgrades?**

The tooltip is a summary of evidence, not a calculator dump. It must identify ambiguity instead of manufacturing an answer.

## Headline result model

Every evaluation returns separate dimensions:

- **direction:** upgrade, downgrade, close, or unknown;
- **modeled delta:** relative performance change, when supported;
- **uncertainty:** model/coverage bound in percentage points;
- **confidence class:** high, medium, special, or unavailable;
- **action:** equip, keep for upgrades, no modeled need for this spec, or simulate/review;
- **reason codes:** short machine-stable reasons used for details/diagnostics.

Color must not carry meaning alone. Use arrows/words and accessible colors:

- green + `▲ Upgrade` for a high-confidence positive result;
- red + `▼ Worse` for a high-confidence negative result;
- yellow + `≈ Probably/Too close` for medium or close results;
- purple + `◆ Special effect` for the dedicated special path;
- gray + `? Unable to evaluate` for missing/unsupported data.

## Quantitative confidence policy

For a supported numeric comparison, let:

- `D` = predicted relative difference in percentage points;
- `U` = packaged validation P95 plus deterministic runtime penalties;
- interval = `[D - U, D + U]`;
- `M = 0.5` percentage points, the initial materiality floor.

The 0.5-point floor is a product threshold, not a claim about human perceptibility. It must be configurable in research builds and revisited from user testing/model error.

### High confidence

All deterministic gates pass:

- ordinary stat-only item/state;
- exact supported spec, talent archetype, and profile;
- all item data resolved from structured APIs;
- legal state and unique/set constraints verified;
- future link/item level verified when projected;
- point inside the validated model domain;
- no unknown stat/effect key;
- `U <= 0.5`;
- interval is materially positive (`D - U >= M`) or negative (`D + U <= -M`).

### Medium confidence

The comparison is still numeric and validated, but one declared factor caps confidence—for example a complete one-hand/off-hand transition, a supported special-effect curve, proximity to a model-domain edge, or nearest supported build archetype. Require `U <= 1.0` and an interval that excludes zero for directional wording.

Display `Probably better/worse`, never the same headline as high confidence.

### Close / ambiguous

Use `Too close to call` when the uncertainty interval crosses zero or the interval does not clear the materiality floor. An estimated `+0.3%` is not an upgrade recommendation just because its center is positive.

### Special

Any detected proc/on-use/cantrip/embellishment or set-threshold change enters the purple special path. A fully supported special model may show a medium-confidence number. An unsupported effect shows no overall percentage; an optional visible-stats-only number is explicitly subordinate.

### Unavailable

Missing item data, stale model/season manifests, invalid configurations, unsupported role/profile, or failed projection produce a gray typed explanation. No zero score is displayed.

## Core tooltip examples

### Ordinary future upgrade

```text
BETTER GEAR ADVISOR
Hero 1/6  •  item level 305

NOW          ▼ 1.7% worse
AT 6/6      ▲ 3.4% upgrade
KEEP — upgrade at Hero 4/6

Replaces: [current chest]
Shift: all ranks   Alt: why
```

“At 6/6” compares the candidate at 6/6 with the current worn state **as currently worn**. If the current item is also upgradeable, details may separately show “both at their maximum” so the two questions cannot be confused.

### All ranks (Shift)

```text
Hero 1/6 (305)   -3.4%
Hero 2/6 (308)   -2.0%
Hero 3/6 (311)   -0.8%  ≈
Hero 4/6 (315)   +0.5%  probably
Hero 5/6 (318)   +1.8%
Hero 6/6 (321)   +3.2%

First confirmed upgrade: Hero 5/6
```

The center estimate first becomes positive at 4/6, but if its uncertainty interval does not clear the materiality floor, the first **confirmed** upgrade can be 5/6. The UI may say “possibly at 4/6; confirmed by 5/6” rather than conceal the uncertainty.

Evaluate every real rank independently. Do not assume monotonicity or binary-search it; rounding and future special models can violate a simple slope.

### Ring

```text
▲ 1.2% upgrade
Best replacement: [lower-value current ring]
Other ring retained: [higher-value current ring]
```

If both legal replacements are tied within uncertainty:

```text
≈ Either ring slot is effectively tied
```

### One hand versus current two hand

```text
≈ Probably better +0.8%
Using: new one-hand + [shield from bags]
Versus: [current two-hand]
Medium confidence — weapon configuration change
```

With no companion:

```text
? Needs a compatible off-hand
No valid one-hand setup found in your bags
```

### Unsupported trinket

```text
◆ Special effect — not reliably evaluated
Visible stats alone: +1.1% (not a recommendation)
KEEP until simulated
```

### Set breakpoint

```text
◆ Equipping this breaks your 4-piece set bonus
Overall value not evaluated
Simulation recommended
```

### Item data still loading

Do not briefly show a wrong downgrade. Either show no addon lines until ready or one muted line:

```text
Better Gear Advisor: loading item data…
```

When data arrives, refresh only if the tooltip still displays the same exact item key.

## KEEP and “worth keeping” semantics

The action is scoped to the current supported spec/archetype/profile:

- `EQUIP` when the current-rank state is a confirmed upgrade;
- `KEEP — upgrade at X` when a later verified rank is a confirmed upgrade;
- `KEEP — too close` when uncertainty prevents a discard conclusion;
- `KEEP — special/unsupported` when a missing effect or state could reverse the result;
- `NO MODELED UPGRADE FOR THIS SPEC` only when every reachable verified rank is a high-confidence material downgrade and every legal replacement state was considered.

Do not say `VENDOR`, `DESTROY`, or globally `DISCARD`. The item can matter for off-spec, PvP, transmog, trading, collection, or a future build. The addon answers gear performance for a declared context, not every reason to own an item.

## Comparing an already-upgraded worn item

Default baseline is the exact current worn state. The details panel can offer two clearly named questions:

1. **Candidate investment:** each candidate rank versus what is worn now.
2. **Ceiling comparison:** candidate maximum versus current item's reachable maximum, only when both projection paths are verified.

A later upgrade planner can compare spend paths rank by rank. The tooltip must not silently max both sides.

## Progressive disclosure

### Default tooltip (target: 4–7 lines)

- addon label and candidate rank;
- NOW result;
- maximum verified result when meaningful;
- keep/equip/unknown action and threshold;
- replacement/companion only for multi-slot states;
- one short special/error reason.

### Shift

- every verified rank with item level and rounded delta;
- first possible and first confirmed upgrade;
- nominal crest count only when clearly labeled.

### Alt

- confidence class and uncertainty;
- spec/archetype/profile used;
- exact replaced/retained items;
- enhancement normalization policy;
- warning/reason codes;
- model/season build age.

### Secondary panel

Use an optional panel for alternative legal states, both-at-max comparisons, full provenance, debugging, and later resource planning. Do not turn the ordinary hover into a miniature spreadsheet.

## Upgrade-cost efficiency

“Expected gain per crest” sounds useful but is easy to misstate:

- each normal step nominally costs 20 matching Mistcrests in Season 2;
- character/Warband high-watermarks can change the actual cost;
- gold and seasonal rules also apply;
- true opportunity cost depends on every other possible slot upgrade, not just this item.

V1 should show no `Poor upgrade value` judgment. Shift details may show `40 Hero Mistcrests nominal (2 ranks)` when using the verified season manifest, with a warning that discounts are not included. When the item is actually selected in Blizzard's upgrade UI, a later adapter may use `C_ItemUpgrade.GetItemUpgradeItemInfo().upgradeLevelInfos` for exact displayed costs.

A real efficiency feature belongs in a planner that compares marginal gain/cost across all eligible item-rank actions:

```text
efficiency(action) = lower-confidence-bound gain / actual incremental cost
```

Even then, label currency types separately; 20 Champion and 20 Myth Mistcrests are not interchangeable.

## Profile selection

Default to the active supported specialization and exact archetype when recognized. Profile selector options are plain language:

- Single target / raid boss
- Dungeon / mixed targets

Show the active choice in Alt details. Do not automatically infer the user's preferred content from location or recent play. Unsupported healer/tank objectives show an explanation and may offer a damage-only profile only if the user explicitly selects it.

## Enhancement policy

Default: compare gear with replaceable enchants normalized and sockets filled by the profile's declared standard gem. Show `Normalized gems/enchants` in details. Offer `As equipped` as an advanced alternative, never silently switch policies between hovers.

## Tooltip behavior requirements

- default Blizzard item tooltips work with no other addon installed;
- repeated refresh is idempotent and adds one block;
- item changes/hide cancel stale work;
- no item pickup/equip/vendor manipulation;
- no protected actions or combat decision support;
- numeric output is rounded to one decimal percentage point;
- every medium/special/unsupported result has a visible reason;
- localization changes display text only, never parsing/classification;
- third-party tooltip support is an optional adapter after core stability.

## Diagnostics without user overload

An opt-in `/bga debug` export should include item key/link, structured fields, data/model/season versions, state revision, considered configurations, rejected-state reasons, projected-link validation, raw delta/uncertainty, and presenter decision. Redact character identity unless the user explicitly includes it.

The normal tooltip should never expose internal bonus IDs, coefficient arrays, or stack traces.
