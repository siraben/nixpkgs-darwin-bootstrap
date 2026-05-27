## Port upstream stage0-posix AMD64/catm_AMD64.hex2 to Darwin Mach-O.
## Mirrors scripts/stage0/port-catm-darwin.sh's perl+sed substitutions
## exactly, but in pure POSIX awk — no perl, no python.
##
## Strips the :ELF_text header marker (and everything before it), then
## applies five fixed-string multi-line substitutions to port:
##   1. argv handling (pop_rax/pop_rdi×2 → rsi-based)
##   2. SYS_BRK heap allocation → Darwin static buffer pointer
##   3. argv input handling
##   4. open/read/write/exit syscall numbers → Darwin 0x2000000-class
##
## Usage:
##   awk -f port-catm-darwin.awk < catm_AMD64.hex2 > catm_AMD64_darwin_body.hex2

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

## Skip everything up to and including the :ELF_text line.
/^:ELF_text$/ { found = 1; next }
!found { next }
{ buf = buf $0 "\n" }

END {
    ## 1. argv handling
    old = "\t58                          ; pop_rax                     # Get the number of arguments\n\t5F                          ; pop_rdi                     # Get the program name\n\t5F                          ; pop_rdi                     # Get the actual output name"
    new = "\t4889F3                      ; mov_rbx,rsi                 # Save Darwin argv\n\t488B7B08                    ; mov_rdi,[rbx+8]             # argv[1]\n\t4883C3 10                   ; add_rbx, !16                # argv[2]"
    buf = replace_once(buf, old, new)

    ## 2. SYS_BRK heap allocation → Darwin static buffer pointer
    old = "\t48C7C0 0C000000             ; mov_rax, %12                # the Syscall # for SYS_BRK\n\t48C7C7 00000000             ; mov_rdi, %0                 # Get current brk\n\t0F05                        ; syscall                     # Let the kernel do the work\n\t4989C6                      ; mov_r14,rax                 # Set our malloc pointer\n\n\t48C7C0 0C000000             ; mov_rax, %12                # the Syscall # for SYS_BRK\n\t4C89F7                      ; mov_r14,rax                 # Using current pointer\n\t4881C7 00001000             ; add_rdi, %0x100000          # Allocate 1MB\n\t0F05                        ; syscall                     # Let the kernel do the work"
    new = "\t49BE 0000E00000000000       ; mov_r14, %0xe00000          # Darwin static buffer"
    buf = replace_once(buf, old, new)

    ## 3. argv input handling
    old = "\t5F                          ; pop_rdi                     # Get the actual input name"
    new = "\t488B3B                      ; mov_rdi,[rbx]               # next argv\n\t4883C3 08                   ; add_rbx, !8                 # advance"
    buf = replace_once(buf, old, new)

    ## 4. Syscall number substitutions
    buf = replace_all(buf,
        "48C7C0 02000000             ; mov_rax, %2                 # the syscall number for open()",
        "48C7C0 05000002             ; mov_rax, %0x2000005       # Darwin open")
    buf = replace_all(buf, "48C7C6 41020000", "48C7C6 01060000")
    buf = replace_all(buf,
        "48C7C0 00000000             ; mov_rax, %0                 # the syscall number for read",
        "48C7C0 03000002             ; mov_rax, %0x2000003       # Darwin read")
    buf = replace_all(buf,
        "48C7C0 01000000             ; mov_rax, %1                 # the syscall number for write",
        "48C7C0 04000002             ; mov_rax, %0x2000004       # Darwin write")
    buf = replace_all(buf, "48C7C0 3C000000", "48C7C0 01000002")

    printf "%s", buf
}
