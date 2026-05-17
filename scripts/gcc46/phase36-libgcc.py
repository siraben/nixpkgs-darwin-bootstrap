#!/usr/bin/env python3
import argparse
import os
import re
from pathlib import Path

SOFT_FP_SOURCES = [
    "addtf3", "divtf3", "eqtf2", "getf2", "letf2", "multf3", "negtf2",
    "subtf3", "unordtf2", "fixtfsi", "fixunstfsi", "floatsitf", "floatunsitf",
    "fixtfdi", "fixunstfdi", "floatditf", "floatunditf", "fixtfti", "fixunstfti",
    "floattitf", "floatuntitf", "extendsftf2", "extenddftf2", "extendxftf2",
    "trunctfsf2", "trunctfdf2", "trunctfxf2",
]
EH_SOURCES = ["unwind-dw2", "unwind-dw2-fde-darwin", "unwind-sjlj", "unwind-c", "emutls"]


def relocate_build_paths(root: Path) -> None:
    root_bytes = str(root).encode()
    pattern = re.compile(rb"/nix/var/nix/builds/[^/\0]+/(src|build)")

    def replacement(match: re.Match[bytes]) -> bytes:
        return root_bytes + b"/work/" + match.group(1)

    for base in (root / "work/src", root / "work/build"):
        for directory, dirs, files in os.walk(base):
            dirs[:] = [name for name in dirs if not os.path.islink(os.path.join(directory, name))]
            for name in files:
                path = Path(directory) / name
                if path.is_symlink():
                    continue
                data = path.read_bytes()
                replaced = pattern.sub(replacement, data)
                if replaced != data:
                    path.write_bytes(replaced)


def copy_once(src: Path, dst: Path) -> None:
    if src.is_symlink():
        return
    if not dst.exists():
        dst.write_bytes(src.read_bytes())


def materialize_headers(root: Path, phase34: Path) -> None:
    build_gcc = root / "work/build/gcc"
    src_gcc = root / "work/src/gcc"
    src_include = root / "work/src/include"
    src_config = src_gcc / "config"

    for suffix in ("h", "def", "md", "opt", "c"):
        for path in build_gcc.glob(f"*.{suffix}"):
            copy_once(path, src_gcc / path.name)
    for path in src_include.glob("*.h"):
        copy_once(path, src_gcc / path.name)
    for path in src_gcc.iterdir():
        if path.is_file() and path.suffix in (".h", ".def", ".md", ".opt"):
            copy_once(path, src_config / path.name)

    i386_config = src_config / "i386/config"
    if i386_config.exists() or i386_config.is_symlink():
        i386_config.unlink()
    i386_config.symlink_to("..")

    soft_fp = src_config / "soft-fp"
    (soft_fp / "sfp-machine.h").write_bytes((build_gcc / "sfp-machine.h").read_bytes())
    soft_fp_config = soft_fp / "config"
    if soft_fp_config.exists() or soft_fp_config.is_symlink():
        soft_fp_config.unlink()
    soft_fp_config.symlink_to("../../../libgcc/config")
    longlong = soft_fp / "longlong.h"
    if longlong.exists() or longlong.is_symlink():
        longlong.unlink()
    longlong.symlink_to("../../longlong.h")

    (src_gcc / "unwind.h").write_bytes((build_gcc / "include/unwind.h").read_bytes())
    (build_gcc / "gthr-default.h").write_text('#include "gthr-single.h"\n')
    (src_gcc / "gthr-default.h").write_text('#include "gthr-single.h"\n')
    (root / "work/src/libgcc/stdarg.h").write_bytes((build_gcc / "include/stdarg.h").read_bytes())

    fcntl = (phase34 / "include/tcc-darwin-bootstrap/fcntl.h").read_text()
    fcntl += "\n#ifndef F_RDLCK\n#define F_RDLCK 1\n#define F_WRLCK 3\n#define F_SETLKW 9\n"
    fcntl += "struct flock { long l_start; long l_len; int l_pid; short l_type; short l_whence; };\n#endif\n"
    (root / "work/src/libgcc/fcntl.h").write_text(fcntl)

    fixed_include = build_gcc / "include"
    (fixed_include / "sys").mkdir(parents=True, exist_ok=True)
    bootstrap_include = phase34 / "include/tcc-darwin-bootstrap"
    for path in bootstrap_include.glob("*.h"):
        copy_once(path, fixed_include / path.name)
    sys_include = bootstrap_include / "sys"
    if sys_include.exists():
        for path in sys_include.glob("*.h"):
            copy_once(path, fixed_include / "sys" / path.name)


def patch_sources(root: Path) -> None:
    gcov_io = root / "work/src/gcc/gcov-io.c"
    gcov_text = gcov_io.read_text()
    if "_DARWIN_BOOTSTRAP_GCOV_LOCKS" not in gcov_text:
        gcov_text = gcov_text.replace(
            "GCOV_LINKAGE int\n",
            "#ifndef F_RDLCK\n#define _DARWIN_BOOTSTRAP_GCOV_LOCKS 1\n#define F_RDLCK 1\n#define F_WRLCK 3\n#define F_SETLKW 9\nstruct flock { long l_start; long l_len; int l_pid; short l_type; short l_whence; };\n#endif\n\nGCOV_LINKAGE int\n",
            1,
        )
        gcov_io.write_text(gcov_text)

    soft_fp_add = " ".join(f"$(gcc_srcdir)/config/soft-fp/{name}.c" for name in SOFT_FP_SOURCES)
    eh_add = " ".join(f"$(gcc_srcdir)/{name}.c" for name in EH_SOURCES)
    mvars = root / "work/build/gcc/libgcc.mvars"
    out = []
    for line in mvars.read_text().splitlines():
        if line.startswith("GCC_EXTRA_PARTS ="):
            line = "GCC_EXTRA_PARTS = "
        elif line.startswith("LIB2ADD ="):
            line = f"LIB2ADD = $(gcc_srcdir)/config/darwin-64.c {soft_fp_add}"
        elif line.startswith(("LIB2ADDEH =", "LIB2ADDEHSTATIC =", "LIB2ADDEHSHARED =")):
            line = line.split("=", 1)[0] + f"= {eh_add}"
        line = line.replace(" -pipe", "").replace(" -g ", " ").replace(" -g0 ", " ")
        out.append(line)
    mvars.write_text("\n".join(out) + "\n")

    makefile = root / "work/src/libgcc/Makefile.in"
    text = makefile.read_text()
    text = text.replace("CFLAGS = -O2 -g", "CFLAGS = -O2 -fno-asynchronous-unwind-tables -fno-unwind-tables")
    text = text.replace("CFLAGS = -g", "CFLAGS = -O2 -fno-asynchronous-unwind-tables -fno-unwind-tables")
    text = text.replace(" -pipe", "").replace(" -g ", " ").replace(" -g0 ", " ")
    if "filter-out _powisf2" not in text:
        patched = []
        in_divmod_filter = False
        for line in text.splitlines():
            patched.append(line)
            if line.startswith("LIB2_DIVMOD_FUNCS :="):
                in_divmod_filter = True
            elif in_divmod_filter and "$(LIB2_DIVMOD_FUNCS))" in line:
                patched.append("lib2funcs := $(filter-out _powisf2 _powidf2 _powixf2 _powitf2 _mulsc3 _muldc3 _mulxc3 _multc3 _divsc3 _divdc3 _divxc3 _divtc3,$(lib2funcs))")
                in_divmod_filter = False
        text = "\n".join(patched) + "\n"
    if "sifuncs :=\ndifuncs :=\ntifuncs :=" not in text:
        text = text.replace(
            "iter-items := $(sifuncs) $(difuncs) $(tifuncs)\n",
            "sifuncs :=\ndifuncs :=\ntifuncs :=\niter-items := $(sifuncs) $(difuncs) $(tifuncs)\n",
        )
    text += "\nLIBGCC2_CFLAGS += -fno-asynchronous-unwind-tables -fno-unwind-tables\n"
    text += "CRTSTUFF_CFLAGS += -fno-asynchronous-unwind-tables -fno-unwind-tables\n"
    makefile.write_text(text)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--phase34", type=Path, required=True)
    args = parser.parse_args()
    relocate_build_paths(args.root)
    materialize_headers(args.root, args.phase34)
    patch_sources(args.root)


if __name__ == "__main__":
    main()
