#!/usr/bin/env python3
"""Generate a Lua trinket dataset from Wowhead BiS guide URLs."""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlparse

from verify_wowhead_trinket_guides import read_urls, verify_url


DEFAULT_URLS_FILE = Path(__file__).with_name("wowhead_bis_guide_urls.txt")
DEFAULT_OUTPUT_FILE = Path(__file__).resolve().parent.parent / "BetterGearCompare_TrinketData.lua"
DEFAULT_TIERS = "S,A,B,C,D"
TIER_SCORES = {
    "S": 5,
    "A": 4,
    "B": 3,
    "C": 2,
    "D": 1,
}
SPEC_ID_BY_SLUG = {
    "death-knight/blood": 250,
    "death-knight/frost": 251,
    "death-knight/unholy": 252,
    "demon-hunter/havoc": 577,
    "demon-hunter/vengeance": 581,
    "demon-hunter/devourer": 1480,
    "druid/balance": 102,
    "druid/feral": 103,
    "druid/guardian": 104,
    "druid/restoration": 105,
    "evoker/devastation": 1467,
    "evoker/preservation": 1468,
    "evoker/augmentation": 1473,
    "hunter/beast-mastery": 253,
    "hunter/marksmanship": 254,
    "hunter/survival": 255,
    "mage/arcane": 62,
    "mage/fire": 63,
    "mage/frost": 64,
    "monk/brewmaster": 268,
    "monk/mistweaver": 270,
    "monk/windwalker": 269,
    "paladin/holy": 65,
    "paladin/protection": 66,
    "paladin/retribution": 70,
    "priest/discipline": 256,
    "priest/holy": 257,
    "priest/shadow": 258,
    "rogue/assassination": 259,
    "rogue/outlaw": 260,
    "rogue/subtlety": 261,
    "shaman/elemental": 262,
    "shaman/enhancement": 263,
    "shaman/restoration": 264,
    "warlock/affliction": 265,
    "warlock/demonology": 266,
    "warlock/destruction": 267,
    "warrior/arms": 71,
    "warrior/fury": 72,
    "warrior/protection": 73,
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate BetterGearCompare trinket data as a Lua file."
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
    parser.add_argument(
        "--tiers",
        default=DEFAULT_TIERS,
        help="Comma-separated tier labels to include in the generated file.",
    )
    return parser.parse_args()


def build_slug(url: str) -> tuple[str, str, str]:
    parts = [part for part in urlparse(url).path.split("/") if part]
    if len(parts) < 5:
        raise ValueError(f"Unexpected Wowhead URL format: {url}")
    return parts[2], parts[3], f"{parts[2]}/{parts[3]}"


def lua_quote(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def lua_key(value: int | str) -> str:
    if isinstance(value, int):
        return f"[{value}]"
    return f"[{lua_quote(value)}]"


def lua_scalar(value: object) -> str:
    if value is None:
        return "nil"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, str):
        return lua_quote(value)
    raise TypeError(f"Unsupported Lua scalar type: {type(value)!r}")


def format_lua_table(value: object, indent: int = 0) -> str:
    space = "  " * indent
    next_space = "  " * (indent + 1)

    if isinstance(value, dict):
        if not value:
            return "{}"

        lines = ["{"]
        for key, nested in value.items():
            lines.append(f"{next_space}{lua_key(key)} = {format_lua_table(nested, indent + 1)},")
        lines.append(f"{space}}}")
        return "\n".join(lines)

    if isinstance(value, list):
        if not value:
            return "{}"

        lines = ["{"]
        for nested in value:
            lines.append(f"{next_space}{format_lua_table(nested, indent + 1)},")
        lines.append(f"{space}}}")
        return "\n".join(lines)

    return lua_scalar(value)


def build_dataset(results: list[dict[str, object]], ordered_tiers: list[str]) -> dict[str, object]:
    specs: dict[str, object] = {}
    spec_ids: dict[int, str] = {}

    for result in results:
        if not result.get("ok"):
            raise ValueError(f"Guide failed verification: {result['url']} ({result.get('error', 'unknown error')})")

        url = str(result["url"])
        class_slug, spec_slug, slug = build_slug(url)
        spec_id = SPEC_ID_BY_SLUG.get(slug)
        if spec_id is None:
            raise ValueError(f"Missing spec ID mapping for {slug}")
        tiers = result["tiers"]

        item_tiers: dict[int, str] = {}
        item_scores: dict[int, int] = {}
        for tier in ordered_tiers:
            for item_id in tiers.get(tier, []):
                item_tiers[item_id] = tier
                item_scores[item_id] = TIER_SCORES.get(tier, 0)

        specs[slug] = {
            "specID": spec_id,
            "classSlug": class_slug,
            "specSlug": spec_slug,
            "sourceUrl": url,
            "tiers": {tier: tiers.get(tier, []) for tier in ordered_tiers},
            "itemTiers": dict(sorted(item_tiers.items())),
            "itemScores": dict(sorted(item_scores.items())),
        }
        spec_ids[spec_id] = slug

    return {
        "generatedAtUtc": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "source": "Wowhead Trinket Tier List",
        "orderedTiers": ordered_tiers,
        "tierScores": {tier: TIER_SCORES[tier] for tier in ordered_tiers if tier in TIER_SCORES},
        "specIDs": dict(sorted(spec_ids.items())),
        "specs": specs,
    }


def main() -> int:
    args = parse_args()
    ordered_tiers = [tier.strip().upper() for tier in args.tiers.split(",") if tier.strip()]
    urls = read_urls(args.urls_file)

    if not urls:
        raise SystemExit("error: no guide URLs found in the input file")

    results = [verify_url(url, args.tiers) for url in urls]
    failed = [result for result in results if not result.get("ok")]
    if failed:
        summary = "\n".join(f"- {result['url']}: {result['error']}" for result in failed)
        raise SystemExit(f"error: some guides failed verification:\n{summary}")

    dataset = build_dataset(results, ordered_tiers)
    lua_content = (
        "local _, ns = ...\n\n"
        f"ns.TrinketData = {format_lua_table(dataset)}\n"
    )
    args.output.write_text(lua_content, encoding="utf-8")

    summary = {
        "output": str(args.output),
        "specCount": len(dataset["specs"]),
        "orderedTiers": ordered_tiers,
    }
    print(json.dumps(summary, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
