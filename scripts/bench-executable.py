#!/usr/bin/env python3
"""Maintainer-only paired launch benchmark; never part of code translation.

Example: bench-executable.py --output launch.json unsigned/make signed/make --version
Each variant must exit zero and produce identical stdout/stderr on every run.
"""
import argparse
import hashlib
import json
import pathlib
import platform
import resource
import statistics
import subprocess
import time


def benchmark(baseline, candidate, arguments, samples, iterations):
    expected = None
    rows = []
    for sample in range(samples):
        order = [("baseline", baseline), ("candidate", candidate)]
        if sample % 2:
            order.reverse()
        for name, executable in order:
            before = resource.getrusage(resource.RUSAGE_CHILDREN)
            start = time.perf_counter()
            for _ in range(iterations):
                result = subprocess.run([executable, *arguments], capture_output=True, check=True)
                output = (result.stdout, result.stderr)
                if expected is None:
                    expected = output
                if output != expected:
                    raise RuntimeError(f"output mismatch: {name}, sample {sample + 1}")
            elapsed = time.perf_counter() - start
            after = resource.getrusage(resource.RUSAGE_CHILDREN)
            rows.append({"sample": sample + 1, "variant": name,
                         "wall_s": elapsed, "user_s": after.ru_utime - before.ru_utime,
                         "sys_s": after.ru_stime - before.ru_stime})
    medians = {name: {key: statistics.median(row[key] for row in rows if row["variant"] == name)
                      for key in ["wall_s", "user_s", "sys_s"]}
               for name in ["baseline", "candidate"]}
    return {"samples": samples, "iterations_per_sample": iterations, "rows": rows,
            "medians": medians,
            "wall_speedup": medians["baseline"]["wall_s"] / medians["candidate"]["wall_s"],
            "output_sha256": [hashlib.sha256(data).hexdigest() for data in expected]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=pathlib.Path, required=True)
    parser.add_argument("--samples", type=int, default=5)
    parser.add_argument("--iterations", type=int, default=20)
    parser.add_argument("baseline")
    parser.add_argument("candidate")
    parser.add_argument("arguments", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if args.samples < 5 or args.iterations < 1:
        parser.error("require at least five samples and one iteration")
    if args.output.exists():
        parser.error("output already exists; keep independent benchmark runs")
    executables = [str(pathlib.Path(p).resolve()) for p in [args.baseline, args.candidate]]
    result = benchmark(*executables, args.arguments, args.samples, args.iterations)
    result.update({"host": platform.platform(), "executables": executables,
                   "executable_sha256": [hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()
                                         for p in executables], "arguments": args.arguments})
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({key: result[key] for key in ["medians", "wall_speedup"]}, indent=2))


if __name__ == "__main__":
    main()
