#!/usr/bin/env python3
"""Fetch and validate the pinned 12.1 upgrade-track manifest.

This consumes Raidbots' documented static JSON endpoint. It is not HTML scraping and
is not used by the runtime addon. A live pointer mismatch fails closed so an old
Phase 0 report cannot silently claim to validate a newer client build.
"""

from __future__ import annotations

import json
import pathlib
import sys
import urllib.request


ROOT = pathlib.Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "fixtures" / "upgrade" / "season-manifest.generated.json"
METADATA_URL = "https://www.raidbots.com/static/data/live/metadata.json"
UPGRADES_URL = "https://www.raidbots.com/static/data/live/bonus-upgrade-sets.json"
EXPECTED_BUILD = "12.1.0.69587"
EXPECTED_HASH = "cbc0c66f5fe503d7e455cd2463fe0e28"
EXPECTED_GROUPS = {
    614: "Adventurer",
    615: "Veteran",
    616: "Champion",
    617: "Hero",
    618: "Myth",
}


def fetch_json(url: str) -> object:
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "BetterGearAdvisor-Phase0/1.0"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def normalize_group(group_id: int, rows: list[dict]) -> dict:
    rows = sorted(rows, key=lambda row: row["level"])
    levels = [row["level"] for row in rows]
    if levels != list(range(1, 7)):
        raise ValueError(f"group {group_id}: expected ranks 1..6, got {levels}")
    if any(row["group"] != group_id or row["max"] != 6 for row in rows):
        raise ValueError(f"group {group_id}: inconsistent group/max fields")

    paid = rows[1:]
    currencies = {
        (row.get("currency") or {}).get("id")
        for row in paid
    }
    amounts = {
        (row.get("currency") or {}).get("amount")
        for row in paid
    }
    if len(currencies) != 1 or None in currencies:
        raise ValueError(f"group {group_id}: inconsistent currency IDs {currencies}")
    if amounts != {20}:
        raise ValueError(f"group {group_id}: expected flat cost 20, got {amounts}")

    return {
        "groupID": group_id,
        "track": EXPECTED_GROUPS[group_id],
        "currencyID": next(iter(currencies)),
        "currencyName": (paid[0].get("currency") or {}).get("name"),
        "ranks": [
            {
                "rank": row["level"],
                "maxRank": row["max"],
                "bonusID": row["bonusId"],
                "itemLevel": row["itemLevel"],
                "cost": 0 if row["level"] == 1 else 20,
            }
            for row in rows
        ],
    }


def main() -> int:
    metadata = fetch_json(METADATA_URL)
    if metadata.get("wowBuild") != EXPECTED_BUILD:
        raise SystemExit(
            f"FAIL CLOSED: live build {metadata.get('wowBuild')} != {EXPECTED_BUILD}"
        )
    if metadata.get("contentHash") != EXPECTED_HASH:
        raise SystemExit(
            "FAIL CLOSED: live content hash "
            f"{metadata.get('contentHash')} != {EXPECTED_HASH}"
        )

    raw = fetch_json(UPGRADES_URL)
    groups = []
    for group_id in EXPECTED_GROUPS:
        rows = raw.get(str(group_id))
        if not rows:
            raise ValueError(f"missing upgrade group {group_id}")
        groups.append(normalize_group(group_id, rows))

    manifest = {
        "schema": 1,
        "environment": metadata["environment"],
        "wowBuild": metadata["wowBuild"],
        "contentHash": metadata["contentHash"],
        "sourceGeneratedAt": metadata["generatedAt"],
        "sources": {
            "metadata": METADATA_URL,
            "upgradeSets": UPGRADES_URL,
        },
        "groups": groups,
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"PASS manifest: {OUTPUT}")
    print(f"build={manifest['wowBuild']} hash={manifest['contentHash']}")
    print(f"groups={len(groups)} ranks={sum(len(g['ranks']) for g in groups)}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, KeyError, json.JSONDecodeError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)

