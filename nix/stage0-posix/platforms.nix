# Platform constants for the Darwin minimal-bootstrap stage0 graph.
{
  lib,
  hostPlatform,
}:

rec {
  platforms = [
    "aarch64-darwin"
    "x86_64-darwin"
  ];

  stage0Arch =
    {
      "aarch64-darwin" = "AArch64";
      "x86_64-darwin" = "AMD64";
    }
    .${hostPlatform.system} or (throw "Unsupported Darwin stage0 system: ${hostPlatform.system}");

  m2libcArch = lib.toLower stage0Arch;

  m2libcOS =
    if hostPlatform.isDarwin then
      "Darwin"
    else
      throw "Unsupported Darwin stage0 system: ${hostPlatform.system}";

  baseAddress =
    {
      "aarch64-darwin" = "0x100000000";
      "x86_64-darwin" = "0x100000000";
    }
    .${hostPlatform.system} or (throw "Unsupported Darwin stage0 system: ${hostPlatform.system}");

  executableHeader = "MACHO-${m2libcArch}.hex2";
  libcCore = "libc-core-Darwin.M1";
  bootstrapC = "${m2libcOS}/bootstrap.c";
}
