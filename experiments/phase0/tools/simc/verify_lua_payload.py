#!/usr/bin/env python3
"""Cross-check the generated model in stock Lua 5.1 and record real timing."""

from __future__ import annotations

import argparse
import json
import pathlib
import subprocess

import numpy as np

import benchmark_models as models


ROOT = pathlib.Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "fixtures" / "simc" / "lua-runtime-benchmark.json"


def wsl_path(path: pathlib.Path) -> str:
    resolved = path.resolve()
    drive = resolved.drive.rstrip(":").lower()
    return f"/mnt/{drive}/{resolved.as_posix().split(':', 1)[1].lstrip('/')}"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--lua", type=pathlib.Path, required=True)
    args = parser.parse_args()

    dataset = models.load_dataset()
    train = dataset.split == "train"
    validation = dataset.split == "validation"
    mean = dataset.x[train].mean(axis=0)
    scale = dataset.x[train].std(axis=0)
    normalized = (dataset.x - mean) / scale
    target = np.log(dataset.dps)
    knots = models.piecewise_knots(normalized[train])
    coefficients, ridge, _ = models.choose_ridge(
        models.piecewise_design(normalized[train], knots),
        target[train],
        models.piecewise_design(normalized[validation], knots),
        target[validation],
    )

    lua_script = pathlib.Path(__file__).with_name("benchmark_lua.lua")
    payload = ROOT / "fixtures" / "simc" / "model-piecewise.lua"
    completed = subprocess.run(
        [
            "wsl.exe",
            wsl_path(args.lua),
            wsl_path(lua_script),
            wsl_path(payload),
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    runtime = json.loads(completed.stdout)
    differences = []
    for row in runtime["vectors"]:
        vector = np.array(row["input"], dtype=float)
        expected = float(
            (models.piecewise_design(((vector - mean) / scale).reshape(1, -1), knots)
            @ coefficients).item()
        )
        differences.append(abs(expected - row["logScore"]))

    report = {
        **runtime,
        "luaSourceSha256": "2640fc56a795f29d28ef15e13c34a47e223960b0240e8cb0a82d9b0738695333",
        "selectedRidge": ridge,
        "maxPythonLuaAbsoluteLogScoreDifference": max(differences),
        "crossLanguageAgreementTolerance": 1e-10,
    }
    report["verdict"] = (
        "PASS"
        if report["outOfDomainRejected"]
        and report["maxPythonLuaAbsoluteLogScoreDifference"] <= 1e-10
        else "FAIL"
    )
    OUTPUT.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    return 0 if report["verdict"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
