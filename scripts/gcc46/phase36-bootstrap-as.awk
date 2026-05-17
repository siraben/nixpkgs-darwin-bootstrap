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
/^[[:space:]]*\.(const|const_data|cstring|literal[0-9]*|static_data)[[:space:]]*$/ { print "\t.data"; next }
/^[[:space:]]*\.comm[[:space:]]/ {
  line = $0
  sub(/^[[:space:]]*\.comm[[:space:]]+/, "", line)
  n = split(line, parts, ",")
  if (n >= 2) {
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
{
  if ($0 !~ /^[[:space:]]*\.(ascii|asciz|string)[[:space:]]/) {
    $0 = strip_darwin_symbol_prefix($0)
  }
  gsub(/@GOTPCREL/, "")
  gsub(/\<movabsq\>/, "movq")
  gsub(/\<movabsl\>/, "movl")
  gsub(/\<movdqa\>/, "movaps")
  gsub(/\<movss\>/, "movd")
  gsub(/\<xorps\>/, "pxor")
  gsub(/\<xorpd\>/, "pxor")
  gsub(/bswap[[:space:]]+%r/, "bswapq %r")
  gsub(/bswap[[:space:]]+%e/, "bswapl %e")
  gsub(/\<salb\>/, "shlb")
  gsub(/\<salw\>/, "shlw")
  gsub(/\<sall\>/, "shll")
  gsub(/\<salq\>/, "shlq")
  if ($0 ~ /^[[:space:]]*cltq[[:space:]]*$/) {
    print "\t.byte 72,152"
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
