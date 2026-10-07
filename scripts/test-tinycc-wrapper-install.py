#!/usr/bin/env python3
"""Maintainer-only tests of step 44 staging and smoke-test failure handling.

Stub compilation here isolates the shell contract; the real bootstrap smoke
must still run with the chain-built compiler.
"""
import os
import pathlib
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent


class WrapperInstallTests(unittest.TestCase):
    def run_step(self, *, compiler_status=0, extra=""):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            target = root / "target"
            tools = target / "bin"
            tools.mkdir(parents=True)
            for name in ["tcc-self", "elf64-to-m1"]:
                tool = tools / name
                tool.write_text("#!/bin/sh\nexit 0\n")
                tool.chmod(0o755)
            sources = root / "sources"
            for name in [
                "tcc-darwin/headers/stdio.h", "tcc-darwin/crt1-tcc-sysv.M1",
                "tcc-darwin/synth-inject.awk",
                "stage0-posix/M2libc/amd64/MACHO-amd64-lowdata.hex2",
            ]:
                path = sources / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.touch()
            (sources / "tcc-darwin/tcc-darwin-cc.sh").write_text(
                '#!@SHELL@\nset -euo pipefail\n'
                'printf "#!/bin/sh\\nexit 42\\n" > "$3"\n'
                'chmod +x "$3"\n'
                'out=$3\nsource @SIGNING@\nsign "$out"\n'
                '@SIGTOOL@ --file "$out" inject\n'
                + extra + f"\nexit {compiler_status}\n"
            )
            env = dict(os.environ, TARGET=str(target), SOURCES=str(sources),
                       PATH=f"{tools}:/usr/bin:/bin")
            return subprocess.run(
                ["/bin/sh", str(ROOT / "steps/44-tinycc-darwin-cc.sh")],
                env=env, capture_output=True, text=True,
            )

    def test_signing_hooks_removed(self):
        result = self.run_step()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("exit 42", result.stdout)
        self.assertNotIn("@SIGTOOL@", result.stdout + result.stderr)

    def test_compiler_failure_not_hidden_by_successful_binary(self):
        result = self.run_step(compiler_status=17)
        self.assertEqual(result.returncode, 17, result.stderr)
        self.assertNotIn("exit 42", result.stdout)

    def test_unsubstituted_placeholder_rejected(self):
        result = self.run_step(extra="# @UNKNOWN_TOOL@")
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("unsubstituted placeholder", result.stderr)


if __name__ == "__main__":
    unittest.main()
