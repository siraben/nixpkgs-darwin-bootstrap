#!/usr/bin/env perl
## Build a runnable Darwin Mach-O hex1 binary from upstream stage0's
## hex1_AMD64.hex0 source.  Replaces tools/phase1-amd64-hex1.py one-for-one.
##
## Steps:
##   1. Construct the Mach-O header (PAGEZERO + TEXT + DATA + LINKEDIT
##      load commands + LC_LOAD_DYLINKER + LC_UUID + LC_BUILD_VERSION +
##      LC_MAIN + LC_LOAD_DYLIB libSystem + LC_FUNCTION_STARTS +
##      LC_DATA_IN_CODE) by hand.
##   2. Port upstream hex1_AMD64.hex0 to Darwin syscalls via fixed
##      string substitutions on the source.
##   3. Run hex0 to assemble the body.
##   4. Concatenate header + body, apply RIP-relative patches that point
##      the read/write/lseek/etc. helpers at the data segment, and
##      inject a tiny stub that retries the read syscall on partial reads
##      (Darwin returns EINTR more aggressively than Linux did).
##   5. Pad to the linkedit offset and write the executable.
use strict;
use warnings;
use File::Path qw(make_path);

die "usage: $0 <stage0_sources> <hex0> <output_dir>\n" unless @ARGV == 3;
my ($stage0_sources, $hex0, $output_dir) = @ARGV;
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
    my $linkedit_offset = 0x1000000;
    my $data_vm         = $base + $text_size;

    my @commands;

    push @commands,
          p32(0x19) . p32(72) . name16('__PAGEZERO')
        . p64(0)    . p64(0x1000)
        . p64(0)    . p64(0)
        . p32(0)    . p32(0) . p32(0) . p32(0);

    my $text =
          p32(0x19) . p32(152) . name16('__TEXT')
        . p64($base) . p64($text_size)
        . p64(0)     . p64($text_size)
        . p32(5)     . p32(5) . p32(1) . p32(0);
    $text .=
          name16('__text') . name16('__TEXT')
        . p64($base + $entry) . p64($text_size - $entry)
        . p32($entry)  . p32(0) . p32(0) . p32(0)
        . p32(0x80000400) . p32(0) . p32(0) . p32(0);
    push @commands, $text;

    push @commands,
          p32(0x19) . p32(72) . name16('__DATA')
        . p64($data_vm) . p64(0x100000)
        . p64($text_size) . p64(0x100000)
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

    push @commands, p32(0x1B) . p32(24) . pack('H*', '102132435465768798a9bacbdcedfe0f');
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
    return ($header . ("\0" x ($entry - length($header))), $base, $data_vm, $linkedit_offset);
}

sub port_hex1_source {
    my ($stage0, $out_path) = @_;
    open(my $sf, '<', "$stage0/AMD64/hex1_AMD64.hex0") or die "open hex1_AMD64.hex0: $!";
    my $text = do { local $/; <$sf> };
    close($sf);
    my $pos = index($text, '#:ELF_text');
    die "ELF_text marker not found\n" if $pos < 0;
    my $source = substr($text, $pos + length('#:ELF_text'));

    {
        my $old = "\t58                  ; pop_rax         # Get the number of arguments\n"
                . "\t5F                  ; pop_rdi         # Get the program name\$\n"
                . "\t5F                  ; pop_rdi         # Get the actual input name";
        my $new = "\t4989F7              ; mov_r15,rsi      # Save Darwin argv\n"
                . "\t498B7F08            ; mov_rdi,[r15+8]  # argv[1]";
        my $p = index($source, $old);
        substr($source, $p, length($old)) = $new if $p >= 0;
    }
    {
        my $old = "\t5F                  ; pop_rdi         # Get the actual output name";
        my $new = "\t498B7F10            ; mov_rdi,[r15+16] # argv[2]";
        my $p = index($source, $old);
        substr($source, $p, length($old)) = $new if $p >= 0;
    }
    my @replacements = (
        ['48C7C0 02000000', '48C7C0 05000002'],
        ['48C7C6 41020000', '48C7C6 01060000'],
        ['48C7C0 08000000', '48C7C0 C7000002'],
        ['48C7C0 3C000000', '48C7C0 01000002'],
        ['48C7C0 01000000', '48C7C0 04000002'],
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
            my $disp_pos        = $i + $oplen;
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

sub patch_binary {
    my ($bytes_ref, $data_vm) = @_;
    for my $op ("\x88\x05", "\x48\x8d\x35", "\x8a\x05", "\x48\x8d\x0d", "\x48\x89\x05") {
        patch_rel32($bytes_ref, $op, $data_vm);
    }
    my @pat = (0x31, 0xc0, 0x0f, 0x05, 0x48, 0x85, 0xc0, 0x74, 0x0b);
    my $patch_position = find_pattern($bytes_ref, @pat);
    die "read syscall pattern not found\n" if $patch_position < 0;

    my $stub_position = scalar(@$bytes_ref) + 0x800;
    $stub_position = $patch_position + 0x100 if $patch_position + 0x100 > $stub_position;
    if (scalar(@$bytes_ref) < $stub_position) {
        push @$bytes_ref, (0) x ($stub_position - scalar(@$bytes_ref));
    }

    my $relA  = ($stub_position - ($patch_position + 5)) & 0xFFFFFFFF;
    my @patchA = (
        0xE9,
        $relA        & 0xFF,
        ($relA >> 8) & 0xFF,
        ($relA >> 16) & 0xFF,
        ($relA >> 24) & 0xFF,
        0x90, 0x90,
    );
    for (my $k = 0; $k < scalar @patchA; $k++) {
        $bytes_ref->[$patch_position + $k] = $patchA[$k];
    }

    my @stub_head = (
        0xb8, 0x03, 0x00, 0x00, 0x02,        # mov eax, 0x2000003
        0x0f, 0x05,                          # syscall
        0x48, 0x85, 0xc0,                    # test rax, rax
    );
    my $relB = (($patch_position + 7) - ($stub_position + 15)) & 0xFFFFFFFF;
    my @stub = (
        @stub_head,
        0xE9,
        $relB        & 0xFF,
        ($relB >> 8) & 0xFF,
        ($relB >> 16) & 0xFF,
        ($relB >> 24) & 0xFF,
    );
    for (my $k = 0; $k < scalar @stub; $k++) {
        $bytes_ref->[$stub_position + $k] = $stub[$k];
    }
}

my $body_source = "$output_dir/hex1_AMD64_darwin_body.hex0";
port_hex1_source($stage0_sources, $body_source);

my $body_binary = "$output_dir/hex1-body.bin";
my $rc = system($hex0, $body_source, $body_binary);
die "hex0 failed: $?\n" if $rc != 0;

my ($header, $base, $data_vm, $linkedit_offset) = macho_header();

open(my $bb, '<:raw', $body_binary) or die "open body: $!";
my $body;
{ local $/; $body = <$bb>; }
close($bb);

my @bytes = unpack 'C*', ($header . $body);
patch_binary(\@bytes, $data_vm);

my $data_end = $data_vm - $base + 0x100000;
push @bytes, (0) x ($data_end - scalar(@bytes))   if scalar(@bytes) < $data_end;
push @bytes, (0) x ($linkedit_offset - scalar(@bytes)) if scalar(@bytes) < $linkedit_offset;

my $output = "$output_dir/hex1-darwin";
open(my $of, '>:raw', $output) or die "open $output: $!";
print $of pack 'C*', @bytes;
close($of);
chmod 0755, $output;
