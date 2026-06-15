#!/usr/bin/env perl
## Stage the GCC 4.6 build/src trees for the libgcc-only sub-build.
##
## Mirrors scripts/gcc46/phase36-libgcc.py exactly:
##   1. rewrite all /nix/var/nix/builds/XXX/(src|build) paths embedded in
##      generated files to <root>/work/<src|build>;
##   2. materialize generated headers / configs from build/gcc into the
##      source tree, and lay the symlinks soft-fp expects;
##   3. patch libgcc/Makefile.in + libgcc.mvars to disable EH/multilib/etc.
##      so libgcc can build with our pinned tinycc-cc.
##
## Args:   --root <dir>   --tcc <tcc-tcc-cc-output>
use strict;
use warnings;
use File::Find;
use File::Copy qw(copy);
use File::Path qw(make_path);
use File::Spec;

my $root;
my $tcc;

while (@ARGV) {
    my $a = shift @ARGV;
    if    ($a eq '--root')    { $root    = shift @ARGV; }
    elsif ($a eq '--tcc') { $tcc = shift @ARGV; }
    else  { die "unknown arg: $a\n"; }
}
die "missing --root\n"    unless defined $root;
die "missing --tcc\n" unless defined $tcc;

my @SOFT_FP_SOURCES = qw(
    addtf3 divtf3 eqtf2 getf2 letf2 multf3 negtf2
    subtf3 unordtf2 fixtfsi fixunstfsi floatsitf floatunsitf
    fixtfdi fixunstfdi floatditf floatunditf fixtfti fixunstfti
    floattitf floatuntitf extendsftf2 extenddftf2 extendxftf2
    trunctfsf2 trunctfdf2 trunctfxf2
);
my @EH_SOURCES = qw(unwind-dw2 unwind-dw2-fde-darwin unwind-sjlj unwind-c emutls);

relocate_build_paths($root);
materialize_headers($root, $tcc);
patch_sources($root);
exit 0;

sub relocate_build_paths {
    my ($root) = @_;
    my $root_bytes = $root;

    for my $base ("$root/work/src", "$root/work/build") {
        next unless -d $base;
        find(
            {
                wanted => sub {
                    return unless -f $_;
                    return if -l $_;
                    my $path = $File::Find::name;
                    open(my $fh, '<:raw', $path) or return;
                    my $data;
                    { local $/; $data = <$fh>; }
                    close($fh);
                    my $orig    = $data;
                    $data =~ s{/nix/var/nix/builds/[^/\0]+/(src|build)}{$root_bytes/work/$1}g;
                    if ($data ne $orig) {
                        open(my $out, '>:raw', $path) or die "rewrite $path: $!";
                        print $out $data;
                        close($out);
                    }
                },
                no_chdir       => 1,
                follow         => 0,
                follow_skip    => 2,
                preprocess     => sub {
                    ## Match python: skip symlinked subdirs.
                    return grep { !-l "$File::Find::dir/$_" } @_;
                },
            },
            $base
        );
    }
}

sub copy_once {
    my ($src, $dst) = @_;
    return if -l $src;
    return if -e $dst;
    open(my $sf, '<:raw', $src) or die "open $src: $!";
    my $data;
    { local $/; $data = <$sf>; }
    close($sf);
    open(my $df, '>:raw', $dst) or die "create $dst: $!";
    print $df $data;
    close($df);
}

sub write_text {
    my ($path, $text) = @_;
    open(my $fh, '>', $path) or die "write $path: $!";
    print $fh $text;
    close($fh);
}

sub read_text {
    my ($path) = @_;
    open(my $fh, '<', $path) or die "read $path: $!";
    local $/;
    my $data = <$fh>;
    close($fh);
    return $data;
}

sub read_text_latin1 {
    my ($path) = @_;
    open(my $fh, '<:raw', $path) or die "read $path: $!";
    local $/;
    my $data = <$fh>;
    close($fh);
    return $data;
}

sub append_text_latin1 {
    my ($path, $text) = @_;
    open(my $fh, '>>:raw', $path) or die "append $path: $!";
    print $fh $text;
    close($fh);
}

sub materialize_headers {
    my ($root, $tcc) = @_;
    my $build_gcc   = "$root/work/build/gcc";
    my $src_gcc     = "$root/work/src/gcc";
    my $src_include = "$root/work/src/include";
    my $src_config  = "$src_gcc/config";

    for my $suffix (qw(h def md opt c)) {
        opendir(my $dh, $build_gcc) or next;
        for my $entry (readdir $dh) {
            next unless $entry =~ /\.\Q$suffix\E$/;
            my $p = "$build_gcc/$entry";
            next unless -f $p;
            copy_once($p, "$src_gcc/$entry");
        }
        closedir $dh;
    }

    if (opendir(my $dh, $src_include)) {
        for my $entry (readdir $dh) {
            next unless $entry =~ /\.h$/;
            my $p = "$src_include/$entry";
            next unless -f $p;
            copy_once($p, "$src_gcc/$entry");
        }
        closedir $dh;
    }

    if (opendir(my $dh, $src_gcc)) {
        for my $entry (readdir $dh) {
            my $p = "$src_gcc/$entry";
            next unless -f $p;
            next unless $entry =~ /\.(?:h|def|md|opt)$/;
            copy_once($p, "$src_config/$entry");
        }
        closedir $dh;
    }

    my $i386_config = "$src_config/i386/config";
    if (-e $i386_config || -l $i386_config) { unlink($i386_config) or die "unlink $i386_config: $!"; }
    symlink('..', $i386_config) or die "symlink $i386_config: $!";

    my $soft_fp = "$src_config/soft-fp";
    {
        open(my $sf, '<:raw', "$build_gcc/sfp-machine.h") or die "read sfp-machine.h: $!";
        my $data;
        { local $/; $data = <$sf>; }
        close($sf);
        open(my $df, '>:raw', "$soft_fp/sfp-machine.h") or die "write sfp-machine.h: $!";
        print $df $data;
        close($df);
    }

    my $soft_fp_config = "$soft_fp/config";
    if (-e $soft_fp_config || -l $soft_fp_config) { unlink($soft_fp_config) or die "unlink $soft_fp_config: $!"; }
    symlink('../../../libgcc/config', $soft_fp_config) or die "symlink $soft_fp_config: $!";

    my $longlong = "$soft_fp/longlong.h";
    if (-e $longlong || -l $longlong) { unlink($longlong) or die "unlink $longlong: $!"; }
    symlink('../../longlong.h', $longlong) or die "symlink $longlong: $!";

    {
        open(my $sf, '<:raw', "$build_gcc/include/unwind.h") or die "read unwind.h: $!";
        my $data;
        { local $/; $data = <$sf>; }
        close($sf);
        open(my $df, '>:raw', "$src_gcc/unwind.h") or die "write unwind.h: $!";
        print $df $data;
        close($df);
    }

    write_text("$build_gcc/gthr-default.h", "#include \"gthr-single.h\"\n");
    write_text("$src_gcc/gthr-default.h",   "#include \"gthr-single.h\"\n");

    {
        open(my $sf, '<:raw', "$build_gcc/include/stdarg.h") or die "read stdarg.h: $!";
        my $data;
        { local $/; $data = <$sf>; }
        close($sf);
        open(my $df, '>:raw', "$root/work/src/libgcc/stdarg.h") or die "write stdarg.h: $!";
        print $df $data;
        close($df);
    }

    my $fcntl = read_text("$tcc/include/tcc-darwin-bootstrap/fcntl.h");
    $fcntl .=
          "\n#ifndef F_RDLCK\n#define F_RDLCK 1\n#define F_WRLCK 3\n#define F_SETLKW 9\n"
        . "struct flock { long l_start; long l_len; int l_pid; short l_type; short l_whence; };\n#endif\n";
    write_text("$root/work/src/libgcc/fcntl.h", $fcntl);

    my $fixed_include = "$build_gcc/include";
    make_path("$fixed_include/sys") unless -d "$fixed_include/sys";
    my $bootstrap_include = "$tcc/include/tcc-darwin-bootstrap";
    if (opendir(my $dh, $bootstrap_include)) {
        for my $entry (readdir $dh) {
            next unless $entry =~ /\.h$/;
            my $p = "$bootstrap_include/$entry";
            next unless -f $p;
            copy_once($p, "$fixed_include/$entry");
        }
        closedir $dh;
    }
    my $sys_include = "$bootstrap_include/sys";
    if (-d $sys_include) {
        opendir(my $dh, $sys_include) or die;
        for my $entry (readdir $dh) {
            next unless $entry =~ /\.h$/;
            my $p = "$sys_include/$entry";
            next unless -f $p;
            copy_once($p, "$fixed_include/sys/$entry");
        }
        closedir $dh;
    }
}

sub patch_sources {
    my ($root) = @_;

    my $gcov_io_path = "$root/work/src/gcc/gcov-io.c";
    my $gcov_text    = read_text($gcov_io_path);
    if (index($gcov_text, '_DARWIN_BOOTSTRAP_GCOV_LOCKS') < 0) {
        my $old = "GCOV_LINKAGE int\n";
        my $new = "#ifndef F_RDLCK\n#define _DARWIN_BOOTSTRAP_GCOV_LOCKS 1\n#define F_RDLCK 1\n#define F_WRLCK 3\n#define F_SETLKW 9\nstruct flock { long l_start; long l_len; int l_pid; short l_type; short l_whence; };\n#endif\n\nGCOV_LINKAGE int\n";
        my $pos = index($gcov_text, $old);
        if ($pos >= 0) {
            substr($gcov_text, $pos, length($old)) = $new;
            write_text($gcov_io_path, $gcov_text);
        }
    }

    my $soft_fp_add = join(' ', map { "\$(gcc_srcdir)/config/soft-fp/$_.c" } @SOFT_FP_SOURCES);
    my $eh_add      = join(' ', map { "\$(gcc_srcdir)/$_.c" } @EH_SOURCES);

    my $mvars_path = "$root/work/build/gcc/libgcc.mvars";
    my @out;
    for my $line (split /\n/, read_text($mvars_path), -1) {
        if ($line =~ /^GCC_EXTRA_PARTS =/)               { $line = 'GCC_EXTRA_PARTS = '; }
        elsif ($line =~ /^LIB2ADD =/)                   { $line = "LIB2ADD = \$(gcc_srcdir)/config/darwin-64.c $soft_fp_add"; }
        elsif ($line =~ /^(LIB2ADDEH|LIB2ADDEHSTATIC|LIB2ADDEHSHARED) =/) {
            my ($prefix) = ($line =~ /^([^=]+=)/);
            $line = "$prefix $eh_add";
        }
        $line =~ s/ -pipe//g;
        $line =~ s/ -g / /g;
        $line =~ s/ -g0 / /g;
        push @out, $line;
    }
    write_text($mvars_path, join("\n", @out) . "\n");

    my $makefile_path = "$root/work/src/libgcc/Makefile.in";
    my $text          = read_text($makefile_path);
    $text =~ s/\QCFLAGS = -O2 -g\E/CFLAGS = -O2 -fno-asynchronous-unwind-tables -fno-unwind-tables/g;
    $text =~ s/\QCFLAGS = -g\E/CFLAGS = -O2 -fno-asynchronous-unwind-tables -fno-unwind-tables/g;
    $text =~ s/ -pipe//g;
    $text =~ s/ -g / /g;
    $text =~ s/ -g0 / /g;

    if (index($text, 'filter-out _powisf2') < 0) {
        my @patched;
        my $in_divmod_filter = 0;
        for my $line (split /\n/, $text, -1) {
            push @patched, $line;
            if ($line =~ /^LIB2_DIVMOD_FUNCS :=/) {
                $in_divmod_filter = 1;
            } elsif ($in_divmod_filter && index($line, '$(LIB2_DIVMOD_FUNCS))') >= 0) {
                push @patched, 'lib2funcs := $(filter-out _powisf2 _powidf2 _powixf2 _powitf2 _mulsc3 _muldc3 _mulxc3 _multc3 _divsc3 _divdc3 _divxc3 _divtc3,$(lib2funcs))';
                $in_divmod_filter = 0;
            }
        }
        $text = join("\n", @patched) . "\n";
    }
    if (index($text, "sifuncs :=\ndifuncs :=\ntifuncs :=") < 0) {
        my $old = "iter-items := \$(sifuncs) \$(difuncs) \$(tifuncs)\n";
        my $new = "sifuncs :=\ndifuncs :=\ntifuncs :=\niter-items := \$(sifuncs) \$(difuncs) \$(tifuncs)\n";
        my $pos = index($text, $old);
        if ($pos >= 0) {
            substr($text, $pos, length($old)) = $new;
        }
    }
    $text .= "\nLIBGCC2_CFLAGS += -fno-asynchronous-unwind-tables -fno-unwind-tables\n";
    $text .= "CRTSTUFF_CFLAGS += -fno-asynchronous-unwind-tables -fno-unwind-tables\n";
    write_text($makefile_path, $text);
}
