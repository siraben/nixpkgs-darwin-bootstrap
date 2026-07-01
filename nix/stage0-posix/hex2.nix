## hex2 — Darwin Mach-O hex2 linker, assembled live from source.
##
## nix/hex0/sources/hex2_AMD64_darwin.hex0 is the genuine hand-documented hex0
## source for hex2 (Mach-O header + hex2 machine code) — no committed
## binary/padding blob.  The hex0 seed assembles it and dd pads to the
## LINKEDIT vmaddr (0x1800000) at build time.  Output runs unsigned in the
## Nix sandbox on x86_64.
{
  hex0,
  hostPlatform,
  mkDarwin,
  root,
  ...
}:

if hostPlatform.isx86_64 then
  mkDarwin {
    pname = "hex2-0";
    version = "0-unstable-2026-05-27";

    buildPhase = ''
      runHook preBuild
      ${hex0}/bin/hex0 ${root + "/hex0/sources/hex2_AMD64_darwin.hex0"} hex2-darwin
      dd if=/dev/zero of=hex2-darwin bs=1 count=1 seek="$((0x1800000 - 1))" conv=notrunc
      chmod +x hex2-darwin
      runHook postBuild
    '';

    doCheck = true;
    checkPhase = ''
      runHook preCheck
      cp ${root + "/stage0-posix/fixtures/hex2-labels.hex2"} labels.hex2
      printf 'Hi\n' > expected
      ./hex2-darwin labels.hex2 labels-output
      cmp expected labels-output

      cp ${root + "/stage0-posix/fixtures/hex2-pointer.hex2"} pointer.hex2
      printf '\xfc\xff\xff\xff' > pointer-expected
      ./hex2-darwin pointer.hex2 pointer-output
      cmp pointer-expected pointer-output
      runHook postCheck
    '';

    installPhase = ''
      runHook preInstall
      install -Dm755 hex2-darwin $out/bin/hex2-darwin
      install -Dm644 ${root + "/hex0/sources/hex2_AMD64_darwin.hex0"} \
        $out/share/darwin-bootstrap/hex2_AMD64_darwin.hex0
      runHook postInstall
    '';

    meta = {
      description = "Darwin Mach-O hex2 linker, assembled from committed hex0 source via the hex0 seed";
    };
  }
else
  null
