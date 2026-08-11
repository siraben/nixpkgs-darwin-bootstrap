#!/usr/bin/env python3
"""Summarize repeated bootstrap stage timing TSV files.

This is host-side review tooling and is not used to produce bootstrap outputs.
"""

from __future__ import annotations

import argparse
import csv
import glob
import math
import statistics
from collections import defaultdict
from pathlib import Path


METRIC_ALIASES = {
    "elapsed_seconds": ("elapsed_seconds",),
    "real_seconds": ("real_seconds", "client_real_seconds"),
    "user_seconds": ("user_seconds", "client_user_seconds"),
    "sys_seconds": ("sys_seconds", "client_sys_seconds"),
    "max_rss_bytes": ("max_rss_bytes", "client_max_rss_bytes"),
    "major_faults": ("major_faults",),
    "minor_faults": ("minor_faults",),
    "fs_inputs": ("fs_inputs",),
    "fs_outputs": ("fs_outputs",),
    "output_bytes": ("output_bytes",),
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-glob", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--expected-samples", type=int)
    parser.add_argument("--one-sample-per-input", action="store_true")
    return parser.parse_args()


def percentile(values: list[float], fraction: float) -> float:
    ordered = sorted(values)
    if len(ordered) == 1:
        return ordered[0]
    position = (len(ordered) - 1) * fraction
    lower = math.floor(position)
    upper = math.ceil(position)
    if lower == upper:
        return ordered[lower]
    weight = position - lower
    return ordered[lower] * (1 - weight) + ordered[upper] * weight


def main() -> None:
    args = parse_args()
    inputs = sorted(glob.glob(args.input_glob))
    if not inputs:
        raise SystemExit(f"no inputs matched {args.input_glob!r}")

    samples: dict[str, dict[str, list[float]]] = defaultdict(
        lambda: defaultdict(list)
    )
    failures: dict[str, int] = defaultdict(int)
    stage_order: list[str] = []
    expected_file_stage_order: list[str] | None = None
    declared_metrics: set[str] = set()
    for input_name in inputs:
        file_stage_order: list[str] = []
        file_stages: set[str] = set()
        with Path(input_name).open(newline="", encoding="utf-8") as stream:
            reader = csv.DictReader(stream, delimiter="\t")
            required = {"stage", "exit_code"}
            elapsed_aliases = METRIC_ALIASES["elapsed_seconds"]
            if (
                reader.fieldnames is None
                or not required.issubset(reader.fieldnames)
                or not any(alias in reader.fieldnames for alias in elapsed_aliases)
            ):
                raise SystemExit(f"invalid timing header in {input_name}")
            present_metric_aliases = {
                metric: tuple(
                    alias for alias in aliases if alias in reader.fieldnames
                )
                for metric, aliases in METRIC_ALIASES.items()
            }
            declared_metrics.update(
                metric for metric, aliases in present_metric_aliases.items() if aliases
            )
            for row_number, row in enumerate(reader, start=2):
                stage = (row.get("stage") or "").strip()
                if not stage:
                    raise SystemExit(
                        f"blank stage in {input_name} row {row_number}"
                    )
                if args.one_sample_per_input and stage in file_stages:
                    raise SystemExit(
                        f"duplicate stage {stage!r} in accepted input {input_name}"
                    )
                file_stages.add(stage)
                file_stage_order.append(stage)
                if stage not in stage_order:
                    stage_order.append(stage)
                try:
                    exit_code = int(row["exit_code"])
                except (TypeError, ValueError) as error:
                    raise SystemExit(
                        f"invalid exit_code in {input_name} row {row_number}"
                    ) from error
                if exit_code:
                    failures[stage] += 1
                    continue
                for metric, aliases in present_metric_aliases.items():
                    if not aliases:
                        continue
                    value_text = next(
                        (
                            row.get(alias, "")
                            for alias in aliases
                            if row.get(alias, "")
                        ),
                        "",
                    )
                    if not value_text:
                        raise SystemExit(
                            f"missing declared metric {metric} for successful "
                            f"stage {stage!r} in {input_name} row {row_number}"
                        )
                    try:
                        value = float(value_text)
                    except ValueError as error:
                        raise SystemExit(
                            f"invalid {metric} for stage {stage!r} in "
                            f"{input_name} row {row_number}"
                        ) from error
                    if not math.isfinite(value) or value < 0:
                        raise SystemExit(
                            f"non-finite or negative {metric} for stage "
                            f"{stage!r} in {input_name} row {row_number}"
                        )
                    samples[stage][metric].append(value)
        if args.one_sample_per_input:
            if not file_stage_order:
                raise SystemExit(f"accepted timing input is empty: {input_name}")
            if expected_file_stage_order is None:
                expected_file_stage_order = file_stage_order
            elif file_stage_order != expected_file_stage_order:
                raise SystemExit(
                    f"stage order/set in {input_name} differs from the first "
                    "accepted input"
                )

    # A metric column in any accepted input declares that metric for the whole
    # campaign.  Otherwise a truncated file can silently contribute fewer
    # samples to (for example) RSS or filesystem medians than to wall time.
    for stage in stage_order:
        successful_rows = len(samples[stage]["elapsed_seconds"])
        for metric in declared_metrics:
            metric_rows = len(samples[stage][metric])
            if metric_rows != successful_rows:
                raise SystemExit(
                    f"declared metric {metric} has {metric_rows} samples for "
                    f"stage {stage!r}; expected {successful_rows} successful rows"
                )

    if args.expected_samples is not None:
        if args.expected_samples < 1:
            raise SystemExit("--expected-samples must be positive")
        if args.one_sample_per_input and len(inputs) != args.expected_samples:
            raise SystemExit(
                f"found {len(inputs)} accepted timing inputs; expected exactly "
                f"{args.expected_samples}"
            )
        for stage in stage_order:
            valid = len(samples[stage]["elapsed_seconds"])
            if valid != args.expected_samples or failures[stage]:
                raise SystemExit(
                    f"stage {stage!r} has {valid} valid and {failures[stage]} "
                    f"failed samples; expected exactly {args.expected_samples} valid"
                )

    elapsed_medians = {
        stage: statistics.median(metrics["elapsed_seconds"])
        for stage, metrics in samples.items()
        if metrics["elapsed_seconds"]
    }
    total_median = sum(elapsed_medians.values())
    ranks = {
        stage: rank
        for rank, (stage, _) in enumerate(
            sorted(elapsed_medians.items(), key=lambda item: item[1], reverse=True),
            start=1,
        )
    }

    fieldnames = [
        "stage",
        "rank_by_median",
        "valid_samples",
        "failed_samples",
        "median_seconds",
        "median_share_percent",
        "mean_seconds",
        "min_seconds",
        "max_seconds",
        "stddev_seconds",
        "mad_seconds",
        "cv_percent",
        "p95_seconds",
        "median_real_seconds",
        "median_user_seconds",
        "median_sys_seconds",
        "median_max_rss_bytes",
        "median_major_faults",
        "median_minor_faults",
        "median_fs_inputs",
        "median_fs_outputs",
        "median_output_bytes",
    ]
    with Path(args.output).open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(
            stream, delimiter="\t", fieldnames=fieldnames, lineterminator="\n"
        )
        writer.writeheader()
        for stage in stage_order:
            values = samples[stage]["elapsed_seconds"]
            if not values:
                writer.writerow(
                    {
                        "stage": stage,
                        "valid_samples": 0,
                        "failed_samples": failures[stage],
                    }
                )
                continue
            median = statistics.median(values)
            mean = statistics.mean(values)
            stddev = statistics.stdev(values) if len(values) > 1 else 0.0
            mad = statistics.median([abs(value - median) for value in values])
            writer.writerow(
                {
                    "stage": stage,
                    "rank_by_median": ranks[stage],
                    "valid_samples": len(values),
                    "failed_samples": failures[stage],
                    "median_seconds": f"{median:.9f}",
                    "median_share_percent": f"{(100 * median / total_median) if total_median else 0:.6f}",
                    "mean_seconds": f"{mean:.9f}",
                    "min_seconds": f"{min(values):.9f}",
                    "max_seconds": f"{max(values):.9f}",
                    "stddev_seconds": f"{stddev:.9f}",
                    "mad_seconds": f"{mad:.9f}",
                    "cv_percent": f"{(100 * stddev / mean) if mean else 0:.6f}",
                    "p95_seconds": f"{percentile(values, 0.95):.9f}",
                    **{
                        f"median_{metric}": (
                            f"{statistics.median(samples[stage][metric]):.9f}"
                            if samples[stage][metric]
                            else ""
                        )
                        for metric in METRIC_ALIASES
                        if metric != "elapsed_seconds"
                    },
                }
            )


if __name__ == "__main__":
    main()
