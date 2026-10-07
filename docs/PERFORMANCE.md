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

The earlier unsigned from-seed run took about eight hours, including GCC 4.6,
C++/libstdc++, GCC 10 and the core-runtime retry; see [STATUS.md](STATUS.md).
It is a historical baseline, not five clean timing samples. A signed run must
still pass the compiler and core-runtime goal tests before any full-chain
performance conclusion can be drawn. No large end-to-end speedup is established
by the component measurements above.
