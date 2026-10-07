#!/usr/bin/env python3
"""Maintainer-only regression tests for bootstrap measurement helpers."""
import os
import pathlib
import shutil
import subprocess
import tempfile
import time
import unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent


class MetricsTests(unittest.TestCase):
    def test_report(self):
        with tempfile.TemporaryDirectory() as directory:
            metrics = pathlib.Path(directory)
            (metrics / "steps.tsv").write_text(
                "step\twall_s\tuser_s\tsys_s\tmax_rss_kib\tpeak_footprint_kib\n"
                "01-hex0\t1.5\t0.2\t0.1\t2048\t3072\n"
                "02-hex1\t2.5\t0.4\t0.2\t4096\t5120\n"
            )
            (metrics / "rss-samples.tsv").write_text(
                "epoch\tstep\ttree_rss_kib\tnprocs\n"
                "1\t01-hex0\t4096\t2\n"
                "2\t01-hex0\t8192\t3\n"
                "3\t02-hex1\t6144\t2\n"
            )
            report = subprocess.check_output(
                ["sh", str(ROOT / "scripts/boot-metrics-report.sh"), directory],
                text=True,
            ).splitlines()
            self.assertEqual(report[1].split(), ["01-hex0", "1.5", "0.2", "0.1", "2.0", "8.0"])
            self.assertEqual(report[2].split(), ["02-hex1", "2.5", "0.4", "0.2", "4.0", "6.0"])
            self.assertEqual(report[3].split(), ["TOTAL/peak", "4.0", "0.6", "0.3", "4.0", "8.0"])

    def test_report_preserves_repeated_step_measurements(self):
        # A directory name must not determine whether a file contains samples.
        with tempfile.TemporaryDirectory(prefix="rss-samples-") as directory:
            metrics = pathlib.Path(directory)
            (metrics / "steps.tsv").write_text(
                "step\twall_s\tuser_s\tsys_s\tmax_rss_kib\tpeak_footprint_kib\n"
                "01-hex0\t1\t0.2\t0.1\t4096\t0\n"
                "01-hex0\t3\t0.4\t0.2\t2048\t0\n"
            )
            (metrics / "rss-samples.tsv").write_text(
                "epoch\tstep\ttree_rss_kib\tnprocs\n"
                "1\t01-hex0\t8192\t2\n"
            )
            report = subprocess.check_output(
                ["sh", str(ROOT / "scripts/boot-metrics-report.sh"), directory],
                text=True,
            ).splitlines()
            self.assertEqual(report[1].split(), ["01-hex0", "1.0", "0.2", "0.1", "4.0", "8.0"])
            self.assertEqual(report[2].split(), ["01-hex0", "3.0", "0.4", "0.2", "2.0", "8.0"])
            self.assertEqual(report[3].split(), ["TOTAL/peak", "4.0", "0.6", "0.3", "4.0", "8.0"])

    def test_sampler_tracks_descendants_and_exits(self):
        with tempfile.TemporaryDirectory() as directory:
            metrics = pathlib.Path(directory)
            (metrics / "current").write_text("test-step\n")
            root = subprocess.Popen(["/bin/sh", "-c", "sleep 30 & wait"])
            sampler = subprocess.Popen([
                "/bin/sh", str(ROOT / "scripts/boot-rss-sampler.sh"),
                str(root.pid), directory, "0.1",
            ])
            try:
                deadline = time.monotonic() + 5
                samples = []
                while time.monotonic() < deadline:
                    output = metrics / "rss-samples.tsv"
                    if output.exists():
                        samples = [line.split("\t") for line in output.read_text().splitlines()[1:]]
                        if any(int(row[3]) >= 2 for row in samples):
                            break
                    time.sleep(0.05)
                self.assertTrue(samples, "sampler produced no data")
                self.assertTrue(any(int(row[3]) >= 2 for row in samples), samples)
                self.assertTrue(all(row[1] == "test-step" for row in samples))
                self.assertTrue(all(int(row[2]) > 0 for row in samples))
            finally:
                subprocess.run(["pkill", "-P", str(root.pid)], check=False)
                root.wait(timeout=5)
                try:
                    sampler.wait(timeout=5)
                finally:
                    if sampler.poll() is None:
                        sampler.kill()
                        sampler.wait()
            self.assertEqual(sampler.returncode, 0)


class DriverTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = pathlib.Path(self.temp.name)
        shutil.copy(ROOT / "build.sh", self.root)
        shutil.copytree(ROOT / "scripts", self.root / "scripts")
        (self.root / "steps").mkdir()
        (self.root / "steps/01-pass.sh").write_text("exit 0\n")
        (self.root / "steps/02-fail.sh").write_text("exit 17\n")

    def run_driver(self, **settings):
        env = {key: value for key, value in os.environ.items()
               if not key.startswith("BOOT_") and key != "TARGET"}
        env.update(settings)
        return subprocess.run(["/bin/sh", str(self.root / "build.sh")],
                              env=env, capture_output=True, text=True)

    def test_enabled_and_resume(self):
        directory = self.root / "custom metrics"
        result = self.run_driver(BOOT_STOP_AFTER="01", BOOT_METRICS_DIR=str(directory))
        self.assertEqual(result.returncode, 0, result.stderr)
        rows = (directory / "steps.tsv").read_text().splitlines()
        self.assertEqual(len(rows), 2)
        fields = rows[1].split("\t")
        self.assertEqual(fields[0], "01-pass")
        self.assertEqual(len(fields), 6)
        self.assertTrue(all(float(value) >= 0 for value in fields[1:]))
        result = self.run_driver(BOOT_START_FROM="01", BOOT_STOP_AFTER="01",
                                 BOOT_METRICS_DIR=str(directory))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len((directory / "steps.tsv").read_text().splitlines()), 3)

    def test_disabled(self):
        result = self.run_driver(BOOT_METRICS="0", BOOT_STOP_AFTER="01")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.root / "target/metrics").exists())

    def test_failure_propagates(self):
        for enabled in ["0", "1"]:
            result = self.run_driver(BOOT_METRICS=enabled)
            self.assertEqual(result.returncode, 17, result.stderr)
            self.assertNotIn("== done", result.stdout)
        rows = (self.root / "target/metrics/steps.tsv").read_text().splitlines()
        self.assertEqual(len(rows), 2, "failed step must not be recorded as successful")


if __name__ == "__main__":
    unittest.main()
