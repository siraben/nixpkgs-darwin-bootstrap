{
  lib,
  hostPlatform,
}:

let
  phaseGraph = import ./phase-graph.nix { inherit lib; };
  platform = import ./platforms.nix { inherit lib hostPlatform; };
in
phaseGraph
// {
  inherit platform;
  inherit (platform)
    baseAddress
    bootstrapC
    executableHeader
    libcCore
    m2libcArch
    m2libcOS
    platforms
    stage0Arch
    ;
}
