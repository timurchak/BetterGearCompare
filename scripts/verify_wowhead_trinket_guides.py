#!/usr/bin/env python3
"""Verify Wowhead BiS guide URLs and extract their trinket tier IDs."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from urllib.parse import urlparse

from extract_wowhead_trinket_tiers import (
    extract_guide_markup,
    extract_trinket_tier_list,
    fetch_html,
    filter_tiers,
    parse_tiers,
)


DEFAULT_URLS_FILE = Path(__file__).with_name("wowhead_bis_guide_urls.txt")
DEFAULT_OUTPUT_FILE = Path(__file__).with_name("wowhead_trinket_verification.json")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Verify Wowhead BiS guide URLs and extract trinket tier lists."
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
        help=f"Where to write the JSON report (default: {DEFAULT_OUTPUT_FILE}).",
    )
    parser.add_argument(
        "--tiers",
        default="S,A,B,C,D",
        help="Comma-separated tier labels to include in the report.",
    )
    parser.add_argument(
        "--timeout-note",
        action="store_true",
        help="No-op flag reserved for future rate-limit handling.",
    )
    return parser.parse_args()


def read_urls(path: Path) -> list[str]:
    urls = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        urls.append(line)
    return urls


def build_slug(url: str) -> str:
    parts = [part for part in urlparse(url).path.split("/") if part]
    if len(parts) >= 5:
        return "/".join(parts[2:5])
    return url


def verify_url(url: str, tiers_arg: str) -> dict[str, object]:
    result: dict[str, object] = {
        "url": url,
        "slug": build_slug(url),
        "ok": False,
    }

    try:
        html = fetch_html(url)
        markup = extract_guide_markup(html)
        tier_list_markup = extract_trinket_tier_list(markup)
        tiers = parse_tiers(tier_list_markup)
        filtered = filter_tiers(tiers, tiers_arg)
    except Exception as exc:
        result["error"] = str(exc)
        return result

    total_items = sum(len(item_ids) for item_ids in filtered.values())
    non_empty_tiers = [tier for tier, item_ids in filtered.items() if item_ids]

    result.update(
        {
            "ok": True,
            "total_items": total_items,
            "non_empty_tiers": non_empty_tiers,
            "tiers": filtered,
        }
    )
    return result


def main() -> int:
    args = parse_args()
    urls = read_urls(args.urls_file)

    if not urls:
        print("error: no guide URLs found in the input file", file=sys.stderr)
        return 1

    results = [verify_url(url, args.tiers) for url in urls]
    ok_count = sum(1 for result in results if result["ok"])
    failed = [result for result in results if not result["ok"]]

    report = {
        "source_file": str(args.urls_file),
        "tiers": [tier.strip().upper() for tier in args.tiers.split(",") if tier.strip()],
        "total_urls": len(urls),
        "ok_urls": ok_count,
        "failed_urls": len(failed),
        "results": results,
    }

    args.output.write_text(
        json.dumps(report, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )

    print(f"Checked {len(urls)} URLs")
    print(f"OK: {ok_count}")
    print(f"Failed: {len(failed)}")
    print(f"Report: {args.output}")

    if failed:
        print("Failures:")
        for result in failed:
            print(f"- {result['slug']}: {result['error']}")

    return 0 if not failed else 2


if __name__ == "__main__":
    raise SystemExit(main())
