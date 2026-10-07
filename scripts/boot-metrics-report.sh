#!/bin/sh
## Summarize build.sh metrics: per-step wall/cpu/max-RSS plus the peak summed
## process-tree RSS observed by the sampler.  Usage:
##   sh scripts/boot-metrics-report.sh [METRICS_DIR]   (default target/metrics)
set -eu
ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd)"
dir=${1:-$ROOT/target/metrics}
/usr/bin/awk -F'\t' '
  FNR == 1 { next }
  FILENAME == ARGV[2] { if ($3 > tree[$2]) tree[$2] = $3; next }
  { order[++n] = $1; wall[n] = $2; usr[n] = $3; sys[n] = $4; rss[n] = $5 }
  END {
    printf "%-26s %10s %10s %10s %12s %12s\n", "step", "wall_s", "user_s", "sys_s", "maxrss_MiB", "treerss_MiB"
    for (i = 1; i <= n; i++) {
      s = order[i]; tw += wall[i]; tu += usr[i]; ts += sys[i]
      if (rss[i] > mr) mr = rss[i]; if (tree[s] > mt) mt = tree[s]
      printf "%-26s %10.1f %10.1f %10.1f %12.1f %12.1f\n", s, wall[i], usr[i], sys[i], rss[i]/1024, tree[s]/1024
    }
    printf "%-26s %10.1f %10.1f %10.1f %12.1f %12.1f\n", "TOTAL/peak", tw, tu, ts, mr/1024, mt/1024
  }' "$dir/steps.tsv" "$dir/rss-samples.tsv"
