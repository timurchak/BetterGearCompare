#!/usr/bin/env python3
"""Deterministic model-based stress test for the tooltip revision algorithm.

This cannot prove Blizzard-frame behavior. It does prove the intended revision/key
algorithm under adversarial callback order and produces a reviewable event report.
"""

from __future__ import annotations

import json
import pathlib
import random
from dataclasses import dataclass, field


ROOT = pathlib.Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "fixtures" / "tooltip" / "offline-lifecycle-report.json"


@dataclass
class Tooltip:
    key: str | None = None
    revision: int = 0
    shown: bool = False
    cycle: int = 0
    blocks_in_cycle: int = 0
    rendered_key: str | None = None
    rendered_signature: str | None = None


@dataclass
class Entry:
    request_id: int
    status: str = "pending"
    waiters: list[tuple[int, int, str]] = field(default_factory=list)


class Harness:
    def __init__(self) -> None:
        self.tooltips = [Tooltip(), Tooltip()]
        self.repository: dict[str, Entry] = {}
        self.next_request = 0
        self.equipment_revision = 0
        self.stale_rejections = 0
        self.duplicate_suppressions = 0
        self.renders = 0
        self.refreshes = 0

    def _entry(self, key: str) -> Entry:
        if key not in self.repository:
            self.next_request += 1
            self.repository[key] = Entry(self.next_request)
        return self.repository[key]

    def show(self, index: int, key: str) -> None:
        tip = self.tooltips[index]
        tip.shown = True
        tip.cycle += 1
        tip.blocks_in_cycle = 0
        if tip.key != key:
            tip.revision += 1
            tip.key = key
            tip.rendered_signature = None
            tip.rendered_key = None
        self.process(index)

    def hide(self, index: int) -> None:
        tip = self.tooltips[index]
        tip.shown = False
        tip.revision += 1
        tip.key = None
        tip.rendered_signature = None
        tip.rendered_key = None

    def process(self, index: int) -> None:
        tip = self.tooltips[index]
        if not tip.shown or tip.key is None:
            return
        entry = self._entry(tip.key)
        if entry.status == "ready":
            signature = f"{tip.key}|{entry.request_id}|{self.equipment_revision}"
            if tip.rendered_signature == signature and tip.blocks_in_cycle >= 1:
                self.duplicate_suppressions += 1
                return
            tip.rendered_signature = signature
            tip.rendered_key = tip.key
            tip.blocks_in_cycle += 1
            self.renders += 1
        elif entry.status == "pending":
            waiter = (index, tip.revision, tip.key)
            if waiter not in entry.waiters:
                entry.waiters.append(waiter)

    def resolve(self, key: str, success: bool = True) -> None:
        entry = self._entry(key)
        if entry.status != "pending":
            return
        entry.status = "ready" if success else "failed"
        waiters, entry.waiters = entry.waiters, []
        for index, revision, waiter_key in waiters:
            tip = self.tooltips[index]
            if tip.shown and tip.revision == revision and tip.key == waiter_key:
                self.refreshes += 1
                tip.cycle += 1
                tip.blocks_in_cycle = 0
                self.process(index)
            else:
                self.stale_rejections += 1

    def equipment_change(self) -> None:
        self.equipment_revision += 1
        for index, tip in enumerate(self.tooltips):
            if tip.shown and tip.key is not None:
                tip.cycle += 1
                tip.blocks_in_cycle = 0
                self.process(index)

    def assert_invariants(self) -> None:
        for tip in self.tooltips:
            if tip.blocks_in_cycle > 1:
                raise AssertionError("duplicate addon block in one tooltip cycle")
            if tip.rendered_key is not None and tip.rendered_key != tip.key:
                raise AssertionError("stale item rendered into tooltip")


def explicit_scenarios() -> list[dict]:
    rows = []

    h = Harness()
    h.show(0, "item:A")
    h.resolve("item:A")
    h.process(0)
    h.assert_invariants()
    rows.append({"name": "uncached-then-refresh", "passed": h.renders == 1 and h.duplicate_suppressions == 1})

    h = Harness()
    h.show(0, "item:A")
    h.hide(0)
    h.resolve("item:A")
    h.assert_invariants()
    rows.append({"name": "hide-before-resolve", "passed": h.renders == 0 and h.stale_rejections == 1})

    h = Harness()
    h.show(0, "item:A")
    h.show(0, "item:B")
    h.resolve("item:A")
    h.resolve("item:B")
    h.assert_invariants()
    rows.append({"name": "item-change-before-resolve", "passed": h.tooltips[0].rendered_key == "item:B" and h.stale_rejections == 1})

    h = Harness()
    h.show(0, "item:A")
    h.show(1, "item:A")
    h.resolve("item:A")
    h.assert_invariants()
    rows.append({"name": "coalesced-two-tooltips", "passed": h.renders == 2 and len(h.repository) == 1})

    h = Harness()
    h.show(0, "item:A")
    h.resolve("item:A")
    h.equipment_change()
    h.process(0)
    h.assert_invariants()
    rows.append({"name": "equipment-refresh-idempotent", "passed": h.renders == 2 and h.duplicate_suppressions == 1})

    h = Harness()
    h.show(0, "item:A")
    for _ in range(100):
        h.process(0)
    h.resolve("item:A")
    h.assert_invariants()
    rows.append({
        "name": "repeated-pending-postcalls-coalesce",
        "passed": h.renders == 1 and h.refreshes == 1 and len(h.repository["item:A"].waiters) == 0,
    })

    h = Harness()
    h.show(0, "item:A")
    h.show(0, "item:B")
    h.show(0, "item:C")
    h.resolve("item:C")
    h.resolve("item:B")
    h.resolve("item:A")
    h.assert_invariants()
    rows.append({
        "name": "rapid-item-churn-reverse-callback-order",
        "passed": h.tooltips[0].rendered_key == "item:C" and h.stale_rejections == 2,
    })

    return rows


def randomized(seed: int = 20260905, actions: int = 100_000) -> dict:
    rng = random.Random(seed)
    h = Harness()
    keys = [f"item:{index}" for index in range(2048)]
    for _ in range(actions):
        operation = rng.randrange(6)
        tip = rng.randrange(2)
        key = rng.choice(keys)
        if operation == 0:
            h.show(tip, key)
        elif operation == 1:
            h.hide(tip)
        elif operation == 2:
            h.process(tip)
        elif operation == 3:
            active = h.tooltips[tip].key
            h.resolve(active if active is not None and rng.random() < 0.75 else key, True)
        elif operation == 4:
            h.resolve(key, False)
        else:
            h.equipment_change()
        h.assert_invariants()
    return {
        "seed": seed,
        "actions": actions,
        "passed": True,
        "renders": h.renders,
        "refreshes": h.refreshes,
        "staleRejections": h.stale_rejections,
        "duplicateSuppressions": h.duplicate_suppressions,
        "repositoryEntries": len(h.repository),
    }


def main() -> int:
    scenarios = explicit_scenarios()
    random_report = randomized()
    report = {
        "schema": 1,
        "verdict": "PASS" if all(row["passed"] for row in scenarios) and random_report["passed"] else "FAIL",
        "scope": "offline revision/key state-machine only; not a WoW client integration result",
        "explicitScenarios": scenarios,
        "randomized": random_report,
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    return 0 if report["verdict"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
