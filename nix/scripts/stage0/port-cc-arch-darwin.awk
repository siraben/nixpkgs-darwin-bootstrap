## Port-mode helper for phase-4 cc_arch translator.  Mirrors port_source()
## from scripts/stage0/phase4-amd64-cc-arch.pl exactly — but in pure POSIX
## awk (no perl).  Applies 9 fixed opcode-level rewrites that turn the
## Linux x86_64 syscalls in cc_arch's source into Darwin syscalls.
##
## Usage:
##   awk -f port-cc-arch-darwin.awk < cc_arch-0-linux.hex2 > cc_arch-0.hex2
##
## Constant: HEAP_VM = 0xF00000 — Darwin static heap base, packed as
## little-endian 64-bit.  Hex form "0000F00000000000".

function replace_once(buf, old, new,    pos) {
    pos = index(buf, old)
    if (pos > 0) return substr(buf, 1, pos - 1) new substr(buf, pos + length(old))
    return buf
}

function replace_all(buf, old, new,    out, pos, oldlen) {
    oldlen = length(old)
    if (oldlen == 0) return buf
    out = ""
    while ((pos = index(buf, old)) > 0) {
        out = out substr(buf, 1, pos - 1) new
        buf = substr(buf, pos + oldlen)
    }
    return out buf
}

{ buf = buf $0 "\n" }

END {
    buf = replace_once(buf, "58\n5F\n5F\n", "4889F3\n488B7B08\n")
    buf = replace_once(buf, "5F\n48C7C6\n41020000\n", "488B7B10\n48C7C6\n01060000\n")

    ## HEAP_VM = 0xF00000, packed little-endian 64-bit uppercase hex
    heap_hex = "0000F00000000000"
    buf = replace_once(buf,
        "48C7C0\n0C000000\n48C7C7\n00000000\n0F05\n4989C5\n",
        "49BD\n" heap_hex "\n")

    buf = replace_all(buf, "48C7C0\n02000000\n0F05", "48C7C0\n05000002\n0F05")
    buf = replace_all(buf,
        "48C7C0\n00000000\n52\n48C7C2\n01000000\n51\n4153\n0F05",
        "48C7C0\n03000002\n52\n48C7C2\n01000000\n51\n4153\n0F05")
    buf = replace_all(buf,
        "48C7C0\n01000000\n52\n48C7C2\n01000000\n51\n4153\n0F05",
        "48C7C0\n04000002\n52\n48C7C2\n01000000\n51\n4153\n0F05")

    ## Single-replacement of exit-style sequence with empty string
    buf = replace_once(buf, "48C7C0\n0C000000\n51\n4153\n0F05\n415B\n59\n", "")

    buf = replace_all(buf, "48C7C0\n3C000000\n0F05", "48C7C0\n01000002\n0F05")

    buf = replace_once(buf,
        ":match\n53\n51\n52\n4889C1\n4889DA\n:match_Loop\n",
        ":match\n53\n51\n52\n4889C1\n4889DA\n4881F9\n00100000\n0F8C\n%match_False\n4881FA\n00100000\n0F8C\n%match_False\n:match_Loop\n")

    ## Inject :ELF_data label right before :prim_types (the first static
    ## data label) so macho-patcher m2-segments mode finds the static-
    ## block start.  Without this, m2-segments scans the source for one
    ## of `:ELF_data`/`:HEX2_data`/`:GLOBAL_*`/`:STRING_*`/`:_string_*`
    ## and bails when it finds none in cc_arch's lowercase label scheme.
    ## With the label in place, m2-segments produces byte-identical
    ## output to the prior `perl phase4-amd64-cc-arch.pl patch` step.
    buf = replace_once(buf, ":prim_types\n", ":ELF_data\n:prim_types\n")

    printf "%s", buf
}
