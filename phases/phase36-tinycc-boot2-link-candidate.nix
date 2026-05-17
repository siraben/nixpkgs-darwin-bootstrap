args:
with args;
tinyccSelfLinkCandidate {
    phase = "phase36";
    boot = "tcc-boot2";
    compiler = "${phase33-tinycc-boot1-link-candidate}/bin/tcc-boot1-candidate";
    objectProbe = phase35-tinycc-boot2-object-probe;
  }
