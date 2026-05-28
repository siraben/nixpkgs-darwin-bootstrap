function strip_darwin_symbol_prefix(line, prefix, rest) {
  rest = line
  line = ""
  while (match(rest, /(^|[^A-Za-z0-9_$])_([A-Za-z_][A-Za-z0-9_$]*)/)) {
    if (RSTART == 1) {
      line = line substr(rest, 2, RLENGTH - 1)
    } else {
      line = line substr(rest, 1, RSTART) substr(rest, RSTART + 2, RLENGTH - 2)
    }
    rest = substr(rest, RSTART + RLENGTH)
  }
  return line rest
}

skip_section && /^[[:space:]]*\.(text|data|bss|section)[[:space:]]/ { skip_section = 0 }
skip_section { next }
/^[[:space:]]*\.section[[:space:]]+(__TEXT,__eh_frame|__DWARF,)/ { skip_section = 1; next }
/^[[:space:]]*\.section[[:space:]]+__TEXT,__text/ { print "\t.text"; next }
/^[[:space:]]*\.section[[:space:]]+__TEXT,__(cstring|literal)/ { print "\t.data"; next }
/^[[:space:]]*\.section[[:space:]]+__DATA,__data/ { print "\t.data"; next }
/^[[:space:]]*\.section[[:space:]]+__DATA,__bss/ { print "\t.bss"; next }
/^[[:space:]]*\.subsections_via_symbols[[:space:]]*$/ { next }
/^[[:space:]]*\.no_dead_strip[[:space:]]/ { next }
## Drop DWARF line directives.  tcc's assembler has no .loc (unknown
## opcode) and segfaults on the numbered ".file N \"name\"" form; libgcc
## needs no debug info, so strip both.
/^[[:space:]]*\.file[[:space:]]+[0-9]/ { next }
/^[[:space:]]*\.loc[[:space:]]/ { next }
/^[[:space:]]*\.(const|const_data|cstring|literal[0-9]*|static_data)[[:space:]]*$/ { print "\t.data"; next }
/^[[:space:]]*\.comm[[:space:]]/ {
  line = $0
  sub(/^[[:space:]]*\.comm[[:space:]]+/, "", line)
  n = split(line, parts, ",")
  if (n >= 2) {
    parts[1] = strip_darwin_symbol_prefix(parts[1])
    print "\t.bss"
    print "\t.globl " parts[1]
    print parts[1] ":"
    print "\t.skip " parts[2]
    next
  }
}
/^[[:space:]]*\.zerofill[[:space:]]/ {
  line = $0
  sub(/^[[:space:]]*\.zerofill[[:space:]]+/, "", line)
  n = split(line, parts, ",")
  if (n >= 4) {
    parts[3] = strip_darwin_symbol_prefix(parts[3])
    print "\t.bss"
    print "\t.globl " parts[3]
    print parts[3] ":"
    print "\t.skip " parts[4]
    next
  }
}
/^[[:space:]]*\.align[[:space:]]+[0-9]+/ {
  line = $0
  sub(/^[[:space:]]*\.align[[:space:]]+/, "", line)
  split(line, parts, ",")
  split(parts[1], words, /[[:space:]]+/)
  align = 1
  for (i = 0; i < words[1]; i++) align *= 2
  print "\t.align " align
  next
}
## GAS ".p2align <exp>[,<fill>][,<max>]" — power-of-2 align with optional
## fill/max-skip.  tcc's assembler chokes on the ",,," form, so convert to
## a plain byte ".align 2^exp" (dropping fill/max, which are advisory).
/^[[:space:]]*\.p2align[[:space:]]+[0-9]+/ {
  line = $0
  sub(/^[[:space:]]*\.p2align[[:space:]]+/, "", line)
  split(line, parts, ",")
  split(parts[1], words, /[[:space:]]+/)
  align = 1
  for (i = 0; i < words[1]; i++) align *= 2
  print "\t.align " align
  next
}
{
  if ($0 !~ /^[[:space:]]*\.(ascii|asciz|string)[[:space:]]/) {
    $0 = strip_darwin_symbol_prefix($0)
  }
  if ($0 ~ /^[[:space:]]*movq[[:space:]]+[A-Za-z_][A-Za-z0-9_$]*@GOTPCREL\(%rip\),[[:space:]]*%r/) {
    line = $0
    sub(/^[[:space:]]*movq[[:space:]]+/, "\tleaq ", line)
    sub(/@GOTPCREL/, "", line)
    print line
    next
  }
  gsub(/@GOTPCREL/, "")
  sub(/^[[:space:]]*movabsq[[:space:]]+/, "\tmovq ")
  sub(/^[[:space:]]*movabsl[[:space:]]+/, "\tmovl ")
  sub(/^[[:space:]]*movdqa[[:space:]]+/, "\tmovaps ")
  sub(/^[[:space:]]*movlps[[:space:]]+/, "\tmovq ")
  sub(/^[[:space:]]*movss[[:space:]]+/, "\tmovd ")
  sub(/^[[:space:]]*xorps[[:space:]]+/, "\tpxor ")
  sub(/^[[:space:]]*xorpd[[:space:]]+/, "\tpxor ")
  gsub(/bswap[[:space:]]+%r/, "bswapq %r")
  gsub(/bswap[[:space:]]+%e/, "bswapl %e")
  sub(/^[[:space:]]*salb[[:space:]]+/, "\tshlb ")
  sub(/^[[:space:]]*salw[[:space:]]+/, "\tshlw ")
  sub(/^[[:space:]]*sall[[:space:]]+/, "\tshll ")
  sub(/^[[:space:]]*salq[[:space:]]+/, "\tshlq ")
  if ($0 ~ /^[[:space:]]*cltq[[:space:]]*$/) {
    print "\t.byte 72,152"
    next
  }
  if ($0 ~ /^[[:space:]]*movaps[[:space:]]+%xmm[0-7],[[:space:]]*%xmm[0-7][[:space:]]*$/) {
    line = $0
    sub(/^[[:space:]]*movaps[[:space:]]+%xmm/, "", line)
    split(line, regs, /,[[:space:]]*%xmm/)
    print "\t.byte 15,40," (192 + (regs[2] * 8) + regs[1])
    next
  }
  if ($0 ~ /^[[:space:]]*divss[[:space:]]+%xmm[0-7],[[:space:]]*%xmm[0-7][[:space:]]*$/) {
    line = $0
    sub(/^[[:space:]]*divss[[:space:]]+%xmm/, "", line)
    split(line, regs, /,[[:space:]]*%xmm/)
    print "\t.byte 243,15,94," (192 + (regs[2] * 8) + regs[1])
    next
  }
  if ($0 ~ /^[[:space:]]*divsd[[:space:]]+%xmm[0-7],[[:space:]]*%xmm[0-7][[:space:]]*$/) {
    line = $0
    sub(/^[[:space:]]*divsd[[:space:]]+%xmm/, "", line)
    split(line, regs, /,[[:space:]]*%xmm/)
    print "\t.byte 242,15,94," (192 + (regs[2] * 8) + regs[1])
    next
  }
  print
}
