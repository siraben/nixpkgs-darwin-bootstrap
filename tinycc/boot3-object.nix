{
  phase36-tinycc-boot2-link-candidate,
  tinyccSelfObjectProbe,
  ...
}:
tinyccSelfObjectProbe {
    phase = "phase37";
    boot = "tcc-boot3";
    compiler = "${phase36-tinycc-boot2-link-candidate}/bin/tcc-boot2-candidate";
  }
