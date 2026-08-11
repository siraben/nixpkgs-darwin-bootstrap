#!/usr/bin/env python3
"""Summarize paired filesystem, VM, swap, and memory-pressure evidence."""

from __future__ import annotations

import argparse
import csv
import math
import re
import statistics
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path


VM_STATE_GAUGES = {
    "pages_free",
    "pages_active",
    "pages_inactive",
    "pages_speculative",
    "pages_throttled",
    "pages_wired_down",
    "pages_purgeable",
    "pages_occupied_by_compressor",
    "file_backed_pages",
    "anonymous_pages",
    "pages_stored_in_compressor",
}
VM_COUNTERS = {"pageins", "pageouts", "swapins", "swapouts"}


@dataclass(frozen=True)
class Metric:
    value: float
    unit: str


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--summary-output", type=Path, required=True)
    return parser.parse_args()


def normalized_label(label: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", label.lower()).strip("_")


def scaled_bytes(number: str, suffix: str) -> float:
    scales = {"K": 1024, "M": 1024**2, "G": 1024**3, "T": 1024**4}
    if suffix not in scales:
        raise ValueError(f"unsupported byte suffix {suffix!r}")
    return float(number) * scales[suffix]


def parse_disk(path: Path) -> dict[str, Metric]:
    candidate: list[str] | None = None
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        fields = line.split()
        if len(fields) >= 5 and all(field.isdigit() for field in fields[1:4]):
            candidate = fields
    if candidate is None:
        raise SystemExit(f"cannot parse df snapshot {path}")
    capacity = candidate[4]
    if not capacity.endswith("%"):
        raise SystemExit(f"invalid df capacity in {path}: {capacity!r}")
    return {
        "filesystem_total_bytes": Metric(float(candidate[1]) * 1024, "bytes"),
        "filesystem_used_bytes": Metric(float(candidate[2]) * 1024, "bytes"),
        "filesystem_available_bytes": Metric(float(candidate[3]) * 1024, "bytes"),
        "filesystem_capacity_percent": Metric(float(capacity[:-1]), "percent"),
    }


def parse_memory(path: Path) -> dict[str, Metric]:
    text = path.read_text(encoding="utf-8", errors="replace")
    page_size_match = re.search(r"page size of (\d+) bytes", text)
    if page_size_match is None:
        raise SystemExit(f"missing vm_stat page size in {path}")
    page_size = int(page_size_match.group(1))
    metrics: dict[str, Metric] = {
        "vm_page_size_bytes": Metric(float(page_size), "bytes")
    }
    for line in text.splitlines():
        match = re.match(r"^([^:]+):\s+(\d+)\.\s*$", line)
        if match is None:
            continue
        label = normalized_label(match.group(1))
        value = int(match.group(2))
        if label in VM_STATE_GAUGES:
            metrics[f"vm_{label}_bytes"] = Metric(float(value * page_size), "bytes")
        elif label in VM_COUNTERS:
            metrics[f"vm_{label}"] = Metric(float(value), "count")

    swap = re.search(
        r"vm\.swapusage:\s+total\s+=\s+([0-9.]+)([KMGT])\s+"
        r"used\s+=\s+([0-9.]+)([KMGT])\s+free\s+=\s+([0-9.]+)([KMGT])",
        text,
    )
    if swap is None:
        raise SystemExit(f"missing vm.swapusage in {path}")
    metrics.update(
        {
            "swap_total_bytes": Metric(scaled_bytes(swap[1], swap[2]), "bytes"),
            "swap_used_bytes": Metric(scaled_bytes(swap[3], swap[4]), "bytes"),
            "swap_free_bytes": Metric(scaled_bytes(swap[5], swap[6]), "bytes"),
        }
    )
    pressure = re.search(r"System-wide memory free percentage:\s*([0-9.]+)%", text)
    if pressure is None:
        raise SystemExit(f"missing memory_pressure percentage in {path}")
    metrics["memory_free_percent"] = Metric(float(pressure[1]), "percent")
    return metrics


def paired_inputs(root: Path) -> list[tuple[str, Path, Path]]:
    pairs: list[tuple[str, Path, Path]] = []
    for kind in ("disk", "memory"):
        for before in sorted(root.rglob(f"*{kind}-before*.txt")):
            after_name = before.name.replace(f"{kind}-before", f"{kind}-after", 1)
            after = before.with_name(after_name)
            if not after.is_file():
                raise SystemExit(f"missing after snapshot for {before}: expected {after}")
            pairs.append((kind, before, after))
    if not pairs:
        raise SystemExit(f"no paired system-state inputs under {root}")
    return pairs


def format_number(value: float) -> str:
    if not math.isfinite(value):
        raise SystemExit("non-finite system-state value")
    return f"{value:.9f}"


def main() -> None:
    args = arguments()
    if not args.root.is_dir():
        raise SystemExit(f"system-state root is not a directory: {args.root}")
    rows: list[dict[str, str]] = []
    summary_values: dict[tuple[str, str, str, str], list[tuple[float, float, float]]] = (
        defaultdict(list)
    )
    for kind, before_path, after_path in paired_inputs(args.root):
        parser = parse_disk if kind == "disk" else parse_memory
        before = parser(before_path)
        after = parser(after_path)
        if before.keys() != after.keys():
            raise SystemExit(
                f"metric set differs between {before_path} and {after_path}: "
                f"{sorted(before)} versus {sorted(after)}"
            )
        relative = before_path.relative_to(args.root)
        profile = relative.parts[0] if len(relative.parts) > 1 else "."
        for metric in sorted(before):
            before_metric = before[metric]
            after_metric = after[metric]
            if before_metric.unit != after_metric.unit:
                raise SystemExit(f"unit differs for {metric} in {before_path}")
            delta = after_metric.value - before_metric.value
            rows.append(
                {
                    "profile": profile,
                    "kind": kind,
                    "metric": metric,
                    "unit": before_metric.unit,
                    "evidence_before": relative.as_posix(),
                    "evidence_after": after_path.relative_to(args.root).as_posix(),
                    "before_value": format_number(before_metric.value),
                    "after_value": format_number(after_metric.value),
                    "delta": format_number(delta),
                }
            )
            summary_values[(profile, kind, metric, before_metric.unit)].append(
                (before_metric.value, after_metric.value, delta)
            )

    fields = list(rows[0])
    with args.output.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(
            stream, fieldnames=fields, delimiter="\t", lineterminator="\n"
        )
        writer.writeheader()
        writer.writerows(rows)

    summary_rows: list[dict[str, str | int]] = []
    for (profile, kind, metric, unit), values in sorted(summary_values.items()):
        before_values = [value[0] for value in values]
        after_values = [value[1] for value in values]
        deltas = [value[2] for value in values]
        summary_rows.append(
            {
                "profile": profile,
                "kind": kind,
                "metric": metric,
                "unit": unit,
                "pairs": len(values),
                "median_before": format_number(statistics.median(before_values)),
                "median_after": format_number(statistics.median(after_values)),
                "median_delta": format_number(statistics.median(deltas)),
                "mean_delta": format_number(statistics.mean(deltas)),
                "min_delta": format_number(min(deltas)),
                "max_delta": format_number(max(deltas)),
            }
        )
    with args.summary_output.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(
            stream,
            fieldnames=list(summary_rows[0]),
            delimiter="\t",
            lineterminator="\n",
        )
        writer.writeheader()
        writer.writerows(summary_rows)


if __name__ == "__main__":
    main()
