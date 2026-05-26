#!/usr/bin/env perl
## Darwin Mach-O segment-size patcher used by the early bootstrap (phase5,
## phase6, phase7, phase8, phase9, phase10).  Mirrors
## tools/phase5-amd64-m2.py exactly so we can drop python from those
## phases' nativeBuildInputs.
##
## Algorithm:
##   1. Parse the hex2 source linearly counting bytes per token; the
##      first label matching the static-data set
##      (:ELF_data / :HEX2_data / :GLOBAL_* / :STRING_* / :_string_*) marks
##      where the data block starts in the hex2-emitted binary.
##   2. Copy that block from its hex2-emitted file position to the
##      Darwin DATA_FILE_OFFSET (0x800000), padding the file if necessary
##      (backward copy because dst > src overlaps).
##   3. Scan the binary for 32 known RIP-relative opcode prefixes; when
##      the next-instruction-relative displacement points into the moved
##      static block, rewrite it as if data lived at DATA_VM (0xE00000).
##
## phase26g/macho-patcher implements the same algorithm in hand-written
## M1 macro-asm; this perl version is used in phases that build BEFORE
## phase9-m1 / phase10-hex2 (so phase26g can't yet exist).
use strict;
use warnings;

my $BASE             = 0x600000;
my $ENTRY_OFFSET     = 0x400;
my $DATA_FILE_OFFSET = 0x800000;
my $DATA_VM          = 0xE00000;

die "usage: $0 patch <source.hex2> <binary>\n" unless @ARGV == 3;
my ($cmd, $src_path, $bin_path) = @ARGV;
die "unknown command: $cmd\n" unless $cmd eq 'patch';

sub hex2_width {
    my ($tok) = @_;
    my $c = substr($tok, 0, 1);
    return 1 if $c eq '!';
    return 2 if $c eq '@' || $c eq '$';
    return 4 if $c eq '%' || $c eq '&';
    if ($tok =~ /^[0-9A-Fa-f]+$/ && length($tok) % 2 == 0) {
        return length($tok) / 2;
    }
    return 0;
}

sub hex2_line_width {
    my ($line) = @_;
    my $width = 0;
    for my $tok (split /\s+/, $line) {
        next if $tok eq '';
        my $w = hex2_width($tok);
        die "untranslated token in hex2: $line\n" if $w == 0;
        $width += $w;
    }
    return $width;
}

sub first_static_offset {
    my ($source) = @_;
    my $offset = 0;
    for my $raw_line (split /\n/, $source) {
        my ($tok_block) = $raw_line =~ /^([^#]*)/;
        $tok_block //= '';
        $tok_block =~ s/^\s+//;
        $tok_block =~ s/\s+$//;
        next if $tok_block eq '';
        my ($first) = split /\s+/, $tok_block;
        if (   $first eq ':ELF_data'
            || $first eq ':HEX2_data'
            || (index($first, ':GLOBAL_')     == 0)
            || (index($first, ':STRING_')     == 0)
            || (index($first, ':_string_')    == 0))
        {
            return $offset;
        }
        if (substr($first, 0, 1) eq ':') {
            ## label that doesn't match → 0-width, continue
            next;
        }
        $offset += hex2_line_width($tok_block);
    }
    die "static data label not found\n";
}

sub patch_rel32 {
    my ($bytes_ref, $opcode_ref, $static_vm, $data_vm, $data_length) = @_;
    my $oplen = scalar @$opcode_ref;
    my $start = 0;
    my $n     = scalar @$bytes_ref;
  OUTER: while ($start + $oplen <= $n) {
      INNER: for (my $i = $start; $i + $oplen <= $n; $i++) {
            for (my $j = 0; $j < $oplen; $j++) {
                next INNER if $bytes_ref->[$i + $j] != $opcode_ref->[$j];
            }
            my $displacement_position = $i + $oplen;
            last OUTER if $displacement_position + 4 > $n;
            my $next_instruction = $BASE + $displacement_position + 4;
            my $b0 = $bytes_ref->[$displacement_position + 0];
            my $b1 = $bytes_ref->[$displacement_position + 1];
            my $b2 = $bytes_ref->[$displacement_position + 2];
            my $b3 = $bytes_ref->[$displacement_position + 3];
            my $displacement = $b0 | ($b1 << 8) | ($b2 << 16) | ($b3 << 24);
            $displacement -= (1 << 32) if $displacement & 0x80000000;
            my $target = $next_instruction + $displacement;
            if ($static_vm <= $target && $target < $static_vm + $data_length) {
                my $new_target = $data_vm + ($target - $static_vm);
                my $new_disp   = ($new_target - $next_instruction) & 0xFFFFFFFF;
                $bytes_ref->[$displacement_position + 0] = $new_disp & 0xFF;
                $bytes_ref->[$displacement_position + 1] = ($new_disp >> 8) & 0xFF;
                $bytes_ref->[$displacement_position + 2] = ($new_disp >> 16) & 0xFF;
                $bytes_ref->[$displacement_position + 3] = ($new_disp >> 24) & 0xFF;
            }
            $start = $displacement_position + 4;
            next OUTER;
        }
        last;
    }
}

open(my $sf, '<', $src_path) or die "open $src_path: $!";
my $source = do { local $/; <$sf> };
close($sf);

open(my $bf, '+<:raw', $bin_path) or die "open $bin_path: $!";
my $raw;
{ local $/; $raw = <$bf>; }
my @bytes = unpack 'C*', $raw;

my $first      = first_static_offset($source);
my $static_file_offset = $ENTRY_OFFSET + $first;
my $static_vm          = $BASE + $static_file_offset;
my $static_length      = scalar(@bytes) - $static_file_offset;

if (scalar(@bytes) < $DATA_FILE_OFFSET + $static_length) {
    push @bytes, (0) x ($DATA_FILE_OFFSET + $static_length - scalar(@bytes));
}
for (my $i = $static_length - 1; $i >= 0; $i--) {
    $bytes[$DATA_FILE_OFFSET + $i] = $bytes[$static_file_offset + $i];
}

my @opcodes = (
    [0x48, 0x8d, 0x05],
    [0x48, 0x8d, 0x1d],
    [0x48, 0x8d, 0x0d],
    [0x48, 0x8d, 0x15],
    [0x48, 0x8d, 0x35],
    [0x48, 0x8d, 0x3d],
    [0x4c, 0x8d, 0x05],
    [0x4c, 0x8d, 0x0d],
    [0x4c, 0x8d, 0x15],
    [0x4c, 0x8d, 0x1d],
    [0x48, 0x8b, 0x05],
    [0x48, 0x8b, 0x1d],
    [0x48, 0x8b, 0x0d],
    [0x48, 0x8b, 0x15],
    [0x48, 0x8b, 0x35],
    [0x48, 0x8b, 0x3d],
    [0x4c, 0x8b, 0x05],
    [0x4c, 0x8b, 0x0d],
    [0x4c, 0x8b, 0x15],
    [0x4c, 0x8b, 0x1d],
    [0x48, 0x89, 0x05],
    [0x48, 0x89, 0x1d],
    [0x48, 0x89, 0x0d],
    [0x48, 0x89, 0x15],
    [0x48, 0x89, 0x35],
    [0x48, 0x89, 0x3d],
    [0x4c, 0x89, 0x05],
    [0x4c, 0x89, 0x0d],
    [0x4c, 0x89, 0x15],
    [0x4c, 0x89, 0x1d],
    [0x88, 0x05],
    [0x8a, 0x05],
);

for my $op (@opcodes) {
    patch_rel32(\@bytes, $op, $static_vm, $DATA_VM, $static_length);
}

seek($bf, 0, 0);
truncate($bf, 0);
print $bf pack 'C*', @bytes;
close($bf);
