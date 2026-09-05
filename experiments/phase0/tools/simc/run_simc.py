#!/usr/bin/env python3
"""Run the pinned SimulationCraft profile over generated stat samples."""

from __future__ import annotations

import argparse
import csv
import json
import pathlib
import re
import subprocess
import time


ROOT = pathlib.Path(__file__).resolve().parents[2]
FIXTURES = ROOT / "fixtures" / "simc"
LOCK_PATH = pathlib.Path(__file__).with_name("simc.lock.json")
SAMPLES_PATH = FIXTURES / "samples.csv"
STATE_OUTPUT = FIXTURES / "simc-states.csv"
RUN_META_OUTPUT = FIXTURES / "simc-run-metadata.json"
STAT_OPTIONS = {
    "primary": "gear_strength",
    "crit": "gear_crit_rating",
    "haste": "gear_haste_rating",
    "mastery": "gear_mastery_rating",
    "versatility": "gear_versatility_rating",
}


def read_rows(path: pathlib.Path) -> list[dict]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def verify(simc: pathlib.Path, source: pathlib.Path, lock: dict) -> str:
    commit = subprocess.check_output(
        ["git", "-C", str(source), "rev-parse", "HEAD"], text=True
    ).strip()
    if commit != lock["commit"]:
        raise SystemExit(f"SimC source commit {commit} != lock {lock['commit']}")

    output = subprocess.run(
        [str(simc), "spell_query=spell.id=1"],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=True,
    ).stdout
    first_line = output.splitlines()[0]
    for required in (lock["reportedVersion"], lock["wowBuild"], lock["commit"][:7]):
        if required not in first_line:
            raise SystemExit(f"SimC version line missing {required!r}: {first_line}")
    return first_line


def write_profilesets(path: pathlib.Path, rows: list[dict]) -> None:
    lines = []
    for row in rows:
        sample_id = row["sample_id"]
        for column, option in STAT_OPTIONS.items():
            lines.append(f'profileset."{sample_id}"+={option}={row[column]}')
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def run_batch(
    simc: pathlib.Path,
    source: pathlib.Path,
    lock: dict,
    name: str,
    rows: list[dict],
    iterations: int,
    max_time: int,
    vary_combat_length: float,
) -> tuple[dict[str, dict], dict]:
    profile = source / lock["profile"]
    profilesets = FIXTURES / f"profilesets-{name}.simc"
    json_output = FIXTURES / f"simc-{name}.json"
    text_output = FIXTURES / f"simc-{name}.log"
    write_profilesets(profilesets, rows)

    command = [
        str(simc),
        str(profile),
        str(profilesets),
        f"iterations={iterations}",
        "threads=8",
        "fixed_time=1",
        f"max_time={max_time}",
        f"vary_combat_length={vary_combat_length}",
        "deterministic=1",
        "seed=20260905",
        f"json2={json_output}",
        "html=",
        "output=",
    ]
    print(f"RUN {name}: states={len(rows)} iterations={iterations}", flush=True)
    started = time.perf_counter()
    process = subprocess.run(
        command,
        cwd=source,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    elapsed = time.perf_counter() - started
    text_output.write_text(process.stdout, encoding="utf-8")
    if process.returncode != 0:
        tail = "\n".join(process.stdout.splitlines()[-40:])
        raise SystemExit(f"SimC batch {name} failed ({process.returncode}):\n{tail}")

    report = json.loads(json_output.read_text(encoding="utf-8"))
    result_rows = report["sim"]["profilesets"]["results"]
    by_id = {row["name"].strip('"'): row for row in result_rows}
    missing = sorted({row["sample_id"] for row in rows} - set(by_id))
    if missing:
        raise SystemExit(f"SimC omitted {len(missing)} profilesets: {missing[:5]}")
    return by_id, {
        "batch": name,
        "states": len(rows),
        "iterationsRequested": iterations,
        "maxTimeSeconds": max_time,
        "varyCombatLength": vary_combat_length,
        "wallSeconds": elapsed,
        "profilesetsFile": profilesets.name,
        "rawJsonFile": json_output.name,
        "textLogFile": text_output.name,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--simc", required=True, type=pathlib.Path)
    parser.add_argument("--simc-source", required=True, type=pathlib.Path)
    parser.add_argument("--train-iterations", type=int, default=400)
    parser.add_argument("--test-iterations", type=int, default=2000)
    parser.add_argument("--max-time", type=int, default=300)
    parser.add_argument("--vary-combat-length", type=float, default=0.2)
    args = parser.parse_args()

    lock = json.loads(LOCK_PATH.read_text(encoding="utf-8"))
    version_line = verify(args.simc, args.simc_source, lock)
    rows = read_rows(SAMPLES_PATH)
    trainval = [row for row in rows if row["split"] != "test"]
    test = [row for row in rows if row["split"] == "test"]

    all_results: dict[str, dict] = {}
    batch_metadata = []
    for name, batch, iterations in (
        ("train-validation", trainval, args.train_iterations),
        ("test", test, args.test_iterations),
    ):
        results, metadata = run_batch(
            args.simc,
            args.simc_source,
            lock,
            name,
            batch,
            iterations,
            args.max_time,
            args.vary_combat_length,
        )
        all_results.update(results)
        batch_metadata.append(metadata)
        print(f"PASS {name}: {metadata['wallSeconds']:.2f}s", flush=True)

    output_fields = list(rows[0].keys()) + [
        "simc_dps",
        "simc_median_dps",
        "simc_stddev",
        "simc_mean_stddev",
        "simc_mean_error",
        "simc_iterations",
        "simc_relative_mean_error",
    ]
    with STATE_OUTPUT.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=output_fields)
        writer.writeheader()
        for row in rows:
            result = all_results[row["sample_id"]]
            enriched = dict(row)
            enriched.update(
                {
                    "simc_dps": result["mean"],
                    "simc_median_dps": result["median"],
                    "simc_stddev": result["stddev"],
                    "simc_mean_stddev": result["mean_stddev"],
                    "simc_mean_error": result["mean_error"],
                    "simc_iterations": result["iterations"],
                    "simc_relative_mean_error": result["mean_error"] / result["mean"],
                }
            )
            writer.writerow(enriched)

    metadata = {
        "schema": 1,
        "versionLine": version_line,
        "simcCommit": lock["commit"],
        "wowBuild": lock["wowBuild"],
        "profile": lock["profile"],
        "profileSHA256": subprocess.check_output(
            [
                "git",
                "-C",
                str(args.simc_source),
                "hash-object",
                str(args.simc_source / lock["profile"]),
            ],
            text=True,
        ).strip(),
        "configuration": {
            "fightStyle": "Patchwerk/default profile behavior",
            "fixedTime": True,
            "maxTimeSeconds": args.max_time,
            "varyCombatLength": args.vary_combat_length,
            "deterministic": True,
            "seed": 20260905,
            "threads": 8,
        },
        "batches": batch_metadata,
    }
    RUN_META_OUTPUT.write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    print(f"PASS merged states: {STATE_OUTPUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
