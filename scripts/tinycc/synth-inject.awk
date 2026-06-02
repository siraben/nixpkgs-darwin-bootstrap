# synth-inject.awk — inject precise cross-object `:<sym>_plus_<hex>` synth-label
# definitions into a combined M1 stream.
#
# elf64-to-m1 emits a synthetic label for every `sym+offset` reference, but it
# can only DEFINE the ones it can predict (its own relocs + a small blanket).
# A cross-object reference whose offset the defining object never relocates
# (e.g. a C++ vtable slot `_ZTV...sym_plus_730`) is left undefined and hex2
# rejects it.  This pass scans the *whole* link for `&sym_plus_<hex>` /
# `%sym_plus_<hex>` references that have no matching `:sym_plus_<hex>` def, and
# injects the def at the correct byte (the position of `:sym` + <hex>), so the
# label resolves to the right address.  Precise = only the handful actually
# referenced, so no hex2 OOM.
#
# Usage: awk -f synth-inject.awk <combined.M1 >combined.injected.M1
# Single pass is impossible (a needed def may sit before its `:sym`), so the
# caller runs it after the references/defs have been collected; this script
# does its own two passes over the file given as ARGV[1].
#
# ARGV[1] = the combined M1 file (read twice).
BEGIN {
    f = ARGV[1]
    # ---- pass A: collect referenced and defined _plus_ labels ----
    while ((getline line < f) > 0) {
        n = split(line, tok, /[ \t]+/)
        for (i = 1; i <= n; i++) {
            t = tok[i]
            c = substr(t, 1, 1)
            if (c == "&" || c == "%") {
                lab = substr(t, 2)
                sub(/>.*/, "", lab)          # strip a >base suffix
                if (lab ~ /_plus_[0-9a-fA-F]+$/) refd[lab] = 1
            } else if (c == ":") {
                lab = substr(t, 2)
                if (lab ~ /_plus_[0-9a-fA-F]+$/) defd[lab] = 1
            }
        }
    }
    close(f)
    # ---- needed = referenced \ defined ; index by base symbol ----
    nneed = 0
    for (lab in refd) {
        if (lab in defd) continue
        # split "<base>_plus_<hex>" on the LAST _plus_
        if (match(lab, /_plus_[0-9a-fA-F]+$/)) {
            base = substr(lab, 1, RSTART - 1)
            hex  = substr(lab, RSTART + 6)
            need[base] = need[base] " " hex
            nneed++
        }
    }
    # ARGV[1] still read again below by the main rule (pass B).
}

# hexadecimal string -> integer
function h2i(s,   v, i, c, d) {
    v = 0
    for (i = 1; i <= length(s); i++) {
        c = tolower(substr(s, i, 1))
        if (c >= "0" && c <= "9") d = index("0123456789", c) - 1
        else d = index("abcdef", c) + 9
        v = v * 16 + d
    }
    return v
}

# byte width contributed by an M1 data token
function tokbytes(t,   c) {
    c = substr(t, 1, 1)
    if (c == "!") return 1
    if (c == "&" || c == "%") return 4
    if (c == "@" || c == "$") return 2
    if (c == "~") return 3
    return 0                                   # :label, markers, blank
}

# emit any scheduled injections whose target == current pos
function flush_at(p,   key, parts, i, nn) {
    key = sched[p]
    if (key == "") return
    delete sched[p]
    nn = split(key, parts, "\x01")
    for (i = 1; i <= nn; i++) if (parts[i] != "") print ":" parts[i]
}

# ---- pass B: walk the file, track data byte position, inject ----
# We only care about byte positions; the marker `:HEX2_data` (or the first data
# byte) starts the data address space at 0, matching how hex2 lays labels.
nneed == 0 { print; next }          # common case: nothing to inject, pass through verbatim
{
    n = split($0, tok, /[ \t]+/)
    for (i = 1; i <= n; i++) {
        t = tok[i]
        if (t == "") continue
        c = substr(t, 1, 1)
        if (c == ":") {
            # before defining this label, flush injections that land exactly here
            flush_at(pos)
            base = substr(t, 2)
            print ":" base
            if (base in need) {
                m = split(need[base], ks, " ")
                for (j = 1; j <= m; j++) {
                    if (ks[j] == "") continue
                    tp = pos + h2i(ks[j])
                    sched[tp] = sched[tp] "\x01" base "_plus_" ks[j]
                }
            }
            continue
        }
        b = tokbytes(t)
        if (b == 0) { print t; continue }
        # a byte-emitting token occupies [pos, pos+b); an injection can only sit
        # at a byte boundary == pos (start of this token).  Flush then emit.
        flush_at(pos)
        print t
        pos += b
    }
}
END { flush_at(pos) }
