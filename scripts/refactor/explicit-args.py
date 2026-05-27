#!/usr/bin/env python3
"""Heuristically extract args used in a `args: with args; ...` file and
emit an explicit-args header.  Lists every identifier that appears in
either `${name}` or `${name.x}` interpolations.

Doesn't catch bare-identifier refs (e.g. `runCommand foo {}` or
`mkDarwin {...}` since the name appears outside `${}`) — those need to be
added by hand from the file's first non-comment expression(s).
"""
import re
import sys
from pathlib import Path

# Common scope attrs to always check for bare refs
SCOPE_NAMES = {
    "runCommand", "mkDarwin", "stdenv", "lib", "fetchurl",
    "darwin", "cctools", "apple-sdk", "perl", "gnumake",
    "root", "hostPlatform", "source", "stage0-posix",
    "stage0Sources", "hex0",
    "minimal-bootstrap-sources",
}

# All scope attrs we know about (will check bare-references against this)
KNOWN_ATTRS = SCOPE_NAMES | {
    "mesVersion", "mesTarball", "nyaccVersion", "nyaccTarball",
    "mesNyacc", "mesDarwinConfigH",
    "tinyccBootstrappableSrc", "tinyccMesSrc",
    "gcc46Version", "gcc46Tarball", "gcc46GmpTarball",
    "gcc46MpfrTarball", "gcc46MpcTarball",
    "gcc10Version", "gcc10Tarball", "gcc10GmpVersion", "gcc10GmpTarball",
    "gccLatestVersion", "gccLatestTarball",
    "gccLatestGmpVersion", "gccLatestGmpTarball",
    "gccModernMpfrVersion", "gccModernMpfrTarball",
    "gccModernMpcVersion", "gccModernMpcTarball",
    "gccModernIslVersion", "gccModernIslTarball",
    "gnumakeVersion", "gnumakeTarball",
    "gnupatchVersion", "gnupatchTarball",
    "coreutilsVersion", "coreutilsTarball", "coreutilsLiveBootstrap",
    "coreutilsMakefile", "coreutilsPatches",
    # All phase variables
    "phase1-hex1", "phase2-hex2", "phase2-catm", "phase3-m0",
    "phase4-cc-arch", "phase5-m2", "phase6-blood-macho-0",
    "phase7-m1-0", "phase8-hex2-1", "phase9-m1", "phase10-hex2",
    "phase11-kaem",
    "phase11b-m1-to-hex2", "phase11c-hex2-data-relocs",
    "phase11d-cc-arch-helper", "phase11e-macho-patcher-early",
    "phase12-m2-planet", "phase13-mes-source",
    "phase14-mes-m2-probe", "phase15-mes-macho-link-probe",
    "phase16-mes-m2",
    "phase17-mescc-macho-probe", "phase18-mescc-libc-mini-probe",
    "phase19-tinycc-mescc-m1-probe", "phase20-mescc-libmescc-probe",
    "phase21-mescc-libc-probe", "phase22-mescc-libc-tcc-probe",
    "phase23-tinycc-mescc-link-probe", "phase24-tinycc-compile-probe",
    "phase25-tinycc-self-object-probe",
    "phase26-gcc46-source", "phase26b-elf64-to-m1",
    "phase26c-bootstrap-gmp", "phase26d-bootstrap-mpfr",
    "phase26e-bootstrap-mpc", "phase26f-bootstrap-isl",
    "phase26g-macho-patcher",
    "phase27-tinycc-elf-to-macho-probe",
    "phase28-tinycc-self-m1-probe",
    "phase29-tinycc-sysv-libc-probe",
    "phase30-tinycc-self-link-candidate",
    "phase31-tinycc-self-compile-probe",
    "phase32-tinycc-boot1-object-probe",
    "phase33-tinycc-boot1-link-candidate",
    "phase34-tinycc-darwin-cc",
    "phase35-tinycc-boot2-object-probe",
    "phase36-tinycc-boot2-link-candidate",
    "phase37-tinycc-boot3-object-probe",
    "phase38-tinycc-boot3-link-candidate",
    "phase35-gcc46-all-gcc", "phase36-gcc46-libgcc",
    "phase37-gcc46-bootstrap", "phase44-gcc46-cxx-bootstrap",
    "phase39-gnumake", "phase40-gnupatch", "phase41-coreutils",
    "phase42-gcc10-source", "phase45-gcc10-bootstrap",
    "phase43-gcc-latest-source", "phase46-gcc-latest-bootstrap",
    "phase47-gcc-latest-strict-bootstrap",
    "gcc46DarwinBootstrapSrc",
    "tinyccSelfObjectProbe", "tinyccSelfLinkCandidate",
    "supportedSystems", "arch",
}


def scan(path: Path):
    text = path.read_text()
    if "args:" not in text or "with args;" not in text:
        return None, None
    refs = set()
    # ${name} or ${name.x}
    for m in re.finditer(r"\$\{([a-zA-Z_][a-zA-Z0-9_-]*)", text):
        refs.add(m.group(1))
    # Bare identifier refs known to be in scope
    for name in KNOWN_ATTRS:
        # Match name as a standalone identifier (not part of a longer word)
        if re.search(rf"(?<![a-zA-Z0-9_-])"
                     rf"{re.escape(name)}"
                     rf"(?![a-zA-Z0-9_-])", text):
            refs.add(name)
    # Keep only names in our known set (filter out shell variables etc.)
    refs &= KNOWN_ATTRS
    return text, sorted(refs)


def transform(path: Path) -> bool:
    text, refs = scan(path)
    if text is None:
        return False
    if not refs:
        return False
    if "args@" in text or text.lstrip().startswith("{"):
        # Already converted
        return False

    # Build header
    refs_list = ",\n  ".join(refs)
    new_header = "{\n  " + refs_list + ",\n  ...\n}:"

    # Replace `args:\nwith args;\n` with new header
    new_text = re.sub(
        r"^args:\s*\nwith args;\s*\n",
        new_header + "\n",
        text,
        count=1,
        flags=re.MULTILINE,
    )
    if new_text == text:
        return False
    path.write_text(new_text)
    return True


if __name__ == "__main__":
    changed = 0
    for arg in sys.argv[1:]:
        if transform(Path(arg)):
            print(f"  rewrote {arg}")
            changed += 1
    print(f"{changed} files rewritten")
