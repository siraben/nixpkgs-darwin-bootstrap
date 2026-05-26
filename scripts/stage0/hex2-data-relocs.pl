#!/usr/bin/env perl
## Darwin-specific post-link patch for hex2-produced Mach-O binaries that
## come out of phase30/phase31/phase33/tinyccSelfLinkCandidate.
##
## hex2 emits a flat layout where all references assume code and data are
## contiguous in VM (TEXT at BASE, data immediately after).  Darwin's
## loader splits TEXT and DATA into separate segments at DATA_VM with a
## file gap (DATA_FILE_OFFSET), so every reference whose target lies in
## the data block needs its disp32 or 4-byte absolute slot recomputed.
##
## Mirrors tools/hex2-data-relocs.py one-for-one; replacing the python
## script eliminates the python build-time dep for these phases.
##
## Usage: hex2-data-relocs.pl patch <source.hex2> <binary>
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
    return 1 if substr($tok, 0, 1) eq '!';
    return 2 if substr($tok, 0, 1) eq '@' || substr($tok, 0, 1) eq '$';
    return 4 if substr($tok, 0, 1) eq '%' || substr($tok, 0, 1) eq '&';
    if ($tok =~ /^[0-9A-Fa-f]+$/ && length($tok) % 2 == 0) {
        return length($tok) / 2;
    }
    die "untranslated token in hex2: $tok\n";
}

sub numeric_reference {
    my ($ref) = @_;
    return $ref =~ /^[-+]?(?:0x[0-9A-Fa-f]+|\d+)$/;
}

open(my $sf, '<', $src_path) or die "open $src_path: $!";
my $offset = 0;
my %labels;
my @relrefs;
my @absrefs;
my $static_offset;

while (my $line = <$sf>) {
    $line =~ s/#.*//;
    for my $tok (split /\s+/, $line) {
        next if $tok eq '';
        my $c = substr($tok, 0, 1);
        if ($c eq ':') {
            my $lbl = substr($tok, 1);
            $labels{$lbl} = $offset;
            if (!defined($static_offset) && ($lbl eq 'ELF_data' || $lbl eq 'HEX2_data')) {
                $static_offset = $offset;
            }
            next;
        }
        if ($c eq '%') {
            my $ref = substr($tok, 1);
            push @relrefs, [$offset, $ref] unless numeric_reference($ref);
        } elsif ($c eq '&') {
            my $ref = substr($tok, 1);
            push @absrefs, [$offset, $ref] unless numeric_reference($ref);
        }
        $offset += hex2_width($tok);
    }
}
close($sf);

die "static data label not found\n" unless defined $static_offset;

open(my $bf, '+<:raw', $bin_path) or die "open $bin_path: $!";
my $binary;
{ local $/; $binary = <$bf>; }
my @bytes = unpack 'C*', $binary;

my $static_file_offset = $ENTRY_OFFSET + $static_offset;
my $static_length      = scalar(@bytes) - $static_file_offset;
if (scalar(@bytes) < $DATA_FILE_OFFSET + $static_length) {
    push @bytes, (0) x ($DATA_FILE_OFFSET + $static_length - scalar(@bytes));
}
## Slice-assignment-with-overlap semantics (python's binary[d:d+n] = binary[s:s+n]
## copies via a temporary).  Source [s..s+n] and destination [d..d+n] overlap
## when d > s, so copy backward to avoid overwriting unread source bytes.
for (my $i = $static_length - 1; $i >= 0; $i--) {
    $bytes[$DATA_FILE_OFFSET + $i] = $bytes[$static_file_offset + $i];
}

for my $r (@relrefs) {
    my ($tok_off, $ref) = @$r;
    next unless exists $labels{$ref};
    my $tgt_off = $labels{$ref};
    next if $tgt_off < $static_offset;
    my $disp_pos   = $ENTRY_OFFSET + $tok_off;
    my $next_instr = $BASE + $disp_pos + 4;
    my $target     = $DATA_VM + ($tgt_off - $static_offset);
    my $disp       = ($target - $next_instr) & 0xFFFFFFFF;
    $bytes[$disp_pos + 0] = $disp & 0xFF;
    $bytes[$disp_pos + 1] = ($disp >> 8) & 0xFF;
    $bytes[$disp_pos + 2] = ($disp >> 16) & 0xFF;
    $bytes[$disp_pos + 3] = ($disp >> 24) & 0xFF;
}

for my $r (@absrefs) {
    my ($tok_off, $ref) = @$r;
    next unless exists $labels{$ref};
    my $tgt_off = $labels{$ref};
    my $target;
    if ($tgt_off < $static_offset) {
        $target = $BASE + $ENTRY_OFFSET + $tgt_off;
    } else {
        $target = $DATA_VM + ($tgt_off - $static_offset);
    }
    my $pos;
    if ($tok_off >= $static_offset) {
        $pos = $DATA_FILE_OFFSET + ($tok_off - $static_offset);
    } else {
        $pos = $ENTRY_OFFSET + $tok_off;
    }
    $target &= 0xFFFFFFFF;
    $bytes[$pos + 0] = $target & 0xFF;
    $bytes[$pos + 1] = ($target >> 8) & 0xFF;
    $bytes[$pos + 2] = ($target >> 16) & 0xFF;
    $bytes[$pos + 3] = ($target >> 24) & 0xFF;
}

seek($bf, 0, 0);
truncate($bf, 0);
print $bf pack 'C*', @bytes;
close($bf);
