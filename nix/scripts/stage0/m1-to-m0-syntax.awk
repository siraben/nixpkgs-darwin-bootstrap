## Rewrite the two M1-only syntactic extensions into M0-friendly form so
## M0 (which only supports DEFINE name → bytes) can assemble M1 sources:
##
##   !0xXX           → BYTE_XX           (single raw byte, uppercase hex)
##   %0xNNN          → 4 BYTE_XX tokens  (little-endian 32-bit immediate)
##
## Pure POSIX awk — no perl, no python.  Used by phases that bootstrap a
## macho-patcher binary before M2-Planet (the m2 attr) exists (see
## macho-patcher-early).
##
## The macho-patcher-early build path verifies via cmp against
## macho-patcher.

function hex_to_le_bytes(hex_str,    padded, b0, b1, b2, b3) {
    ## Left-pad to 8 hex chars, then peel off LE bytes from the right.
    padded = hex_str
    while (length(padded) < 8) padded = "0" padded
    b3 = toupper(substr(padded, 1, 2))
    b2 = toupper(substr(padded, 3, 2))
    b1 = toupper(substr(padded, 5, 2))
    b0 = toupper(substr(padded, 7, 2))
    return "BYTE_" b0 " BYTE_" b1 " BYTE_" b2 " BYTE_" b3
}

function rewrite_byte_marker(line,    pos, h, result) {
    result = ""
    while ((pos = match(line, /!0x[0-9a-fA-F][0-9a-fA-F]/)) > 0) {
        h = toupper(substr(line, pos + 3, 2))
        result = result substr(line, 1, pos - 1) "BYTE_" h
        line = substr(line, pos + RLENGTH)
    }
    return result line
}

function rewrite_imm32(line,    pos, hex, le_bytes, result) {
    result = ""
    while ((pos = match(line, /%0x[0-9a-fA-F]+/)) > 0) {
        hex = substr(line, pos + 3, RLENGTH - 3)
        le_bytes = hex_to_le_bytes(hex)
        result = result substr(line, 1, pos - 1) le_bytes
        line = substr(line, pos + RLENGTH)
    }
    return result line
}

{
    line = rewrite_byte_marker($0)
    line = rewrite_imm32(line)
    print line
}
