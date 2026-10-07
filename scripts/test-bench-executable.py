#!/usr/bin/env python3
"""Regression tests for the paired executable benchmark's correctness gate."""
import importlib.util
import pathlib
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).with_name("bench-executable.py")
spec = importlib.util.spec_from_file_location("bench_executable", SCRIPT)
bench = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bench)


class BenchmarkTests(unittest.TestCase):
    def test_five_pairs_alternate_order(self):
        result = bench.benchmark("/usr/bin/printf", "/usr/bin/printf", ["same"], 5, 1)
        self.assertEqual(len(result["rows"]), 10)
        self.assertEqual([row["variant"] for row in result["rows"][:4]],
                         ["baseline", "candidate", "candidate", "baseline"])
        self.assertGreater(result["wall_speedup"], 0)
        self.assertTrue(all(row["wall_s"] > 0 for row in result["rows"]))

    def test_output_mismatch_is_fatal(self):
        with tempfile.TemporaryDirectory() as directory:
            script = pathlib.Path(directory) / "different"
            script.write_text("#!/bin/sh\nprintf different\n")
            script.chmod(0o755)
            with self.assertRaisesRegex(RuntimeError, "output mismatch"):
                bench.benchmark("/usr/bin/printf", str(script), ["same"], 5, 1)


if __name__ == "__main__":
    unittest.main()
