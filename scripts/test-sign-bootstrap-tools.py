#!/usr/bin/env python3
"""Darwin integration tests using a seed-assembled executable, not host C."""
import os
import pathlib
import struct
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent


def text_section(path):
    data = path.read_bytes()
    position = 32
    for _ in range(struct.unpack_from("<I", data, 16)[0]):
        command, size = struct.unpack_from("<II", data, position)
        if command == 0x19:  # LC_SEGMENT_64
            sections = struct.unpack_from("<I", data, position + 64)[0]
            for i in range(sections):
                section = position + 72 + i * 80
                if data[section:section + 16].rstrip(b"\0") == b"__text":
                    _, length, offset = struct.unpack_from("<QQI", data, section + 32)
                    return data[offset:offset + length]
        position += size
    raise AssertionError("missing __text section")


class SigningTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = pathlib.Path(self.temp.name)
        self.tool = self.directory / "hex1"
        subprocess.run([str(ROOT / "seed/hex0-amd64-darwin"),
                        str(ROOT / "sources/hex1_AMD64_darwin.hex0"), str(self.tool)], check=True)
        with self.tool.open("r+b") as output:
            output.truncate(0x1000000)
        self.tool.chmod(0o755)

    def sign(self, *tools, enabled="1"):
        return subprocess.run(["/bin/sh", str(ROOT / "scripts/sign-bootstrap-tools.sh"),
                               *map(str, tools or [self.tool])],
                              env=dict(os.environ, BOOT_SIGN_EXECUTABLES=enabled),
                              capture_output=True, text=True)

    def test_disabled_preserves_bytes(self):
        before = self.tool.read_bytes()
        self.assertEqual(self.sign(enabled="0").returncode, 0)
        self.assertEqual(self.tool.read_bytes(), before)

    def test_signing_preserves_code_and_execution_and_is_idempotent(self):
        before = text_section(self.tool)
        inode = self.tool.stat().st_ino
        result = self.sign()
        self.assertEqual(result.returncode, 0, result.stderr)
        subprocess.run(["/usr/bin/codesign", "--verify", "--strict", str(self.tool)], check=True)
        self.assertEqual(text_section(self.tool), before)
        self.assertNotEqual(self.tool.stat().st_ino, inode)
        source = self.directory / "input.hex1"
        source.write_text("41 42\n")
        output = self.directory / "output"
        subprocess.run([str(self.tool), str(source), str(output)], check=True)
        self.assertEqual(output.read_bytes(), b"AB")
        signed = self.tool.read_bytes()
        inode = self.tool.stat().st_ino
        self.assertEqual(self.sign().returncode, 0)
        self.assertEqual(self.tool.read_bytes(), signed)
        self.assertEqual(self.tool.stat().st_ino, inode)

    def test_scripts_and_symlinks_are_not_modified(self):
        link = self.directory / "link"
        link.symlink_to(self.tool)
        script = self.directory / "script"
        script.write_text("#!/bin/sh\nexit 0\n")
        script.chmod(0o755)
        before = self.tool.read_bytes()
        self.assertEqual(self.sign(link, script).returncode, 0)
        self.assertEqual(self.tool.read_bytes(), before)
        self.assertEqual(script.read_text(), "#!/bin/sh\nexit 0\n")

    def test_signing_failure_preserves_original_and_cleans_temporary(self):
        # The fixed seed has no signable LINKEDIT layout; callers must keep
        # it untouched rather than silently accepting a failed signature.
        self.tool.write_bytes((ROOT / "seed/hex0-amd64-darwin").read_bytes())
        before = self.tool.read_bytes()
        self.assertNotEqual(self.sign().returncode, 0)
        self.assertEqual(self.tool.read_bytes(), before)
        self.assertEqual(list(self.directory.glob("*.signed.*")), [])


if __name__ == "__main__":
    unittest.main()
