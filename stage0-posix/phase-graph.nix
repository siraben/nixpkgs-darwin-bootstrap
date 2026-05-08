{ lib }:

let
  darwinM2libc = arch: "M2libc/${arch}/Darwin";
  defs = arch: "M2libc/${arch}/${arch}_defs.M1";
  libcCore = arch: "M2libc/${arch}/libc-core-Darwin.M1";
  macho = arch: "M2libc/${arch}/MACHO-${arch}.hex2";
  phases = [
    {
      number = 0;
      name = "hex0-seed";
      builder = "trusted Mach-O seed";
      inputs = [ "stage0-posix/<arch>/hex0_<arch>.hex0" ];
      output = "hex0";
      darwinStatus = "implemented as a C-built seed until hand-written Mach-O hex0 bytes exist";
    }
    {
      number = 1;
      name = "hex1";
      builder = "hex0";
      inputs = [ "stage0-posix/<arch>/hex1_<arch>.hex0" ];
      output = "hex1";
      darwinStatus = "implemented for amd64 Darwin as a signed Mach-O wrapper around the stage0 payload";
    }
    {
      number = 2;
      name = "hex2-0";
      builder = "hex1";
      inputs = [ "stage0-posix/<arch>/hex2_<arch>.hex1" ];
      output = "hex2-0";
      darwinStatus = "implemented for amd64 Darwin as phase2-hex2";
    }
    {
      number = 3;
      name = "catm";
      builder = "hex1 or hex2-0";
      inputs = [ "stage0-posix/<arch>/catm_<arch>.hex{1,2}" ];
      output = "catm";
      darwinStatus = "implemented for amd64 Darwin as phase2-catm";
    }
    {
      number = 4;
      name = "M0";
      builder = "hex2-0";
      inputs = [ (macho "<arch>") "stage0-posix/<arch>/M0_<arch>.hex2" ];
      output = "M0";
      darwinStatus = "implemented for amd64 Darwin as phase3-m0";
    }
    {
      number = 5;
      name = "cc_arch";
      builder = "M0 then hex2-0";
      inputs = [ (macho "<arch>") "stage0-posix/<arch>/cc_<arch>.M1" ];
      output = "cc_arch";
      darwinStatus = "implemented for amd64 Darwin as phase4-cc-arch";
    }
    {
      number = 6;
      name = "M2-0";
      builder = "cc_arch then M0 then hex2-0";
      inputs = [ (darwinM2libc "<arch>") (defs "<arch>") (libcCore "<arch>") (macho "<arch>") "M2-Planet/*.c" ];
      output = "M2";
      darwinStatus = "implemented for amd64 Darwin as phase5-m2";
    }
    {
      number = 7;
      name = "blood-elf-0";
      builder = "M2 then M0 then hex2-0";
      inputs = [ (darwinM2libc "<arch>") (defs "<arch>") (libcCore "<arch>") (macho "<arch>") "mescc-tools/blood-elf.c" ];
      output = "blood-macho-0";
      darwinStatus = "implemented for amd64 Darwin as phase6-blood-macho-0; ELF debug footer use remains disabled for Mach-O-linked tools";
    }
    {
      number = 8;
      name = "M1-0";
      builder = "M2, blood-macho-0, M0, hex2-0";
      inputs = [ "mescc-tools/M1-macro.c" ];
      output = "M1-0";
      darwinStatus = "implemented for amd64 Darwin as phase7-m1-0";
    }
    {
      number = 9;
      name = "hex2-1";
      builder = "M2, blood-macho-0, M1-0, hex2-0";
      inputs = [ "mescc-tools/hex2*.c" ];
      output = "hex2-1";
      darwinStatus = "implemented for amd64 Darwin as phase8-hex2-1 using the Mach-O low-data header";
    }
    {
      number = 10;
      name = "M1";
      builder = "M2, blood-macho-0, M1-0, hex2-1";
      inputs = [ "mescc-tools/M1-macro.c" ];
      output = "M1";
      darwinStatus = "implemented for amd64 Darwin as phase9-m1";
    }
    {
      number = 11;
      name = "hex2";
      builder = "M2, blood-macho-0, M1, hex2-1";
      inputs = [ "mescc-tools/hex2*.c" ];
      output = "hex2";
      darwinStatus = "implemented for amd64 Darwin as phase10-hex2 using the Mach-O low-data header";
    }
    {
      number = 12;
      name = "kaem";
      builder = "M2, blood-macho-0, M1, hex2";
      inputs = [ "mescc-tools/Kaem/*.c" ];
      output = "kaem";
      darwinStatus = "implemented for amd64 Darwin as phase11-kaem";
    }
    {
      number = 13;
      name = "M2-Planet";
      builder = "M2, blood-macho, M1, hex2";
      inputs = [ (darwinM2libc "<arch>") "M2-Planet/*.c" ];
      output = "M2-Planet";
      darwinStatus = "implemented for amd64 Darwin as phase12-m2-planet";
    }
    {
      number = 14;
      name = "tinycc-mes";
      builder = "M2-Planet/MesCC chain";
      inputs = [ "tinycc bootstrappable fork" "Darwin M2libc" "Mach-O hex2" ];
      output = "tcc";
      darwinStatus = "blocked: the bootstrappable TinyCC fork is MesCC-oriented and ELF-only at this point; Darwin needs a Mes compiler path plus Mach-O TCC backend/runtime work";
    }
  ];
in
{
  inherit phases;

  completed = [
    "raw syscall smoke binary"
    "C-built hex0 seed for experimentation"
    "Darwin M2libc bootstrap syscall stubs"
    "Darwin M2libc startup M1 snippets"
    "amd64 Darwin MesCC tools through kaem"
    "amd64 Darwin full M2-Planet"
  ];

  missingCriticalPath = [
    "hand-written Mach-O hex0 seed bytes"
    "Mach-O debug footer/symbol generator for debug-enabled MesCC stages"
    "TCC Darwin bootstrap path: Mes compiler input, Mach-O backend, and libc/libtcc1 runtime"
  ];

  sameLengthAsLinuxMesccToolsBoot = builtins.length phases == 15;
}
