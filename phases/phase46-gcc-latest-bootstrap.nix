args:
with args;
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-phase46-gcc-${gccLatestVersion}-amd64" { } ''
        ${root + "/scripts/gcc-modern/bootstrap-gcc.sh"} \
          ${phase43-gcc-latest-source} \
          ${phase45-gcc10-bootstrap} \
          ${phase39-gnumake} \
          ${phase34-tinycc-darwin-cc} \
          ${cctools} \
          "$out" \
          ${gccLatestVersion} \
          gcc-latest
      ''
    else
      null
