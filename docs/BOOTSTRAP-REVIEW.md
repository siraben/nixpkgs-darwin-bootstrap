# Darwin bootstrap review

Review target: commit `8bfbe07f010b866d4c869edc784d8c2ab907ad8e`
(`speed up gcc46 cxx frontend build`) plus the correctness fixes and review
instrumentation in the working tree.  Review host: Apple M5 Pro, 48 GiB RAM,
macOS 26.3.2 (25D2150), Darwin 25.3.0, with the x86_64 chain running under
Rosetta 2.

## Verdict

The GCC 4.6 backend-object reuse optimization in `8bfbe07` must not be the
default.  It copies objects built by TinyCC in the C-only `gcc46-all-gcc`
configuration into a C+C++, `--disable-threads` checkpoint compiled by GCC
4.6.  The flags, compiler, generated headers, and dependency information do
not match.  A successful C-only GNU Hello build cannot prove C++ frontend or
backend equivalence.  The review therefore changes the default from reuse to
recompile and retains reuse only as an explicit A/B experiment.

The project is a substantial from-seed compiler chain, but neither its shell
track nor its Nix track is yet a faithful stage0 bootstrap under the policy in
`scripts/trust-policy.tsv`.  Both tracks still ask host semantic text tools to
change source, generated code, or linker inputs.  The shell track additionally
compiles runtime stubs with host `cc`.  These are correctness blockers for a
claim of “4 KiB seed plus text sources”; they are not erased by a matching
final GNU Hello hash.

## Trust boundary used for this review

Allowed and disclosed:

- the 4,096-byte x86_64 `hex0` seed;
- the Darwin kernel, dyld, and libSystem ABI;
- the pinned macOS SDK;
- cryptographically fixed source inputs with recorded origins;
- `as`, `ld`, `ar`, `ranlib`, and ad-hoc signing at an explicitly logged
  platform-binary boundary;
- the host shell and file-moving/scheduling tools as orchestration.

Not allowed:

- host C or C++ compilation of bootstrap source;
- mutable or unhashed network inputs;
- host `awk`, `perl`, `python`, `sed`, or `patch` when it decides or emits
  program semantics, changes source/generated code, selects symbols, or
  constructs linker input;
- prebuilt compiler objects unless compiler, flags, configuration, generated
  headers, dependency closure, and target all match the consuming stage.

This is stricter than merely proving that the final executable is reproducible.
The Reproducible Builds definition requires the same source, environment, and
instructions to produce bit-for-bit identical artifacts; it does not by itself
establish that every translator in those instructions descended from the
declared seed.

## Provenance and clean-source checks

The proposed-index audit completed with zero hard audit failures:

| Check | Result |
|---|---|
| x86_64 seed | 4,096 bytes, SHA-256 `0d47e3c09c2fe182810a0ac6102151bbb6aaf6224456d0ca9f1b2b883be9e7c5` |
| seed self-reproduction | byte-identical when assembling the committed `hex0` source |
| `hex1` Darwin source | 13,132-byte native Git blob, SHA-256 `d4ad158486497b6afce45cd9daa2632acff3d68c7797e701a59d9040703885ab` |
| `hex2` Darwin source | 9,218-byte native Git blob, SHA-256 `7e998343ac945e4d97ebcdd602fe2e22e41b5f07f9e5c455413acf2adf372130` |
| shell stages inventoried | 64 |
| Nix stages inventoried | 73 |
| host-tool candidates | 81 (triage candidates, not 81 proven violations) |
| semantic-transform candidates | 75 (triage candidates, not 75 proven violations) |
| strict modern-GCC host compile switches | disabled |
| GCC 4.6 unproved object-reuse default | disabled |

The two Darwin `.hex0` files were Git LFS pointers in `HEAD`, even though the
working tree had materialized content.  Nix Git flakes import Git objects and
do not run the LFS smudge filter, so a clean Git-source build fed the 129/130
byte pointer to the seed assembler and failed at `hex2-0`.  The proposal removes
the LFS attribute and stores both sources as native Git blobs.  A detached
proposal commit was then addressed through `git+file:?rev=...`; rebuilding
`hex2-0` from that Git flake completed successfully in the strict sandbox.

The Coreutils derivation also embedded a local patch path without retaining its
Nix string context.  The proposal declares `coreutilsPatches` as an input and
iterates that input directly, eliminating the “store reference without proper
context” warning.  A clean rebuild then exposed that Coreutils 5.0's bootstrap
`install` copied all 61 Mach-O programs with mode `0644`: the build-tree smoke
passed, but the installed output was unusable.  The install phase now sets mode
`0755` with the orchestration `chmod` and runs the installed `echo`; a successful
derivation therefore proves both content production and executable output
metadata.  The corrected clean output is
`/nix/store/fdikhr83kcs1x7ab2jindxp7ibyg1vrr-coreutils-5.0`: 61 programs,
store-normalized mode `0555`, about 2.0 GiB, NAR hash
`sha256-6OPbHbvdURl+RZB05hinYn/4HgKhNEiG4sJzVBuTpVE=`.  Both installed `echo`
and `md5sum` executed successfully.

## Compilation chain

The declared chain is:

```text
hex0 seed
  -> hex1 -> hex2-0 -> M0/cc-arch -> M2-Planet
  -> blood/M1/full hex2/kaem
  -> Mes -> MesCC libc -> TinyCC
  -> self-built TinyCC -> tcc-darwin-cc
  -> GNU Make + GNU Patch + Coreutils
  -> GCC 4.6 C -> libgcc -> GCC 4.6 C++
  -> GCC 10 -> GCC 15 -> strict GCC 15
  -> GNU Hello bootstrap/strict/reference hash gate
```

The hash gate fails unless the bootstrap and strict outputs match and their
common hash matches the pinned bootstrap baseline.  The independently executed
nixpkgs reference has its own pinned baseline because nixpkgs's compiler and
linker wrappers add frame-pointer, deployment, search-path, and RPATH policy
that the minimal bootstrap wrapper deliberately omits.  Treating those
policy-distinct binaries as byte-identical would test wrapper policy, not
self-hosting; the gate records the inequality explicitly and fails on drift in
either baseline.  This is a strong reproducibility and regression check; it
does not prove that every translator descended from the declared seed.

The first finalized run exposed and correctly stopped on an over-strong gate
introduced during review: the bootstrap and strict binaries were identical
(49,400 bytes, SHA-256
`0854f4ab9cf255a37ddfb6251198164e6f14f3606239c963d2530f77e257f90a`),
while the nixpkgs reference was 49,360 bytes with SHA-256
`f23f901be1f6c913487bfc939364f746127357805c0ccbe2a922c7c6b793f417`.
`otool -l` showed substantive policy differences rather than a random UUID:
the reference carried nixpkgs library RPATHs and different text, unwind,
symbol, and stub layouts.  Its compiler is `gcc-wrapper`, whereas the strict
chain uses the minimal bootstrap wrapper; the former injects frame-pointer,
deployment-target, include/library, and linker policy.  A host-side diagnostic
using raw nixpkgs GCC with an explicit common SDK/link policy still produced a
third hash, confirming that the differently configured compilers are not an
exact-byte oracle for each other.  Revision
`799560d202fd20a8a6cc8df14b1d763e8fd7709e` therefore keeps the meaningful
self-hosting assertion (bootstrap equals strict), pins both policy-specific
baselines, executes all three programs, and records the expected cross-policy
inequality instead of pretending it is equality.

The flake maps `aarch64-darwin` to this x86_64 package set.  On Apple Silicon
this is an x86_64 bootstrap under Rosetta, not a native AArch64 bootstrap.  The
committed 34,656-byte AArch64 seed is outside the reviewed promoted chain.

### Fidelity blockers: shell track

1. Early Mes/TinyCC stages use host `awk` to split M1 code and data and, in
   some cases, collect or rewrite labels.  Examples include steps 21, 24-27,
   31, 33, 35-36, 38, 40, and 42.  This is semantic assembler/linker work.
   Chain-built replacements arrive only at steps 44c-44g; their own bootstrap
   still uses the host fallback.
2. Step 17 rewrites the Mes build program with host `sed`/`awk` and injects an
   early exit.  That changes the program that drives the next compiler stage.
3. Host Perl edits Mes, Make, and GCC source/generated files (steps 15, 45,
   48, 49, and 51).  Step 53b uses host Python to edit GCC 10 source.
4. Step 55 compiles `.boot-stub.c` with `/usr/bin/cc` and archives it into
   `libgcc_eh`, `libgcc_s`, and `libemutls_w`.  The core `libgcc.a` is
   chain-built, but these runtime libraries are still host-produced inputs.
5. The gcov and fixincludes executable/stamp shortcuts intentionally skip
   work outside the stated C compiler goal.  They must be described as a
   reduced bootstrap goal, not as a complete GCC build.

### Fidelity blockers: Nix track

1. `sed -i '/^<$/d'` cleans MesCC-produced M1 in the libc and TinyCC probes.
   Because the removed tokens affect assembler input, this is semantic work.
2. Host `patch` creates `tinyccMesSrc` before chain-built GNU Patch exists.
3. Host Perl edits the staged GCC sysroot, generated `config.h`, caches,
   Makefiles, compiler wrappers, and modern-GCC generated build files.  Some
   committed source patches are correctly applied by chain-built GNU Patch,
   but the remaining in-build edits are still part of the result's semantics.
4. The live `gcc46-all-gcc` build log shows Nixpkgs `gawk` executing GCC's
   `opt-functions.awk` and `optc-gen.awk` to emit `options.c`.  This is host
   semantic code generation even though the resulting C is compiled by the
   chain compiler.  GCC's other generated-source paths need the same dynamic
   classification; they cannot be cleared merely because configure found no
   host C compiler.
5. The default no-backend-reuse `gcc46-cxx` path still imports generated C and
   headers, chain-built `build/gen*` executables, and their generator objects
   from the preceding TinyCC-built `gcc46-all-gcc` checkpoint.  It recompiles
   the C/C++ frontend and language-independent backend sources with GCC 4.6;
   the retained `build/*.o` files are generator inputs, not the backend-object
   reuse disabled by this review.  During the clean correctness run, Make also
   tried an absolute `src/missing flex` path left by the earlier build.  That
   regeneration failed and was ignored, retaining the staged generated Flex
   scanner.  These are disclosed, seed-descended stage inputs rather than a
   hidden host compiler, but their exact generator and C-only versus C+C++
   configuration provenance remains inside the trust boundary.  Representative
   retained inputs in the completed `gcc46-all-gcc` output are the Mach-O
   `build/gengtype` executable (SHA-256
   `9cf39b7e5af1c8b34152f5e2c8721eda85a5e5b6d33d61bae3ae63532aab79a7`),
   its ELF `build/gengtype-lex.o` object
   (`9e5333526a3f557542aeccbf46815a78a882f439b91217bde6f9ec687e51f79f`),
   and generated `gengtype-lex.c`
   (`49a11e4a346512e5df2abd1b7ea1b074c09330daaa26781629d039137584bb0f`).
   Chain-built Make also reports `gcc.c` as having modification time `g s` in
   the future.  A controlled fixture set exactly ten seconds ahead reproduced
   the message: Make detected the future timestamp correctly, but the bootstrap
   formatting path rendered GNU Make's `%.2g` literally as `g`.  Normal
   non-generator objects are deleted before this Make invocation, so the
   warning is not evidence that those objects were retained.  Timestamp-driven
   decisions for the staged generators and generated sources nevertheless
   remain part of their disclosed provenance.
6. The strict GCC derivations correctly set
   `GCC_MODERN_WRAPPER_HOST_SHORTCUTS=0`,
   `GCC_MODERN_HOST_BUILD_CC=0`, and the GCC 4.6 host-source/generated-source
   shortcuts to zero.  This is good evidence that host C/C++ source compilation
   is not the normal strict path; it does not make the semantic host edits
   acceptable under this review policy.

Dynamic `exec` tracing would strengthen the static audit by proving which
conditional branches actually run.  macOS `eslogger exec` requires root on
this host, so no privileged trace was collected.  That evidence limitation is
explicit rather than being treated as proof of absence.

## GCC 4.6 object-reuse review

`8bfbe07` copies every `.o` in `gcc/` and `gcc/c-family/`, plus backend
archives, from `gcc46-all-gcc` after preparing only a subset of headers.  The
reuse preconditions are not met:

| Property | Producer (`gcc46-all-gcc`) | Consumer (`gcc46-cxx`) |
|---|---|---|
| compiler | chain TinyCC | GCC 4.6 checkpoint |
| object format | ELF | Mach-O 64-bit by default; reuse silently forces ELF |
| languages | `--enable-languages=c` | `--enable-languages=c,c++` |
| threads | producer configuration | `--disable-threads` |
| debug flags | `-g` | `-g0` in the C++ checkpoint defaults |
| generated configuration | C-only build tree | independently configured C+C++ tree |
| dependency metadata | `.o` copied without matching `.d` files | Make can retain stale objects |

There is no exhaustive proof that `config.h`, `bconfig.h`, `tm.h`, `tm_p.h`,
`options.h`, generated enums, and every included header are identical.  Even if
one small C++ fixture compiles identically, that is evidence about the fixture,
not about all reused objects.  Correct ways to recover this optimization are:

1. Build the reusable backend once with the same GCC 4.6 compiler, C+C++
   configuration, target, thread model, flags, and generated headers used by
   the consuming checkpoint.
2. Give every object a manifest containing compiler hash, full argv,
   preprocessed-source hash, and dependency/header hashes; reuse only on exact
   manifest equality.
3. Rebuild both variants and compare an agreed semantic test suite and all
   compiler outputs.  Keep reuse opt-in unless that proof is maintained in CI.

The included A/B harness builds default/no-reuse and experimental/reuse as
separate derivations, interleaves treatment order, compiles C and C++ fixtures
at `-O0`, `-O2`, and `-Os`, requires byte-identical assembly and objects, and
executes linked C and C++ fixtures (including exactly representable
floating-point constant-folding checks) before collecting performance samples.

`scripts/collect-gcc46-provenance.py` inventories only finalized producer and
consumer outputs.  The C++ output retains a normalized compressed archive of
the regular `src/gcc` and `build/gcc` files so the collector can hash the actual
final object bytes after the Nix sandbox disappears without storing the large
Mach-O padding uncompressed.  It retains artifact and compiler-component
hashes, complete consumer compile argv, compile-log coverage for every retained
non-generator object, and the `cc1plus` link command.  It also records its
limitation: without every preprocessed translation unit and complete
header/dependency closure, this evidence can prove that the default rebuilt its
objects but cannot make the mismatched-object reuse path faithful.

The `gcc46-all-gcc` configure log also warns that the TinyCC-built MPFR probe
cannot validate NaN behavior and cannot determine the `long double` format.
Those warnings do not alone prove a miscompile, but they are a correctness gap
that a C-only GNU Hello hash does not cover.  Floating-point execution tests
are therefore a minimum gate; broader GCC tests remain necessary before making
a general compiler-correctness claim.

## Performance methodology

Measurement tooling is host-side only and cannot contribute bytes to bootstrap
outputs.

The restored-host corrected-gate build and quiet timing campaign evaluate
derivations at final code revision
`0a199c25095401d4cdb650f7bfde9ba760f5ccc6`.  That revision includes the
complete shared signed-tool mitigation, the cctools `ranlib` sibling repair,
the GCC wrapper and libgcc isolation fixes, copied-prerequisite path rebasing,
and the BSD `find` portability correction described below.  It also records an
explicit `extra-platforms = x86_64-darwin` option in Nix timing commands.  The
latter does not replace or translate a compiler: it tells a Nix daemon that
the already installed and independently smoke-tested Rosetta execution
platform is available.  Every campaign records exact harness-file hashes, and
the provenance bundle records and copies its collector, keeping late
evidence-tool changes from silently changing either compiler work or its
interpretation.

- `build.sh` records per-step nanosecond wall time and `/usr/bin/time -l`
  process metrics only when explicitly enabled.
- `time-shell-e2e.sh` verifies tarball hashes, starts from an empty dedicated
  target, runs the GCC 10 goal test, and hashes the output tree.  Before quiet
  waiting, it also records mode, size, and SHA-256 for every effective shell
  input reached through `build.sh`, `seed/`, `sources/`, and `steps/`, following
  the source symlinks, plus the explicitly enumerated build and goal-test
  helpers under `scripts/`; the user-owned `bake/` tree is outside that
  manifest.
- Shell and paired A/B wall clocks bracket only the build command; monitor
  startup, shutdown, quality assessment, log export, hashing, and goal tests
  are outside the reported workload interval.
- Each successful shell attempt retains both per-file content hashes and a
  sorted output-tree manifest covering entry type, mode, size, file hash, and
  symlink target.  This exposes metadata and layout drift that content-only
  hashing would miss.
- Every timed Nix stage, A/B treatment, and shell attempt records filesystem
  capacity with macOS `/bin/df` immediately before and after its workload,
  outside the timed interval.  Pinning the implementation matters on APFS:
  macOS `df` and GNU `df` can report radically different used-block and
  capacity values for the same shared container even while agreeing on
  available blocks.  This exposes low-space/APFS pressure rather than silently
  attributing it to compiler variance.
- Before quiet waiting, every harness also requires and records at least
  10 GiB of free space on the workload volume by default
  (`BENCHMARK_MIN_AVAILABLE_KIB` overrides the threshold).  A low-space run
  fails before timing rather than becoming a performance sample.
- The same boundaries retain `vm_stat`, `vm.swapusage`, and
  `memory_pressure -Q` snapshots outside the timed interval.  “Fresh” means the
  declared build outputs and derivation plans were deleted; it does not claim a
  cold Darwin VM/APFS cache.  No privileged cache purge is performed.
  Sample-order drift and the recorded swap and
  inactive/speculative/purgeable-page state must therefore be inspected with
  the dispersion statistics rather than silently treating cache warmth as
  controlled.
- `time-nix-e2e.sh` records sandbox, substitution, job/core settings, output
  hashes and sizes, and client resource use.  Nix CPU/RSS fields are labeled
  client-side because daemon builders are separate processes.
- Nix builder logs are retained by the daemon and exported after the timed
  interval.  Streaming them through the client is opt-in, so terminal and log
  transport I/O are not mislabeled as compiler cost.
- Nix “fresh” mode deletes only an explicit closed set of project outputs and
  their exact evaluated `.drv` plans.  Nix requires the latter because each
  plan refers to its own output; the harness re-evaluates the plans before the
  timer starts.  It refuses deletion if an outside output or derivation
  referrer exists and proves that every enumerated output is invalid before
  starting.  Nyacc and both TinyCC source-preparation outputs are explicitly
  included.
- `time-nix-suite.sh` uses `--rebuild` for isolated stage cost and safe scoped
  deletion for end-to-end cost.  Rebuild mode proves that every requested
  output is valid before monitoring starts and fails closed rather than
  silently including a missing dependency closure in a stage sample.
- `benchmark-lib.sh` waits for three observations with at least 80% CPU idle,
  no active competing `nix build` client, no more than 5% Spotlight CPU, and no
  more than 5% aggregate CPU from background-service classes observed to
  disturb work on this host.  The observed classes include Borg backups, Apple
  Virtualization, Docker activity, Redline background workers, and the indexed
  and personal-data services named by the harness.  It also requires AC power
  and monitors power source, the active `pmset` power-mode value (numeric mode
  `2` on this review host),
  those services, and Nix clients throughout the timed workload.  The power
  mode is locked before environment capture and must remain unchanged.  A
  threshold, power-source, or power-mode violation marks the entire attempt
  rejected; the repeat harnesses retain each attempt's evidence and retry until
  five clean samples have been accepted (or the explicit attempt limit is
  reached).
- `fseventsd` is intentionally not an automatic rejection class: the measured
  GCC wrappers themselves create and remove thousands of symlinks, which can
  drive FSEvents CPU.  Its exact observations remain in the process evidence
  for review as a possible workload-side system cost rather than being assumed
  to be independent interference.
- Every workload monitor also retains a timestamped snapshot stream of all
  processes reporting at least 5% CPU.  This is diagnostic rather than an
  automatic allowlist: it exposes previously unseen interference for explicit
  reclassification without incorrectly rejecting the measured compilers and
  Nix daemon builders themselves.  The stream includes sampled resident-set
  size, but only for processes above that CPU threshold at a sampling instant;
  its mean and maximum are diagnostic samples, not whole-workload or true
  peak-RSS measurements.
- `summarize-process-snapshots.py` aggregates those streams globally and per
  evidence file, and can emit a per-file exact-command manifest.  It reports
  sampled CPU and RSS, observation counts, unique-command counts, and commands,
  and fails on missing, malformed, or empty inputs.  Its workload, harness, and
  known-background labels are review hints rather than acceptance decisions.
  It recognizes Clang as workload only for the observed sandboxed GCC 4.6
  `-x assembler -integrated-as` boundary; generic Clang stays unclassified, and
  a process key seen in both roles becomes `mixed-review-required`.  Every
  per-file row and exact-command row must be reviewed, including
  workload-looking basenames that could belong to another project; an
  `unclassified-review-required` or `mixed-review-required` row cannot remain
  unresolved when the affected samples are finally accepted.
- `summarize-timings.py` reports median, mean, min/max, sample standard
  deviation, MAD, CV, interpolated p95, and each stage's median share.  The
  summarizers reject malformed, non-finite, and negative measurements and fail
  closed unless every shell/Nix input has one identical ordered stage set,
  every metric declared by an accepted input is present on every successful
  row, every stage and A/B treatment has exactly the requested number of
  accepted samples, and pair identifiers are contiguous.  The paired A/B
  summary adds min/max, standard deviation, MAD, interpolated p95,
  geometric-mean ratio, treatment-order strata, and an exact two-sided sign
  test.
- `summarize-system-state.py` pairs every retained disk and memory before/after
  file and fails closed.  It converts `df` blocks and VM page gauges to bytes,
  retains page-in/out and swap-in/out counter deltas, parses swap usage and
  memory-pressure percentages, and reports per-profile median, mean, and
  min/max deltas.  A missing counterpart or mismatched metric set is an error.

Five accepted samples per stage/profile are the target; an attempted run is not
silently promoted to a sample merely because the command succeeded.  The required result
table is generated as `stage-summary.tsv`; raw logs, thermal state, process
snapshots, workload monitoring, hashes, and clean-state proofs remain beside
it.  The harness `accepted` flag means that the automated power, known-service,
and competing-Nix-client gates passed; it is provisional until every row in
that attempt's per-file and exact-command detail has been reviewed and every
`unclassified-review-required` or `mixed-review-required` row adjudicated.
Warm-ups and contaminated or unresolved-process runs are not final samples.
`pmset -g therm` reports no recorded thermal/performance warning level on this
host, so its before/after output is retained as an explicit sensor limitation;
power-mode continuity and the reported sample dispersion guard the observable
parts of thermal/power variance but are not a direct temperature trace.

### Host panic and signed-orchestration mitigation

The 2026-08-10 correctness rerun is not a timing sample.  At
2026-08-10T05:45:23-07:00, while the faithful GCC 4.6 C++ Make was in its first
parallel compile batch, macOS panicked with `Cannot grow ipc space beyond
IVAC_ENTRIES_MAX. Some process is leaking vouchers @ipc_voucher.c:573`.  The
full report was the host-owned
`/Library/Logs/DiagnosticReports/panic-full-2026-08-10-084519.0002.panic`
(3,706,650 bytes; incident
`630302BB-F261-429C-A1FC-D9FC19B54B4F`) before the subsequent host refresh.  It
was inspected in the archived review session but was not copied into the
review-evidence directory, and that system-owned file did not survive the
refresh.  The transcript retains the report header and inspection results, not
a byte-for-byte redistributable panic artifact; this is an explicit
evidence-retention limitation.  The panicked task was Apple's `taskgated`, not
a Nix builder.  The inspected report
says memory pressure was false, compressor and swap space were OK, no pages
were wanted, and about 6.3 GiB of RAM was free; it does not identify an OOM,
thermal, APFS, NVMe, or compiler fault.

The panic stackshot contains the exact active bootstrap PIDs: Nix clients and
daemon builder, chain Make, and 18 GCC wrapper Bash processes.  Each wrapper
had accumulated about 428--430 seconds of system CPU and roughly 1.5 million
page faults before its live `cc1` child appeared.  The unified log supplies a
strongly correlated trigger path, not proof of leak ownership: `taskgated`
repeatedly tried to consult `/private/var/db/DetachedSignatures` and returned
Security error `-67062`, which Apple's Security source defines as
[`errSecCSUnsigned`](https://github.com/apple-oss-distributions/Security/blob/Security-61901.80.25/OSX/libsecurity_codesigning/lib/CSCommon.h#L70-L76).
There were 22,050 such detached-signature checks in the preceding 15-minute
bootstrap interval, 178,102 in the next 30 minutes, and 113,741 in the final
12-minute main-Make interval.  The last 90 seconds sustained roughly 130--178
checks per second until logging stopped at the panic.  Executing one known
unsigned fixture reproduced exactly one such lookup/error sequence; executing
the explicitly selected Apple platform utilities reproduced none.

XNU source narrows the proximate failure.  A global table for one voucher
attribute manager had exhausted its freelist and reached the hard
[`IVAC_ENTRIES_MAX` limit of 524,288 entries](https://github.com/apple-oss-distributions/xnu/blob/xnu-12377.81.4/osfmk/ipc/ipc_voucher.h#L137-L150);
the next attempted growth follows the
[`ipc_voucher.c` panic path](https://github.com/apple-oss-distributions/xnu/blob/xnu-12377.81.4/osfmk/ipc/ipc_voucher.c#L553-L610).
`taskgated` was the current task whose allocation encountered that full shared
cache.  Neither the panic string nor the surviving stackshot proves that
`taskgated` retained the earlier voucher values, identifies the exhausted
attribute manager, or establishes one voucher allocation per signature check.
The three recorded intervals total 313,893 checks, about 60% of the table cap;
that is order-of-magnitude compatible with the storm precipitating exhaustion
when the cache already had occupants or a request created multiple unreclaimed
values, but it rejects an unqualified one-check/one-leaked-voucher claim.  The
calibrated conclusion is therefore that bootstrap-induced unsigned-tool churn
very likely precipitated the voucher-cap panic through `taskgated`'s
signature-check path, not that the surviving evidence proves a `taskgated`
leak.

The high-fanout GCC wrapper used `ln`, `mkdir`, `cp`, `rm`, `readlink`, and
`mktemp` through the Nix build `PATH` while constructing thousands of
per-translation-unit overlay entries.  The corrected wrapper uses the fully
signed Apple `/bin/ln`, `/bin/mkdir`, `/bin/cp`, `/bin/rm`,
`/usr/bin/readlink`, and `/usr/bin/mktemp` for this disclosed file-moving and
orchestration boundary.  Their signatures and a symlink/copy behavior smoke
test pass.

That first mitigation was necessary but not sufficient.  An eight-core
`gcc46-all-gcc` retry at `a25ca8d6ec9d036d37156da7c2aa62fc18d25f18`
recorded 4,110 and then 5,994 detached-signature lookups in consecutive
one-minute guard windows, so it was terminated before the 6,000/minute cutoff.
The remaining hot path was repeated execution of unsigned x86_64 stdenv Bash,
GNU build tools, and cctools from the Nix store.  A controlled idle-host test
launched the exact Nix-store Bash 50 times and observed 50 lookups; 50 launches
of a writable ad-hoc-signed copy observed zero.

The second mitigation, evaluated at
`69a81ef7d8ce3c55d625713623b943cf9d3f6144`, makes private writable copies of
the exact derivation-selected stdenv and cctools executables, applies an ad-hoc
signature with timestamping disabled, verifies each signature, and invokes the
unchanged chain TinyCC wrapper through the signed copy of the exact stdenv
Bash.  It neither mutates Nix-store inputs nor substitutes a host compiler or
source translator.  The signature changes Mach-O execution metadata on
build-tool copies only; those copies are not installed into compiler outputs.
Its live guard windows began 0, 1, 1, and 58 lookups/minute, versus
5,994/minute before normalization, but rose to 773/minute as TinyCC linking
started.  That retry was also stopped proactively.  Inspection found absolute
paths to the pinned unsigned `elf64-to-m1`, `sigtool`/`codesign`, and
`codesign_allocate` inputs inside the wrapper and signing helper.  Revision
`13b3211ab27b101cb92e23fa784363ab9ce89bb8` signs private copies of
`sigtool`/`codesign` and `codesign_allocate` and rewrites only those execution
paths in private wrapper/helper copies.  The custom padded stage0-built
`elf64-to-m1` has no suitable Mach-O signature load command: both Apple
`codesign` and the pinned `sigtool` refuse to produce a strictly valid signed
copy in that 40 MiB layout.  Its Mach-O commands actually declare
`__LINKEDIT` at 16 MiB; the extra 24 MiB was an unowned gap copied from a
different low-data layout.  Revision
`a868cdada3e2c1dd7619a4136fc2acc1221f09dc` truncates the no-data helper at its
declared boundary before applying the existing pinned signing bridge.  The
result is a strict-valid 16,909,536-byte chain-built executable, and an
independent ELF-symbol conversion smoke passes.  The build remains
correctness-gated until the complete checkpoint, provenance, installed-tree
checks, and pinned Hello comparisons pass.  Every interrupted run and every
pre-mitigation timing observation is rejected.

The first post-fix GCC checkpoint then exposed a distinct correctness bug, not
a taskgated cutoff: the signed copy was installed as `cctools-ranlib`, while
cctools `ar` derives and executes an exact sibling path named `ranlib` when it
refreshes an archive index.  The build stopped at `libiberty.a` with that
missing path.  Revision `b5f4600cebdfaae081b5dd2624f1d254fec349a9`
provides a second signed copy of the same derivation-selected cctools binary at
the required internal name and regression-tests the invariant.

After the host was refreshed, Rosetta itself remained installed and
`/usr/bin/arch -x86_64 /usr/bin/true` succeeded, but the root-owned Determinate
Nix daemon had started without advertising `x86_64-darwin`.  A guarded
single-stage test with an explicit `extra-platforms` option built and executed
`hex0` successfully with zero detached-signature lookups.  Revision
`601d6680532538d7d43f40cddd41770bca997e81` makes that already-required
platform setting explicit in every timed Nix build and records it beside the
other Nix settings.  This avoids relying on an unrecorded daemon restart or
administrator action.

The first fresh-store run at that revision still reached 600 counted
detached-signature lookups/minute while many short early derivations ran and
was terminated by the unchanged 500/minute guard at only 524 cumulative
lookups.  The same attempt independently exposed that `/usr/bin/truncate`,
although signed and functional outside the sandbox, was not an allowed
executable inside this refreshed Nix sandbox.  Revision
`405c19ea245cc2fe5d59a3117d3a52a656d59deb` builds one reusable set of
ad-hoc-signed copies of the exact stdenv orchestration tools, places it before
the original PATH for every `mkDarwin` and `runCommand` phase, and uses its
signed `truncate`.  All 33 finalized store executables pass strict signature
verification; 50 controlled launches of its Bash caused zero detached-
signature lookups.  A guarded rebuild of nine stage0 derivations peaked at
207 lookups/minute and completed, and the formerly failing translator again
produced a strict-valid 16,909,536-byte executable.  The signed-tool
derivation is part of the enumerated clean timing closure rather than an
unmeasured cache input.

Subsequent fresh-chain retries found two more execution-compatibility gaps.
First, early stage0 `hex1`, `hex2`, `catm`, `M0`, both Mach-O patchers, and
`cc-arch` needed signatures at their declared `__LINKEDIT` boundary, and the
shared signing bridge itself needed signed copies of the exact pinned
`sigtool`, `codesign`, and `codesign_allocate` inputs.  Those fixes do not
replace a compiler or translator: they add Mach-O execution metadata to the
same derivation-selected executables.  Controlled tests found zero detached-
signature lookups for 60 launches of a strict-valid TinyCC-linked output, 45
shared-bridge signing operations, and 45 signing-plus-`sigtool inject`
operations.

Second, revision `cc0f2f22c2b5c00d3949ec19a49d810b87b72e7b` still reached
570 lookups/minute and was stopped at only 214 cumulative lookups.  A live
taskgated trace identified 219 checked executable paths: 213 were the exact
nixpkgs Coreutils 9.10 multicall binary, three were raw stdenv Bash, two raw
GNU grep, and one diffutils.  The shared set covered only 36 explicitly named
tools; a missing applet symlink still resolved to the same unsigned
`bin/coreutils` binary, which made the path-frequency evidence look less
specific than the actual applet gap.

Revision `824175be9ce896d8712525b08b1be9805248474e` removes that guesswork.
It signs the exact stdenv Coreutils multicall binary once, verifies the strict
signature, and uses that already-signed binary to reproduce every applet name
present in its own `bin` directory.  This includes names hidden by Bash
builtins such as `test`, `true`, `printf`, and `echo`.  The isolated output
contains all 107 source names (106 applet symlinks plus `coreutils`), alongside
the non-Coreutils and signing bridge tools; all 12 regular executables verify
strictly, representative applets execute correctly, the closure occupies
7.5 MiB, and its guarded build observed zero detached-signature lookups.

The first full retry at that revision passed the taskgated guard (201/minute
peak, 251 cumulative) but exposed an ordinary archive-tool correctness bug.
Nixpkgs's `${cctools}/bin/ranlib` is a symlink to the cctools `libtool`
multicall executable, which selects ranlib mode only when `argv[0]` is exactly
`ranlib`.  The private signed copy was named `cctools-ranlib`; Make invoked it
on `libiberty.a` and `libmpn.a`, so it entered libtool mode and failed with
“no output file specified.”  A controlled test of two byte-identical,
strict-valid signed copies reproduced the distinction: `ranlib` returned zero
on the test archive, while `cctools-ranlib` returned one with the build's exact
diagnostic.  Revision `2067e2eed5dfd8cdffe5a5cabb315a52fc63b14f` uses one
signed copy with the required basename for both Make and cctools `ar`'s
derived sibling lookup, and regression-tests that no prefixed copy remains.

The next guarded libgcc retries closed four remaining execution and isolation
gaps.  Revision `13fc98e8e31533e82e07b751e88975d8206339a0` invokes the GCC
4.6 and modern-GCC build scripts with the shared strict-verified Bash instead
of a raw stdenv interpreter.  Revision
`df726bd8eb8ce974f02ffa0a8b5d4b75bf7c661b` routes the TinyCC signing helper
through the same signed-tool boundary.  Revision
`89547541ec83953ebfd32071d5ce918ee56c5265` adds `-nostdinc` to the libgcc
bootstrap wrapper so an absent bootstrap header cannot silently fall through
to host headers; its guarded libgcc rebuild then completed.  Revision
`af7122e7107aaa176565005fed12c3a409e5b69e` likewise pins the installed TinyCC
Darwin wrapper to the signed
Bash.  These changes select the same derivation inputs and compiler lineage;
they remove undeclared interpreter execution and host-header fallback rather
than substituting a host translator.

The first fresh C++ retry then proved that copying configured GCC prerequisite
trees also copied ephemeral build-directory paths into Makefiles, libtool,
and configure state.  Revision `145ad62bc61f1d16e1c555dae9249eeea1e37981`
rebases both source/build roots and every copied signed cctools/TinyCC tool
path to the consuming derivation.  Its next configure correctly failed closed
when the installed GCC wrapper tried to reach undeclared host file utilities;
revision `78b20937341acabafaff57bb3d073e0d2cff1653` instead embeds the exact
shared, strict-verified `mktemp`, `rm`, `ln`, `readlink`, `mkdir`, and `cp`
store paths.  The isolated bootstrap compiler rebuilt successfully.  The
following C++ attempt reached the prerequisite-state rewrite and exposed a
Darwin BSD `find -exec ... +` portability bug: an empty Perl loop body used a
second literal `{}` placeholder.  Final code revision
`0a199c25095401d4cdb650f7bfde9ba760f5ccc6` changes the loop body to `{ 1; }`,
leaving exactly the one pathname placeholder required by BSD `find`, and adds
a regression assertion for that invariant.

### Performance observations and priorities

The correctness warm-ups are deliberately excluded from statistical results.
Earlier attempts had Spotlight consuming tens to hundreds of percent CPU.  In
the final guarded C++ checkpoint, `ecosystemd`, `ecosystemanalyticsd`, and
`trustd` together consumed roughly 180% CPU while the unified log continuously
recorded Rosetta analysis, code-signature inspection, and trust verification
for the active x86 executions.  That is bootstrap-induced host overhead worth
reporting, but it is not a quiet timing baseline and must not be silently
subtracted from wall time.  The separate performance campaign starts only
after correctness and trusted-output work stops, requires three consecutive
quiet observations, and rejects any workload observation where those known
background services exceed 5% aggregate CPU.  The correctness runs still
exposed likely Pareto targets:

1. Mes compiling TinyCC's large `tcc.c` through MesCC takes minutes on one
   core.  Independent MesCC libc translation units are currently serialized;
   bounded parallel translation is the first safe early-chain experiment.
2. The GCC 4.6 bootstrap driver rebuilds a broad source/header symlink overlay
   inside a fresh temporary directory for every translation unit.  In the
   correctness-only no-reuse run, the initial parallel GCC batch spent more
   than eleven wall-clock minutes in the Bash wrapper at roughly 70--80% CPU
   per process before an `cc1` child was present, even for small inputs such as
   `version.c`.  A later batch showed 15--17 minutes in the wrapper before its
   `cc1` children appeared; those compiler children had then accumulated only
   seconds to under two minutes.  A 2026-08-09T01:46:43-07:00 process-tree
   snapshot made the split explicit: wrapper versus descendant-compiler
   elapsed times were 19:39 versus 4:22 for `cp/semantics.c`, 19:31 versus
   4:04 for `cp/tree.c`, 18:44 versus 2:35 for `cp/optimize.c`, 18:29 versus
   2:11 for `cp/mangle.c`, and 16:39 versus 0:36 for `attribs.c`.  Thus the
   pre-compiler portions were respectively 15:17, 15:27, 16:09, 16:18, and
   16:03.  The exact staged tree contains at least 4,688 entries in the
   directly traversed GCC root, config, language, and support directories,
   before repeated include-directory scans and link fan-out.  This is
   qualitative point-in-time profiling evidence, not an accepted timing
   sample.  Selecting signed platform file utilities removes the observed
   taskgated failure mode and avoids unsigned-exec validation on the hottest
   orchestration calls.  A live `0a199c2` snapshot made that improvement
   visible on the same especially expensive `insn-emit.c`: its wrapper had
   elapsed 28:56 and its `cc1` descendant 25:35, leaving 3:21 before the
   compiler instead of roughly 18 minutes in the earlier run.  The final host
   was not quiet and this is therefore qualitative mechanism evidence, not an
   accepted speedup ratio.  The correction still does not remove the repeated
   traversal itself.
   Build the overlay once from an exact manifest, publish it by atomic
   rename, and have each invocation add only its input-specific links.  The
   cache key must cover the source/build roots, merged sysroot, every include
   directory, wrapper version, and link targets.  Before promotion, compare
   preprocessed source, assembly, objects, installed compiler trees, and the
   final Hello gate against the uncached path under both serial and parallel
   builds.  This removes orchestration work without weakening the compiler
   lineage and is preferable to reusing mismatched backend objects.
3. GCC 4.6 dominates the later chain.  Existing per-file observations in the
   repository show about 125 seconds for `combine.c` and 243 seconds for
   generated `insn-recog.c`; parallelism helps, but does not justify unsafe
   cross-compiler object reuse.  The faithful correctness build sharpened this
   tail-cost evidence: generated `insn-emit.c` occupied one Make slot for about
   2 hours 11 minutes, including roughly 18 minutes before its live `cc1`
   descendant appeared and roughly 1 hour 53 minutes in that compiler.  The
   final `0a199c2` watcher bounded the same source below 36 minutes end to end,
   with the 3:21 wrapper interval recorded above and therefore less than about
   32:39 in `cc1`.  The host was not quiet throughout either interval, so this
   is qualitative mechanism and bottleneck evidence rather than an accepted
   timing sample or statistical speedup claim.
4. Repeated configure tests are numerous.  Audited target-specific cache
   answers can remove probes, but each answer becomes trusted configuration
   data and needs a source citation or an independently compiled assertion.
5. The TinyCC link path's first GCC `cc1` link spends minutes selecting and
   converting archive members one at a time.  Preserve the current deterministic
   symbol-selection order, then convert the already-selected ELF members in a
   bounded parallel batch and concatenate code/data fragments in recorded
   selection order.  The existing checksum-keyed cache provides the right
   correctness anchor.  Also avoid repeated materialization, oversized fixed
   Mach-O padding, and redundant archive extraction where hashes prove reuse.
   `elf64-to-m1` currently emits section plus every symbol/relocation diagnostic
   for each converted object, producing megabytes during a single `cc1` link;
   measure a quiet-by-default mode that retains diagnostics for failure or an
   explicit verbose flag, and prove identical Mach-O output hashes.
   The Coreutils correctness rebuild made the space cost concrete: it installs
   61 Mach-O programs at roughly 34.9 MB each and occupies about 2.0 GiB.  Most
   of that is fixed-layout padding, so the already-used low-data template
   strategy should be extended to these links and checked with byte/hash and
   execution equivalence before promotion.  The Coreutils bootstrap also
   clears `MAKEFLAGS` and supplies no `-j`; its independent translation units
   and program links are a parallelism opportunity after the shared archive
   cache is made race-safe and parallel/serial output hashes match.
6. The modern GCC driver defaults `BOOTSTRAP_JOBS` to one, and the Nix GCC
   10/GCC 15 derivations do not override it.  The retained GCC 10 correctness
   build consequently enters `all-gcc` as `make -j1`, despite the host having
   18 available build cores.  Treat bounded parallelism as an experiment,
   because the generated compiler wrappers and converter caches have not yet
   been proved race-safe.  Compare serial and parallel installed-tree
   manifests, compiler output matrices, the bootstrap/strict equality, and both
   pinned Hello baselines before
   changing the default; if those gates pass, this removes serialization
   without importing a host compiler or weakening lineage.
7. Replacing host semantic transformations with chain-built tools improves
   both fidelity and speed by removing repeated general-purpose Perl/sed/awk
   passes.

## Comparison with other bootstrap projects

- [stage0-posix](https://github.com/oriansj/stage0-posix) starts from a
  256-byte seed, can use a chain kaem seed rather than the host shell, replaces
  utilities phase by phase, and retains intermediate artifacts for audit.
  This project's 4 KiB seed is still small enough for manual review, but the
  host semantic transformations are a larger boundary.
- [live-bootstrap](https://github.com/fosslinux/live-bootstrap) defines its
  aim as a reproducible, automatic, complete end-to-end bootstrap from minimal
  binary seeds.  Its stronger policy rejects binaries other than seeds and
  also rejects pregenerated Autotools and parser outputs.  It candidly records
  that external preparation is still an unsolved problem.
- [Guix full-source bootstrap](https://guix.gnu.org/en/blog/2023/the-full-source-bootstrap-building-from-source-all-the-way-down/)
  roots the x86 graph in 357 bytes, while explicitly acknowledging the roughly
  25 MiB static Guile build driver that remains in the binary set.
- [stage0-macos](https://github.com/Lohann/stage0-macos) is an early macOS
  experiment with shell hex0 and Mach-O examples.  It highlights the Darwin
  constraint that arm64 static executables are disallowed, but does not yet
  provide this repository's compiler chain.
- The [Bootstrappable Builds GCC 4.6.4
  project](https://bootstrappable.org/projects/gcc-464.html) maintains the
  last-GCC-in-C bridge specifically so small compilers such as TinyCC can build
  it.  It supports this repository's version choice, while not weakening the
  requirement that every copied object and generated artifact match the
  consuming configuration.
- [Reproducible Builds definition](https://reproducible-builds.org/docs/definition/)
  supplies the bit-identical reproducibility criterion used for output checks.

The useful lesson is not to advertise an impossibly empty trust boundary.  It
is to make every unavoidable binary and semantic driver explicit, reduce that
set monotonically, and retain enough intermediate evidence that another party
can reproduce each reduction.

## Required follow-up order

1. Keep GCC 4.6 cross-compiler object reuse disabled by default.
2. Land native Git stage0 sources and the Coreutils dependency-context fix.
3. Replace the shell track's early M1 `awk` transforms and step-55 host-compiled
   runtime stubs with chain-built equivalents.
4. Replace Nix MesCC cleanup and GCC Perl edits with chain-built tools or
   committed, independently reproducible patches consumed at the right stage.
5. Replace GCC's host `gawk` generated-source steps with a chain-built awk or
   purpose-built seed-descended generators.
6. Add an unprivileged invocation log inside compiler wrappers and semantic
   tools so the dynamic trust trace does not depend on root-only `eslogger`.
7. Run the five-sample suites on an otherwise idle host; publish raw evidence,
   not only summary numbers.
8. Only reconsider reuse after exact producer/consumer manifests and broad
   C/C++ output equivalence become a maintained gate.
