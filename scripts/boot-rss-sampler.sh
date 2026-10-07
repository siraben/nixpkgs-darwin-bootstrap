#!/bin/sh
## Process-tree RSS sampler for build.sh metrics (measurement only; not part
## of the bootstrap trust path — it only reads `ps`).
##
## Usage: boot-rss-sampler.sh ROOT_PID METRICS_DIR [INTERVAL_SECONDS]
##
## Every INTERVAL seconds, sums RSS over ROOT_PID and all its descendants and
## tracks the per-step maximum.  The current step name is read from
## METRICS_DIR/current (written by build.sh).  Writes one line per sample to
## METRICS_DIR/rss-samples.tsv:  epoch  step  tree_rss_kib  nprocs
## and exits when ROOT_PID is gone.
set -u
root=$1
dir=$2
interval=${3:-1}
out="$dir/rss-samples.tsv"
[ -f "$out" ] || printf 'epoch\tstep\ttree_rss_kib\tnprocs\n' > "$out"
while kill -0 "$root" 2>/dev/null; do
  step=$(cat "$dir/current" 2>/dev/null || echo '?')
  /bin/ps -A -o pid=,ppid=,rss= | /usr/bin/awk -v root="$root" -v step="$step" -v now="$(date +%s)" '
    { ppid[$1] = $2; rss[$1] = $3; pids[NR] = $1 }
    END {
      tot = 0; n = 0
      for (i in pids) {
        p = pids[i]; q = p; hops = 0
        while (q != "" && q != root && q > 1 && hops < 64) { q = ppid[q]; hops++ }
        if (q == root) { tot += rss[p]; n++ }
      }
      printf "%s\t%s\t%d\t%d\n", now, step, tot, n
    }' >> "$out"
  sleep "$interval"
done
