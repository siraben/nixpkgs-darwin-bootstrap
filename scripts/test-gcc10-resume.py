#!/usr/bin/env python3
"""Maintainer-only tests for the GCC 10 resume tool's environment contract."""
import os
import pathlib
import shutil
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent


class ResumeTests(unittest.TestCase):
    def check_resume(self, custom_target):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            (root / "scripts").mkdir()
            for name in ["gcc10-env.sh", "gcc10-resume-make.sh"]:
                shutil.copy(ROOT / "scripts" / name, root / "scripts" / name)
            target = root / ("scratch target" if custom_target else "target")
            build = target / "work/gcc10-all-gcc/build"
            libcpp = build / "build-x86_64-apple-darwin/libcpp"
            libcpp.mkdir(parents=True)
            makefile = libcpp / "Makefile"
            makefile.write_text("AR = ar\n")
            (target / "bin").mkdir()
            make = target / "bin/make"
            make.write_text(
                '#!/bin/sh\npwd > cwd.txt\nenv > env.txt\n'
                'printf "%s\\n" "$@" > args.txt\nexit 23\n'
            )
            make.chmod(0o755)
            env = {k: v for k, v in os.environ.items()
                   if k not in {"ROOT", "TARGET", "MAKE", "TCC_DARWIN_CACHE_DIR"}}
            if custom_target:
                env["TARGET"] = str(target)
            result = subprocess.run(
                ["/bin/sh", str(root / "scripts/gcc10-resume-make.sh")],
                env=env, capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 23, result.stderr)
            self.assertEqual(pathlib.Path((build / "cwd.txt").read_text().strip()).resolve(), build.resolve())
            actual = dict(line.split("=", 1) for line in (build / "env.txt").read_text().splitlines())
            self.assertEqual(actual["CC"], str(target / "bin/tcc-darwin-cc"))
            self.assertEqual(actual["CXX"], str(target / "gcc46-cxx/bin/g++"))
            self.assertEqual(actual["AR_FOR_BUILD"], str(root / "scripts/boot-ar"))
            self.assertEqual(actual["TCC_DARWIN_CACHE_DIR"], str(target / "work/.tcc-darwin-archive-cache"))
            self.assertEqual(actual["GCC10_BUILD"], str(build))
            self.assertEqual(actual["MACOSX_DEPLOYMENT_TARGET"], "10.6")
            arguments = (build / "args.txt").read_text().splitlines()
            self.assertEqual(arguments[:3], ["all-gcc", "-j1", "MAKEINFO=true"])
            self.assertIn("CXXFLAGS=" + actual["CXXFLAGS"], arguments)
            self.assertIn("NATIVE_SYSTEM_HEADER_DIR=" + actual["GCC10_SYS"], arguments)
            self.assertEqual(makefile.read_text(), f"AR = {root}/scripts/boot-ar\n")

    def test_default_target(self):
        self.check_resume(False)

    def test_custom_target_with_spaces(self):
        self.check_resume(True)


if __name__ == "__main__":
    unittest.main()
