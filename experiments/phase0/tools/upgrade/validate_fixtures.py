#!/usr/bin/env python3
"""Validate JSON exports captured by Phase0UpgradeProbe in the Retail client."""

from __future__ import annotations

import argparse
import json
import pathlib
import sys
from typing import Any


ROOT = pathlib.Path(__file__).resolve().parents[2]
DEFAULT_MANIFEST = ROOT / "fixtures" / "upgrade" / "season-manifest.generated.json"
DEFAULT_CLIENT_DIR = ROOT / "fixtures" / "upgrade" / "client"
DEFAULT_REPORT = ROOT / "fixtures" / "upgrade" / "validation-report.json"
CURRENT_CATEGORIES = {"armor", "ring", "neck", "socketed"}
LEGACY_CATEGORIES = {"old-season", "upgrade-like-ineligible"}


def load_json(path: pathlib.Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def stat_delta(expected: dict[str, float], actual: dict[str, float]) -> dict[str, float]:
    keys = set(expected) | set(actual)
    return {
        key: actual.get(key, 0) - expected.get(key, 0)
        for key in sorted(keys)
        if actual.get(key, 0) != expected.get(key, 0)
    }


def validate_fixture(data: dict, bonus_to_rank: dict[int, dict]) -> dict:
    errors: list[str] = []
    category = data.get("category")
    capture = data.get("capture", data)
    source = capture.get("source") or {}
    projections = capture.get("projections") or []

    if capture.get("tooltipParsingUsed") is not False:
        errors.append("tooltipParsingUsed must be explicitly false")
    if not source.get("fullItemLink"):
        errors.append("missing exact source fullItemLink")
    if source.get("itemID") is None:
        errors.append("missing source itemID")

    source_bonus = source.get("upgradeBonusID")
    manifest_rank = bonus_to_rank.get(source_bonus)

    if category in CURRENT_CATEGORIES:
        if not manifest_rank:
            errors.append(f"current-season category has unknown rank bonus {source_bonus}")
        if source.get("currentlyUpgradeable") is not True:
            errors.append("owned current-season fixture was not live-upgradeable")
        if manifest_rank:
            expected_future = manifest_rank["maxRank"] - manifest_rank["rank"]
            if expected_future < 1:
                errors.append("current-season fixture is already max rank and cannot validate projection")
            if len(projections) != expected_future:
                errors.append(
                    f"expected {expected_future} future ranks, got {len(projections)}"
                )

    if category in LEGACY_CATEGORIES:
        if source.get("currentlyUpgradeable") is not False:
            errors.append("legacy/ineligible item was treated as currently upgradeable")
        if any(row.get("verified") for row in projections):
            errors.append("legacy/ineligible item has a verified current-season projection")

    projection_results = []
    for row in projections:
        bonus_id = row.get("targetBonusID")
        expected = bonus_to_rank.get(bonus_id)
        row_errors: list[str] = []
        if not expected:
            row_errors.append(f"unknown target bonus {bonus_id}")
        else:
            if row.get("targetRank") != expected["rank"]:
                row_errors.append("target rank does not match manifest")
            if row.get("expectedItemLevel") != expected["itemLevel"]:
                row_errors.append("fixture expected item level does not match manifest")
            if row.get("projectedItemLevel") != expected["itemLevel"]:
                row_errors.append("projected item level mismatch")

        expected_stats = row.get("expectedStats")
        projected_stats = row.get("projectedStats")
        mismatch = None
        if isinstance(expected_stats, dict):
            if projected_stats is None:
                row_errors.append("expected stats exist but projected stats are missing")
            else:
                mismatch = stat_delta(expected_stats, projected_stats)
                if mismatch:
                    row_errors.append(f"stat mismatch: {mismatch}")
        elif isinstance(expected_stats, list):
            mismatch = row.get("statMismatches", row.get("vendorStatMismatches")) or []
            if projected_stats is None:
                row_errors.append("expected stats exist but projected stats are missing")
            if row.get("vendorStatValuesMatched") is not True:
                row_errors.append(f"structured vendor stat values did not match: {mismatch}")
        elif row.get("authoritativeExpectedSource") == "upgrade-vendor":
            row_errors.append("upgrade-vendor source declared but expectedStats absent")

        if row.get("verified") is True and row_errors:
            row_errors.append("projection claims verified despite mismatches")
        if category in CURRENT_CATEGORIES and row.get("verified") is not True:
            row_errors.append("current-season projection is not independently verified")
        projection_results.append(
            {
                "targetRank": row.get("targetRank"),
                "targetBonusID": bonus_id,
                "statDelta": mismatch,
                "errors": row_errors,
            }
        )
        errors.extend(f"rank {row.get('targetRank')}: {item}" for item in row_errors)

    return {
        "fixtureID": data.get("fixtureID"),
        "category": category,
        "passed": not errors,
        "errors": errors,
        "projections": projection_results,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=pathlib.Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--client-dir", type=pathlib.Path, default=DEFAULT_CLIENT_DIR)
    parser.add_argument("--report", type=pathlib.Path, default=DEFAULT_REPORT)
    args = parser.parse_args()

    manifest = load_json(args.manifest)
    bonus_to_rank: dict[int, dict] = {}
    for group in manifest["groups"]:
        for rank in group["ranks"]:
            bonus_to_rank[rank["bonusID"]] = {
                **rank,
                "groupID": group["groupID"],
                "track": group["track"],
            }

    paths = sorted(args.client_dir.glob("*.json")) if args.client_dir.exists() else []
    results = [validate_fixture(load_json(path), bonus_to_rank) for path in paths]
    categories = {row["category"] for row in results if row["passed"]}
    required = CURRENT_CATEGORIES | {"crafted"} | LEGACY_CATEGORIES
    missing = sorted(required - categories)
    failures = [row for row in results if not row["passed"]]

    if not paths:
        verdict = "PARTIAL"
        reason = "no live-client fixtures were available on this host"
    elif failures:
        verdict = "FAIL"
        reason = "one or more captured fixtures failed validation"
    elif missing:
        verdict = "PARTIAL"
        reason = "available fixtures passed, but required categories are missing"
    else:
        verdict = "PASS"
        reason = "all required live-client categories and projection checks passed"

    report = {
        "schema": 1,
        "verdict": verdict,
        "reason": reason,
        "manifestBuild": manifest["wowBuild"],
        "fixtureCount": len(paths),
        "passedFixtureCount": sum(row["passed"] for row in results),
        "missingCategories": missing,
        "results": results,
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    return 0 if verdict == "PASS" else 2 if verdict == "PARTIAL" else 1


if __name__ == "__main__":
    raise SystemExit(main())
