{
  gcc46Version,
  gcc46-source,
  gnupatch,
  root,
  runCommand,
  ...
}:
    runCommand "gcc-${gcc46Version}-darwin-bootstrap-source" { } ''
      mkdir -p $out
      cp -R ${gcc46-source}/. $out/
      chmod -R u+w $out
      cd $out
      ${gnupatch}/bin/patch -p1 < ${root + "/patches/gcc46-genconditions-tcc-safe.patch"}
      ${gnupatch}/bin/patch -p1 < ${root + "/patches/gcc46-darwin-bootstrap-host.patch"}
      ${gnupatch}/bin/patch -p1 < ${root + "/patches/gcc46-darwin-macho-driver.patch"}
    ''
