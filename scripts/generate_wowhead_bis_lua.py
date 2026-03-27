#!/usr/bin/env python3
"""Generate a Lua BIS gear dataset from Wowhead BiS guide URLs.

Fetches all spec BIS guides, extracts gear item IDs, and produces a Lua
file that the addon can use to mark items as Best-in-Slot.
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlparse

from extract_wowhead_bis_gear import extract_bis_table, parse_bis_items
from extract_wowhead_trinket_tiers import extract_guide_markup, fetch_html
from generate_wowhead_trinket_lua import (
    SPEC_ID_BY_SLUG,
    format_lua_table,
)


DEFAULT_URLS_FILE = Path(__file__).with_name("wowhead_bis_guide_urls.txt")
DEFAULT_OUTPUT_FILE = (
    Path(__file__).resolve().parent.parent / "BetterGearCompare_BisData.lua"
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate BetterGearCompare BIS gear data as a Lua file."
    )
    parser.add_argument(
        "--urls-file",
        type=Path,
        default=DEFAULT_URLS_FILE,
        help=f"Text file with one Wowhead guide URL per line (default: {DEFAULT_URLS_FILE}).",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT_FILE,
        help=f"Lua output path (default: {DEFAULT_OUTPUT_FILE}).",
    )
    return parser.parse_args()


def build_slug(url: str) -> tuple[str, str, str]:
    parts = [part for part in urlparse(url).path.split("/") if part]
    if len(parts) < 5:
        raise ValueError(f"Unexpected Wowhead URL format: {url}")
    return parts[2], parts[3], f"{parts[2]}/{parts[3]}"


def fetch_bis_for_url(url: str) -> dict[str, object]:
    result: dict[str, object] = {"url": url, "ok": False}
    try:
        html = fetch_html(url)
        markup = extract_guide_markup(html)
        table_markup = extract_bis_table(markup)
        items = parse_bis_items(table_markup)
    except Exception as exc:
        result["error"] = str(exc)
        return result

    all_ids = []
    for slot_items in items.values():
        all_ids.extend(entry["itemID"] for entry in slot_items)

    result.update(
        {
            "ok": True,
            "itemsBySlot": items,
            "allItemIDs": sorted(set(all_ids)),
        }
    )
    return result


def build_dataset(results: list[dict[str, object]]) -> dict[str, object]:
    specs: dict[str, object] = {}
    spec_ids: dict[int, str] = {}

    for result in results:
        if not result.get("ok"):
            raise ValueError(
                f"Guide failed: {result['url']} ({result.get('error', 'unknown')})"
            )

        url = str(result["url"])
        class_slug, spec_slug, slug = build_slug(url)
        spec_id = SPEC_ID_BY_SLUG.get(slug)
        if spec_id is None:
            raise ValueError(f"Missing spec ID mapping for {slug}")

        all_item_ids = result["allItemIDs"]
        items_by_slot = result["itemsBySlot"]

        # Build lookups: itemID -> true, itemID -> source
        item_set: dict[int, bool] = {item_id: True for item_id in all_item_ids}
        item_sources: dict[int, str] = {}
        for slot_items in items_by_slot.values():
            for entry in slot_items:
                if entry["source"]:
                    item_sources[entry["itemID"]] = entry["source"]

        specs[slug] = {
            "specID": spec_id,
            "classSlug": class_slug,
            "specSlug": spec_slug,
            "sourceUrl": url,
            "itemsBySlot": items_by_slot,
            "bisItems": dict(sorted(item_set.items())),
            "itemSources": dict(sorted(item_sources.items())),
        }
        spec_ids[spec_id] = slug

    return {
        "generatedAtUtc": datetime.now(timezone.utc)
        .replace(microsecond=0)
        .isoformat(),
        "source": "Wowhead Best in Slot Guides",
        "specIDs": dict(sorted(spec_ids.items())),
        "specs": specs,
    }


def read_urls(path: Path) -> list[str]:
    urls = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        urls.append(line)
    return urls


def main() -> int:
    args = parse_args()
    urls = read_urls(args.urls_file)

    if not urls:
        raise SystemExit("error: no guide URLs found in the input file")

    print(f"Fetching BIS data for {len(urls)} specs...")
    results = []
    for i, url in enumerate(urls, 1):
        slug = "/".join(
            p
            for p in urlparse(url).path.split("/")
            if p and p not in ("guide", "classes", "bis-gear")
        )
        print(f"  [{i}/{len(urls)}] {slug}...", end=" ", flush=True)
        result = fetch_bis_for_url(url)
        if result["ok"]:
            print(f"OK ({len(result['allItemIDs'])} items)")
        else:
            print(f"FAILED: {result.get('error', '?')}")
        results.append(result)

    failed = [r for r in results if not r.get("ok")]
    if failed:
        summary = "\n".join(
            f"  - {r['url']}: {r.get('error', '?')}" for r in failed
        )
        raise SystemExit(f"error: some guides failed:\n{summary}")

    dataset = build_dataset(results)
    lua_content = (
        "local _, ns = ...\n\n" f"ns.BisData = {format_lua_table(dataset)}\n"
    )
    args.output.write_text(lua_content, encoding="utf-8")

    summary = {
        "output": str(args.output),
        "specCount": len(dataset["specs"]),
    }
    print(f"\nDone: {json.dumps(summary, ensure_ascii=False)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
