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
      darwinStatus = "blocked: upstream hex1_<arch>.hex0 emits ELF, needs Mach-O replacement";
    }
    {
      number = 2;
      name = "hex2-0";
      builder = "hex1";
      inputs = [ "stage0-posix/<arch>/hex2_<arch>.hex1" ];
      output = "hex2-0";
      darwinStatus = "blocked on phase 1 and Mach-O syscall/header port";
    }
    {
      number = 3;
      name = "catm";
      builder = "hex1 or hex2-0";
      inputs = [ "stage0-posix/<arch>/catm_<arch>.hex{1,2}" ];
      output = "catm";
      darwinStatus = "blocked on phase 1/2 and Mach-O syscall/header port";
    }
    {
      number = 4;
      name = "M0";
      builder = "hex2-0";
      inputs = [ (macho "<arch>") "stage0-posix/<arch>/M0_<arch>.hex2" ];
      output = "M0";
      darwinStatus = "MACHO-<arch>.hex2 template started; blocked on signed phase wrapper and Darwin M0/syscall source";
    }
    {
      number = 5;
      name = "cc_arch";
      builder = "M0 then hex2-0";
      inputs = [ (macho "<arch>") "stage0-posix/<arch>/cc_<arch>.M1" ];
      output = "cc_arch";
      darwinStatus = "blocked on M0 and signed Mach-O phase output";
    }
    {
      number = 6;
      name = "M2-0";
      builder = "cc_arch then M0 then hex2-0";
      inputs = [ (darwinM2libc "<arch>") (defs "<arch>") (libcCore "<arch>") (macho "<arch>") "M2-Planet/*.c" ];
      output = "M2";
      darwinStatus = "M2libc Darwin startup/syscalls started; blocked on prior Mach-O executable phases";
    }
    {
      number = 7;
      name = "blood-elf-0";
      builder = "M2 then M0 then hex2-0";
      inputs = [ (darwinM2libc "<arch>") (defs "<arch>") (libcCore "<arch>") (macho "<arch>") "mescc-tools/blood-elf.c" ];
      output = "blood-macho-0";
      darwinStatus = "blocked: blood-elf must be ported/replaced for Mach-O symbol/footer generation";
    }
    {
      number = 8;
      name = "M1-0";
      builder = "M2, blood-macho-0, M0, hex2-0";
      inputs = [ "mescc-tools/M1-macro.c" ];
      output = "M1-0";
      darwinStatus = "blocked on blood-macho-0";
    }
    {
      number = 9;
      name = "hex2-1";
      builder = "M2, blood-macho-0, M1-0, hex2-0";
      inputs = [ "mescc-tools/hex2*.c" ];
      output = "hex2-1";
      darwinStatus = "blocked: hex2_linker needs --macho/final wrapper support";
    }
    {
      number = 10;
      name = "M1";
      builder = "M2, blood-macho-0, M1-0, hex2-1";
      inputs = [ "mescc-tools/M1-macro.c" ];
      output = "M1";
      darwinStatus = "blocked on hex2-1 Mach-O output";
    }
    {
      number = 11;
      name = "hex2";
      builder = "M2, blood-macho-0, M1, hex2-1";
      inputs = [ "mescc-tools/hex2*.c" ];
      output = "hex2";
      darwinStatus = "blocked on --macho implementation";
    }
    {
      number = 12;
      name = "kaem";
      builder = "M2, blood-macho-0, M1, hex2";
      inputs = [ "mescc-tools/Kaem/*.c" ];
      output = "kaem";
      darwinStatus = "blocked on hex2 Mach-O output";
    }
    {
      number = 13;
      name = "M2-Planet";
      builder = "M2, blood-macho, M1, hex2";
      inputs = [ (darwinM2libc "<arch>") "M2-Planet/*.c" ];
      output = "M2-Planet";
      darwinStatus = "blocked on kaem/hex2 Mach-O output";
    }
    {
      number = 14;
      name = "tinycc-mes";
      builder = "M2-Planet/MesCC chain";
      inputs = [ "tinycc bootstrappable fork" "Darwin M2libc" "Mach-O hex2" ];
      output = "tcc";
      darwinStatus = "blocked until phases 1-13 produce runnable Mach-O tools";
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
  ];

  missingCriticalPath = [
    "hand-written Mach-O hex0 seed bytes"
    "Mach-O hex1_<arch>.hex0 and hex2_<arch>.hex1 sources"
    "signed Darwin phase wrapper around generated Mach-O tools"
    "blood-macho footer/symbol generator"
    "hex2 --macho final wrapper support"
    "TCC Darwin bootstrap flags after M2/MesCC is runnable"
  ];

  sameLengthAsLinuxMesccToolsBoot = builtins.length phases == 15;
}
