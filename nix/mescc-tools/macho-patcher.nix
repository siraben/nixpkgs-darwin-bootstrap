{
  darwin,
  hex2,
  elf64-to-m1,
  m1,
  root,
  runCommand,
  ...
}:
runCommand "macho-patcher" { } ''
  mkdir -p $out/bin $out/share/darwin-bootstrap

  ## Assemble the hand-written generic Mach-O patcher through the
  ## existing M1+hex2 pipeline.  No Python; no C compiler.  Pattern
  ## mirrors elf64-to-m1.
  ${m1}/bin/M1 \
    --architecture amd64 \
    --little-endian \
    -f ${root + "/M2libc/amd64/amd64_defs.M1"} \
    -f ${root + "/tools/macho-patcher.M1"} \
    -o macho-patcher.hex2 \
    > m1.stdout \
    2> m1.stderr

  ${hex2}/bin/hex2 \
    --architecture amd64 \
    --little-endian \
    --base-address 0x1000000 \
    -f ${root + "/M2libc/amd64/MACHO-amd64.hex2"} \
    -f macho-patcher.hex2 \
    -o macho-patcher \
    > hex2.stdout \
    2> hex2.stderr

  ## MACHO-amd64.hex2 declares __LINKEDIT.fileoff = 0x1000000.  Normalize to
  ## that boundary before signing; padding to 0x2800000 creates an unowned
  ## zero gap that codesign_allocate correctly refuses.
  linkeditOffset="$((0x1000000))"
  truncate -s "$linkeditOffset" macho-patcher
  chmod +x macho-patcher
  source ${darwin.signingUtils}
  sign macho-patcher

  install -Dm755 macho-patcher $out/bin/macho-patcher
  cp macho-patcher.hex2 m1.stdout m1.stderr hex2.stdout hex2.stderr \
    $out/share/darwin-bootstrap/
''
