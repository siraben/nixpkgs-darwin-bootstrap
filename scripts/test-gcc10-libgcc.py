#!/usr/bin/env python3
"""Maintainer-only tests for core runtime failure handling and goal checks."""
import os
import pathlib
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent


class LibgccTests(unittest.TestCase):
    def check_failure(self, configure_failure):
        with tempfile.TemporaryDirectory() as directory:
            target = pathlib.Path(directory)
            build = target / "work/gcc10-all-gcc/build"
            gcc = build / "gcc"
            libgcc = build / "x86_64-apple-darwin/libgcc"
            gcc.mkdir(parents=True)
            libgcc.mkdir(parents=True)
            (target / "gcc10-source").mkdir()
            (gcc / "Makefile").write_text("# fixture\n")
            (gcc / "gcov").write_text("#!/bin/sh\nexit 0\n")
            (gcc / "libgcc.a").write_bytes(b"previous installed archive")
            (libgcc / "libgcc.a").write_bytes(b"stale incomplete archive")
            make = target / "fake-make"
            make.write_text(
                '#!/bin/sh\n'
                'printf "%s\\n" "$@" >> "$TARGET/make-args"\n'
                'if [ "$1" = configure-target-libgcc ]; then\n'
                + ('  exit 19\n' if configure_failure else '  exit 0\n')
                + 'fi\nexit 23\n'
            )
            make.chmod(0o755)
            result = subprocess.run(
                ["/bin/sh", str(ROOT / "scripts/gcc10-build-libgcc.sh")],
                env=dict(os.environ, ROOT=str(ROOT), TARGET=str(target), MAKE=str(make)),
                capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 19 if configure_failure else 23, result.stderr)
            self.assertEqual((gcc / "libgcc.a").read_bytes(), b"previous installed archive")
            self.assertNotIn("installed real core", result.stdout)
            if not configure_failure:
                arguments = (target / "make-args").read_text().splitlines()
                self.assertIn("libgcc.a", arguments)
                self.assertNotIn("all-target-libgcc", arguments)
                self.assertIn("LIB2ADDEH=", arguments)
                self.assertIn("LIB2FUNCS_ST=__gcc_bcmp", arguments)
                self.assertIn("LIB2_DIVMOD_EXCEPTION_FLAGS=-fno-exceptions -fno-non-call-exceptions", arguments)
                self.assertFalse((libgcc / "libgcc.a").exists())

    def test_configure_failure_is_fatal(self):
        self.check_failure(True)

    def test_core_build_failure_does_not_install_partial_archive(self):
        self.check_failure(False)


class GoalTests(unittest.TestCase):
    def check_map(self, bootstrap_archive):
        with tempfile.TemporaryDirectory() as directory:
            build = pathlib.Path(directory)
            (build / "gcc").mkdir()
            compiler = build / "gcc/xgcc"
            compiler.write_text(
                '#!/bin/sh\nset -eu\nmap=\n'
                'while [ "$#" -gt 0 ]; do\n'
                '  case "$1" in\n'
                '    -o) shift; out=$1 ;;\n'
                '    -Wl,-map,*) map=${1#-Wl,-map,} ;;\n'
                '  esac\n  shift\ndone\n'
                'printf "#!/bin/sh\\nexit 7\\n" > "$out"\nchmod +x "$out"\n'
                'if [ -n "$map" ]; then\n'
                + ('  printf "%s\\n" "$GCC10_BUILD/gcc/libgcc.a(_divdi3.o)" '
                   '"$GCC10_BUILD/gcc/libgcc.a(_udivdi3.o)" > "$map"\n'
                   if bootstrap_archive else '  : > "$map"\n')
                + 'fi\n'
            )
            compiler.chmod(0o755)
            result = subprocess.run(
                ["/bin/sh", str(ROOT / "scripts/gcc10-goal-test.sh")],
                env=dict(os.environ, GCC10_BUILD=str(build)),
                capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0 if bootstrap_archive else 1, result.stderr)
            if not bootstrap_archive:
                self.assertIn("did not load _divdi3.o", result.stderr)
                self.assertNotIn("GOAL PASS", result.stdout)

    def test_runtime_loaded_from_core_archive(self):
        self.check_map(True)

    def test_successful_execution_without_core_archive_is_rejected(self):
        self.check_map(False)


if __name__ == "__main__":
    unittest.main()
