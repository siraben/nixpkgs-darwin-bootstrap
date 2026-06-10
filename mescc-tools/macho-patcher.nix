{
  hex2,
  elf64-to-m1,
  m1,
  root,
  runCommand,
  ...
}:
runCommand "phase26c-macho-patcher" { } ''
  mkdir -p $out/bin $out/share/darwin-bootstrap

  ## Assemble the hand-written generic Mach-O patcher through the
  ## existing M1+hex2 pipeline.  No Python; no C compiler.  Pattern
  ## mirrors phase26b-elf64-to-m1.
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

  ## No codesign: same reasoning as phase26b — Darwin nix-sandbox
  ## loader runs unsigned native code, and the Mach-O segment-size
  ## patcher cycle is exactly what we're replacing.
  linkeditOffset="$((0x800000 + 0x2000000))"
  dd if=/dev/zero of=macho-patcher bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc \
    > dd.stdout 2> dd.stderr
  chmod +x macho-patcher

  install -Dm755 macho-patcher $out/bin/macho-patcher
  cp macho-patcher.hex2 m1.stdout m1.stderr hex2.stdout hex2.stderr \
    $out/share/darwin-bootstrap/
''
