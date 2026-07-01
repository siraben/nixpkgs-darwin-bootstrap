#!/usr/bin/env bash
## Replace the POSIX-spawn-style child_execute_job block in GNU Make's
## src/job.c with a classic fork/exec path so it works under our minimal
## Mach-O libc (no posix_spawn yet).
set -eu

target=src/job.c

perl -i -0pe '
  my $func_anchor = "child_execute_job (struct childbase *child";
  my $start_anchor = "#if !defined(USE_POSIX_SPAWN)";
  my $end_anchor = "#else /* USE_POSIX_SPAWN */";
  my $replacement = "#if !defined(USE_POSIX_SPAWN)\n\n  pid = fork ();\n  if (pid != 0)\n    return pid;\n\n  if (fdin >= 0 && fdin != FD_STDIN)\n    dup2 (fdin, FD_STDIN);\n  if (fdout != FD_STDOUT)\n    dup2 (fdout, FD_STDOUT);\n  if (fderr != FD_STDERR)\n    dup2 (fderr, FD_STDERR);\n\n  environ = child->environment;\n  execvp (argv[0], argv);\n  _exit (127);\n\n";

  my $func_pos = index($_, $func_anchor);
  die "anchor not found: $func_anchor" if $func_pos < 0;
  my $start_pos = index($_, $start_anchor, $func_pos);
  die "anchor not found: $start_anchor" if $start_pos < 0;
  my $end_pos = index($_, $end_anchor, $start_pos);
  die "anchor not found: $end_anchor" if $end_pos < 0;
  substr($_, $start_pos, $end_pos - $start_pos) = $replacement;
' "$target"
