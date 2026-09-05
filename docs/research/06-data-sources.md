# Data sources, legality, and maintainability

Research snapshot: 2026-09-05. This is an engineering risk assessment, not legal advice. Terms and permissions must be reviewed again before distribution.

## Decision summary

The advisor's runtime source of item/player truth should be Blizzard's in-game API. Its build-time performance source should be a pinned local SimulationCraft build plus minimally derived, versioned client-data manifests. No runtime web service is required.

Website popularity data is optional product content and must be isolated from valuation. Archon/Wowhead page scraping should be removed from required builds. Where a service offers an official API, use only that API under its terms; where redistribution rights are unclear, obtain written permission or do not embed the result.

## Source matrix

| Source | What it can provide | Official/supported access | Rate/availability | Redistribution/build-time position | Recommendation |
|---|---|---|---|---|---|
| Blizzard in-game Lua API | Exact possessed links/locations, stats, item levels, upgrade metadata/eligibility, structured tooltip lines, spec/talents, inventory | Yes, inside WoW's addon sandbox | No web quota; asynchronous cache and API restrictions apply | Addon reads at runtime; package only minimal generated manifests | Primary runtime source |
| Blizzard Battle.net web API | Game-data records, media, character profile/equipment subject to scopes | Official OAuth API and developer portal | Quotas/headers and terms apply; network unavailable to Lua addon | Build service only if necessary; credentials never in addon | Supplemental, not needed for V1 runtime |
| WoW client data via reproducible extractors | Bonus trees, upgrade groups, curves, spells/effects, item records | Data ships in client; extraction tooling is third party | Build-pinned; hotfix/cache coverage matters | Redistribute only minimal derived facts after license review | Primary season-manifest input |
| SimulationCraft | Spec mechanics/APLs, item effects, deterministic simulations, client-data extraction | Open-source local executable/project | Local compute; no service rate limit | Prefer executing pinned build; record commit/config; review licenses for copied code/data | Performance source of truth |
| Raidbots | Cloud SimC UI; versioned static game-data JSON; public report files | Developer page explicitly publishes static/report files; no documented public sim-submission API | Cache static files; service provides no accuracy warranty | Good bootstrap/cross-check; permission/license review before redistributing substantial data | Do not depend on runtime; local SimC preferred |
| Warcraft Logs | Logged combat/rankings/report data | Official OAuth 2.0 GraphQL API | Point budget per API key/hour, queryable via `rateLimitData` | Build-time aggregate research only under terms/permission | Optional archetype/meta research, never stat weights |
| Raider.IO | Character/M+/raid profile and progression data | Public developer API | Public fixed quota was not found in reviewed docs; honor API limits/headers | Terms permit automation through public API, not page scraping; redistribution needs review | Not useful for gear valuation |
| Wowhead | Editorial guides, item pages, community comments/tier lists | No general public data API identified for this use | Page protections/markup change; no reliable contract | Do not scrape or redistribute guide tables without permission | Human research/citation only |
| Archon | Aggregated builds, popularity, logs-derived statistics | No public WoW data API/redistribution grant identified | Current code traverses human verification and private Next.js payloads | High maintenance/terms risk; written feed agreement required | Remove as required source |
| Class Discords/theorycraft sheets | Expert context, archetype definitions, edge cases | Usually manual/community documents | Ad hoc; revisions and ownership vary | Obtain author permission and preserve attribution/version | Review/input only, not automatic truth |

## Blizzard APIs

### In-game Lua API

This is the strongest runtime source because it describes the exact link and owned location being shown. The architecture uses the functions documented in `02-wow-item-and-upgrade-system.md` and `04-weapons-and-equipment-states.md`, including:

- `C_Item.GetItemInfoInstant`, `GetItemInfo`, `GetDetailedItemLevelInfo`, `GetCurrentItemLevel`, `GetItemStats`;
- `C_Item.GetItemUpgradeInfo` and `C_ItemUpgrade.CanUpgradeItem`;
- `C_Item.GetItemUniquenessByID`, `DoesItemContainSpec`, set-bonus and item-spell calls;
- `C_TooltipInfo` structured data and `TooltipDataProcessor`;
- `C_Container`, `GetInventoryItemLink`, specialization and trait APIs.

Midnight introduced Secret Values and tightened combat-sensitive APIs, but Blizzard's stated goal still allows UI customization while restricting competitive combat-solving ([official Midnight addon/API overview](https://news.blizzard.com/en-us/article/24246290/combat-philosophy-and-addon-disarmament-in-midnight); [planned API details](https://warcraft.wiki.gg/wiki/Patch_12.0.0/Planned_API_changes)). This gear advisor is an out-of-combat/tooltip item tool and should avoid all combat-derived inputs. It must nonetheless check API contracts on each patch and use `issecretvalue` defensively before arithmetic or string operations on any value that can be secret.

The addon must also follow Blizzard's UI Add-On Development Policy: visible source, free distribution, no in-game advertising/solicitation, and no harmful realm/player impact ([official policy post](https://us.forums.blizzard.com/en/wow/t/ui-add-on-development-policy/24534/1)).

### Battle.net web API

Blizzard offers official game-data and profile APIs through OAuth; current guidance requires bearer tokens in the authorization header ([official API gateway update](https://us.forums.blizzard.com/en/blizzard/t/upcoming-changes-to-battlenet%E2%80%99s-api-gateway/51561)). The [Blizzard Developer API Terms](https://www.blizzard.com/legal/) govern access, monetization, data handling, changes, and termination.

These endpoints can enrich an offline build, but they do not replace exact in-client bonus/context links and they cannot be called by a normal Lua addon. No client secret belongs in packaged addon code. Obey the developer portal's current quota/response headers rather than hard-coding a remembered number.

## SimulationCraft

SimulationCraft is the recommended performance source because it models the spec, talents, APL, items, spells, and encounters explicitly and can run reproducibly offline. It extracts client data for items, spells, enchants, gems, ratings, and stat conversions ([GameClientData](https://github.com/simulationcraft/simc/wiki/GameClientData)). Its `midnight` branch is actively maintained ([repository](https://github.com/simulationcraft/simc)).

The project documentation says SimulationCraft is GPLv3; the repository also contains components under additional licenses ([license FAQ](https://github.com/simulationcraft/simc/wiki/FAQ)). Recommended separation:

- do not embed the SimC executable or copy engine code into the addon;
- run an exact pinned build in the offline generator;
- publish generator inputs, command lines, commit, APL/profile hashes, and validation metrics;
- review whether any copied profiles/data and the selected addon license create attribution/copyleft obligations;
- treat generated numeric model output as requiring provenance and project legal review rather than assuming it is unrestricted.

## Raidbots

Raidbots is a valuable cross-check and bootstrap source, not the runtime dependency. Its [developer page](https://www.raidbots.com/developers) explicitly publishes versioned static JSON generated from client data with SimC extractors, supports exact build/content-hash URLs, asks consumers to cache files, and disclaims guarantees. The current metadata identifies the live patch/build and available files ([metadata JSON](https://www.raidbots.com/static/data/live/metadata.json)).

Appropriate uses:

- verify the locally extracted upgrade-group and curve manifests;
- inspect public static schemas during generator development;
- link back to a public report when a user explicitly imports one.

Inappropriate uses:

- calling undocumented internal simulation-submission endpoints;
- downloading “live” data at addon runtime;
- silently redistributing large Raidbots datasets without an explicit license/permission review;
- treating Raidbots availability as necessary for packaged addon operation.

The durable design reproduces required manifests from a pinned client/SimC toolchain. Raidbots can detect disagreement in CI.

## Warcraft Logs

Warcraft Logs has an official OAuth 2.0 GraphQL API ([API documentation](https://www.warcraftlogs.com/api/docs)). Limits are point-based and key-specific; the schema exposes `limitPerHour`, `pointsSpentThisHour`, and `pointsResetIn` ([RateLimitData](https://www.warcraftlogs.com/v2-api-docs/warcraft/ratelimitdata.doc.html)).

Possible build-time uses:

- discover common talent archetypes to prioritize for simulation;
- characterize encounter duration/target-count distributions for a declared dungeon or raid profile;
- analyze whether model recommendations are badly out of family with observed high-level play.

It does not directly provide marginal stat value. Logged data has selection, execution, kill-time, team, and acquisition confounders. Any embedded aggregate requires documented sample filters, timestamp/patch, privacy/terms compliance, and redistribution permission. The V1 advisor does not need it.

## Raider.IO

Raider.IO exposes a public developer API for profiles/progression ([developer API](https://raider.io/api)). Its terms state that automated access is prohibited except through the public-facing API ([Raider.IO terms](https://raider.io/terms-of-use)). It is useful for M+ score, run, character, or guild context—not for item stat curves or performance derivatives. It should not be a dependency of the advisor or a substitute population source.

## Wowhead

Wowhead is useful for human-readable cross-checks and current editorial explanations. No general official API or clear bulk-redistribution grant was identified for this design. The existing BetterGearCompare scripts extract guide/trinket tables and use browser impersonation because normal requests are blocked. HTML layout, guide author judgments, item names, and tiers are volatile.

Recommendation: cite Wowhead articles in research, but remove Wowhead scraping from the product's required generation path. If a future feature needs Wowhead content, obtain explicit permission/API access and keep it outside the evaluator.

## Archon and the current PopularSlotsAndChants pipeline

The local pipeline is concrete evidence of an unsuitable access model:

- [`archon_common.py`](../../../PopularSlotsAndChants/scripts/archon_common.py#L82) shells out to `curl` with browser headers/cookies;
- [`fetch_archon_next_data`](../../../PopularSlotsAndChants/scripts/archon_common.py#L124) handles a human-verification challenge and extracts private `__NEXT_DATA__` page state;
- no official API contract, schema version, quota, or redistribution permission is recorded;
- the generated data can break when page internals or verification change.

The absence of an identified public grant does not by itself prove that every use is unlawful. It does mean the project lacks the permission and stability evidence required for a maintainable product. Stop automated acquisition unless Archon supplies a documented licensed feed or written permission.

## Class Discord and curated theorycraft data

Experts are valuable reviewers for:

- defining materially distinct build archetypes;
- selecting realistic encounter profiles;
- identifying weapon rules, breakpoints, or unsupported effects;
- validating surprising results.

Do not automatically copy spreadsheets, rankings, or text into the addon. Record author/source, explicit permission, patch, scope, and review date. Curated overrides should be small, typed, and explain why they exist; they must not silently replace reproducible simulations.

## Recommendation for PopularSlotsAndChants

### Remove immediately

- the “Archon stat values → BetterGearCompare weights” conversion and export;
- any implication that average stat totals are marginal values;
- the advisor's dependency on the generated Archon table;
- required Archon page scraping and challenge handling.

### Product options

1. **Archive it.** This is the safest option until a legitimate population feed is secured.
2. **Keep a separate descriptive meta browser.** Use a licensed Archon feed or an official API such as Warcraft Logs where the required data is available and allowed. Label sample, region, bracket, encounter/profile, patch, collection time, and sample size. Never call the result “weights.”
3. **Repurpose its UI.** Display the advisor's supported model archetypes, provenance, and optional human-readable “common build” context without feeding popularity numbers into evaluation.

Blizzard APIs can replace item/spell/talent definitions but cannot create population popularity. SimulationCraft can replace valuation but cannot tell what players commonly choose. Those are different products and should remain different modules/repositories.

## Build-source policy

Every external build input must pass this checklist:

- documented access method (official API, local open-source tool, or written permission);
- recorded terms/license and review date;
- version/build/patch pin and content hash;
- cache and rate-limit behavior;
- deterministic transformation committed in source;
- validation against at least one independent source;
- minimal embedded output and attribution/provenance;
- ability to build/release from a previous verified artifact if the source is temporarily unavailable;
- no runtime dependency on the source.

If any item fails the access/redistribution checks, it cannot be a required production input.
