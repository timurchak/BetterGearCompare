#!/usr/bin/env python3
"""Discover gear upgrade-track bonus IDs from Wowhead's item tooltip API.

Every upgrade track (Explorer/Adventurer/Veteran/Champion/Hero/Myth) occupies a
run of consecutive item bonus IDs — one per upgrade rank — and Blizzard hands out
a fresh block of IDs with every season. BetterGearCompare needs those IDs to
rebuild an item link at its maximum rank, so gear from the previous season and
gear from the live season both have to be recognised.

The script probes one item with a range of candidate bonus IDs, keeps the ones
that produce an "Upgrade Level: <track> <rank>/<ranks>" tooltip line, groups them
into tracks and per-season blocks, and detects which block the live season uses
by looking at the default item level of current Best-in-Slot items.

Usage:
  python extract_upgrade_tracks.py               # print the Lua table to paste into Constants
  python extract_upgrade_tracks.py --json        # print the raw findings
  python extract_upgrade_tracks.py --verify      # compare with Constants, exit 2 if stale
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from extract_wowhead_bis_gear import DEFAULT_URL as DEFAULT_BIS_URL
from extract_wowhead_bis_gear import extract_bis_table, parse_bis_items
from extract_wowhead_trinket_tiers import (
    BROWSER_HEADERS,
    extract_guide_markup,
    fetch_html,
)


DEFAULT_CONSTANTS_FILE = (
    Path(__file__).resolve().parent.parent / "BetterGearCompare_Constants.lua"
)
# Any equippable item works as a probe: the bonus ID carries the item level.
DEFAULT_PROBE_ITEM = 193757
DEFAULT_MIN_BONUS = 12700
DEFAULT_MAX_BONUS = 13600
# Tracks inside one season block sit 2-3 IDs apart, the next block starts about
# 10 IDs later.
BLOCK_GAP = 4
MIN_TRACKS_PER_BLOCK = 3
TOOLTIP_URL = "https://nether.wowhead.com/tooltip/item/{item}?locale=0&bonus={bonus}"
UPGRADE_LINE_RE = re.compile(
    r"Upgrade Level:\s*([A-Za-z' ]+?)\s*<!--uindex-->(\d+)/(\d+)"
)
ITEM_LEVEL_RE = re.compile(r"<!--ilvl-->(\d+)")
TRACK_KEYS = {
    "explorer": "EXPLORER",
    "adventurer": "ADVENTURER",
    "veteran": "VETERAN",
    "champion": "CHAMPION",
    "hero": "HERO",
    "myth": "MYTH",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Discover upgrade-track bonus IDs from Wowhead."
    )
    parser.add_argument(
        "--probe-item",
        type=int,
        default=DEFAULT_PROBE_ITEM,
        help=f"Item ID used for probing bonus IDs (default: {DEFAULT_PROBE_ITEM}).",
    )
    parser.add_argument(
        "--min-bonus",
        type=int,
        default=DEFAULT_MIN_BONUS,
        help=f"First bonus ID to scan (default: {DEFAULT_MIN_BONUS}).",
    )
    parser.add_argument(
        "--max-bonus",
        type=int,
        default=DEFAULT_MAX_BONUS,
        help=f"Last bonus ID to scan (default: {DEFAULT_MAX_BONUS}).",
    )
    parser.add_argument(
        "--workers",
        type=int,
        default=8,
        help="Parallel tooltip requests (default: 8).",
    )
    parser.add_argument(
        "--bis-url",
        default=DEFAULT_BIS_URL,
        help="BiS guide used to sample live items for current-season detection.",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Print the raw findings as JSON instead of a Lua table.",
    )
    parser.add_argument(
        "--verify",
        action="store_true",
        help="Compare the findings with Constants and exit 2 when they differ.",
    )
    parser.add_argument(
        "--constants-file",
        type=Path,
        default=DEFAULT_CONSTANTS_FILE,
        help=f"Lua file checked by --verify (default: {DEFAULT_CONSTANTS_FILE}).",
    )
    return parser.parse_args()


class TooltipProbe:
    """Reads item tooltips from Wowhead, one bonus ID at a time."""

    def __init__(self, item_id: int, workers: int) -> None:
        try:
            from curl_cffi import requests as curl_requests
        except ImportError as exc:
            raise RuntimeError(
                "curl_cffi is not installed. Install it with: python -m pip install --user curl_cffi"
            ) from exc

        self.item_id = item_id
        self.workers = workers
        self.session = curl_requests.Session(
            headers=BROWSER_HEADERS,
            impersonate="chrome136",
        )
        self.seen: dict[int, dict | None] = {}

    def probe(self, bonus: int, item_id: int | None = None) -> dict | None:
        url = TOOLTIP_URL.format(item=item_id or self.item_id, bonus=bonus)
        last_error: Exception | None = None

        for _ in range(3):
            try:
                tooltip = self.session.get(url, timeout=30).json().get("tooltip", "")
            except Exception as exc:  # network hiccup or rate limit
                last_error = exc
                continue

            match = UPGRADE_LINE_RE.search(tooltip)
            if not match:
                return None

            track = TRACK_KEYS.get(match.group(1).strip().lower())
            if not track:
                return None

            item_level = ITEM_LEVEL_RE.search(tooltip)
            return {
                "bonus": bonus,
                "track": track,
                "rank": int(match.group(2)),
                "ranks": int(match.group(3)),
                "itemLevel": int(item_level.group(1)) if item_level else 0,
            }

        raise RuntimeError(f"Could not read tooltip for bonus {bonus}: {last_error}")

    def probe_many(self, bonuses: list[int]) -> list[dict]:
        pending = [bonus for bonus in bonuses if bonus not in self.seen]
        if not pending:
            return []

        with ThreadPoolExecutor(max_workers=self.workers) as pool:
            for bonus, result in zip(pending, pool.map(self.probe, pending)):
                self.seen[bonus] = result

        return [self.seen[bonus] for bonus in pending if self.seen[bonus]]

    def default_upgrade_level(self, item_id: int) -> dict | None:
        """Read the upgrade level a live item link carries by default."""
        url = f"https://nether.wowhead.com/tooltip/item/{item_id}?locale=0"
        try:
            tooltip = self.session.get(url, timeout=30).json().get("tooltip", "")
        except Exception:
            return None

        match = UPGRADE_LINE_RE.search(tooltip)
        item_level = ITEM_LEVEL_RE.search(tooltip)
        if not match or not item_level:
            return None

        track = TRACK_KEYS.get(match.group(1).strip().lower())
        if not track:
            return None

        return {
            "itemID": item_id,
            "track": track,
            "rank": int(match.group(2)),
            "ranks": int(match.group(3)),
            "itemLevel": int(item_level.group(1)),
        }


def scan_bonus_ids(probe: TooltipProbe, min_bonus: int, max_bonus: int) -> list[dict]:
    """Coarse scan first, then fill in the neighbourhood of every hit.

    Tracks are at least 6 IDs long, so a stride of 3 cannot step over one.
    """
    probe.probe_many(list(range(min_bonus, max_bonus + 1, 3)))

    while True:
        hits = sorted(bonus for bonus, hit in probe.seen.items() if hit)
        if not hits:
            return []

        neighbourhood = {
            bonus
            for hit in hits
            for bonus in range(hit - 8, hit + 9)
            if min_bonus <= bonus <= max_bonus
        }
        if not probe.probe_many(sorted(neighbourhood)):
            break

    return [probe.seen[bonus] for bonus in sorted(probe.seen) if probe.seen[bonus]]


def build_tracks(hits: list[dict]) -> tuple[list[dict], list[dict]]:
    """Group hits into complete tracks; return (tracks, incomplete runs).

    A run that reaches the last rank is complete even when it starts above rank 1
    (rank 1 of the Explorer track, for instance, has no tooltip of its own), so
    the base ID is derived from the rank the run starts at.
    """
    tracks: list[dict] = []
    incomplete: list[dict] = []
    run: list[dict] = []

    def flush(run: list[dict]) -> None:
        if not run:
            return

        first, last = run[0], run[-1]
        entry = {
            "key": first["track"],
            "baseBonus": first["bonus"] - (first["rank"] - 1),
            "ranks": first["ranks"],
            "minItemLevel": first["itemLevel"],
            "maxItemLevel": last["itemLevel"],
            "itemLevels": {hit["rank"]: hit["itemLevel"] for hit in run},
        }
        if last["rank"] == first["ranks"]:
            tracks.append(entry)
        else:
            entry["firstRank"] = first["rank"]
            entry["lastRank"] = last["rank"]
            incomplete.append(entry)

    for hit in hits:
        previous = run[-1] if run else None
        continues = (
            previous is not None
            and hit["bonus"] == previous["bonus"] + 1
            and hit["track"] == previous["track"]
            and hit["ranks"] == previous["ranks"]
            and hit["rank"] == previous["rank"] + 1
        )
        if continues:
            run.append(hit)
            continue

        flush(run)
        run = [hit]

    flush(run)
    return tracks, incomplete


def build_blocks(tracks: list[dict]) -> list[list[dict]]:
    """Split tracks into per-season blocks by ID distance and repeated tracks."""
    blocks: list[list[dict]] = []

    for track in tracks:
        block = blocks[-1] if blocks else None
        if block:
            previous = block[-1]
            gap = track["baseBonus"] - (previous["baseBonus"] + previous["ranks"] - 1)
            same_track_again = any(entry["key"] == track["key"] for entry in block)
            if gap <= BLOCK_GAP and not same_track_again:
                block.append(track)
                continue

        blocks.append([track])

    return blocks


def sample_live_items(bis_url: str, limit: int = 12) -> list[int]:
    markup = extract_guide_markup(fetch_html(bis_url))
    items = parse_bis_items(extract_bis_table(markup))
    item_ids: list[int] = []
    for slot_items in items.values():
        for entry in slot_items:
            if entry["itemID"] not in item_ids:
                item_ids.append(entry["itemID"])
    return item_ids[:limit]


def detect_current_block(
    probe: TooltipProbe, blocks: list[list[dict]], item_ids: list[int]
) -> tuple[int | None, list[dict]]:
    """Pick the block that reproduces the upgrade level live gear ships with.

    Item levels can be item-specific, so every candidate bonus ID is probed on the
    sampled item itself instead of comparing against the scan's probe item.
    """
    votes: dict[int, int] = {}
    samples: list[dict] = []

    for item_id in item_ids:
        sample = probe.default_upgrade_level(item_id)
        if not sample:
            continue

        samples.append(sample)
        for index, block in enumerate(blocks, start=1):
            for track in block:
                if track["key"] != sample["track"] or track["ranks"] != sample["ranks"]:
                    continue

                candidate = probe.probe(
                    track["baseBonus"] + sample["rank"] - 1, item_id=item_id
                )
                if (
                    candidate
                    and candidate["track"] == sample["track"]
                    and candidate["rank"] == sample["rank"]
                    and candidate["itemLevel"] == sample["itemLevel"]
                ):
                    votes[index] = votes.get(index, 0) + 1

    if not votes:
        return None, samples

    return max(votes, key=lambda index: votes[index]), samples


def format_lua(blocks: list[list[dict]], current_block: int | None) -> str:
    lines = ["  upgradeTrackBlocks = {"]
    for index, block in enumerate(blocks, start=1):
        first = block[0]["baseBonus"]
        last = block[-1]["baseBonus"] + block[-1]["ranks"] - 1
        current = ", current season" if index == current_block else ""
        lines.append(f"    {{ -- bonus {first}-{last}{current}")
        for track in block:
            lines.append(
                f"      {{ key = \"{track['key']}\", baseBonus = {track['baseBonus']}, ranks = {track['ranks']} }},"
            )
        lines.append("    },")
    lines.append("  },")
    lines.append(f"  currentUpgradeBlock = {current_block or 1},")
    return "\n".join(lines)


def read_constants(path: Path) -> tuple[list[tuple[str, int, int]], int | None]:
    text = path.read_text(encoding="utf-8")
    tracks = [
        (key, int(base), int(ranks))
        for key, base, ranks in re.findall(
            r'key\s*=\s*"([A-Z]+)"\s*,\s*baseBonus\s*=\s*(\d+)\s*,\s*ranks\s*=\s*(\d+)',
            text,
        )
    ]
    current = re.search(r"currentUpgradeBlock\s*=\s*(\d+)", text)
    return tracks, int(current.group(1)) if current else None


def verify(
    blocks: list[list[dict]], current_block: int | None, path: Path
) -> int:
    known, current_in_file = read_constants(path)
    found = [
        (track["key"], track["baseBonus"], track["ranks"])
        for block in blocks
        for track in block
    ]

    missing = [track for track in found if track not in known]
    unknown = [track for track in known if track not in found]

    print(f"Constants file: {path}")
    print(f"Tracks on Wowhead: {len(found)}  |  in Constants: {len(known)}")

    for key, base, ranks in missing:
        print(f"- missing from Constants: {key} baseBonus={base} ranks={ranks}")
    for key, base, ranks in unknown:
        print(f"- not found on Wowhead: {key} baseBonus={base} ranks={ranks}")

    if current_block and current_in_file != current_block:
        print(
            f"- currentUpgradeBlock is {current_in_file}, live season looks like block {current_block}"
        )

    stale = bool(missing) or (current_block is not None and current_in_file != current_block)
    print("Result: stale" if stale else "Result: up to date")
    return 2 if stale else 0


def main() -> int:
    args = parse_args()

    try:
        probe = TooltipProbe(args.probe_item, args.workers)
        hits = scan_bonus_ids(probe, args.min_bonus, args.max_bonus)
        if not hits:
            raise ValueError(
                f"No upgrade tracks found between {args.min_bonus} and {args.max_bonus}."
            )

        tracks, incomplete = build_tracks(hits)
        blocks = build_blocks(tracks)

        skipped = [block for block in blocks if len(block) < MIN_TRACKS_PER_BLOCK]
        blocks = [block for block in blocks if len(block) >= MIN_TRACKS_PER_BLOCK]
        if not blocks:
            raise ValueError("No complete season block was found.")

        current_block, samples = detect_current_block(
            probe, blocks, sample_live_items(args.bis_url)
        )
    except Exception as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    for entry in incomplete:
        print(
            f"note: ignoring partial track {entry['key']} "
            f"({entry['baseBonus']}, ranks {entry['firstRank']}-{entry['lastRank']} of {entry['ranks']})",
            file=sys.stderr,
        )
    for block in skipped:
        keys = ", ".join(track["key"] for track in block)
        print(f"note: ignoring block with too few tracks ({keys})", file=sys.stderr)
    if blocks[-1][-1]["baseBonus"] + 32 > args.max_bonus:
        print(
            "note: hits reach the end of the scanned range, rerun with a higher --max-bonus",
            file=sys.stderr,
        )
    if current_block is None:
        print(
            "note: could not match live items to a block, currentUpgradeBlock needs a manual check",
            file=sys.stderr,
        )

    if args.verify:
        return verify(blocks, current_block, args.constants_file)

    if args.json:
        print(
            json.dumps(
                {
                    "probeItem": args.probe_item,
                    "currentBlock": current_block,
                    "blocks": blocks,
                    "liveSamples": samples,
                },
                indent=2,
                ensure_ascii=False,
            )
        )
    else:
        print(format_lua(blocks, current_block))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
