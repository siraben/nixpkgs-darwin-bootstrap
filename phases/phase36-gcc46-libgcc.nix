args:
with args;
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-phase36-gcc-${gcc46Version}-libgcc-amd64" { } ''
        ${root + "/scripts/gcc46/phase36-libgcc.sh"} \
          ${phase35-gcc46-all-gcc} \
          ${phase34-tinycc-darwin-cc} \
          ${cctools} \
          ${python3}/bin/python3 \
          ${root + "/scripts/gcc46/phase36-libgcc.py"} \
          ${root + "/scripts/gcc46/phase36-bootstrap-as.awk"} \
          "$out" \
          ${gcc46Version} \
          ${root + "/scripts/gcc46/phase36-xgcc-wrapper.sh"}
      ''
    else
      null
