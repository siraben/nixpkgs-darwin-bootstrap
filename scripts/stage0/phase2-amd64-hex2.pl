#!/usr/bin/env perl
## Build a runnable Darwin Mach-O hex2 binary from upstream stage0's
## hex2_AMD64.hex1 source.  Replaces tools/phase2-amd64-hex2.py one-for-one.
##
## Same shape as phase1-amd64-hex1.pl (manual Mach-O header construction
## + ported hex1 source + binary patches) but with a larger DATA segment
## (0x1000000) and a malloc-syscall replacement that points at the
## reserved heap region inside DATA.
use strict;
use warnings;
use File::Path qw(make_path);

die "usage: $0 <stage0_sources> <hex1> <output_dir>\n" unless @ARGV == 3;
my ($stage0_sources, $hex1, $output_dir) = @ARGV;
make_path($output_dir) unless -d $output_dir;

sub p32 { return pack 'V', $_[0] & 0xFFFFFFFF; }
sub p64 { return pack 'Q<', $_[0]; }
sub name16 {
    my ($s) = @_;
    return $s . ("\0" x (16 - length($s)));
}

sub macho_header {
    my $base            = 0x600000;
    my $entry           = 0x400;
    my $text_size       = 0x800000;
    my $data_size       = 0x1000000;
    my $linkedit_offset = $text_size + $data_size;
    my $data_vm         = $base + $text_size;

    my @commands;
    push @commands,
          p32(0x19) . p32(72) . name16('__PAGEZERO')
        . p64(0)    . p64(0x1000) . p64(0) . p64(0)
        . p32(0)    . p32(0) . p32(0) . p32(0);

    my $text =
          p32(0x19) . p32(152) . name16('__TEXT')
        . p64($base) . p64($text_size)
        . p64(0)     . p64($text_size)
        . p32(5)     . p32(5) . p32(1) . p32(0);
    $text .=
          name16('__text') . name16('__TEXT')
        . p64($base + $entry) . p64($text_size - $entry)
        . p32($entry) . p32(0) . p32(0) . p32(0)
        . p32(0x80000400) . p32(0) . p32(0) . p32(0);
    push @commands, $text;

    push @commands,
          p32(0x19) . p32(72) . name16('__DATA')
        . p64($data_vm) . p64($data_size)
        . p64($text_size) . p64($data_size)
        . p32(3) . p32(3) . p32(0) . p32(0);

    push @commands,
          p32(0x19) . p32(72) . name16('__LINKEDIT')
        . p64($base + $linkedit_offset) . p64(0x100000)
        . p64($linkedit_offset) . p64(0)
        . p32(1) . p32(1) . p32(0) . p32(0);

    push @commands, p32(0x80000022) . p32(48) . ("\0" x 40);
    push @commands, p32(0x2) . p32(24) . ("\0" x 16);
    push @commands, p32(0xB) . p32(80) . ("\0" x 72);

    my $dylinker = "/usr/lib/dyld\0";
    push @commands,
          p32(0xE) . p32(32) . p32(12)
        . $dylinker
        . ("\0" x (32 - 12 - length($dylinker)));

    push @commands, p32(0x1B) . p32(24) . pack('H*', '2132435465768798a9bacbdcedfe0f10');
    push @commands,
          p32(0x32) . p32(32)
        . p32(1) . p32(0xE0000) . p32(0)
        . p32(1) . p32(3) . p32(0);
    push @commands, p32(0x80000028) . p32(24) . p64($entry) . p64(0);

    my $libsystem = "/usr/lib/libSystem.B.dylib\0";
    push @commands,
          p32(0xC) . p32(56)
        . p32(24) . p32(2)
        . p32(0x054C0000) . p32(0x10000)
        . $libsystem
        . ("\0" x (56 - 24 - length($libsystem)));
    push @commands, p32(0x26) . p32(16) . ("\0" x 8);
    push @commands, p32(0x29) . p32(16) . ("\0" x 8);

    my $cmd_count = scalar(@commands);
    my $cmd_size  = 0;
    $cmd_size += length($_) for @commands;
    my $header =
          p32(0xFEEDFACF) . p32(0x01000007)
        . p32(3) . p32(2)
        . p32($cmd_count) . p32($cmd_size)
        . p32(0x85) . p32(0)
        . join('', @commands);

    die sprintf("Mach-O header exceeds entry offset: %d > %d\n", length($header), $entry)
        if length($header) > $entry;
    return ($header . ("\0" x ($entry - length($header))), $base, $data_vm, $data_size, $linkedit_offset);
}

sub port_hex2_source {
    my ($stage0, $out_path) = @_;
    open(my $sf, '<', "$stage0/AMD64/hex2_AMD64.hex1") or die "open hex2_AMD64.hex1: $!";
    my $text = do { local $/; <$sf> };
    close($sf);
    my $pos = index($text, ':ELF_text');
    die "ELF_text marker not found\n" if $pos < 0;
    my $source = substr($text, $pos + length(':ELF_text'));

    {
        my $old =
              "\t58                          ; pop_rax                     # Get the number of arguments\n"
            . "\t5F                          ; pop_rdi                     # Get the program name\n"
            . "\t5F                          ; pop_rdi                     # Get the actual input name";
        my $new =
              "\t4989F7                      ; mov_r15,rsi                 # Save Darwin argv\n"
            . "\t498B7F08                    ; mov_rdi,[r15+8]             # argv[1]";
        my $p = index($source, $old);
        substr($source, $p, length($old)) = $new if $p >= 0;
    }
    {
        my $old = "\t5F                          ; pop_rdi                     # Get the actual output name";
        my $new = "\t498B7F10                    ; mov_rdi,[r15+16]            # argv[2]";
        my $p = index($source, $old);
        substr($source, $p, length($old)) = $new if $p >= 0;
    }

    my @replacements = (
        [ '48C7C0 02000000', '48C7C0 05000002' ],
        [ '48C7C6 41020000', '48C7C6 01060000' ],
        [ '48C7C0 08000000', '48C7C0 C7000002' ],
        [ '48C7C0 3C000000', '48C7C0 01000002' ],
        [
            "48C7C0 00000000             ; mov_rax, %0                 # the syscall number for read",
            "48C7C0 03000002             ; mov_rax, %0x2000003           # Darwin read",
        ],
        [
            "48C7C0 01000000             ; mov_rax, %1                 # the syscall number for write",
            "48C7C0 04000002             ; mov_rax, %0x2000004           # Darwin write",
        ],
        [
              "\t48C7C7 01000000             ; mov_rdi, %1                 # All is wrong\n"
            . "\t48C7C0 01000002             ; mov_rax, %0x3C              # put the exit syscall number in eax\n"
            . "\t0F05                        ; syscall                     # Call it a good day",
              "\t48C7C2 40000000             ; mov_rdx, %64                # Debug token length\n"
            . "\t488B35 %T                   ; mov_rsi,[rip+DWORD] %scratch # Debug unresolved token\n"
            . "\t48C7C7 02000000             ; mov_rdi, %2                 # stderr\n"
            . "\t48C7C0 04000002             ; mov_rax, %0x2000004         # Darwin write\n"
            . "\t0F05                        ; syscall\n"
            . "\t48C7C7 01000000             ; mov_rdi, %1                 # All is wrong\n"
            . "\t48C7C0 01000002             ; mov_rax, %0x2000001         # Darwin exit\n"
            . "\t0F05                        ; syscall",
        ],
    );

    for my $r (@replacements) {
        my ($old, $new) = @$r;
        my $cursor = 0;
        while ((my $p = index($source, $old, $cursor)) >= 0) {
            substr($source, $p, length($old)) = $new;
            $cursor = $p + length($new);
        }
    }

    open(my $of, '>', $out_path) or die "write $out_path: $!";
    print $of $source;
    close($of);
}

sub patch_rel32 {
    my ($bytes_ref, $opcode, $target) = @_;
    my $oplen = length($opcode);
    my @op    = unpack 'C*', $opcode;
    my $start = 0;
    my $n     = scalar @$bytes_ref;
  OUTER: while ($start + $oplen <= $n) {
      INNER: for (my $i = $start; $i + $oplen <= $n; $i++) {
            for (my $j = 0; $j < $oplen; $j++) {
                next INNER if $bytes_ref->[$i + $j] != $op[$j];
            }
            my $disp_pos = $i + $oplen;
            last OUTER if $disp_pos + 4 > $n;
            my $next_instruction = 0x600000 + $disp_pos + 4;
            my $disp = ($target - $next_instruction) & 0xFFFFFFFF;
            $bytes_ref->[$disp_pos + 0] = $disp & 0xFF;
            $bytes_ref->[$disp_pos + 1] = ($disp >> 8) & 0xFF;
            $bytes_ref->[$disp_pos + 2] = ($disp >> 16) & 0xFF;
            $bytes_ref->[$disp_pos + 3] = ($disp >> 24) & 0xFF;
            $start = $disp_pos + 4;
            next OUTER;
        }
        last;
    }
}

sub find_pattern {
    my ($bytes_ref, @pat) = @_;
    my $n = scalar @$bytes_ref;
    my $plen = scalar @pat;
  OUTER: for (my $i = 0; $i + $plen <= $n; $i++) {
        for (my $j = 0; $j < $plen; $j++) {
            next OUTER if $bytes_ref->[$i + $j] != $pat[$j];
        }
        return $i;
    }
    return -1;
}

sub patch_malloc {
    my ($bytes_ref, $heap) = @_;
    my @pat = unpack 'C*', pack('H*', '48c7c00c00000041530f05415bc3');
    my $position = find_pattern($bytes_ref, @pat);
    die "malloc syscall pattern not found\n" if $position < 0;
    my @repl = (0x48, 0xB8, unpack('C*', p64($heap)), 0xC3);
    for (my $k = 0; $k < scalar @repl; $k++) {
        $bytes_ref->[$position + $k] = $repl[$k];
    }
    ## Zero the leftover bytes from the original pattern.
    for (my $k = scalar @repl; $k < scalar @pat; $k++) {
        $bytes_ref->[$position + $k] = 0;
    }
}

sub patch_binary {
    my ($bytes_ref, $data_vm) = @_;
    my $write_buffer = $data_vm;
    my $scratch_slot = $data_vm + 8;
    my $heap         = $data_vm + 0x1000;

    for my $op ("\x48\x8d\x35", "\x8a\x05") {
        patch_rel32($bytes_ref, $op, $write_buffer);
    }
    for my $op ("\x4c\x89\x25", "\x48\x8b\x1d", "\x48\x8b\x3d", "\x48\x8b\x05", "\x48\x8b\x35") {
        patch_rel32($bytes_ref, $op, $scratch_slot);
    }
    patch_malloc($bytes_ref, $heap);
}

my $body_source = "$output_dir/hex2_AMD64_darwin_body.hex1";
port_hex2_source($stage0_sources, $body_source);

my $body_binary = "$output_dir/hex2-body.bin";
my $rc = system($hex1, $body_source, $body_binary);
die "hex1 failed: $?\n" if $rc != 0;

my ($header, $base, $data_vm, $data_size, $linkedit_offset) = macho_header();

open(my $bb, '<:raw', $body_binary) or die "open body: $!";
my $body;
{ local $/; $body = <$bb>; }
close($bb);

my @bytes = unpack 'C*', ($header . $body);
patch_binary(\@bytes, $data_vm);

my $data_end = $data_vm - $base + $data_size;
push @bytes, (0) x ($data_end - scalar(@bytes))      if scalar(@bytes) < $data_end;
push @bytes, (0) x ($linkedit_offset - scalar(@bytes)) if scalar(@bytes) < $linkedit_offset;

my $output = "$output_dir/hex2-darwin";
open(my $of, '>:raw', $output) or die "open $output: $!";
print $of pack 'C*', @bytes;
close($of);
chmod 0755, $output;
