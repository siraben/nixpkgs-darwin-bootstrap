{
  tinycc-boot2-link-candidate,
  tinycc-boot3-object-probe,
  tinyccSelfLinkCandidate,
  ...
}:
tinyccSelfLinkCandidate {
    phase = "phase38";
    boot = "tcc-boot3";
    compiler = "${tinycc-boot2-link-candidate}/bin/tcc-boot2-candidate";
    objectProbe = tinycc-boot3-object-probe;
  }
