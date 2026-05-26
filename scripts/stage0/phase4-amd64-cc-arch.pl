#!/usr/bin/env perl
## Port-and-patch helper for the phase-4 cc_arch translator.
## Mirrors tools/phase4-amd64-cc-arch.py one-for-one.
##
## Two subcommands:
##   port  <linux-source.hex2> <darwin-source.hex2>
##         Apply a fixed list of opcode-level rewrites that turn the
##         Linux x86_64 syscalls in cc_arch's source into Darwin syscalls.
##   patch <source.hex2> <binary>
##         Locate the fix_types lea marker, copy the static block to the
##         Darwin DATA segment, then re-target every RIP-relative load /
##         store that points into the moved static block.
use strict;
use warnings;

my $BASE             = 0x600000;
my $DATA_FILE_OFFSET = 0x800000;
my $DATA_VM          = 0xE00000;
my $HEAP_VM          = 0xF00000;

die "usage: $0 (port|patch) <src> <dst>\n" unless @ARGV == 3;
my ($cmd, $src, $dst) = @ARGV;

if ($cmd eq 'port') { port_source($src, $dst); }
elsif ($cmd eq 'patch') { patch_binary($src, $dst); }
else { die "unknown command: $cmd\n"; }
exit 0;

sub replace_once {
    my ($source, $old, $new) = @_;
    my $pos = index($source, $old);
    die "pattern not found\n" if $pos < 0;
    return substr($source, 0, $pos) . $new . substr($source, $pos + length($old));
}

sub replace_all {
    my ($source, $old, $new) = @_;
    return $source if $old eq '' || index($source, $old) < 0;
    my $out      = '';
    my $cursor   = 0;
    my $oldlen   = length($old);
    while ((my $pos = index($source, $old, $cursor)) >= 0) {
        $out .= substr($source, $cursor, $pos - $cursor) . $new;
        $cursor = $pos + $oldlen;
    }
    $out .= substr($source, $cursor);
    return $out;
}

sub port_source {
    my ($input_path, $output_path) = @_;
    open(my $sf, '<', $input_path) or die "open $input_path: $!";
    my $source = do { local $/; <$sf> };
    close($sf);

    $source = replace_once($source, "58\n5F\n5F\n", "4889F3\n488B7B08\n");
    $source = replace_once($source, "5F\n48C7C6\n41020000\n", "488B7B10\n48C7C6\n01060000\n");
    my $heap_hex = uc unpack 'H*', pack 'Q<', $HEAP_VM;
    $source = replace_once(
        $source,
        "48C7C0\n0C000000\n48C7C7\n00000000\n0F05\n4989C5\n",
        "49BD\n$heap_hex\n",
    );
    $source = replace_all($source, "48C7C0\n02000000\n0F05",                                      "48C7C0\n05000002\n0F05");
    $source = replace_all($source, "48C7C0\n00000000\n52\n48C7C2\n01000000\n51\n4153\n0F05",      "48C7C0\n03000002\n52\n48C7C2\n01000000\n51\n4153\n0F05");
    $source = replace_all($source, "48C7C0\n01000000\n52\n48C7C2\n01000000\n51\n4153\n0F05",      "48C7C0\n04000002\n52\n48C7C2\n01000000\n51\n4153\n0F05");
    ## Single-replacement of an exit-style sequence with empty string.
    {
        my $needle = "48C7C0\n0C000000\n51\n4153\n0F05\n415B\n59\n";
        my $pos = index($source, $needle);
        substr($source, $pos, length($needle)) = '' if $pos >= 0;
    }
    $source = replace_all($source, "48C7C0\n3C000000\n0F05", "48C7C0\n01000002\n0F05");
    $source = replace_once(
        $source,
        ":match\n53\n51\n52\n4889C1\n4889DA\n:match_Loop\n",
        ":match\n53\n51\n52\n4889C1\n4889DA\n4881F9\n00100000\n0F8C\n%match_False\n4881FA\n00100000\n0F8C\n%match_False\n:match_Loop\n",
    );

    open(my $of, '>', $output_path) or die "open $output_path: $!";
    print $of $source;
    close($of);
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
            my $next_instruction      = $BASE + $displacement_position + 4;
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

sub patch_binary {
    my ($source_path, $binary_path) = @_;
    open(my $sf, '<', $source_path) or die "open $source_path: $!";
    my $source = do { local $/; <$sf> };
    close($sf);

    open(my $bf, '+<:raw', $binary_path) or die "open $binary_path: $!";
    my $raw;
    { local $/; $raw = <$bf>; }
    my @bytes = unpack 'C*', $raw;

    ## Find marker: \x53 \x48 \x8d \x05 (push rbx; lea rax,[rip+...])
    my $marker = -1;
    for (my $i = 0; $i + 4 <= scalar @bytes; $i++) {
        if (    $bytes[$i]     == 0x53
             && $bytes[$i + 1] == 0x48
             && $bytes[$i + 2] == 0x8d
             && $bytes[$i + 3] == 0x05)
        {
            $marker = $i;
            last;
        }
    }
    die "fix_types marker not found\n" if $marker < 0;

    my $lea_position     = $marker + 1;
    my $next_instruction = $BASE + $lea_position + 7;
    my $d0 = $bytes[$lea_position + 3];
    my $d1 = $bytes[$lea_position + 4];
    my $d2 = $bytes[$lea_position + 5];
    my $d3 = $bytes[$lea_position + 6];
    my $disp = $d0 | ($d1 << 8) | ($d2 << 16) | ($d3 << 24);
    $disp -= (1 << 32) if $disp & 0x80000000;
    my $static_vm          = $next_instruction + $disp;
    my $static_file_offset = $static_vm - $BASE;
    my $static_length      = scalar(@bytes) - $static_file_offset;

    if (scalar(@bytes) < $DATA_FILE_OFFSET + $static_length) {
        push @bytes, (0) x ($DATA_FILE_OFFSET + $static_length - scalar(@bytes));
    }
    ## backward copy: dst (0x800000) > src.
    for (my $i = $static_length - 1; $i >= 0; $i--) {
        $bytes[$DATA_FILE_OFFSET + $i] = $bytes[$static_file_offset + $i];
    }

    my @opcodes = (
        [0x48, 0x8d, 0x05],
        [0x48, 0x8d, 0x1d],
        [0x48, 0x8d, 0x0d],
        [0x48, 0x8d, 0x15],
        [0x48, 0x8d, 0x35],
        [0x48, 0x8b, 0x05],
        [0x48, 0x8b, 0x1d],
        [0x48, 0x8b, 0x0d],
        [0x48, 0x8b, 0x15],
        [0x48, 0x8b, 0x35],
        [0x48, 0x89, 0x05],
        [0x48, 0x89, 0x1d],
        [0x48, 0x89, 0x0d],
        [0x48, 0x89, 0x15],
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
}
