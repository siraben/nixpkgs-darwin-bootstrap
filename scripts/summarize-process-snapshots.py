#!/usr/bin/env python3
"""Summarize diagnostic high-CPU process streams from bootstrap benchmarks."""

from __future__ import annotations

import argparse
import csv
import glob
import math
import shlex
import statistics
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path


KNOWN_BACKGROUND = {
    "backupd", "bird", "cloudd", "contactsd", "corespotlightd",
    "com.apple.Virtualization.VirtualMachine", "com.docker.backend",
    "duetexpertd", "ecosystemanalyticsd", "ecosystemd", "knowledge-agent",
    "mds", "mds_stores", "mdsync", "mdworker", "mdworker_shared",
    "mediaanalysisd", "photoanalysisd", "routined", "spotlightknowledged",
    "redline-analytics-projector", "redline-chain-worker", "redline-indexer",
    "redline-projector", "suggestd", "triald", "trustd",
}
WORKLOAD_PROCESSES = {
    "ar", "as", "bash:g++", "bash:gcc", "cc1", "cc1plus", "collect2",
    "g++", "gcc", "ld", "make", "nix", "nix-daemon", "ranlib", "sh:g++",
    "sh:gcc", "tcc", "tcc-darwin-cc", "xgcc",
}
HARNESS_PROCESSES = {
    "awk", "memory_pressure", "ps", "sh:top", "sleep", "top", "vm_stat",
}


@dataclass
class Aggregate:
    cpu: list[float] = field(default_factory=list)
    rss_kib: list[int] = field(default_factory=list)
    files: set[str] = field(default_factory=set)
    pids: set[str] = field(default_factory=set)
    commands: set[str] = field(default_factory=set)
    role_hints: set[str] = field(default_factory=set)
    first_timestamp: str = ""
    last_timestamp: str = ""
    example_command: str = ""

    def add(
        self,
        input_name: str,
        timestamp: str,
        pid: str,
        cpu: float,
        rss_kib: int,
        command: str,
        role: str,
    ) -> None:
        self.cpu.append(cpu)
        self.rss_kib.append(rss_kib)
        self.files.add(input_name)
        self.pids.add(f"{input_name}:{pid}")
        self.commands.add(command)
        self.role_hints.add(role)
        if not self.first_timestamp or timestamp < self.first_timestamp:
            self.first_timestamp = timestamp
        if not self.last_timestamp or timestamp > self.last_timestamp:
            self.last_timestamp = timestamp
        if not self.example_command:
            self.example_command = command


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-glob", action="append", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--detail-output", type=Path)
    parser.add_argument("--command-output", type=Path)
    return parser.parse_args()


def process_key(command: str) -> str:
    try:
        words = shlex.split(command)
    except ValueError:
        words = command.split()
    if not words:
        return "<empty>"
    executable = Path(words[0]).name
    if executable in {"bash", "dash", "sh", "zsh"} and len(words) > 1:
        script = words[1]
        if not script.startswith("-"):
            executable = f"{executable}:{Path(script).name}"
    return executable


def role_hint(key: str, command: str) -> str:
    leaf = key.split(":")[-1]
    if key in WORKLOAD_PROCESSES or leaf in WORKLOAD_PROCESSES:
        return "measured-workload-likely"
    if leaf == "clang":
        try:
            words = shlex.split(command)
        except ValueError:
            words = command.split()
        assembler_language = any(
            words[index] == "-x" and words[index + 1] == "assembler"
            for index in range(len(words) - 1)
        )
        staged_gcc46_input = any(
            "gcc46-bootstrap." in word and word.endswith("/input.s")
            for word in words
        )
        if assembler_language and "-integrated-as" in words and staged_gcc46_input:
            return "measured-workload-likely"
    if key in HARNESS_PROCESSES or leaf in HARNESS_PROCESSES:
        return "measurement-harness-likely"
    if leaf in KNOWN_BACKGROUND:
        return "known-background-rejection-class"
    # Borg is launched through a Python wrapper, so process_key() correctly
    # reports the interpreter while the exact command supplies its role.
    if "borgbackup" in command and " create " in f" {command} ":
        return "known-background-rejection-class"
    return "unclassified-review-required"


def input_files(patterns: list[str]) -> list[str]:
    names: set[str] = set()
    for pattern in patterns:
        names.update(glob.glob(pattern, recursive=True))
    files = sorted(name for name in names if Path(name).is_file())
    if not files:
        raise SystemExit("no process snapshot inputs matched")
    return files


def read_inputs(
    files: list[str],
) -> tuple[
    dict[str, Aggregate],
    dict[tuple[str, str], Aggregate],
    dict[tuple[str, str, str], Aggregate],
]:
    overall: dict[str, Aggregate] = defaultdict(Aggregate)
    per_file: dict[tuple[str, str], Aggregate] = defaultdict(Aggregate)
    per_command: dict[tuple[str, str, str], Aggregate] = defaultdict(Aggregate)
    for input_name in files:
        input_observations = 0
        with Path(input_name).open(newline="", encoding="utf-8") as stream:
            reader = csv.DictReader(stream, delimiter="\t")
            required = {
                "timestamp",
                "pid",
                "ppid",
                "ps_cpu_percent",
                "rss_kib",
                "command",
            }
            if reader.fieldnames is None or not required.issubset(reader.fieldnames):
                raise SystemExit(f"invalid process snapshot header in {input_name}")
            for row_number, row in enumerate(reader, start=2):
                input_observations += 1
                timestamp = (row.get("timestamp") or "").strip()
                command = (row.get("command") or "").strip()
                try:
                    pid_number = int(row["pid"])
                    ppid_number = int(row["ppid"])
                    cpu = float(row["ps_cpu_percent"])
                    rss_kib = int(row["rss_kib"])
                except (TypeError, ValueError) as error:
                    raise SystemExit(
                        f"invalid process snapshot value in {input_name} "
                        f"row {row_number}"
                    ) from error
                if not timestamp or not command:
                    raise SystemExit(
                        f"blank process snapshot value in {input_name} "
                        f"row {row_number}"
                    )
                if (
                    pid_number <= 0
                    or ppid_number < 0
                    or not math.isfinite(cpu)
                    or cpu < 0
                    or rss_kib < 0
                ):
                    raise SystemExit(
                        f"out-of-range process snapshot value in {input_name} "
                        f"row {row_number}"
                    )
                key = process_key(command)
                role = role_hint(key, command)
                overall[key].add(
                    input_name,
                    timestamp,
                    row["pid"],
                    cpu,
                    rss_kib,
                    command,
                    role,
                )
                per_file[(input_name, key)].add(
                    input_name,
                    timestamp,
                    row["pid"],
                    cpu,
                    rss_kib,
                    command,
                    role,
                )
                per_command[(input_name, key, command)].add(
                    input_name,
                    timestamp,
                    row["pid"],
                    cpu,
                    rss_kib,
                    command,
                    role,
                )
        if input_observations == 0:
            raise SystemExit(f"process snapshot input is empty: {input_name}")
    return overall, per_file, per_command


def summary_row(key: str, aggregate: Aggregate) -> dict[str, object]:
    role = (
        next(iter(aggregate.role_hints))
        if len(aggregate.role_hints) == 1
        else "mixed-review-required"
    )
    return {
        "role_hint": role,
        "process_key": key,
        "observations": len(aggregate.cpu),
        "input_files": len(aggregate.files),
        "unique_file_pids": len(aggregate.pids),
        "unique_commands": len(aggregate.commands),
        "sampled_cpu_sum": f"{sum(aggregate.cpu):.3f}",
        "mean_ps_cpu_percent": f"{statistics.mean(aggregate.cpu):.3f}",
        "max_ps_cpu_percent": f"{max(aggregate.cpu):.3f}",
        "mean_rss_kib": f"{statistics.mean(aggregate.rss_kib):.3f}",
        "max_rss_kib": max(aggregate.rss_kib),
        "first_timestamp": aggregate.first_timestamp,
        "last_timestamp": aggregate.last_timestamp,
        "example_command": aggregate.example_command,
    }


def write_summary(path: Path, rows: list[dict[str, object]]) -> None:
    fields = list(rows[0])
    with path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(
            stream, fieldnames=fields, delimiter="\t", lineterminator="\n"
        )
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    args = arguments()
    files = input_files(args.input_glob)
    overall, per_file, per_command = read_inputs(files)
    if not overall:
        raise SystemExit("process snapshots contained no observations")
    overall_rows = [
        summary_row(key, aggregate)
        for key, aggregate in sorted(
            overall.items(), key=lambda item: (-sum(item[1].cpu), item[0])
        )
    ]
    write_summary(args.output, overall_rows)
    if args.detail_output is not None:
        detail_rows: list[dict[str, object]] = []
        for (input_name, key), aggregate in sorted(per_file.items()):
            row = summary_row(key, aggregate)
            detail_rows.append({"input": input_name, **row})
        write_summary(args.detail_output, detail_rows)
    if args.command_output is not None:
        command_rows: list[dict[str, object]] = []
        for (input_name, key, command), aggregate in sorted(per_command.items()):
            row = summary_row(key, aggregate)
            if row["example_command"] != command:
                raise AssertionError("exact-command aggregate lost its command")
            command_rows.append({"input": input_name, **row})
        write_summary(args.command_output, command_rows)


if __name__ == "__main__":
    main()
