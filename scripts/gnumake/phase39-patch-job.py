#!/usr/bin/env python3
from pathlib import Path


path = Path("src/job.c")
text = path.read_text()
start = text.index(
    "#if !defined(USE_POSIX_SPAWN)",
    text.index("child_execute_job (struct childbase *child"),
)
end = text.index("#else /* USE_POSIX_SPAWN */", start)
replacement = r"""#if !defined(USE_POSIX_SPAWN)

  pid = fork ();
  if (pid != 0)
    return pid;

  if (fdin >= 0 && fdin != FD_STDIN)
    dup2 (fdin, FD_STDIN);
  if (fdout != FD_STDOUT)
    dup2 (fdout, FD_STDOUT);
  if (fderr != FD_STDERR)
    dup2 (fderr, FD_STDERR);

  environ = child->environment;
  execvp (argv[0], argv);
  _exit (127);

"""
path.write_text(text[:start] + replacement + text[end:])
