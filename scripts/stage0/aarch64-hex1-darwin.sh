#!/usr/bin/env bash
## Port the AArch64 stage0 hex1 source to Darwin syscalls/ABI by applying
## a fixed list of opcode replacements.  Operates in-place on
## ./hex1-body.hex0.  Mirrors scripts/stage0/phase1-aarch64-hex1-darwin.py.
set -eu

perl -i -pe '
  BEGIN {
    @once = (
      ["E10B40F9",
       "ef0301aa\n000080d2\n0102a0d2\n620080d2\n430082d2\n04008092\n050080d2\nb01880d2\n011000d4\nec0300aa\ne10540f9"],
      ["E10F40F9", "e10940f9"],
      ["020080D2", "010080d2\n020080d2"],
    );
    @all = (
      ["600C8092", "e00301aa"],
      ["224880D2", "21c080d2"],
      ["033880D2", "023880d2"],
      ["080780D2", "b00080d2"],
      ["A80B80D2", "300080d2"],
      ["C80780D2", "f01880d2"],
      ["E80780D2", "700080d2"],
      ["080880D2", "900080d2"],
      ["010000D4", "011000d4"],
      ["0D0CA0D2", "ed030caa"],
    );
    @once_done = (0) x scalar(@once);
  }
  for (my $i = 0; $i < @once; $i++) {
    next if $once_done[$i];
    my ($old, $new) = @{$once[$i]};
    if (index($_, $old) >= 0) {
      my $p = index($_, $old);
      substr($_, $p, length($old)) = $new;
      $once_done[$i] = 1;
    }
  }
  for my $pair (@all) {
    my ($old, $new) = @$pair;
    my $cursor = 0;
    while ((my $p = index($_, $old, $cursor)) >= 0) {
      substr($_, $p, length($old)) = $new;
      $cursor = $p + length($new);
    }
  }
' hex1-body.hex0
