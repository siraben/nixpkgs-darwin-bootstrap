#!/usr/bin/env python3
"""Summarize accepted paired GCC object-reuse benchmark samples."""

from __future__ import annotations

import argparse
import csv
import math
import statistics
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--pairs-output", required=True)
    parser.add_argument("--summary-output", required=True)
    parser.add_argument("--expected-pairs", type=int)
    return parser.parse_args()


def median_or_blank(values: list[float]) -> str:
    return f"{statistics.median(values):.9f}" if values else ""


def exact_two_sided_sign_test(positive: int, negative: int) -> float:
    observations = positive + negative
    if not observations:
        return 1.0
    tail = min(positive, negative)
    probability = 2 * sum(
        math.comb(observations, successes)
        for successes in range(tail + 1)
    ) / (2**observations)
    return min(1.0, probability)


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
    pairs: dict[int, dict[str, tuple[int, float]]] = {}
    with Path(args.input).open(newline="", encoding="utf-8") as stream:
        reader = csv.DictReader(stream, delimiter="\t")
        required = {"pair", "order", "stage", "exit_code", "elapsed_seconds"}
        if reader.fieldnames is None or not required.issubset(reader.fieldnames):
            raise SystemExit(f"invalid paired-sample header in {args.input}")
        for row_number, row in enumerate(reader, start=2):
            try:
                pair = int(row["pair"])
                position = int(row["order"])
                exit_code = int(row["exit_code"])
                elapsed = float(row["elapsed_seconds"])
            except (TypeError, ValueError) as error:
                raise SystemExit(
                    f"invalid paired-sample value in {args.input} row {row_number}"
                ) from error
            if pair < 1:
                raise SystemExit(f"invalid pair id {pair} in row {row_number}")
            if not math.isfinite(elapsed) or elapsed <= 0:
                raise SystemExit(
                    f"non-finite or nonpositive elapsed time in pair {pair}"
                )
            variant = (row.get("stage") or "").strip()
            if variant not in {"reuse", "no-reuse"}:
                raise SystemExit(f"unexpected A/B variant {variant!r} in pair {pair}")
            if exit_code:
                raise SystemExit(f"accepted pair {pair} contains failed {variant} row")
            if position not in {1, 2}:
                raise SystemExit(f"invalid treatment position {position} in pair {pair}")
            if variant in pairs.setdefault(pair, {}):
                raise SystemExit(f"duplicate {variant} row in pair {pair}")
            pairs[pair][variant] = (position, elapsed)

    if not pairs:
        raise SystemExit("no accepted A/B pairs found")
    if args.expected_pairs is not None:
        if args.expected_pairs < 1:
            raise SystemExit("--expected-pairs must be positive")
        expected_pair_ids = set(range(1, args.expected_pairs + 1))
        if set(pairs) != expected_pair_ids:
            raise SystemExit(
                f"accepted pair ids are {sorted(pairs)}; expected "
                f"{sorted(expected_pair_ids)}"
            )

    pair_rows: list[dict[str, str | int]] = []
    deltas: list[float] = []
    ratios: list[float] = []
    saved_percents: list[float] = []
    reuse_times: list[float] = []
    no_reuse_times: list[float] = []
    reuse_first_deltas: list[float] = []
    no_reuse_first_deltas: list[float] = []
    positive = negative = ties = 0

    for pair in sorted(pairs):
        variants = pairs[pair]
        if set(variants) != {"reuse", "no-reuse"}:
            raise SystemExit(f"pair {pair} does not contain exactly both variants")
        reuse_position, reuse = variants["reuse"]
        no_reuse_position, no_reuse = variants["no-reuse"]
        if reuse_position == no_reuse_position:
            raise SystemExit(f"pair {pair} has duplicate treatment position")
        delta = no_reuse - reuse
        ratio = no_reuse / reuse
        saved_percent = 100 * delta / no_reuse
        first = "reuse" if reuse_position == 1 else "no-reuse"
        (reuse_first_deltas if first == "reuse" else no_reuse_first_deltas).append(delta)
        positive += delta > 0
        negative += delta < 0
        ties += delta == 0
        reuse_times.append(reuse)
        no_reuse_times.append(no_reuse)
        deltas.append(delta)
        ratios.append(ratio)
        saved_percents.append(saved_percent)
        pair_rows.append(
            {
                "pair": pair,
                "first_variant": first,
                "reuse_seconds": f"{reuse:.9f}",
                "no_reuse_seconds": f"{no_reuse:.9f}",
                "no_reuse_minus_reuse_seconds": f"{delta:.9f}",
                "speedup_ratio_no_reuse_over_reuse": f"{ratio:.9f}",
                "reuse_saved_percent": f"{saved_percent:.6f}",
            }
        )

    pair_fields = list(pair_rows[0])
    with Path(args.pairs_output).open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(
            stream, delimiter="\t", fieldnames=pair_fields, lineterminator="\n"
        )
        writer.writeheader()
        writer.writerows(pair_rows)

    delta_median = statistics.median(deltas)
    delta_stddev = statistics.stdev(deltas) if len(deltas) > 1 else 0.0
    delta_mad = statistics.median(
        [abs(value - delta_median) for value in deltas]
    )
    geometric_mean_ratio = math.exp(
        statistics.mean([math.log(value) for value in ratios])
    )
    summary = {
        "accepted_pairs": len(pair_rows),
        "reuse_first_pairs": len(reuse_first_deltas),
        "no_reuse_first_pairs": len(no_reuse_first_deltas),
        "median_reuse_seconds": median_or_blank(reuse_times),
        "median_no_reuse_seconds": median_or_blank(no_reuse_times),
        "median_paired_delta_seconds": median_or_blank(deltas),
        "mean_paired_delta_seconds": f"{statistics.mean(deltas):.9f}",
        "min_paired_delta_seconds": f"{min(deltas):.9f}",
        "max_paired_delta_seconds": f"{max(deltas):.9f}",
        "stddev_paired_delta_seconds": f"{delta_stddev:.9f}",
        "mad_paired_delta_seconds": f"{delta_mad:.9f}",
        "p95_paired_delta_seconds": f"{percentile(deltas, 0.95):.9f}",
        "median_speedup_ratio_no_reuse_over_reuse": median_or_blank(ratios),
        "mean_speedup_ratio_no_reuse_over_reuse": f"{statistics.mean(ratios):.9f}",
        "geometric_mean_speedup_ratio_no_reuse_over_reuse": (
            f"{geometric_mean_ratio:.9f}"
        ),
        "median_reuse_saved_percent": median_or_blank(saved_percents),
        "median_delta_reuse_first_seconds": median_or_blank(reuse_first_deltas),
        "median_delta_no_reuse_first_seconds": median_or_blank(no_reuse_first_deltas),
        "positive_pairs_reuse_faster": positive,
        "negative_pairs_reuse_slower": negative,
        "tied_pairs": ties,
        "two_sided_exact_sign_test_p": f"{exact_two_sided_sign_test(positive, negative):.9f}",
    }
    with Path(args.summary_output).open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(
            stream, delimiter="\t", fieldnames=list(summary), lineterminator="\n"
        )
        writer.writeheader()
        writer.writerow(summary)


if __name__ == "__main__":
    main()
