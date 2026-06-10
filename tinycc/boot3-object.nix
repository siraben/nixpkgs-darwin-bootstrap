{
  tinycc-boot2-link-candidate,
  tinyccSelfObjectProbe,
  ...
}:
tinyccSelfObjectProbe {
    phase = "phase37";
    boot = "tcc-boot3";
    compiler = "${tinycc-boot2-link-candidate}/bin/tcc-boot2-candidate";
  }
