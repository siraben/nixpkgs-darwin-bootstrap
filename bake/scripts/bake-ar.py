#!/usr/bin/env python3
"""Minimal `ar` that stores object members verbatim (works with ELF).

Apple's /usr/bin/ar refuses non-Mach-O members ("not a mach-o file") and
silently produces an archive with only a symbol table and zero members,
which breaks the gcc-4.6 in-tree gmp/mpfr/mpc static libs (our tcc
toolchain emits ELF objects).  This tool writes a plain `ar` archive,
storing members byte-for-byte regardless of their object format.

Supported: create/replace (c r q), extract (x), list (t), delete (d).
The `s` (symbol-table) modifier is accepted and ignored — tcc-darwin-cc
indexes archive members itself, so no ranlib index is needed.

Archive format: the 4.4BSD `ar` container that Apple's /usr/bin/ar
understands, so the existing tcc-darwin-cc wrapper (which extracts
members via `/usr/bin/ar -x`) keeps working unchanged.  Every member
name is stored with the BSD extended-name convention "#1/<namelen>",
with the name bytes prepended to the member data.
"""
import os
import sys

MAGIC = b"!<arch>\n"
HDR = 60  # fixed member header size


def pad2(data):
    return data + (b"\n" if len(data) % 2 else b"")


def mkheader(name, size, mtime=0, uid=0, gid=0, mode=0o644):
    name = name.ljust(16)[:16]
    h = (
        name.encode()
        + f"{mtime:<12d}".encode()
        + f"{uid:<6d}".encode()
        + f"{gid:<6d}".encode()
        + f"{mode:<8o}".encode()
        + f"{size:<10d}".encode()
        + b"`\n"
    )
    assert len(h) == HDR, len(h)
    return h


def write_archive(path, members):
    """members: list of (basename, bytes). BSD #1/<len> extended names."""
    out = bytearray(MAGIC)
    for base, data in members:
        nb = base.encode("latin-1")
        payload = nb + data  # BSD: name bytes prepended to the data
        out += mkheader("#1/%d" % len(nb), len(payload))
        out += payload
        if len(payload) % 2:
            out += b"\n"
    with open(path, "wb") as f:
        f.write(out)


def read_archive(path):
    """Return list of (basename, bytes). Handles BSD #1/ and plain names."""
    with open(path, "rb") as f:
        blob = f.read()
    if not blob.startswith(MAGIC):
        sys.exit(f"bake-ar: {path}: not an archive")
    pos = len(MAGIC)
    members = []
    while pos + HDR <= len(blob):
        hdr = blob[pos : pos + HDR]
        pos += HDR
        name = hdr[0:16].decode("latin-1").rstrip()
        try:
            size = int(hdr[48:58].decode().strip())
        except ValueError:
            break
        data = blob[pos : pos + size]
        pos += size + (size % 2)
        if name.startswith("#1/"):
            nlen = int(name[3:])
            base = data[:nlen].decode("latin-1")
            data = data[nlen:]
        elif name in ("/", "//") or name.startswith("__.SYMDEF"):
            continue  # skip symbol-table / long-name-table members
        else:
            base = name.rstrip("/")
        members.append((base, bytes(data)))
    return members


def main(argv):
    if len(argv) < 2:
        sys.exit("usage: bake-ar <[cqrxtds]...> archive [members...]")
    mods = argv[1].lstrip("-")
    archive = argv[2]
    files = argv[3:]
    op = None
    for c in mods:
        if c in "xtd":
            op = c
    # create/replace if any of c/q/r present and no x/t/d op
    if op is None:
        # create / replace / quick-append: merge with any existing members
        # (the 'c' flag only suppresses the "creating archive" notice).
        existing = []
        if os.path.exists(archive):
            try:
                existing = read_archive(archive)
            except SystemExit:
                existing = []
        newbases = {os.path.basename(f) for f in files}
        merged = [(b, d) for (b, d) in existing if b not in newbases]
        for f in files:
            with open(f, "rb") as fh:
                merged.append((os.path.basename(f), fh.read()))
        write_archive(archive, merged)
        return 0
    if op == "t":
        for base, _ in read_archive(archive):
            print(base)
        return 0
    if op == "x":
        wanted = set(files)
        for base, data in read_archive(archive):
            if wanted and base not in wanted:
                continue
            with open(base, "wb") as fh:
                fh.write(data)
        return 0
    if op == "d":
        drop = set(files)
        keep = [(b, d) for (b, d) in read_archive(archive) if b not in drop]
        write_archive(archive, keep)
        return 0
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
