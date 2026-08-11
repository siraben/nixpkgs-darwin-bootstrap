#!/bin/sh
# Host-side helpers shared by benchmark harnesses.  Not in the trust path.

benchmark_record_harness_files() {
  manifest_output="$1"
  shift
  printf 'sha256\tbytes\tpath\n' > "$manifest_output"
  for manifest_path do
    if [ ! -f "$manifest_path" ]; then
      echo "missing benchmark harness input: $manifest_path" >&2
      return 1
    fi
    manifest_hash="$(shasum -a 256 "$manifest_path" | awk '{ print $1 }')"
    manifest_bytes="$(wc -c < "$manifest_path" | tr -d ' ')"
    printf '%s\t%s\t%s\n' "$manifest_hash" "$manifest_bytes" "$manifest_path" \
      >> "$manifest_output"
  done
}

benchmark_record_input_tree() {
  input_manifest_output="$1"
  shift
  for input_manifest_root do
    if [ ! -e "$input_manifest_root" ]; then
      echo "missing benchmark input tree: $input_manifest_root" >&2
      return 1
    fi
  done

  printf 'sha256\tbytes\tmode_octal\tpath\n' > "$input_manifest_output"
  {
    for input_manifest_root do
      if [ -d "$input_manifest_root" ]; then
        find -L "$input_manifest_root" -type f -print
      elif [ -f "$input_manifest_root" ]; then
        printf '%s\n' "$input_manifest_root"
      else
        echo "unsupported benchmark input type: $input_manifest_root" >&2
        return 1
      fi
    done
  } | LC_ALL=C sort -u |
    while IFS= read -r input_manifest_path; do
      input_manifest_hash="$(
        shasum -a 256 "$input_manifest_path" | awk '{ print $1 }'
      )"
      input_manifest_bytes="$(wc -c < "$input_manifest_path" | tr -d ' ')"
      input_manifest_mode="$(/usr/bin/stat -f '%OLp' "$input_manifest_path")"
      printf '%s\t%s\t%s\t%s\n' \
        "$input_manifest_hash" "$input_manifest_bytes" "$input_manifest_mode" \
        "$input_manifest_path"
    done >> "$input_manifest_output"
}

benchmark_spotlight_cpu() {
  ps -axo %cpu=,comm= | awk '
    $2 ~ /\/(mds|mds_stores|mdworker|mdworker_shared|mdsync|corespotlightd|spotlightknowledged)$/ { total += $1 }
    END { printf "%.1f", total + 0 }
  '
}

# Background services that have repeatedly disturbed bootstrap measurements on
# this host.  Keep this separate from Spotlight so the evidence says which gate
# rejected a sample.  Compiler/build processes are intentionally absent: the
# measured workload itself consists mostly of those processes.
benchmark_background_cpu() {
  # Inspect the complete command rather than only comm: Borg is launched by a
  # Python wrapper on this host, so its executable basename alone is not a
  # useful interference signal.  These are observed host services, not a claim
  # that every possible background process can be recognized automatically.
  ps -axo %cpu=,command= | awk '
    $0 ~ /\/(ecosystemd|ecosystemanalyticsd|duetexpertd|contactsd|routined|photoanalysisd|mediaanalysisd|backupd|bird|cloudd|suggestd|knowledge-agent|triald|trustd)([[:space:]]|$)/ ||
    $0 ~ /borgbackup.*[[:space:]]create([[:space:]]|$)/ ||
    $0 ~ /com\.apple\.Virtualization\.VirtualMachine/ ||
    $0 ~ /\/com\.docker\.backend([[:space:]]|$)/ ||
    $0 ~ /\/(redline-chain-worker|redline-indexer|redline-projector|redline-analytics-projector)([[:space:]]|$)/ {
      total += $1
    }
    END { printf "%.1f", total + 0 }
  '
}

benchmark_nix_build_clients() {
  ps -axo comm=,args= | awk '
    $1 ~ /(^|\/)nix$/ {
      for (i = 3; i <= NF; i++) {
        if ($i == "build") {
          clients++
          break
        }
      }
    }
    END { print clients + 0 }
  '
}

benchmark_cpu_idle() {
  top -l 1 -n 0 2>/dev/null | awk '
    /CPU usage:/ {
      for (i = 1; i <= NF; i++) {
        if ($i == "idle") {
          value = $(i - 1)
          sub(/%$/, "", value)
          print value
          exit
        }
      }
    }
  '
}

benchmark_power_source() {
  pmset -g ps 2>/dev/null | awk -F "'" '/^Now drawing from / { print $2; exit }'
}

benchmark_power_mode() {
  active_power_source="$(benchmark_power_source)"
  case "$active_power_source" in
    'AC Power') power_mode_section='AC Power:' ;;
    'Battery Power') power_mode_section='Battery Power:' ;;
    *) printf '%s\n' unknown; return ;;
  esac
  active_power_mode="$(pmset -g custom 2>/dev/null | awk \
    -v wanted="$power_mode_section" '
      /^[^[:space:]].*:$/ { in_section = ($0 == wanted) }
      in_section && $1 == "powermode" { print $2; exit }
    ')"
  if [ -n "$active_power_mode" ]; then
    printf '%s\n' "$active_power_mode"
  else
    printf '%s\n' unknown
  fi
}

benchmark_lock_power_mode() {
  if [ -z "${BENCHMARK_REQUIRED_POWER_MODE:-}" ]; then
    BENCHMARK_REQUIRED_POWER_MODE="$(benchmark_power_mode)"
    export BENCHMARK_REQUIRED_POWER_MODE
  fi
}

benchmark_record_memory_state() {
  memory_state_output="$1"
  {
    date -Iseconds
    /usr/bin/vm_stat
    /usr/sbin/sysctl vm.swapusage
    /usr/bin/memory_pressure -Q
  } > "$memory_state_output" 2>&1
}

benchmark_require_disk_headroom() {
  headroom_output="$1"
  headroom_filesystem="${2:-/nix/store}"
  headroom_required_kib="${BENCHMARK_MIN_AVAILABLE_KIB:-10485760}"
  case "$headroom_required_kib" in
    ''|*[!0-9]*|0)
      echo "BENCHMARK_MIN_AVAILABLE_KIB must be a positive integer" >&2
      return 2
      ;;
  esac
  headroom_available_kib="$(
    /bin/df -Pk "$headroom_filesystem" | awk 'NR > 1 { value = $4 } END { print value }'
  )"
  case "$headroom_available_kib" in
    ''|*[!0-9]*)
      echo "could not determine available disk space for $headroom_filesystem" >&2
      return 1
      ;;
  esac
  printf 'timestamp\tfilesystem\tavailable_kib\trequired_kib\n' > "$headroom_output"
  printf '%s\t%s\t%s\t%s\n' \
    "$(date -Iseconds)" "$headroom_filesystem" "$headroom_available_kib" \
    "$headroom_required_kib" >> "$headroom_output"
  if [ "$headroom_available_kib" -lt "$headroom_required_kib" ]; then
    echo "benchmark requires at least ${headroom_required_kib} KiB free on $headroom_filesystem; found ${headroom_available_kib} KiB" >&2
    return 1
  fi
}

benchmark_wait_for_quiet() {
  quiet_log="$1"
  quiet_interval="${BENCHMARK_QUIET_INTERVAL_SECONDS:-10}"
  quiet_limit="${BENCHMARK_QUIET_TIMEOUT_SECONDS:-1800}"
  spotlight_limit="${BENCHMARK_MAX_SPOTLIGHT_CPU:-5}"
  background_limit="${BENCHMARK_MAX_BACKGROUND_CPU:-5}"
  nix_client_limit="${BENCHMARK_QUIET_MAX_NIX_BUILD_CLIENTS:-0}"
  idle_limit="${BENCHMARK_MIN_IDLE_PERCENT:-80}"
  required_power_source="${BENCHMARK_REQUIRED_POWER_SOURCE:-AC Power}"
  benchmark_lock_power_mode
  required_power_mode="$BENCHMARK_REQUIRED_POWER_MODE"
  quiet_started="$(date +%s)"
  quiet_consecutive=0
  : > "$quiet_log"

  while :; do
    quiet_now="$(date +%s)"
    quiet_spotlight="$(benchmark_spotlight_cpu)"
    quiet_background="$(benchmark_background_cpu)"
    quiet_nix_clients="$(benchmark_nix_build_clients)"
    quiet_idle="$(benchmark_cpu_idle)"
    quiet_power_source="$(benchmark_power_source)"
    quiet_power_mode="$(benchmark_power_mode)"
    [ -n "$quiet_idle" ] || quiet_idle=0
    printf '%s\tcpu_idle_percent=%s\tspotlight_cpu_percent=%s\tbackground_cpu_percent=%s\tnix_build_clients=%s\tpower_source=%s\tpower_mode=%s\n' \
      "$(date -Iseconds)" "$quiet_idle" "$quiet_spotlight" \
      "$quiet_background" "$quiet_nix_clients" "$quiet_power_source" \
      "$quiet_power_mode" >> "$quiet_log"

    if awk -v idle="$quiet_idle" -v min_idle="$idle_limit" \
      -v spotlight="$quiet_spotlight" -v max_spotlight="$spotlight_limit" \
      -v background="$quiet_background" -v max_background="$background_limit" \
      -v nix_clients="$quiet_nix_clients" -v max_nix_clients="$nix_client_limit" \
      'BEGIN { exit !(idle >= min_idle && spotlight <= max_spotlight && background <= max_background && nix_clients <= max_nix_clients) }' \
      && [ "$quiet_power_source" = "$required_power_source" ] \
      && [ "$quiet_power_mode" = "$required_power_mode" ]; then
      quiet_consecutive=$((quiet_consecutive + 1))
    else
      quiet_consecutive=0
    fi
    [ "$quiet_consecutive" -ge 3 ] && return 0

    if [ $((quiet_now - quiet_started)) -ge "$quiet_limit" ]; then
      echo "benchmark host did not become quiet within ${quiet_limit}s; see $quiet_log" >&2
      return 1
    fi
    sleep "$quiet_interval"
  done
}

benchmark_start_monitor() {
  monitor_log="$1"
  monitor_interval="${BENCHMARK_MONITOR_INTERVAL_SECONDS:-15}"
  monitor_process_log="${monitor_log%.tsv}.processes.tsv"
  monitor_process_min_cpu="${BENCHMARK_PROCESS_SNAPSHOT_MIN_CPU:-5}"
  benchmark_lock_power_mode
  printf 'timestamp\tpid\tppid\tps_cpu_percent\trss_kib\tcommand\n' > "$monitor_process_log"
  (
    printf 'timestamp\tcpu_idle_percent\tspotlight_cpu_percent\tbackground_cpu_percent\tnix_build_clients\tpower_source\tpower_mode\n'
    while :; do
      monitor_idle="$(benchmark_cpu_idle)"
      [ -n "$monitor_idle" ] || monitor_idle=0
      monitor_spotlight="$(benchmark_spotlight_cpu)"
      monitor_background="$(benchmark_background_cpu)"
      monitor_nix_clients="$(benchmark_nix_build_clients)"
      monitor_power_source="$(benchmark_power_source)"
      monitor_power_mode="$(benchmark_power_mode)"
      monitor_timestamp="$(date -Iseconds)"
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$monitor_timestamp" "$monitor_idle" "$monitor_spotlight" \
        "$monitor_background" "$monitor_nix_clients" "$monitor_power_source" \
        "$monitor_power_mode"
      ps -axo pid=,ppid=,%cpu=,rss=,command= | awk \
        -v timestamp="$monitor_timestamp" \
        -v min_cpu="$monitor_process_min_cpu" '
          $3 + 0 >= min_cpu {
            command = $5
            for (field = 6; field <= NF; field++) command = command " " $field
            printf "%s\t%s\t%s\t%s\t%s\t%s\n", timestamp, $1, $2, $3, $4, command
          }
        ' >> "$monitor_process_log"
      sleep "$monitor_interval"
    done
  ) > "$monitor_log" 2>&1 &
  BENCHMARK_MONITOR_PID=$!
}

# Return success only when no monitored background class crossed its limit at
# any observation.  CPU idle is recorded for diagnosis but is not an acceptance
# threshold during a workload: a healthy parallel compiler should consume the
# machine.  The caller retains both this assessment and the raw monitor.
benchmark_assess_monitor() {
  monitor_log="$1"
  assessment_log="$2"
  spotlight_limit="${BENCHMARK_MAX_SPOTLIGHT_CPU:-5}"
  background_limit="${BENCHMARK_MAX_BACKGROUND_CPU:-5}"
  expected_nix_clients="${BENCHMARK_EXPECTED_NIX_BUILD_CLIENTS:-0}"
  required_power_source="${BENCHMARK_REQUIRED_POWER_SOURCE:-AC Power}"
  benchmark_lock_power_mode
  required_power_mode="$BENCHMARK_REQUIRED_POWER_MODE"

  awk -F '\t' \
    -v max_spotlight_allowed="$spotlight_limit" \
    -v max_background_allowed="$background_limit" \
    -v expected_nix_clients="$expected_nix_clients" \
    -v required_power_source="$required_power_source" \
    -v required_power_mode="$required_power_mode" '
      NR == 1 { next }
      {
        observations++
        if (observations == 1 || $2 < min_cpu_idle) min_cpu_idle = $2
        if ($2 > max_cpu_idle) max_cpu_idle = $2
        if ($3 > max_spotlight) max_spotlight = $3
        if ($4 > max_background) max_background = $4
        if ($5 > max_nix_clients) max_nix_clients = $5
        if ($6 != required_power_source) unexpected_power_source++
        if ($7 != required_power_mode) unexpected_power_mode++
        if ($3 > max_spotlight_allowed || $4 > max_background_allowed || $5 > expected_nix_clients || $6 != required_power_source || $7 != required_power_mode) contaminated++
      }
      END {
        accepted = observations > 0 && contaminated == 0
        print "observations=" observations + 0
        print "min_cpu_idle_percent=" min_cpu_idle + 0
        print "max_cpu_idle_percent=" max_cpu_idle + 0
        print "max_spotlight_cpu_percent=" max_spotlight + 0
        print "max_background_cpu_percent=" max_background + 0
        print "max_nix_build_clients=" max_nix_clients + 0
        print "spotlight_limit_percent=" max_spotlight_allowed
        print "background_limit_percent=" max_background_allowed
        print "expected_nix_build_clients=" expected_nix_clients
        print "required_power_source=" required_power_source
        print "required_power_mode=" required_power_mode
        print "unexpected_power_source_observations=" unexpected_power_source + 0
        print "unexpected_power_mode_observations=" unexpected_power_mode + 0
        print "contaminated_observations=" contaminated + 0
        print "accepted=" accepted
        exit !accepted
      }
    ' "$monitor_log" > "$assessment_log"
}

benchmark_stop_monitor() {
  if [ -n "${BENCHMARK_MONITOR_PID:-}" ]; then
    kill "$BENCHMARK_MONITOR_PID" 2>/dev/null || true
    wait "$BENCHMARK_MONITOR_PID" 2>/dev/null || true
    BENCHMARK_MONITOR_PID=
  fi
}
