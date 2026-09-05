# Engineering recommendation

## Decision

This addon is technically worth building, but only as a deliberately bounded, evidence-aware advisor. It should not attempt to assign a confident number to every item. Its differentiator should be that it answers ordinary cases clearly, evaluates complete legal equipment states, and says exactly why a complex case is unavailable.

Build it as a new addon architecture. Do not refactor the current `BetterGearCompare` implementation into the product core.

## What can be evaluated reliably

With exact loaded item data, a pinned current-season manifest, and a validated per-spec/profile model, the addon can reliably evaluate:

- ordinary armor and jewelry whose performance-relevant behavior is represented by primary/secondary stats;
- sockets, gems, and enchants under an explicit symmetric normalization policy;
- both legal replacement choices for rings;
- current versus verified future ranks on the active ordinary upgrade track;
- the first rank that clears a declared materiality and uncertainty threshold;
- current exact crafted items when no hypothetical recraft is implied;
- complete weapon configurations once spec weapon models and bag-companion enumeration have independently passed validation.

These are not item-versus-item comparisons. The evaluator scores the current equipped state against every supported legal successor state and reports the exact removed item(s) and companion item.

## What should intentionally remain unsupported

Do not display an overall upgrade percentage for:

- unknown proc or on-use trinkets;
- unmodeled special-effect weapons, rings, embellishments, or other scripted items;
- a tier change that activates or breaks a set bonus without a validated interaction model;
- a one-handed candidate against a two-hander when no legal companion item is in the declared inventory scope;
- a spec, talent archetype, encounter profile, or stat region outside the model's capability record;
- legacy, Timewalking, heirloom, PvP-context, post-track, or hypothetical crafted-quality behavior that has not been separately verified;
- healer or tank choices reduced to a single DPS-style percentage.

The correct user-facing answer is “unable to evaluate this special effect/configuration reliably,” plus the reason and, where useful, a clearly labeled visible-stats-only comparison that is not presented as an upgrade verdict.

## Source of truth

Use two complementary sources of truth:

1. **Structured Blizzard client APIs and a build-verified season manifest** for the exact item instance, stats, slot/weapon facts, uniqueness, current eligibility, item level, sockets, effects evidence, and upgrade-rank projection.
2. **Pinned offline SimulationCraft generation** for performance response models by specialization, supported talent archetype, and encounter profile.

SimulationCraft should run during the build/data pipeline, never inside WoW. The preferred compact surrogate is a bounded piecewise-additive model over primary stat, total secondary budget, and secondary distribution, with only validated pair interactions. Benchmark it against interpolation and polynomial alternatives; ship it only if held-out pairwise upgrade errors meet published gates. Local SimulationCraft scale factors remain useful diagnostics, not global item weights.

For recognized special items, use a separate generated effect catalog with per-spec/profile item-level knots, uncertainty, and pairing rules. Do not feed proc text through ordinary stat weights.

Average high-ranking-player stat distributions must not be used as weights. They describe what selected players currently possess after loot availability, item level, encounter, build, and gearing constraints. They do not estimate the marginal performance gained from adding one point of a stat to this character.

## BetterGearCompare disposition

Replace the runtime code rather than refactor it.

The prototype contains useful product discoveries—current/max comparisons, keep thresholds, dual-slot concerns, and the need for tooltip visibility—but its implementation couples UI, asynchronous data access, heuristic link manipulation, scoring, and third-party bag presentation. Its current shortcuts include zero/nil item-data behavior, permanent per-tooltip annotation state, hard-coded season bonus IDs, arbitrary trinket tiers, limited class rules, and invalid one-hand weapon doubling. Preserving those boundaries would make correctness harder to prove than a clean implementation.

Retain only reviewed requirements, anonymized real-item fixtures, and regression cases. No third-party bag addon belongs in the core dependency graph.

## PopularSlotsAndChants disposition

Remove it from the gear-value path and retire the BetterGearCompare weight export. Its Archon acquisition is based on browser impersonation and private page payloads rather than a documented redistribution API, and converting observed average stat totals to weights is conceptually invalid.

There are two defensible futures:

- archive it after preserving any independent UI ideas; or
- keep it as a clearly labeled descriptive “popular choices” product backed only by a licensed/documented source, with provenance, sample/context filters, and no claim that popularity equals performance.

It should not be required by the new advisor. Blizzard APIs provide character/item facts; SimulationCraft provides reproducible modeled performance. Warcraft Logs or Raider.IO can support separate research under their official APIs/terms, but population observations are validation/context, not the scoring source of truth.

## Smallest useful V1

Ship a limited-spec technical preview with:

- Blizzard-default tooltip integration using `TooltipDataProcessor`;
- safe asynchronous exact-item loading and refresh;
- ordinary non-weapon, non-trinket armor/jewelry comparison, including both ring slots;
- current Midnight 12.1 track verification and current-to-max/all-ranks projection;
- roughly three to five validated DPS specs, each with labeled single-target and dungeon profiles;
- “now,” “at max,” “becomes an upgrade at,” and conservative keep/no-modeled-upgrade actions;
- deterministic high/medium/too-close/special/unsupported evidence states;
- an on-demand details view with the chosen replacement, rank table, uncertainty, model/profile, and data versions;
- pure Lua tests, real-link fixtures, model validation, and patch/season circuit breakers;
- no runtime network or required addon dependency.

Add weapons in V1.5 after complete configuration enumeration and weapon-sensitive models pass tests. Add only curated recognized special effects in V2.

## Largest technical risks

1. **Rank projection stability.** Blizzard exposes current upgrade information well, but not a documented general “give me this exact item at arbitrary future rank” API. Full-link rank-bonus substitution must be pinned, verified by observed item level, and disabled on mismatch.
2. **Asynchronous item identity.** Item data can be unavailable initially, and the tooltip or equipment state can change before it arrives. Canonical full-link keys, revisions, cancellation, and refresh idempotence are mandatory.
3. **Model maintenance.** Class tuning, talents, APLs, profiles, stat rules, and items change. Every shipped model needs provenance, domain limits, held-out validation, and an explicit invalidation/update process.
4. **Weapon-state legality.** A single candidate can imply several paired states. Unknown handedness/spec/unique rules must fail closed; a one-hander can never be evaluated by doubling it.
5. **Special-effect interactions.** Trinket pairing, cooldown alignment, sets, and encounter timing can defeat additive estimates. Coverage must be curated and uncertainty visible.
6. **False precision.** Small modeled deltas are often below approximation and profile uncertainty. The UI must reserve “upgrade” for intervals that clear a materiality threshold.
7. **Patch and source governance.** Stale season constants and unofficial scraping can silently poison results. Generated data needs reproducible provenance, legal review, schema/build guards, and an update owner.

## Final recommendation

Proceed with Phase 0 validation spikes and a clean V1, subject to three go/no-go results: verified arbitrary-rank snapshots on the target client, a pilot SimulationCraft surrogate that passes pairwise error gates, and stale-safe default-UI tooltip refresh. If any fails, narrow coverage rather than introduce tooltip parsing, population-derived weights, or heuristic scores.

The winning product is not the addon that always gives an answer. It is the addon whose answer a normal player can understand and trust.

## Research package

- [Existing codebase review](01-existing-codebase-review.md)
- [WoW item and upgrade system](02-wow-item-and-upgrade-system.md)
- [Gear evaluation model](03-gear-evaluation-model.md)
- [Weapons and equipment states](04-weapons-and-equipment-states.md)
- [Trinkets and special effects](05-trinkets-and-special-effects.md)
- [Data sources](06-data-sources.md)
- [Product and UX](07-product-and-ux.md)
- [Proposed architecture](08-proposed-architecture.md)
- [Test plan](09-test-plan.md)
- [Roadmap](10-roadmap.md)

