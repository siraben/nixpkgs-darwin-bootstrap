## Port upstream stage0-posix AMD64/M0_AMD64.hex2 to Darwin Mach-O.
## Mirrors scripts/stage0/port-m0-darwin.sh's perl substitutions exactly,
## but in pure POSIX awk — no perl, no python.
##
## Substitutes:
##   1. Linux pop_rax/pop_rdi argv handling → Darwin rsi-based
##   2. argv[2] dereference
##   3. SYS_BRK heap → static heap pointer
##   4. Second SYS_BRK call removed (Darwin uses pre-allocated buffer)
##   5. open/read/write/exit syscall numbers → Darwin 0x2000000-class
##
## Usage:
##   awk -f port-m0-darwin.awk < M0_AMD64.hex2 > M0_AMD64_darwin_body.hex2

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
    ## 1. argv handling: pop_rax + pop_rdi×2 → rsi-based
    old = "    58                      ; pop_rax                     # Get the number of arguments\n    5F                      ; pop_rdi                     # Get the program name\n    5F                      ; pop_rdi                     # Get the actual input name"
    new = "    4889F3                  ; mov_rbx,rsi                 # Save Darwin argv\n    488B7B08                ; mov_rdi,[rbx+8]             # argv[1]"
    buf = replace_once(buf, old, new)

    ## 2. argv[2]
    old = "    5F                      ; pop_rdi                     # Get the actual output name"
    new = "    488B7B10                ; mov_rdi,[rbx+16]            # argv[2]"
    buf = replace_once(buf, old, new)

    ## 3. SYS_BRK heap allocation → Darwin static heap pointer
    old = "    48C7C0 0C000000         ; mov_rax, %12                # the Syscall # for SYS_BRK\n    48C7C7 00000000         ; mov_rdi, %0                 # Get current brk\n    0F05                    ; syscall                     # Let the kernel do the work\n    4989C4                  ; mov_r12,rax                 # Set our malloc pointer"
    new = "    49BC 0000E00000000000   ; mov_r12, %0xe00000          # Darwin static heap"
    buf = replace_once(buf, old, new)

    ## 4. Second SYS_BRK call removed
    old = "    48C7C0 0C000000         ; mov_rax, %12                # the Syscall # for SYS_BRK\n    51                      ; push_rcx                    # Protect rcx\n    4153                    ; push_r11                    # Protect r11\n    0F05                    ; syscall                     # call the Kernel\n    415B                    ; pop_r11                     # Restore r11\n    59                      ; pop_rcx                     # Restore rcx\n"
    buf = replace_once(buf, old, "")

    ## 5. Syscall number substitutions
    buf = replace_all(buf,
        "48C7C0 02000000         ; mov_rax, %2                 # the syscall number for open()",
        "48C7C0 05000002         ; mov_rax, %0x2000005       # Darwin open")
    buf = replace_all(buf, "48C7C6 41020000", "48C7C6 01060000")
    buf = replace_all(buf,
        "48C7C0 00000000         ; mov_rax, %0                 # the syscall number for read",
        "48C7C0 03000002         ; mov_rax, %0x2000003       # Darwin read")
    buf = replace_all(buf,
        "48C7C0 01000000         ; mov_rax, %1                 # the syscall number for write",
        "48C7C0 04000002         ; mov_rax, %0x2000004       # Darwin write")
    buf = replace_all(buf, "48C7C0 3C000000", "48C7C0 01000002")

    printf "%s", buf
}
