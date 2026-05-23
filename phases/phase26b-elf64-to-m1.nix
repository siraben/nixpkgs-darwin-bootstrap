args:
with args;
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-phase26b-elf64-to-m1-amd64" { } ''
        mkdir -p $out/bin $out/share/darwin-bootstrap

        ## Assemble the hand-written ELF→M1 converter through the existing
        ## stage0-derived M1+hex2 pipeline. No Python; no C compiler.
        ${phase9-m1}/bin/M1 \
          --architecture amd64 \
          --little-endian \
          -f ${root + "/M2libc/amd64/amd64_defs.M1"} \
          -f ${root + "/tools/elf64-to-m1.M1"} \
          -o elf64-to-m1.hex2 \
          > m1.stdout \
          2> m1.stderr

        ${phase10-hex2}/bin/hex2 \
          --architecture amd64 \
          --little-endian \
          --base-address 0x1000000 \
          -f ${root + "/M2libc/amd64/MACHO-amd64.hex2"} \
          -f elf64-to-m1.hex2 \
          -o elf64-to-m1 \
          > hex2.stdout \
          2> hex2.stderr

        ## Pad to __LINKEDIT so codesign can write the signature blob.
        linkeditOffset="$((0x800000 + 0x2000000))"
        dd if=/dev/zero of=elf64-to-m1 bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc \
          > dd.stdout 2> dd.stderr
        chmod +x elf64-to-m1

        source ${darwin.signingUtils}
        sign elf64-to-m1

        install -Dm755 elf64-to-m1 $out/bin/elf64-to-m1
        cp elf64-to-m1.hex2 m1.stdout m1.stderr hex2.stdout hex2.stderr \
          $out/share/darwin-bootstrap/
      ''
    else
      null
