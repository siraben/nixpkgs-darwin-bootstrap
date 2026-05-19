args:
with args;
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-phase44-gcc-${gcc46Version}-cxx-amd64" {
        nativeBuildInputs = [ perl ];
      } ''
        ${root + "/scripts/gcc46/phase44-cxx.sh"} \
          ${phase35-gcc46-all-gcc} \
          ${phase37-gcc46-bootstrap} \
          ${phase39-gnumake} \
          ${phase34-tinycc-darwin-cc} \
          ${cctools} \
          "$out" \
          ${gcc46Version}
      ''
    else
      null
