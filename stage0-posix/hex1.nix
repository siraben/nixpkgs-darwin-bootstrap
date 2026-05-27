## phase1-hex1 — seed-built Darwin Mach-O hex1.
##
## Both the binary bytes AND the LINKEDIT-vmaddr padding now live in
## hex0/sources/hex1_AMD64_darwin.hex0.  The pure `derivation{}` builder
## is hex0 itself; output runs unsigned in the Nix sandbox on x86_64
## (verified empirically).  A small stdenv wrapper installs the binary
## at the conventional $out/bin layout for downstream phases that haven't
## been migrated yet.
{
  darwin,
  hex0,
  hostPlatform,
  mkDarwin,
  root,
  stage0Sources,
  ...
}:

let
  ## --- pure seed-built hex1 (no stdenv) ---
  hex1-raw =
    if hostPlatform.isx86_64 then
      derivation {
        name = "phase1-hex1-raw";
        system = "x86_64-darwin";
        builder = hex0.hex0-raw;
        args = [
          (root + "/hex0/sources/hex1_AMD64_darwin.hex0")
          (placeholder "out")
        ];
        outputHashMode = "recursive";
        outputHashAlgo = "sha256";
        outputHash = "sha256-R3UV/XFmb2Q7WE4nSLgHP7LE98pNPL2VPaUIxvirNmw=";
      }
    else
      null;
in

if hostPlatform.isx86_64 then
  mkDarwin {
    pname = "phase1-hex1";
    version = "0-unstable-2026-05-27";

    buildPhase = ''
      runHook preBuild
      install -m755 ${hex1-raw} hex1-darwin
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

    passthru = { inherit hex1-raw; };

    meta = {
      description = "Seed-built Darwin Mach-O phase-1 AMD64 hex1 (no clang in trust path)";
    };
  }
else if hostPlatform.isAarch64 then
  mkDarwin {
    pname = "phase1-hex1";
    buildPhase = ''
      runHook preBuild

      awk 'seen { print } /^#:ELF_text/ { seen = 1 }' \
        ${stage0Sources}/AArch64/hex1_AArch64.hex0 > hex1-body.hex0

      bash ${root + "/scripts/stage0/phase1-aarch64-hex1-darwin.sh"}

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
      description = "Signed Darwin Mach-O phase-1 hex1 candidate";
      platforms = [ "aarch64-darwin" ];
    };
  }
else
  null
