#!/usr/bin/env perl
## Translate M1-macro-assembler output into hex2 input.  Mirrors
## tools/m1-to-hex2.py; lets phase34's tcc-darwin-cc wrapper drop its
## python3 dependency.
##
## Recognizes the small subset of M1/hex2 tokens that elf64-to-m1 emits:
##   !0xXX (5 chars)  →  raw hex byte XX (uppercase)
##   %LABEL / &LABEL  →  passthrough (4-byte references resolved by hex2)
##   :LABEL           →  passthrough; may trigger --align-label padding
##   anything else    →  passthrough (single byte / literal hex)
##
## Usage:
##   m1-to-hex2.pl [--architecture <a>] [--little-endian|--big-endian]
##                 [--base-address <addr>] [--align-label NAME=ADDR ...]
##                 -f <file> [-f <file> ...] -o <out>
use strict;
use warnings;

my $base_address = 0;
my @files;
my $output_path;
my %align_labels;

sub parse_int {
    my ($v) = @_;
    if ($v =~ /^0[xX]([0-9A-Fa-f]+)$/) { return hex($1); }
    if ($v =~ /^-?\d+$/)              { return $v + 0; }
    die "bad integer: $v\n";
}

while (@ARGV) {
    my $a = shift @ARGV;
    if    ($a eq '--architecture')    { shift @ARGV; }
    elsif ($a eq '--little-endian')   { }
    elsif ($a eq '--big-endian')      { }
    elsif ($a eq '--base-address')    { $base_address = parse_int(shift @ARGV); }
    elsif ($a eq '--align-label')     {
        my $kv = shift @ARGV;
        die "invalid --align-label value: $kv\n" unless $kv =~ /=/;
        my ($k, $v) = split /=/, $kv, 2;
        $align_labels{$k} = parse_int($v);
    }
    elsif ($a eq '-f' || $a eq '--file') { push @files, shift @ARGV; }
    elsif ($a eq '-o' || $a eq '--output') { $output_path = shift @ARGV; }
    else { die "unknown arg: $a\n"; }
}
die "no -f files\n" unless @files;
die "no -o output\n" unless defined $output_path;

sub translate_token {
    my ($tok) = @_;
    if (length($tok) == 5 && substr($tok, 0, 3) eq '!0x') {
        return uc(substr($tok, 3));
    }
    return $tok;
}

sub translated_width {
    my ($tok) = @_;
    my $c = substr($tok, 0, 1);
    return 4 if $c eq '%' || $c eq '&';
    return 0 if $c eq ':';
    return 1;
}

open(my $out, '>', $output_path) or die "open $output_path: $!";

my $address = $base_address;

sub write_padding {
    my ($target) = @_;
    die sprintf("label alignment target 0x%x is before current address 0x%x\n",
                $target, $address)
        if $address > $target;
    my @line;
    while ($address < $target) {
        push @line, '00';
        $address++;
        if (@line == 16) {
            print $out join(' ', @line), "\n";
            @line = ();
        }
    }
    print $out join(' ', @line), "\n" if @line;
}

for my $path (@files) {
    open(my $sf, '<', $path) or die "open $path: $!";
    while (my $line = <$sf>) {
        $line =~ s/[\r\n]+$//;
        my $stripped = $line;
        $stripped =~ s/^\s+//;
        $stripped =~ s/\s+$//;
        if ($stripped eq '') {
            print $out "\n";
            next;
        }
        my @tokens;
        for my $tok (split /\s+/, $stripped) {
            if (substr($tok, 0, 1) eq ':') {
                my $lbl = substr($tok, 1);
                if (exists $align_labels{$lbl}) {
                    write_padding($align_labels{$lbl});
                }
            }
            my $tr = translate_token($tok);
            push @tokens, $tr;
            $address += translated_width($tr);
        }
        print $out join(' ', @tokens), "\n";
    }
    close($sf);
}
close($out);
