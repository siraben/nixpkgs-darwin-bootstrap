#!/usr/bin/env bash
# Port upstream stage0-posix AMD64/catm_AMD64.hex2 to Darwin Mach-O:
# substitute Linux SysV argv handling (pop_rax/pop_rdi), SYS_BRK heap
# allocation, and SYS_* numbers with Darwin equivalents.  Mirrors
# port_catm_source() in the (removed) tools/phase2-amd64-catm.py.
#
# Usage: port-catm-darwin.sh <stage0Sources> <output_file>
set -euo pipefail
stage0=$1
out=$2

# The upstream catm has a ":ELF_text" marker that splits the ELF
# header from the actual code body.  We only want the body.
awk '/^:ELF_text$/ { found=1; next } found { print }' \
  "$stage0/AMD64/catm_AMD64.hex2" > "$out"

# Patch 1: argv handling (pop_rax + pop_rdi + pop_rdi → mov_rbx,rsi + mov_rdi,[rbx+8] + add rbx,16)
perl -i -0pe 's/\t58                          ; pop_rax                     # Get the number of arguments\n\t5F                          ; pop_rdi                     # Get the program name\n\t5F                          ; pop_rdi                     # Get the actual output name/\t4889F3                      ; mov_rbx,rsi                 # Save Darwin argv\n\t488B7B08                    ; mov_rdi,[rbx+8]             # argv[1]\n\t4883C3 10                   ; add_rbx, !16                # argv[2]/' "$out"

# Patch 2: SYS_BRK heap allocation → Darwin static buffer pointer
perl -i -0pe 's/\t48C7C0 0C000000             ; mov_rax, %12                # the Syscall # for SYS_BRK\n\t48C7C7 00000000             ; mov_rdi, %0                 # Get current brk\n\t0F05                        ; syscall                     # Let the kernel do the work\n\t4989C6                      ; mov_r14,rax                 # Set our malloc pointer\n\n\t48C7C0 0C000000             ; mov_rax, %12                # the Syscall # for SYS_BRK\n\t4C89F7                      ; mov_r14,rax                 # Using current pointer\n\t4881C7 00001000             ; add_rdi, %0x100000          # Allocate 1MB\n\t0F05                        ; syscall                     # Let the kernel do the work/\t49BE 0000E00000000000       ; mov_r14, %0xe00000          # Darwin static buffer/' "$out"

# Patch 3: argv input handling
perl -i -0pe 's/\t5F                          ; pop_rdi                     # Get the actual input name/\t488B3B                      ; mov_rdi,[rbx]               # next argv\n\t4883C3 08                   ; add_rbx, !8                 # advance/' "$out"

# Patch 4-N: syscall number substitutions
sed -i.bak \
  -e 's|48C7C0 02000000             ; mov_rax, %2                 # the syscall number for open()|48C7C0 05000002             ; mov_rax, %0x2000005       # Darwin open|' \
  -e 's|48C7C6 41020000|48C7C6 01060000|' \
  -e 's|48C7C0 00000000             ; mov_rax, %0                 # the syscall number for read|48C7C0 03000002             ; mov_rax, %0x2000003       # Darwin read|' \
  -e 's|48C7C0 01000000             ; mov_rax, %1                 # the syscall number for write|48C7C0 04000002             ; mov_rax, %0x2000004       # Darwin write|' \
  -e 's|48C7C0 3C000000|48C7C0 01000002|' \
  "$out"
rm -f "$out.bak"
