{
  phase33-tinycc-boot1-link-candidate,
  tinyccSelfObjectProbe,
  ...
}:
tinyccSelfObjectProbe {
    phase = "phase35";
    boot = "tcc-boot2";
    compiler = "${phase33-tinycc-boot1-link-candidate}/bin/tcc-boot1-candidate";
  }
