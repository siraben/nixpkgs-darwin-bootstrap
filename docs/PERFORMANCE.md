# Shell bootstrap performance

## Measurement policy

Keep compiler/source provenance and executable tests as gates; elapsed time
alone does not justify a shortcut. Use separate targets for signed/unsigned
runs and include signing overhead in the stage timings. For small experiments,
`scripts/bench-executable.py` requires at least five alternating baseline/candidate
pairs, successful exits, and byte-identical stdout/stderr. It records individual
wall/user/system times, command arguments, and executable hashes.

Do not reuse GCC backend objects across differently configured checkpoints
without proving compiler, flags, generated headers and dependency equivalence.
In particular, C-only TinyCC objects are not automatically equivalent to the
GCC-built C++ checkpoint in the Nix track. The shell C++ stage continues to
rebuild its own objects; no unproved backend reuse is enabled here.

## 2026-10-07 component benchmarks

Host: MacBookPro18,3, 32 GiB RAM, 10 CPUs, x86-64 tools under Rosetta 2.
OS information and all five raw pairs are retained in
[`benchmarks/2026-10-07/`](benchmarks/2026-10-07/). The Make/TinyCC experiments
finished before the signed bootstrap began. The catm experiment overlapped
an early signed bootstrap, so these are component measurements, not a controlled
end-to-end comparison. `pmset -g therm` reported no thermal/performance warning.

| Workload | Baseline median wall | Candidate median wall | Baseline / candidate |
|---|---:|---:|---:|
| 20 Make `--version` launches, unsigned vs signed | 0.1923 s | 0.1815 s | 1.059x |
| 20 TinyCC `-v` launches, unsigned vs signed | 0.2063 s | 0.1962 s | 1.051x |
| Build catm, smoke-test and hash output, bytewise vs sparse padding | 19.8746 s | 1.4230 s | 13.966x |

The launch differences are small and do **not** establish an end-to-end gain.
System CPU was not reduced in those launch samples. Signed execution is opt-in
(`BOOT_SIGN_EXECUTABLES=1`), primarily to avoid the unsigned-code validation
path, not a claim of fewer vouchers or a quantified kernel-resource saving.
The shell already uses Apple-signed orchestration utilities.

Sparse catm padding removes millions of one-byte read/write calls: median
system CPU fell from 16.3819 s to 0.0362 s, with identical executable SHA-256
across all ten builds. This saves roughly 18 seconds in a stage, not hours
from the full chain. Each measured wrapper included the concatenation smoke
test and an executable hash; the hashes in the JSON's `executables` fields
identify those measurement wrappers.

The single-segment macho-patcher and ELF converter now end at their declared
16 MiB LINKEDIT boundary rather than an unowned 40 MiB extent. Chain rebuilds
confirmed that the declared bytes were unchanged and only trailing zeros were
removed. Both passed strict ad-hoc signing; the converter's symbol output
matched the original. This is a signing-layout fix, not an algorithmic speedup.

## End-to-end validation

```sh
sh scripts/bench-shell-e2e.sh /tmp/darwin-e2e-pair
# For stronger timing evidence (many hours per build, substantial disk use):
BOOT_BENCH_SAMPLES=5 sh scripts/bench-shell-e2e.sh /tmp/darwin-e2e-five-pairs
```

The harness checks out a detached committed-source worktree, verifies pinned
inputs before timing, resets inherited cache/resume/debug settings, and builds
unsigned and signed variants into independent fresh targets. It alternates
order between pairs, records full logs (without background-log truncation),
checks compiler/runtime goals, and stops on failure or insufficient disk space.
Its default single pair is descriptive only, not statistically conclusive.


### Completed clean pair (2026-10-07/08)

Both variants built from seed using the same isolated source revision
`4cefc2cbb75b5c94cb291f9ce8a7c3557382f252`, with fresh per-variant targets and
caches. Both include sparse catm padding and the corrected Mach-O extents;
this pair isolates signed execution, not all optimization changes.

| Variant | Full build wall time | User CPU | System CPU | Goal checks |
|---|---:|---:|---:|---:|
| Unsigned | 29,450.30 s (8h10m50s) | 14,035.26 s | 14,952.98 s | 9.97 s, passed |
| Signed | 29,733.03 s (8h15m33s) | 14,097.47 s | 15,432.32 s | 9.72 s, passed |

Signed execution took **282.73 s longer (+0.96%)** in this pair. There is no
measured end-to-end speedup here; the small launch-only differences did not
translate into a faster complete bootstrap. Keep signing opt-in rather than
promoting it as a speed optimization. This is one descriptive pair: run order,
host state and ordinary variation prevent a statistically conclusive claim
about a difference this small.

Both builds produced 134-member core runtime archives, passed recursion and
signed/unsigned 128-bit division tests with bootstrap-archive link-map checks,
and left their tracked source tree unchanged. The signed TinyCC, GCC 10 `cc1`
and `xgcc` also passed strict signature verification after the build.

The initial harness stopped after the successful unsigned build and tests
because its restricted PATH hid `git-lfs` during the source audit. That audit
was rerun successfully with the maintainer PATH, and the signed variant was
started later from the unchanged source revision. The gap between runs is not
included in the reported build times. Fetching/verifying inputs is also outside
the timing boundary; signing work is inside it. The harness now preserves the
maintainer PATH for Git audits without exposing it to bootstrap commands.

Raw per-stage timings, total resource usage, test logs, exit statuses and source
revision are retained under
[`benchmarks/2026-10-07/e2e/`](benchmarks/2026-10-07/e2e/). Full build logs and
both output trees remain at `/tmp/darwin-e2e-pair-2026-10-07/` on the test host.
The earlier approximately eight-hour run in [STATUS.md](STATUS.md) is historical
context, not an additional matched timing sample.
