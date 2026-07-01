## hex1 — Darwin Mach-O hex1, assembled live from source.
##
## nix/hex0/sources/hex1_AMD64_darwin.hex0 is the genuine hand-documented hex0
## source for hex1 (Mach-O header + hex1 machine code + the Darwin EINTR
## retry stub) — no committed binary/padding blob.  The hex0 seed assembles
## it and dd pads to the LINKEDIT vmaddr (0x1000000) at build time.  Output
## runs unsigned in the Nix sandbox on x86_64 (verified empirically).
{
  darwin,
  hex0,
  hostPlatform,
  mkDarwin,
  root,
  stage0Sources,
  ...
}:

if hostPlatform.isx86_64 then
  mkDarwin {
    pname = "hex1";
    version = "0-unstable-2026-05-27";

    buildPhase = ''
      runHook preBuild
      ## Assemble hex1 from its committed hex0 source (genuine machine-code
      ## source, no padding blob), then pad to file size 0x1000000 (the
      ## LINKEDIT vmaddr).  Runs unsigned in the Nix sandbox on x86_64.
      ${hex0}/bin/hex0 ${root + "/hex0/sources/hex1_AMD64_darwin.hex0"} hex1-darwin
      dd if=/dev/zero of=hex1-darwin bs=1 count=1 seek="$((0x1000000 - 1))" conv=notrunc
      chmod +x hex1-darwin
      runHook postBuild
    '';

    doCheck = true;
    checkPhase = ''
      runHook preCheck
      cp ${root + "/stage0-posix/fixtures/hex1-input.hex1"} input.hex1
      printf 'Hi\n' > expected
      ./hex1-darwin input.hex1 output
      cmp expected output

      cp ${root + "/stage0-posix/fixtures/hex1-labels.hex1"} labels.hex1
      ./hex1-darwin labels.hex1 labels-output
      cmp expected labels-output

      cp ${root + "/stage0-posix/fixtures/hex1-pointer.hex1"} pointer.hex1
      printf '\xfc\xff\xff\xff' > pointer-expected
      ./hex1-darwin pointer.hex1 pointer-output
      cmp pointer-expected pointer-output
      runHook postCheck
    '';

    installPhase = ''
      runHook preInstall
      install -Dm755 hex1-darwin $out/bin/hex1-darwin
      install -Dm644 ${root + "/hex0/sources/hex1_AMD64_darwin.hex0"} \
        $out/share/darwin-bootstrap/hex1_AMD64_darwin.hex0
      runHook postInstall
    '';

    meta = {
      description = "Darwin Mach-O hex1, assembled from committed hex0 source via the hex0 seed";
    };
  }
else if hostPlatform.isAarch64 then
  mkDarwin {
    pname = "hex1";
    buildPhase = ''
      runHook preBuild

      awk 'seen { print } /^#:ELF_text/ { seen = 1 }' \
        ${stage0Sources}/AArch64/hex1_AArch64.hex0 > hex1-body.hex0

      bash ${root + "/scripts/stage0/aarch64-hex1-darwin.sh"}

      grep -v '^:' ${root + "/M2libc"}/aarch64/MACHO-aarch64.hex2 > hex1-darwin.hex0
      cat hex1-body.hex0 >> hex1-darwin.hex0

      ${hex0}/bin/hex0 hex1-darwin.hex0 hex1-darwin

      currentSize="$(wc -c < hex1-darwin | tr -d ' ')"
      if [ "$currentSize" -gt 16777216 ]; then
        echo "phase1 hex1 candidate exceeds reserved __TEXT before __LINKEDIT" >&2
        exit 1
      fi

      dd if=/dev/zero of=hex1-darwin bs=1 count=1 seek=16777215 conv=notrunc
      chmod +x hex1-darwin

      source ${darwin.signingUtils}
      sign hex1-darwin

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      install -Dm755 hex1-darwin $out/bin/hex1-darwin
      install -Dm644 hex1-darwin.hex0 $out/share/darwin-bootstrap/hex1_AArch64_darwin.hex0
      install -Dm644 hex1-body.hex0 $out/share/darwin-bootstrap/hex1_AArch64_darwin_body.hex0
      install -Dm644 ${root + "/stage0-posix/fixtures/hex1-darwin-readme.txt"} \
        $out/share/darwin-bootstrap/README
      runHook postInstall
    '';

    meta = {
      description = "Signed Darwin Mach-O hex1 candidate";
      platforms = [ "aarch64-darwin" ];
    };
  }
else
  null
