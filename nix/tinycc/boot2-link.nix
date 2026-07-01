{
  tinycc-boot1-link-candidate,
  tinycc-boot2-object-probe,
  tinyccSelfLinkCandidate,
  ...
}:
tinyccSelfLinkCandidate {
    phase = "phase36";
    boot = "tcc-boot2";
    compiler = "${tinycc-boot1-link-candidate}/bin/tcc-boot1-candidate";
    objectProbe = tinycc-boot2-object-probe;
  }
