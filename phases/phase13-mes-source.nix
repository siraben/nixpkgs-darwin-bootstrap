args:
with args;
    if hostPlatform.isx86_64 then
      stdenv.mkDerivation {
        pname = "darwin-minimal-bootstrap-phase13-mes-source";
        version = mesVersion;

        src = mesTarball;

        dontConfigure = true;
        dontBuild = true;
        dontFixup = true;

        nativeBuildInputs = [ perl ];

        installPhase = ''
          runHook preInstall

          mkdir -p $out/share/darwin-bootstrap
          cp -R . $out/
          chmod -R u+w $out
          cp ${mesDarwinConfigH} $out/include/mes/config.h
          cp -R ${root + "/mes-darwin"}/. $out/
          mkdir -p $out/include/arch
          cp $out/include/darwin/x86_64/kernel-stat.h $out/include/arch/kernel-stat.h
          cp $out/include/darwin/x86_64/signal.h $out/include/arch/signal.h
          cp $out/include/darwin/x86_64/syscall.h $out/include/arch/syscall.h
          bash ${root + "/scripts/mes/phase13-patch-assert-fail.sh"}

          cat > $out/share/darwin-bootstrap/darwin-mes-next.txt <<'EOF'
          This is the Darwin Mes source-prep checkpoint.
          Next steps:
          - port Mes include/linux and lib/linux references to Darwin;
          - add Darwin crt1, syscall, signal, stat, and setjmp support;
          - build mes-m2 with phase11-kaem, phase9-M1, and phase10-hex2.
          EOF

          test -f $out/kaem.x86_64
          test -f $out/scripts/mescc.scm.in
          test -f $out/lib/darwin/x86_64-mes-m2/crt1.M1
          test -f $out/include/darwin/x86_64/syscall.h
          test -f $out/include/arch/kernel-stat.h
          test -f $out/include/arch/signal.h
          test -f $out/include/arch/syscall.h
          grep -q 'MES_VERSION "${mesVersion}"' $out/include/mes/config.h
          grep -q 'typedef unsigned long uintptr_t' $out/include/mes/config.h

          runHook postInstall
        '';

        meta = {
          description = "Prepared GNU Mes source tree for the Darwin bootstrap path";
          platforms = [ "x86_64-darwin" ];
        };
      }
    else
      null
