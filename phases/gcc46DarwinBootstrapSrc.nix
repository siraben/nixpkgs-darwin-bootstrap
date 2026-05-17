args:
with args;
    runCommand "darwin-minimal-bootstrap-gcc-${gcc46Version}-darwin-bootstrap-source" { } ''
      mkdir -p $out
      cp -R ${phase26-gcc46-source}/. $out/
      chmod -R u+w $out
      cd $out
      patch -p1 < ${root + "/patches/gcc46-genconditions-tcc-safe.patch"}
      patch -p1 < ${root + "/patches/gcc46-darwin-bootstrap-host.patch"}
    ''
