args:
with args;
tinyccSelfLinkCandidate {
    phase = "phase38";
    boot = "tcc-boot3";
    compiler = "${phase36-tinycc-boot2-link-candidate}/bin/tcc-boot2-candidate";
    objectProbe = phase37-tinycc-boot3-object-probe;
  }
