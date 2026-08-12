#!/usr/bin/env python3
"""Regression tests for host-side bootstrap review evidence tools."""

from __future__ import annotations

import csv
import importlib.util
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def run_tool(script: str, *arguments: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(ROOT / "scripts" / script), *arguments],
        check=False,
        capture_output=True,
        text=True,
    )


def write_tsv(path: Path, fields: list[str], rows: list[list[object]]) -> None:
    with path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.writer(stream, delimiter="\t", lineterminator="\n")
        writer.writerow(fields)
        writer.writerows(rows)


class HarnessSourceTests(unittest.TestCase):
    def test_elf64_to_m1_signs_at_its_declared_linkedit_boundary(self) -> None:
        expression = (
            ROOT / "nix" / "mescc-tools" / "elf64-to-m1.nix"
        ).read_text(encoding="utf-8")
        self.assertIn('linkeditOffset="$((0x1000000))"', expression)
        self.assertIn('truncate -s "$linkeditOffset" elf64-to-m1', expression)
        self.assertIn("source ${darwin.signingUtils}", expression)
        self.assertIn("sign elf64-to-m1", expression)
        self.assertNotIn("0x800000 + 0x2000000", expression)

    def test_early_stage0_execution_tools_are_signed_without_padding_gap(self) -> None:
        for relative_path in (
            "stage0-posix/hex1.nix",
            "stage0-posix/hex2.nix",
            "stage0-posix/catm.nix",
            "stage0-posix/m0.nix",
            "stage0-posix/cc-arch.nix",
            "mescc-tools/macho-patcher-early.nix",
            "mescc-tools/macho-patcher.nix",
        ):
            expression = (ROOT / "nix" / relative_path).read_text(encoding="utf-8")
            self.assertIn("source ${darwin.signingUtils}", expression)
            self.assertRegex(expression, r"(?m)^\s+sign \S+")
        for patcher_name in ("macho-patcher-early.nix", "macho-patcher.nix"):
            patcher = (
                ROOT / "nix" / "mescc-tools" / patcher_name
            ).read_text(encoding="utf-8")
            self.assertIn('linkeditOffset="$((0x1000000))"', patcher)
            self.assertIn('truncate -s "$linkeditOffset" macho-patcher', patcher)
            self.assertNotIn("0x2800000 - 1", patcher)

    def test_gcc46_all_gcc_normalizes_unsigned_build_tool_execution(self) -> None:
        expression = (
            ROOT / "nix" / "gcc-4.6" / "all-gcc.nix"
        ).read_text(encoding="utf-8")
        helper = (
            ROOT / "nix" / "scripts" / "darwin" / "prepare-signed-build-tools.sh"
        ).read_text(encoding="utf-8")
        self.assertIn("prepare-signed-build-tools.sh", expression)
        self.assertIn('__impureHostDeps = [ "/usr/bin/codesign" ];', expression)
        self.assertIn('DARWIN_SHARED_BUILD_TOOLS="$(dirname "$(command -v bash)")"', expression)
        self.assertIn('export CONFIG_SHELL="$DARWIN_SHARED_BUILD_TOOLS/bash"', expression)
        self.assertIn(
            'export CC="$DARWIN_SHARED_BUILD_TOOLS/bash $DARWIN_SIGNED_BUILD_TOOLS/tcc-darwin-cc"',
            expression,
        )
        for pinned_tool in (
            "${darwin.sigtool}/bin/sigtool",
        ):
            self.assertIn(pinned_tool, expression)
        self.assertIn(
            "prepare_signed_build_tool ranlib ${cctools}/bin/ranlib",
            expression,
        )
        self.assertIn(
            'export RANLIB="$DARWIN_SIGNED_BUILD_TOOLS/ranlib"',
            expression,
        )
        self.assertNotIn("cctools-ranlib", expression)
        self.assertIn("DARWIN_SIGNED_PREPARE_PATH_TOOLS=0", expression)
        for signed_orchestration_tool in (
            'DARWIN_SIGNED_COPY="$(command -v cp)"',
            'DARWIN_SIGNED_CHMOD="$(command -v chmod)"',
            'DARWIN_SIGNED_MKDIR="$(command -v mkdir)"',
        ):
            self.assertIn(signed_orchestration_tool, expression)
        self.assertNotRegex(expression, r"/bin/(?:cp|chmod|mkdir)\b")
        for requirement in (
            '"$DARWIN_SIGNED_COPY" -L',
            '"$DARWIN_SIGNED_CHMOD" u+w,go-w',
            '"$DARWIN_SIGNED_MKDIR" -p',
            "${DARWIN_SIGNED_PREPARE_PATH_TOOLS:-1}",
            "/usr/bin/codesign --force --sign - --timestamp=none",
            "/usr/bin/codesign --verify --strict",
        ):
            self.assertIn(requirement, helper)

    def test_nix_run_commands_share_signed_orchestration_tools(self) -> None:
        expression = (ROOT / "nix" / "packages.nix").read_text(encoding="utf-8")
        helper = (
            ROOT / "nix" / "scripts" / "darwin" / "prepare-signed-build-tools.sh"
        ).read_text(encoding="utf-8")
        self.assertIn('signedBuildTools = runCommand "darwin-signed-build-tools"', expression)
        self.assertIn('__impureHostDeps = [ "/usr/bin/codesign" ];', expression)
        self.assertIn("runCommand = signedRunCommand;", expression)
        self.assertIn("mkDarwin = signedMkDarwin;", expression)
        self.assertIn('export PATH="${signedBuildTools}/bin:$PATH"', expression)
        for signed_signer in (
            "prepare_signed_build_tool cctools-codesign-allocate",
            "prepare_signed_build_tool tinycc-codesign",
            "prepare_signed_build_tool tinycc-sigtool",
        ):
            self.assertIn(signed_signer, expression)
        self.assertIn("bootstrapDarwin = darwin //", expression)
        self.assertIn('darwin = bootstrapDarwin;', expression)
        self.assertIn(
            'signingUtils = "${signedBuildTools}/share/darwin-bootstrap/signing-utils";',
            expression,
        )
        self.assertIn(
            '${darwin.sigtool}/bin/codesign "$out/bin/tinycc-codesign"',
            expression,
        )
        self.assertIn('"$out/bin/ln" -s tinycc-codesign "$out/bin/codesign"', expression)
        self.assertIn('"$out/bin/ln" -s tinycc-sigtool "$out/bin/sigtool"', expression)
        self.assertIn("sigtool = signedBuildTools;", expression)
        for seed_tool in (
            'DARWIN_SIGNED_COPY="$(command -v cp)"',
            'DARWIN_SIGNED_CHMOD="$(command -v chmod)"',
            'DARWIN_SIGNED_MKDIR="$(command -v mkdir)"',
        ):
            self.assertIn(seed_tool, expression)
        self.assertIn("${DARWIN_SIGNED_BUILD_TOOLS:-", helper)
        for complete_coreutils_requirement in (
            "prepare_signed_coreutils_path_tools()",
            'source_coreutils_bin="${DARWIN_SIGNED_COREUTILS_BIN:-${DARWIN_SIGNED_COPY%/*}}"',
            'for source_tool in "$source_coreutils_bin"/*',
            'test "$source_tool" -ef "$source_coreutils"',
            '"$DARWIN_SIGNED_BUILD_TOOLS/coreutils" --coreutils-prog=ln',
            'prepare_signed_coreutils_path_tools',
        ):
            self.assertIn(complete_coreutils_requirement, helper)
        self.assertIn("bash sh make sed awk gawk grep cmp", helper)
        stages = (ROOT / "scripts" / "nix-bootstrap-stages.txt").read_text(
            encoding="utf-8"
        ).splitlines()
        self.assertIn("darwin-signed-build-tools", stages)

    def test_gcc46_overlay_pins_shared_signed_file_tools(self) -> None:
        script = (
            ROOT / "nix" / "scripts" / "gcc-4.6" / "driver.sh"
        ).read_text(encoding="utf-8")
        wrapper = script.split('cat > "$out/bin/gcc" <<EOF_GCC', 1)[1]
        for tool in ("mktemp", "rm", "ln", "readlink", "mkdir", "cp"):
            self.assertIn(f"wrapper_{tool}=$(command -v {tool})", script)
            self.assertIn(f'"$wrapper_{tool}"', wrapper)
        self.assertNotRegex(
            wrapper,
            r"/(?:usr/)?bin/(?:mktemp|rm|ln|readlink|mkdir|cp)\b",
        )

    def test_gcc_build_scripts_are_explicitly_run_by_signed_bash(self) -> None:
        invocations = {
            "gcc-4.6/libgcc.nix": 'bash ${root + "/scripts/gcc-4.6/libgcc.sh"}',
            "gcc-4.6/bootstrap.nix": 'bash ${root + "/scripts/gcc-4.6/driver.sh"}',
            "gcc-4.6/cxx.nix": 'bash ${root + "/scripts/gcc-4.6/cxx.sh"}',
            "gcc-10/default.nix": 'bash ${root + "/scripts/gcc-modern/bootstrap-gcc.sh"}',
            "gcc-latest/default.nix": 'bash ${root + "/scripts/gcc-modern/bootstrap-gcc.sh"}',
            "gcc-latest/strict.nix": 'bash ${root + "/scripts/gcc-modern/bootstrap-gcc.sh"}',
        }
        for relative_path, invocation in invocations.items():
            expression = (ROOT / "nix" / relative_path).read_text(encoding="utf-8")
            self.assertIn(invocation, expression, relative_path)

    def test_generated_gcc_wrappers_pin_the_signed_bash_store_path(self) -> None:
        libgcc = (
            ROOT / "nix" / "scripts" / "gcc-4.6" / "libgcc.sh"
        ).read_text(encoding="utf-8")
        self.assertIn("wrapper_bash=$(command -v bash)", libgcc)
        self.assertIn('sed -i "1s|.*|#!$wrapper_bash|"', libgcc)

        cxx = (
            ROOT / "nix" / "scripts" / "gcc-4.6" / "cxx.sh"
        ).read_text(encoding="utf-8")
        self.assertIn("#!$(command -v bash)", cxx)
        self.assertIn("printf '#!%s\\n' \"$(command -v bash)\"", cxx)

        modern = (
            ROOT / "nix" / "scripts" / "gcc-modern" / "bootstrap-gcc.sh"
        ).read_text(encoding="utf-8")
        self.assertTrue(modern.startswith("#!/usr/bin/env bash\n"))
        self.assertEqual(modern.count("#!/usr/bin/env bash"), 1)
        self.assertEqual(modern.count("#!$(command -v bash)"), 4)

    def test_generated_tinycc_wrapper_pins_the_signed_bash_store_path(self) -> None:
        expression = (
            ROOT / "nix" / "tinycc" / "darwin-cc.nix"
        ).read_text(encoding="utf-8")
        self.assertIn("wrapper_bash=$(command -v bash)", expression)
        self.assertIn('--replace-fail @SHELL@ "$wrapper_bash"', expression)
        self.assertNotIn("--replace-fail @SHELL@ ${stdenv.shell}", expression)

    def test_gcc46_libgcc_wrapper_excludes_compiled_in_host_headers(self) -> None:
        wrapper = (
            ROOT / "nix" / "scripts" / "gcc-4.6" / "xgcc-wrapper.sh"
        ).read_text(encoding="utf-8")
        common_args = wrapper.split("common_args=(", 1)[1].split(")", 1)[0]
        self.assertIn("-nostdinc", common_args)

        libgcc = (
            ROOT / "nix" / "scripts" / "gcc-4.6" / "libgcc.sh"
        ).read_text(encoding="utf-8")
        self.assertIn(
            "-isystem $tcc/include/tcc-darwin-bootstrap -isystem $PWD/include",
            libgcc,
        )

    def test_gcc46_libstdcxx_probes_exclude_host_include_defaults(self) -> None:
        script = (
            ROOT / "nix" / "scripts" / "gcc-4.6" / "cxx.sh"
        ).read_text(encoding="utf-8")
        configure = script.split("configure_direct_libstdcxx() {", 1)[1].split(
            "build_direct_libstdcxx() {", 1
        )[0]
        for variable in ("CC", "CXX", "CPP", "CXXCPP"):
            assignment = configure.split(f'{variable}="', 1)[1].split('" \\', 1)[0]
            self.assertIn("-nostdinc", assignment, variable)
            self.assertIn("-isystem $target_include", assignment, variable)

    def test_gcc46_cxx_rebases_copied_private_tool_paths(self) -> None:
        script = (
            ROOT / "nix" / "scripts" / "gcc-4.6" / "cxx.sh"
        ).read_text(encoding="utf-8")
        rebase = script.split('DARWIN_REBASE_SRC="$PWD/../src"', 1)[1].split(
            "{} +", 1
        )[0]
        self.assertIn("-name libtool", rebase)
        self.assertIn('*)"\\\\\\n"([A-Za-z0-9._+-]+)}{$1$2}g) { 1; }', rebase)
        self.assertEqual(rebase.count("{}"), 0)
        for tool, replacement in (
            ("cctools-ar", "DARWIN_REBASE_AR"),
            ("cctools-nm", "DARWIN_REBASE_NM"),
            ("ranlib", "DARWIN_REBASE_RANLIB"),
            ("cctools-strip", "DARWIN_REBASE_STRIP"),
            ("cctools-lipo", "DARWIN_REBASE_LIPO"),
            ("cctools-otool", "DARWIN_REBASE_OTOOL"),
            ("tcc-darwin-cc", "DARWIN_REBASE_TCC_CC"),
        ):
            self.assertIn(
                f"/\\.darwin-signed-build-tools/{tool}}}{{$ENV{{{replacement}}}}}g",
                rebase,
            )
        self.assertIn('DARWIN_REBASE_TCC_CC="$tcc/bin/tcc-darwin-cc"', rebase)

    def test_gcc46_provenance_archive_returns_to_work_root(self) -> None:
        script = (
            ROOT / "nix" / "scripts" / "gcc-4.6" / "cxx.sh"
        ).read_text(encoding="utf-8")
        self.assertIn("work_root=$PWD", script)
        archive = script.split(
            'provenance_archive="$bootstrap_share/work-regular-files.tar.gz"',
            1,
        )[1]
        self.assertIn('(\n  cd "$work_root"\n  LC_ALL=C find src/gcc build/gcc', archive)

    def test_gcc46_provenance_parses_grouped_default_object(self) -> None:
        script = ROOT / "scripts" / "collect-gcc46-provenance.py"
        spec = importlib.util.spec_from_file_location("gcc46_provenance", script)
        self.assertIsNotNone(spec)
        self.assertIsNotNone(spec.loader)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as directory:
            consumer = Path(directory)
            share = consumer / "share" / "darwin-bootstrap"
            share.mkdir(parents=True)
            (share / "make.log").write_text(
                "(SHLIB_LINK='dummy'; \\\n"
                "/usr/bin/true -c \\\n"
                "  ../../src/gcc/cp/g++spec.c)\n",
                encoding="utf-8",
            )
            compiled, links, rows = module.compile_and_link_evidence(consumer)
        self.assertIn("g++spec.o", compiled)
        self.assertEqual(links, [])
        self.assertEqual(rows[0]["source_paths"], "../../src/gcc/cp/g++spec.c")

    def test_observed_redline_workers_are_background_noise(self) -> None:
        command = r'''
ps() {
  printf '%s\n' \
    '44.0 /Users/example/Git/redline/target/debug/redline-chain-worker' \
    '3.5 /Users/example/Git/redline/target/debug/redline-indexer' \
    '2.0 /Users/example/Git/redline/target/debug/redline-projector' \
    '1.5 /Users/example/Git/redline/target/debug/redline-analytics-projector' \
    '99.0 /usr/bin/unrelated-workload'
}
source "$1"
benchmark_background_cpu
'''
        result = subprocess.run(
            [
                "/bin/bash",
                "-c",
                command,
                "test",
                str(ROOT / "scripts" / "benchmark-lib.sh"),
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "51.0")

    def test_disk_evidence_pins_macos_df(self) -> None:
        scripts = [
            "benchmark-lib.sh",
            "time-gcc46-reuse-ab.sh",
            "time-nix-e2e.sh",
            "time-shell-e2e.sh",
        ]
        for script in scripts:
            text = (ROOT / "scripts" / script).read_text(encoding="utf-8")
            self.assertIn("/bin/df ", text, script)
            for number, line in enumerate(text.splitlines(), 1):
                self.assertFalse(
                    line.lstrip().startswith("df "),
                    f"{script}:{number} uses PATH-dependent df",
                )

    def test_nix_timings_explicitly_advertise_rosetta_platform(self) -> None:
        for script in ("time-nix-e2e.sh", "time-gcc46-reuse-ab.sh"):
            text = (ROOT / "scripts" / script).read_text(encoding="utf-8")
            self.assertIn(
                'NIX_EXTRA_PLATFORM="${NIX_EXTRA_PLATFORM:-x86_64-darwin}"',
                text,
                script,
            )
            self.assertIn(
                '--option extra-platforms "$NIX_EXTRA_PLATFORM"',
                text,
                script,
            )


class TimingSummaryTests(unittest.TestCase):
    def test_complete_metrics_are_accepted(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fields = ["stage", "exit_code", "elapsed_seconds", "output_bytes"]
            write_tsv(root / "01.tsv", fields, [["compiler", 0, 2.0, 100]])
            write_tsv(root / "02.tsv", fields, [["compiler", 0, 4.0, 100]])
            output = root / "summary.tsv"
            result = run_tool(
                "summarize-timings.py",
                "--input-glob",
                str(root / "*.tsv"),
                "--output",
                str(output),
                "--expected-samples",
                "2",
                "--one-sample-per-input",
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            with output.open(newline="", encoding="utf-8") as stream:
                row = next(csv.DictReader(stream, delimiter="\t"))
            self.assertEqual(row["valid_samples"], "2")
            self.assertEqual(row["median_seconds"], "3.000000000")
            self.assertEqual(row["median_output_bytes"], "100.000000000")

    def test_metric_column_missing_from_one_input_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            write_tsv(
                root / "01.tsv",
                ["stage", "exit_code", "elapsed_seconds", "output_bytes"],
                [["compiler", 0, 2.0, 100]],
            )
            write_tsv(
                root / "02.tsv",
                ["stage", "exit_code", "elapsed_seconds"],
                [["compiler", 0, 4.0]],
            )
            result = run_tool(
                "summarize-timings.py",
                "--input-glob",
                str(root / "*.tsv"),
                "--output",
                str(root / "summary.tsv"),
                "--expected-samples",
                "2",
                "--one-sample-per-input",
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("declared metric output_bytes has 1 samples", result.stderr)


class ProcessSummaryTests(unittest.TestCase):
    fields = [
        "timestamp",
        "pid",
        "ppid",
        "ps_cpu_percent",
        "rss_kib",
        "command",
    ]

    def test_nonempty_inputs_are_accepted(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            write_tsv(
                root / "01.processes.tsv",
                self.fields,
                [["2026-08-09T00:00:00-07:00", 10, 1, 50.0, 1024, "/bin/gcc -c x.c"]],
            )
            output = root / "summary.tsv"
            result = run_tool(
                "summarize-process-snapshots.py",
                "--input-glob",
                str(root / "*.processes.tsv"),
                "--output",
                str(output),
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            with output.open(newline="", encoding="utf-8") as stream:
                row = next(csv.DictReader(stream, delimiter="\t"))
            self.assertEqual(row["process_key"], "gcc")
            self.assertEqual(row["role_hint"], "measured-workload-likely")

    def test_header_only_input_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            write_tsv(root / "01.processes.tsv", self.fields, [])
            write_tsv(
                root / "02.processes.tsv",
                self.fields,
                [["2026-08-09T00:00:00-07:00", 10, 1, 50.0, 1024, "/bin/gcc -c x.c"]],
            )
            result = run_tool(
                "summarize-process-snapshots.py",
                "--input-glob",
                str(root / "*.processes.tsv"),
                "--output",
                str(root / "summary.tsv"),
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("process snapshot input is empty", result.stderr)

    def test_background_roles_preserve_fsevents_for_review(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            write_tsv(
                root / "01.processes.tsv",
                self.fields,
                [
                    ["2026-08-09T00:00:00-07:00", 10, 1, 10.0, 1024, "/usr/libexec/fseventsd"],
                    [
                        "2026-08-09T00:00:00-07:00",
                        11,
                        1,
                        20.0,
                        2048,
                        "/Applications/Docker.app/Contents/MacOS/com.docker.backend services",
                    ],
                    [
                        "2026-08-09T00:00:00-07:00",
                        12,
                        1,
                        30.0,
                        4096,
                        "/usr/bin/python3 /opt/borgbackup/bin/borg create archive",
                    ],
                    [
                        "2026-08-09T00:00:00-07:00",
                        13,
                        1,
                        40.0,
                        8192,
                        "/Users/example/redline-chain-worker",
                    ],
                ],
            )
            output = root / "summary.tsv"
            result = run_tool(
                "summarize-process-snapshots.py",
                "--input-glob",
                str(root / "*.processes.tsv"),
                "--output",
                str(output),
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            with output.open(newline="", encoding="utf-8") as stream:
                rows = {
                    row["process_key"]: row["role_hint"]
                    for row in csv.DictReader(stream, delimiter="\t")
                }
            self.assertEqual(rows["fseventsd"], "unclassified-review-required")
            self.assertEqual(
                rows["com.docker.backend"],
                "known-background-rejection-class",
            )
            self.assertEqual(rows["python3"], "known-background-rejection-class")
            self.assertEqual(
                rows["redline-chain-worker"],
                "known-background-rejection-class",
            )


class SystemStateSummaryTests(unittest.TestCase):
    def test_disk_vm_swap_and_pressure_deltas(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            profile = root / "nix-e2e"
            profile.mkdir()
            disk_header = (
                "Filesystem 1024-blocks Used Available Capacity iused ifree "
                "%iused Mounted on\n"
            )
            (profile / "sample.disk-before.txt").write_text(
                disk_header + "/dev/disk 1000 400 600 40% 1 2 0% /nix\n",
                encoding="utf-8",
            )
            (profile / "sample.disk-after.txt").write_text(
                disk_header + "/dev/disk 1000 450 550 45% 1 2 0% /nix\n",
                encoding="utf-8",
            )
            before_memory = """2026-08-09T00:00:00-07:00
Mach Virtual Memory Statistics: (page size of 16384 bytes)
Pages free: 100.
Pages active: 200.
Pageins: 5.
vm.swapusage: total = 2.00G used = 512.00M free = 1.50G
System-wide memory free percentage: 25%
"""
            after_memory = """2026-08-09T00:01:00-07:00
Mach Virtual Memory Statistics: (page size of 16384 bytes)
Pages free: 90.
Pages active: 210.
Pageins: 7.
vm.swapusage: total = 2.00G used = 576.00M free = 1.44G
System-wide memory free percentage: 20%
"""
            (profile / "sample.memory-before.txt").write_text(
                before_memory, encoding="utf-8"
            )
            (profile / "sample.memory-after.txt").write_text(
                after_memory, encoding="utf-8"
            )
            output = root / "system-state.tsv"
            result = run_tool(
                "summarize-system-state.py",
                "--root",
                str(root),
                "--output",
                str(output),
                "--summary-output",
                str(root / "system-state-summary.tsv"),
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            with output.open(newline="", encoding="utf-8") as stream:
                rows = {
                    row["metric"]: float(row["delta"])
                    for row in csv.DictReader(stream, delimiter="\t")
                }
            self.assertEqual(rows["filesystem_available_bytes"], -50 * 1024)
            self.assertEqual(rows["vm_pages_free_bytes"], -10 * 16384)
            self.assertEqual(rows["vm_pageins"], 2)
            self.assertEqual(rows["swap_used_bytes"], 64 * 1024**2)
            self.assertEqual(rows["memory_free_percent"], -5)


class PairedSummaryTests(unittest.TestCase):
    fields = ["pair", "order", "stage", "exit_code", "elapsed_seconds"]

    def test_balanced_complete_pairs_are_accepted(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            samples = root / "samples.tsv"
            write_tsv(
                samples,
                self.fields,
                [
                    [1, 1, "reuse", 0, 10.0],
                    [1, 2, "no-reuse", 0, 20.0],
                    [2, 1, "no-reuse", 0, 18.0],
                    [2, 2, "reuse", 0, 12.0],
                ],
            )
            summary = root / "summary.tsv"
            result = run_tool(
                "summarize-ab.py",
                "--input",
                str(samples),
                "--pairs-output",
                str(root / "pairs.tsv"),
                "--summary-output",
                str(summary),
                "--expected-pairs",
                "2",
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            with summary.open(newline="", encoding="utf-8") as stream:
                row = next(csv.DictReader(stream, delimiter="\t"))
            self.assertEqual(row["accepted_pairs"], "2")
            self.assertEqual(row["reuse_first_pairs"], "1")
            self.assertEqual(row["no_reuse_first_pairs"], "1")
            self.assertEqual(row["positive_pairs_reuse_faster"], "2")
            self.assertEqual(row["two_sided_exact_sign_test_p"], "0.500000000")

    def test_noncontiguous_pair_ids_are_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            samples = root / "samples.tsv"
            write_tsv(
                samples,
                self.fields,
                [
                    [1, 1, "reuse", 0, 10.0],
                    [1, 2, "no-reuse", 0, 20.0],
                    [3, 1, "no-reuse", 0, 18.0],
                    [3, 2, "reuse", 0, 12.0],
                ],
            )
            result = run_tool(
                "summarize-ab.py",
                "--input",
                str(samples),
                "--pairs-output",
                str(root / "pairs.tsv"),
                "--summary-output",
                str(root / "summary.tsv"),
                "--expected-pairs",
                "2",
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("accepted pair ids are [1, 3]", result.stderr)


if __name__ == "__main__":
    unittest.main()
