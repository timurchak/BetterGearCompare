#!/usr/bin/env python3
"""Extract trinket item IDs from a Wowhead guide tier list.

The script targets the embedded guide markup used by Wowhead pages such as:
https://www.wowhead.com/guide/classes/death-knight/frost/bis-gear

It can read either a live URL or a previously saved HTML file and returns
trinket item IDs grouped by tier letter.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import urllib.request
from pathlib import Path


DEFAULT_URL = "https://www.wowhead.com/guide/classes/death-knight/blood/bis-gear"
# Guides label tiers freely: besides S/A/B/C/D they also use S+, A+, F and even G.
# Tiers are kept in the order the guide lists them (best first), so no fixed list
# of labels is required anymore.
DEFAULT_TIERS = ()
BROWSER_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/133.0.0.0 Safari/537.36"
    ),
    "Accept": (
        "text/html,application/xhtml+xml,application/xml;q=0.9,"
        "image/avif,image/webp,image/apng,*/*;q=0.8"
    ),
    "Accept-Language": "en-US,en;q=0.9",
    "Cache-Control": "no-cache",
    "Pragma": "no-cache",
    "Referer": "https://www.wowhead.com/",
    "Upgrade-Insecure-Requests": "1",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extract item IDs from Wowhead's Trinket Tier List."
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
        help="Read HTML from a local file instead of downloading the page.",
    )
    parser.add_argument(
        "--tiers",
        default="",
        help=(
            "Optional comma-separated tier labels to keep, for example S,A,B. "
            "By default every tier the guide lists is kept, in guide order."
        ),
    )
    parser.add_argument(
        "--pretty",
        action="store_true",
        help="Pretty-print the resulting JSON.",
    )
    parser.add_argument(
        "--save-html",
        type=Path,
        help="Optional path to save the downloaded HTML for debugging or reuse.",
    )
    return parser.parse_args()


def load_html(args: argparse.Namespace) -> str:
    if args.html_file:
        return args.html_file.read_text(encoding="utf-8")

    html = fetch_html(args.url)
    if args.save_html:
        args.save_html.write_text(html, encoding="utf-8")
    return html


def fetch_html(url: str) -> str:
    fetch_errors: list[str] = []

    fetchers: list[tuple[str, object]] = [("curl_cffi", lambda: fetch_with_curl_cffi(url))]

    fetchers.extend(
        [
            ("urllib", lambda: fetch_with_urllib(url)),
            ("powershell", lambda: fetch_with_powershell(url)),
        ]
    )

    curl_path = shutil.which("curl.exe") or shutil.which("curl")
    if curl_path:
        fetchers.append(("curl", lambda: fetch_with_curl(curl_path, url)))

    for name, fetcher in fetchers:
        try:
            html = fetcher()
        except Exception as exc:
            fetch_errors.append(f"{name}: {exc}")
            continue

        if looks_like_wowhead_guide(html):
            return html

        fetch_errors.append(f"{name}: response did not contain Wowhead guide markup")

    raise ValueError(
        "Unable to download a usable Wowhead guide page. " + " | ".join(fetch_errors)
    )


def looks_like_wowhead_guide(html: str) -> bool:
    return "WH.markup.printHtml(" in html and '"guide-body"' in html


def fetch_with_curl_cffi(url: str) -> str:
    try:
        from curl_cffi import requests as curl_requests
    except ImportError as exc:
        raise RuntimeError(
            "curl_cffi is not installed. Install it with: python -m pip install --user curl_cffi"
        ) from exc

    response = curl_requests.get(
        url,
        headers=BROWSER_HEADERS,
        impersonate="chrome136",
        timeout=30,
    )
    response.raise_for_status()
    return response.text


def fetch_with_urllib(url: str) -> str:
    request = urllib.request.Request(url, headers=BROWSER_HEADERS)
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read().decode("utf-8", errors="replace")


def fetch_with_curl(curl_path: str, url: str) -> str:
    command = [
        curl_path,
        "-L",
        url,
        "-A",
        BROWSER_HEADERS["User-Agent"],
        "-H",
        f"Accept: {BROWSER_HEADERS['Accept']}",
        "-H",
        f"Accept-Language: {BROWSER_HEADERS['Accept-Language']}",
        "-H",
        f"Referer: {BROWSER_HEADERS['Referer']}",
    ]
    result = subprocess.run(
        command,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=60,
        check=True,
    )
    return result.stdout


def fetch_with_powershell(url: str) -> str:
    powershell = shutil.which("pwsh") or shutil.which("powershell") or "powershell"
    command = [
        powershell,
        "-NoProfile",
        "-Command",
        (
            "$ProgressPreference='SilentlyContinue'; "
            "$headers = @{"
            "'User-Agent'='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36';"
            "'Accept'='text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8';"
            "'Accept-Language'='en-US,en;q=0.9';"
            "'Referer'='https://www.wowhead.com/';"
            "}; "
            f"(Invoke-WebRequest -UseBasicParsing -Headers $headers '{url}').Content"
        ),
    ]
    result = subprocess.run(
        command,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=60,
        check=True,
    )
    return result.stdout


def extract_guide_markup(html: str) -> str:
    match = re.search(
        r'WH\.markup\.printHtml\("((?:\\.|[^"\\])*)",\s*"guide-body"',
        html,
        re.DOTALL,
    )
    if not match:
        raise ValueError("Could not find embedded Wowhead guide markup in the HTML.")

    return json.loads(f'"{match.group(1)}"')


def extract_trinket_tier_list(markup: str) -> str:
    header = (
        r"\[h3\s+toc=false\s+type=bar\]"
        r"\[color=[^\]]+\]\s*Trinket Tier List\s*\[/color\]"
        r"\[/h3\]"
    )
    section_match = re.search(
        header + r".*?(\[tier-list=rows grid\].*?\[/tier-list\])",
        markup,
        re.DOTALL,
    )
    if not section_match:
        raise ValueError("Could not find the Trinket Tier List block in the guide markup.")

    return section_match.group(1)


def parse_tiers(tier_list_markup: str) -> list[dict[str, object]]:
    """Return tiers in guide order: [{"label": "S+", "itemIDs": [...]}, ...]."""
    tiers: list[dict[str, object]] = []

    for tier_match in re.finditer(
        r"\[tier\](.*?)\[/tier\]",
        tier_list_markup,
        re.DOTALL,
    ):
        tier_block = tier_match.group(1)
        label_match = re.search(
            r"\[tier-label[^\]]*\]\s*([^\[\]]+?)\s*\[/tier-label\]",
            tier_block,
        )
        if not label_match:
            continue

        label = normalize_tier_label(label_match.group(1))
        if not label:
            continue

        ids = [
            int(item_id)
            for item_id in re.findall(r"\[icon-badge=(\d+)\b", tier_block)
        ]
        tiers.append({"label": label, "itemIDs": ids})

    if not tiers:
        raise ValueError("No tier entries were parsed from the Trinket Tier List block.")

    return tiers


def normalize_tier_label(raw_label: str) -> str:
    """Collapse a tier label to its printable form, for example "s+" -> "S+"."""
    label = re.sub(r"\s+", "", raw_label).upper()
    return label if re.fullmatch(r"[A-Z][+-]?", label) else ""


def filter_tiers(
    tiers: list[dict[str, object]], requested_tiers: str
) -> list[dict[str, object]]:
    """Keep only the requested labels; an empty request keeps every tier."""
    wanted = [
        normalize_tier_label(tier)
        for tier in requested_tiers.split(",")
        if tier.strip()
    ]
    if not wanted:
        return tiers

    return [tier for tier in tiers if tier["label"] in wanted]


def tiers_as_mapping(tiers: list[dict[str, object]]) -> dict[str, list[int]]:
    """Flatten parsed tiers into {label: [itemID, ...]} for reporting."""
    return {str(tier["label"]): list(tier["itemIDs"]) for tier in tiers}


def main() -> int:
    args = parse_args()

    try:
        html = load_html(args)
        markup = extract_guide_markup(html)
        tier_list_markup = extract_trinket_tier_list(markup)
        tiers = parse_tiers(tier_list_markup)
        filtered = filter_tiers(tiers, args.tiers)
    except Exception as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    if args.pretty:
        print(json.dumps(tiers_as_mapping(filtered), indent=2, ensure_ascii=False))
    else:
        print(json.dumps(tiers_as_mapping(filtered), ensure_ascii=False))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
