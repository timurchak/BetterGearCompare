# Spike C — Blizzard-default tooltip and asynchronous item lifecycle

**Verdict: PARTIAL, with mandatory default-tooltip sources exercised.** The proposed revision/key/repository algorithm passes deterministic and randomized offline stress tests. A live Retail 12.1.0.69587 export exercises bags, character/equipment, chat links, comparison tooltips, `GameTooltip`, both `ShoppingTooltip` frames, `ItemRefTooltip`, duplicate suppression, and equipment revision. The live session did not produce an asynchronous uncached completion or stale callback rejection; loot, merchant, and journal marks are also absent.

## Current supported hook

[`Phase0TooltipProbe.lua`](addons/Phase0TooltipProbe/Phase0TooltipProbe.lua) registers one callback:

```lua
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItemTooltip)
```

It does not hook bag-addon internals, global `OnTooltipSetItem`, ElvUI, Bagnon, BetterBags, or Auction House addons. Blizzard's current UI source uses the same post-call mechanism for final item-tooltip processing ([`TooltipDataRules.lua`](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipDataRules.lua)) and defines the tooltip data handler/processor in [`TooltipDataHandler.lua`](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua). The source mirror inspected for this spike was pinned locally at commit `8ea15b61e45c0ed4eba01439c90757f86eb78d34`; the target client must still confirm the runtime API.

## Lifecycle design

There are two independent layers:

1. **Repository state by exact item key.** The canonical key prefers GUID-derived complete item link, then tooltip hyperlink, then `TooltipUtil.GetDisplayedItem`. One `Item:ContinueWithCancelOnItemLoad` request is coalesced for all tooltip consumers of that exact key. Entry states are `pending`, `ready`, or `failed`; failures render nothing and may retry after one second.
2. **Weak per-tooltip view state.** Each tooltip owns `revision`, `key`, waiter ID, rendered signature, and rendered line count. Key change or hide increments the revision and clears render state. A load completion may call `tooltip:RefreshData()` only if tooltip identity, revision, key, and shown state still match the subscription. Rendering occurs only on the subsequent cache-backed post-call.

The render signature is `exact item key | repository request ID | equipment revision`. A block is suppressed only when the signature matches and the previously recorded line count is still present. This avoids both duplicate lines and the permanent “processed” flag bug that prevents legitimate refresh.

`PLAYER_EQUIPMENT_CHANGED` and `SOCKET_INFO_UPDATE` increment the equipment revision and refresh currently shown tracked tooltips. No protected action is called and no tooltip is mutated from an obsolete async callback.

## Executable stress evidence

[`stress_lifecycle.py`](tools/tooltip/stress_lifecycle.py) is a model-based implementation of the same revision/key rules. Its generated [`offline-lifecycle-report.json`](fixtures/tooltip/offline-lifecycle-report.json) passes seven explicit regressions:

- uncached item resolves and refreshes once;
- tooltip hides before completion;
- tooltip changes items before completion;
- two tooltips coalesce one item request;
- equipment refresh remains idempotent;
- 100 repeated pending post-calls create one subscription;
- rapid A→B→C item churn with C/B/A callback order renders only C.

It also passes 100,000 deterministic randomized actions over two tooltips and 2,048 item keys, recording 15,281 renders, 311 valid refreshes, 758 stale callback rejections, and 3,889 duplicate suppressions with no invariant failure. The invariants are: never more than one addon block in one tooltip cycle, and never render a key other than the tooltip's current key.

All three addon/model Lua files and the generated model payload pass `luac 5.1 -p`. Offline evidence proves the state algorithm, not Blizzard UI behavior.

## Live 12.1.0.69587 evidence

The unedited user export is preserved as [`Phase0TooltipProbe-export-69587.lua`](fixtures/tooltip/client/Phase0TooltipProbe-export-69587.lua). [`analyze_client_export.lua`](tools/tooltip/analyze_client_export.lua) generates [`live-lifecycle-report.json`](fixtures/tooltip/live-lifecycle-report.json).

| Marked segment | Rows | Item changes | Renders | Loads ready/start | Duplicate suppressions | Notable frames/events |
|---|---:|---:|---:|---:|---:|---|
| bags | 861 | 73 | 624 | 41/41 | 9 | `GameTooltip`, `ShoppingTooltip1/2` |
| character | 323 | 34 | 238 | 4/4 | 0 | two equipment revisions and refresh renders |
| chat | 26 | 6 | 14 | cached | 0 | `ItemRefTooltip`, `ItemRefShoppingTooltip1/2` |
| comparison | 295 | 19 | 251 | 1/1 | 0 | both shopping tooltips |

Across the session there are 1,505 log rows, 46 load starts and 46 ready completions, 132 item changes, 143 hides, 1,127 renders, nine explicit duplicate suppressions, and no `load-failed`, `refresh-unsupported`, or orphan-completion event. Repeated render events are not themselves duplicate visible lines: Blizzard may rebuild a tooltip and legitimately require the block again. The export cannot replace the user's visual assertion that simultaneous duplicate lines were absent.

The captured [`taint-69587.log`](fixtures/tooltip/client/taint-69587.log) contains two “execution tainted” traces caused by reading the standard `SLASH_PHASE0...` globals. Addon code is inherently tainted; the relevant safety result is that the log contains no blocked/forbidden protected action and no tooltip/protected-frame propagation trace. The analyzer records both the benign slash attribution and `noBlockedProtectedAction=true` rather than incorrectly claiming that no addon taint exists.

All 46 item records resolved synchronously/from cache: there is no `load-publish-refresh` and no `stale-result-rejected`. The offline harness covers the algorithmic orderings, but the live async path remains an open gate.

## Live test matrix

Run with every non-Blizzard addon disabled and taint logging enabled. Use `/p0c mark <source>` before each group, `/p0c debug on`, and `/p0c export` after the session.

| Source/scenario | Required assertion | Status |
|---|---|---|
| Bag item, cached | Correct `GameTooltip`/shopping activity and duplicate suppression | Passed |
| Bag item, genuinely uncached | Async refresh after data resolves | Missing |
| Equipped item and character sheet | Same hook/path plus equipment revision | Passed |
| Chat item link / ItemRefTooltip | `ItemRefTooltip` and both ItemRef shopping frames | Passed |
| Loot tooltip | Correct block or documented unsupported tooltip type | Missing |
| Merchant item | Correct block or documented unsupported source | Missing |
| Encounter journal | Correct block or documented unsupported source | Missing |
| Comparison/shopping tooltips | Both shopping tooltips have independent revisions | Passed |
| Close before load | `stale-result-rejected`, no late block | Missing |
| Rapid A→B→C hover | Only C may render | Missing |
| Equipment/socket change while open | Two equipment revisions observed | Passed for equipment |
| Repeated refresh/post-call | Nine duplicate suppressions; rebuild renders remain allowed | Passed structurally |
| Missing structured data | No recommendation; later retry possible | Not exercised live |
| Combat and protected UI | Slash-command attribution only; no blocked protected action | Passed for captured session |

Suggested procedure:

```text
/console taintLog 2
/reload
/p0c clear
/p0c debug on
```

Exercise every row, including deliberately uncached links after a clean cache/login where practical. Inspect `Logs/taint.log` for probe-attributed execution paths, save the unedited SavedVariables/export under [`fixtures/tooltip`](fixtures/tooltip/), and review log sequences by marks. A passing run must show no duplicate render signature within one data generation and no render after a stale rejection for that subscription.

## Pass gate

Spike C becomes PASS only when the complete matrix succeeds on the target 12.1 Retail build using Blizzard UI alone, with no probe-attributed taint, duplicate addon blocks, stale-item render, permanent suppression, or unresolved-data recommendation. Sources that do not emit item tooltip post-calls may be explicitly unsupported, but bags, equipped/character sheet, chat links, and comparison tooltips are mandatory.

Until a genuinely uncached live callback is refreshed/rejected under rapid tooltip change, the lifecycle architecture is supported but the shipping integration is not approved. Loot, merchant, and journal should also be marked or explicitly documented unsupported before final sign-off.
