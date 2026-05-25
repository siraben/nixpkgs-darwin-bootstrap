#!/usr/bin/env bash
# Port upstream stage0-posix M0_AMD64.hex2 to Darwin Mach-O: substitute
# Linux SysV argv handling, SYS_BRK heap allocation, and SYS_* syscall
# numbers with Darwin equivalents.  Mirrors port_m0_source() in the
# (removed) tools/phase3-amd64-m0.py.
#
# Usage: port-m0-darwin.sh <stage0Sources> <output_file>
set -euo pipefail
stage0=$1
out=$2

python_free_sed() {
  # GNU/BSD-portable in-place edit
  awk -v RS= -v ORS= '{print}' "$1" > "$1.tmp"
  mv "$1.tmp" "$1"
}

cp "$stage0/AMD64/M0_AMD64.hex2" "$out"

# 1. argv handling: pop_rax + pop_rdi×2 (Linux pops argc+argv[0]+argv[1])
#    → Darwin: argv is in rsi, dereference rsi[8] for argv[1]
perl -i -0pe 's/    58                      ; pop_rax                     # Get the number of arguments\n    5F                      ; pop_rdi                     # Get the program name\n    5F                      ; pop_rdi                     # Get the actual input name/    4889F3                  ; mov_rbx,rsi                 # Save Darwin argv\n    488B7B08                ; mov_rdi,[rbx+8]             # argv[1]/' "$out"

# 2. argv[2] (Linux pops rdi; Darwin dereferences rsi[16])
perl -i -0pe 's/    5F                      ; pop_rdi                     # Get the actual output name/    488B7B10                ; mov_rdi,[rbx+16]            # argv[2]/' "$out"

# 3. SYS_BRK (12) heap allocation → Darwin static heap pointer
perl -i -0pe 's/    48C7C0 0C000000         ; mov_rax, %12                # the Syscall # for SYS_BRK\n    48C7C7 00000000         ; mov_rdi, %0                 # Get current brk\n    0F05                    ; syscall                     # Let the kernel do the work\n    4989C4                  ; mov_r12,rax                 # Set our malloc pointer/    49BC 0000E00000000000   ; mov_r12, %0xe00000          # Darwin static heap/' "$out"

# 4. Remove second SYS_BRK call (Darwin uses pre-allocated buffer)
perl -i -0pe 's/    48C7C0 0C000000         ; mov_rax, %12                # the Syscall # for SYS_BRK\n    51                      ; push_rcx                    # Protect rcx\n    4153                    ; push_r11                    # Protect r11\n    0F05                    ; syscall                     # call the Kernel\n    415B                    ; pop_r11                     # Restore r11\n    59                      ; pop_rcx                     # Restore rcx\n//' "$out"

# 5. Syscall number substitutions (Linux SYS_* → Darwin 0x02000000-class)
sed -i.bak \
  -e 's|48C7C0 02000000         ; mov_rax, %2                 # the syscall number for open()|48C7C0 05000002         ; mov_rax, %0x2000005       # Darwin open|' \
  -e 's|48C7C6 41020000|48C7C6 01060000|' \
  -e 's|48C7C0 00000000         ; mov_rax, %0                 # the syscall number for read|48C7C0 03000002         ; mov_rax, %0x2000003       # Darwin read|' \
  -e 's|48C7C0 01000000         ; mov_rax, %1                 # the syscall number for write|48C7C0 04000002         ; mov_rax, %0x2000004       # Darwin write|' \
  -e 's|48C7C0 3C000000|48C7C0 01000002|' \
  "$out"
rm -f "$out.bak"
