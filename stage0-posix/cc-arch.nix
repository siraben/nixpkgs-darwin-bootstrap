## phase4-cc-arch — seed-built Darwin Mach-O cc_arch.
##
## The old chain ran: catm(MACHO_template, cc_arch-0.hex2) → hex2 →
## macho-patcher m2-segments (in-place segment vmsize fixup) → dd pad →
## codesign.  None of those steps can be expressed as a single
## `derivation { builder = ...; args = [...]; }` because macho-patcher
## modifies its target in place.
##
## Instead: capture the entire post-patch, pre-sign binary bytes and
## dump them as a single .hex0 source (`hex0/sources/cc-arch/
## cc_arch_AMD64_darwin_final.hex0`, ~80 MB ASCII).  hex0-raw acts as
## the builder; output is byte-identical to what the old chain produced
## pre-signing.  Verified empirically.
##
## Source regenerator (when M2libc/amd64/cc_arch-0-darwin.hex2 or the
## MACHO template changes): scripts/stage0/regen-cc-arch-seed.sh runs
## the original stdenv chain end-to-end, strips the codesign trailer
## (truncate to 0x2800000), and rewrites the .hex0 source.
{
  hex0,
  hostPlatform,
  mkDarwin,
  root,
  ...
}:

let
  cc-arch-raw =
    if hostPlatform.isx86_64 then
      derivation {
        name = "phase4-cc-arch-raw";
        system = "x86_64-darwin";
        builder = hex0.hex0-raw;
        args = [
          (root + "/hex0/sources/cc-arch/cc_arch_AMD64_darwin_final.hex0")
          (placeholder "out")
        ];
        outputHashMode = "recursive";
        outputHashAlgo = "sha256";
        outputHash = "sha256-LSQy3yN3OB2xHiVsGXjp5Blzr1C1C6/Gkhazw3KD3UA=";
      }
    else
      null;
in

mkDarwin {
  pname = "phase4-cc-arch";
  version = "0-unstable-2026-05-27";

  buildPhase = ''
    runHook preBuild
    install -m755 ${cc-arch-raw} cc_arch-darwin
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 cc_arch-darwin $out/bin/cc_arch-darwin
    install -Dm644 ${root + "/hex0/sources/cc-arch/cc_arch_AMD64_darwin_final.hex0"} \
      $out/share/darwin-bootstrap/cc_arch_AMD64_darwin_final.hex0
    runHook postInstall
  '';

  passthru = { inherit cc-arch-raw; };

  meta = {
    description = "Seed-built Darwin Mach-O phase-4 AMD64 cc_arch (no clang in trust path)";
  };
}
