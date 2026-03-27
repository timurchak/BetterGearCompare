#!/usr/bin/env python3
"""Extract BIS gear item IDs from a Wowhead guide page.

Parses the "Overall BiS" table from Wowhead BIS gear guides and returns
item IDs grouped by equipment slot.

Uses the same fetching infrastructure as extract_wowhead_trinket_tiers.py.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

from extract_wowhead_trinket_tiers import (
    extract_guide_markup,
    fetch_html,
)


DEFAULT_URL = "https://www.wowhead.com/guide/classes/warrior/fury/bis-gear"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extract BIS gear item IDs from a Wowhead guide."
    )
    source = parser.add_mutually_exclusive_group()
    source.add_argument(
        "--url",
        default=DEFAULT_URL,
        help=f"Wowhead guide URL to fetch (default: {DEFAULT_URL})",
    )
    source.add_argument(
        "--html-file",
        type=Path,
        help="Read HTML from a local file instead of downloading.",
    )
    parser.add_argument(
        "--pretty",
        action="store_true",
        help="Pretty-print the resulting JSON.",
    )
    parser.add_argument(
        "--save-html",
        type=Path,
        help="Save downloaded HTML for debugging.",
    )
    return parser.parse_args()


SLOT_NORMALIZE = {
    "head": "Head",
    "helm": "Head",
    "neck": "Neck",
    "shoulders": "Shoulders",
    "shoulder": "Shoulders",
    "cloak": "Back",
    "back": "Back",
    "cape": "Back",
    "chest": "Chest",
    "bracers": "Wrist",
    "wrist": "Wrist",
    "gloves": "Hands",
    "hands": "Hands",
    "belt": "Waist",
    "waist": "Waist",
    "legs": "Legs",
    "boots": "Feet",
    "feet": "Feet",
    "ring": "Ring",
    "finger": "Ring",
    "trinket": "Trinket",
    "weapon": "Weapon",
    "mainhand": "Weapon",
    "main hand": "Weapon",
    "offhand": "Offhand",
    "off hand": "Offhand",
    "off-hand": "Offhand",
    "shield": "Offhand",
    "holdable": "Offhand",
}


def normalize_slot(raw_slot: str) -> str | None:
    return SLOT_NORMALIZE.get(raw_slot.strip().lower())


def extract_bis_table(markup: str) -> str:
    """Extract the first BIS table from the BIS tab (tries several name variants)."""
    bis_tab_patterns = [
        r'\[tab name="Overall BiS"[^\]]*\](.*?)\[/tab\]',
        r'\[tab name="[^"]*Best-in-Slot[^"]*"[^\]]*\](.*?)\[/tab\]',
        r'\[tab name="[^"]*BiS[^"]*"[^\]]*\](.*?)\[/tab\]',
    ]
    tab_match = None
    for pattern in bis_tab_patterns:
        tab_match = re.search(pattern, markup, re.DOTALL | re.IGNORECASE)
        if tab_match:
            break

    if not tab_match:
        raise ValueError("Could not find a BIS tab in the guide markup.")

    tab_content = tab_match.group(1)

    table_match = re.search(
        r"\[table[^\]]*\](.*?)\[/table\]",
        tab_content,
        re.DOTALL,
    )
    if not table_match:
        raise ValueError("Could not find a gear table inside the 'Overall BiS' tab.")

    return table_match.group(1)


def _extract_source(cells: list[str], row: str) -> str:
    """Try to extract item source text from the row cells."""
    # Look through all cells (skip first = slot, skip cells containing [item=])
    for cell in cells:
        if re.search(r"\[item=", cell):
            continue
        # Guide URL: [url guide=33231]Chimaerus[/url]
        guide = re.search(r"\[url guide=\d+\]([^\[]+)\[/url\]", cell)
        if guide:
            return guide.group(1).strip()
        # Skill (crafting): [skill=164]
        if re.search(r"\[skill=\d+\]", cell):
            return "Crafted"
    # Fallback: strip all tags from last non-empty cell
    for cell in reversed(cells):
        text = re.sub(r"\[/?[^\]]+\]", "", cell).strip()
        if text and not re.search(r"^\d+$", text):
            return text
    return ""


def parse_bis_items(table_markup: str) -> dict[str, list[dict]]:
    """Parse table rows into {slot: [{itemID, source}, ...]}."""
    items: dict[str, list[dict]] = {}

    for row_match in re.finditer(
        r"\[tr\](.*?)\[/tr\]",
        table_markup,
        re.DOTALL,
    ):
        row = row_match.group(1)

        cells = re.findall(r"\[td[^\]]*\](.*?)\[/td\]", row, re.DOTALL)
        if len(cells) < 2:
            continue

        # First cell is the slot name — strip all bbcode tags
        slot_raw = re.sub(r"\[/?[^\]]+\]", "", cells[0]).strip()

        # Skip header rows
        if slot_raw.lower() in ("slot", "item slot", "name", "item", "source", ""):
            continue

        slot = normalize_slot(slot_raw)
        if not slot:
            continue

        # Find item IDs in any cell (not just the second one)
        item_ids = [int(m) for m in re.findall(r"\[item=(\d+)", row)]
        if not item_ids:
            continue

        source = _extract_source(cells[1:], row)

        if slot not in items:
            items[slot] = []
        for item_id in item_ids:
            items[slot].append({"itemID": item_id, "source": source})

    return items


def main() -> int:
    args = parse_args()

    try:
        if args.html_file:
            html = args.html_file.read_text(encoding="utf-8")
        else:
            html = fetch_html(args.url)
            if args.save_html:
                args.save_html.write_text(html, encoding="utf-8")

        markup = extract_guide_markup(html)
        table_markup = extract_bis_table(markup)
        items = parse_bis_items(table_markup)
    except Exception as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    # Flatten to a simple list of all BIS item IDs
    all_ids = []
    for slot_items in items.values():
        all_ids.extend(entry["itemID"] for entry in slot_items)

    result = {
        "itemsBySlot": items,
        "allItemIDs": sorted(set(all_ids)),
        "totalItems": len(set(all_ids)),
    }

    if args.pretty:
        print(json.dumps(result, indent=2, ensure_ascii=False))
    else:
        print(json.dumps(result, ensure_ascii=False))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
