#!/usr/bin/env python3
"""Compare retained GCC 4.6 producer and consumer build-tree artifacts."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import re
import shlex
import shutil
import stat
import tarfile
from collections import Counter
from pathlib import Path
from typing import BinaryIO, Callable


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--producer", type=Path, required=True)
    parser.add_argument("--consumer", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    return parser.parse_args()


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def magic_prefix(prefix: bytes) -> str:
    if prefix.startswith(b"\x7fELF"):
        return "ELF"
    if prefix[:4] in {b"\xcf\xfa\xed\xfe", b"\xfe\xed\xfa\xcf"}:
        return "Mach-O-64"
    if prefix.startswith(b"!<arch>\n"):
        return "archive"
    if prefix.startswith(b"#!"):
        return "script"
    return "other"


def magic(path: Path) -> str:
    with path.open("rb") as stream:
        return magic_prefix(stream.read(8))


def classify(
    relative: Path, source_exists: Callable[[Path], bool]
) -> str | None:
    text = relative.as_posix()
    suffix = relative.suffix
    name = relative.name
    if text.startswith("build/") and suffix == ".o":
        return "generator-object"
    if text.startswith("build/gen") and suffix not in {".c", ".h", ".o"}:
        return "generator-executable"
    if suffix == ".o":
        if text.startswith("cp/"):
            return "cxx-frontend-object"
        if text.startswith("c-family/"):
            return "c-family-object"
        return "backend-object"
    if suffix == ".a":
        return "backend-archive"
    if text.startswith(("include/", "include-fixed/")) and suffix == ".h":
        return "staged-compiler-header"
    if (
        name in {
            "gengtype-lex.c", "gtype-desc.c", "gtype-desc.h",
            "min-insn-modes.c", "options.c", "options.h",
        }
        or name.startswith(("gtype-", "gt-", "insn-"))
    ):
        return "generated-source-or-header"
    if suffix in {".c", ".h", ".inc"} and not source_exists(relative):
        return "generated-source-or-header"
    if text.startswith("build/gen") or name.startswith(("insn-", "gt-")):
        return "generated-artifact"
    return None


def inventory_directory(root: Path) -> dict[str, dict[str, object]]:
    build_root = root / "share/darwin-bootstrap/work/build/gcc"
    source_root = root / "share/darwin-bootstrap/work/src/gcc"
    if not build_root.is_dir() or not source_root.is_dir():
        raise SystemExit(f"incomplete retained GCC tree under {root}")
    result: dict[str, dict[str, object]] = {}
    for directory, names, files in os.walk(build_root):
        names.sort()
        files.sort()
        base = Path(directory)
        for name in files:
            path = base / name
            relative = path.relative_to(build_root)
            artifact_class = classify(
                relative, lambda item: (source_root / item).exists()
            )
            if artifact_class is None:
                continue
            if path.is_symlink() and artifact_class in {
                "generated-source-or-header", "staged-compiler-header"
            }:
                continue
            link_target = os.readlink(path) if path.is_symlink() else ""
            resolved = path.resolve(strict=False)
            target_exists = resolved.is_file()
            details: dict[str, object] = {
                "class": artifact_class,
                "path": relative.as_posix(),
                "kind": "symlink" if path.is_symlink() else "file",
                "link_target": link_target,
                "bytes": resolved.stat().st_size if target_exists else 0,
                "mode": f"{stat.S_IMODE(path.lstat().st_mode):04o}",
                "magic": magic(resolved) if target_exists else "dangling-symlink",
                "sha256": sha256(resolved) if target_exists else "",
            }
            result[relative.as_posix()] = details
    return result


def hash_archive_member(stream: BinaryIO) -> tuple[str, bytes]:
    digest = hashlib.sha256()
    prefix = stream.read(8)
    digest.update(prefix)
    for chunk in iter(lambda: stream.read(1024 * 1024), b""):
        digest.update(chunk)
    return digest.hexdigest(), prefix


def inventory_archive(root: Path, archive: Path) -> dict[str, dict[str, object]]:
    result: dict[str, dict[str, object]] = {}
    with tarfile.open(archive, mode="r:gz") as bundle:
        members = bundle.getmembers()
        source_prefix = "src/gcc/"
        build_prefix = "build/gcc/"
        source_paths = {
            member.name.removeprefix(source_prefix)
            for member in members
            if member.isfile() and member.name.startswith(source_prefix)
        }
        build_members = [
            member
            for member in members
            if member.isfile() and member.name.startswith(build_prefix)
        ]
        if not source_paths or not build_members:
            raise SystemExit(f"incomplete retained GCC archive under {root}")
        for member in sorted(build_members, key=lambda item: item.name):
            relative = Path(member.name.removeprefix(build_prefix))
            artifact_class = classify(
                relative, lambda item: item.as_posix() in source_paths
            )
            if artifact_class is None:
                continue
            stream = bundle.extractfile(member)
            if stream is None:
                raise SystemExit(f"cannot read {member.name} from {archive}")
            digest, prefix = hash_archive_member(stream)
            result[relative.as_posix()] = {
                "class": artifact_class,
                "path": relative.as_posix(),
                "kind": "archived-file",
                "link_target": "",
                "bytes": member.size,
                "mode": f"{member.mode:04o}",
                "magic": magic_prefix(prefix),
                "sha256": digest,
            }
    return result


def inventory(root: Path) -> dict[str, dict[str, object]]:
    build_root = root / "share/darwin-bootstrap/work/build/gcc"
    archive = root / "share/darwin-bootstrap/work-regular-files.tar.gz"
    if build_root.is_dir():
        return inventory_directory(root)
    if archive.is_file():
        return inventory_archive(root, archive)
    raise SystemExit(f"incomplete retained GCC tree or archive under {root}")


def logical_commands(log: Path) -> list[str]:
    commands: list[str] = []
    pending = ""
    for raw in log.read_text(encoding="utf-8", errors="replace").splitlines():
        stripped = raw.strip()
        if not stripped:
            continue
        pending = f"{pending} {stripped}".strip()
        if pending.endswith("\\"):
            pending = pending[:-1].rstrip()
            continue
        commands.append(pending)
        pending = ""
    if pending:
        commands.append(pending)
    return commands


def compile_and_link_evidence(
    consumer: Path,
) -> tuple[set[str], list[str], list[dict[str, object]]]:
    log = consumer / "share/darwin-bootstrap/make.log"
    if not log.is_file():
        raise SystemExit(f"missing consumer make log: {log}")
    compiled: set[str] = set()
    links: list[str] = []
    compile_rows: list[dict[str, object]] = []
    for command in logical_commands(log):
        try:
            words = shlex.split(command)
        except ValueError:
            words = command.split()
        if "-c" in words:
            outputs: list[tuple[str, bool]] = []
            for index, word in enumerate(words[:-1]):
                output_word = words[index + 1].rstrip(");")
                if word == "-o" and output_word.endswith(".o"):
                    outputs.append((output_word.removeprefix("gcc/"), False))
            # GCC 4.6 has grouped recipes such as `(SHLIB_LINK=...; gcc -c
            # cp/g++spec.c)`.  shlex correctly preserves the closing shell
            # parenthesis on the last word, so remove only grouping punctuation
            # before testing the source suffix and inferring GCC's default .o.
            sources = []
            for word in words:
                source_word = word.rstrip(");")
                if Path(source_word).suffix in {".c", ".cc", ".cpp", ".C"}:
                    sources.append(source_word)
            if not outputs:
                if len(sources) == 1:
                    outputs.append((f"{Path(sources[0]).stem}.o", True))
            compiler = next(
                (
                    Path(word) for word in words
                    if Path(word).is_file() and os.access(Path(word), os.X_OK)
                ),
                Path(),
            )
            compiler_hash = sha256(compiler.resolve()) if compiler.is_file() else ""
            for output_path, inferred in outputs:
                compiled.add(output_path)
                compile_rows.append({
                    "output_path": output_path,
                    "output_inferred": int(inferred),
                    "source_paths": ",".join(sources),
                    "compiler_path": str(compiler),
                    "compiler_sha256": compiler_hash,
                    "argv": command,
                })
        if "-o" in words:
            for index, word in enumerate(words[:-1]):
                if word == "-o" and Path(words[index + 1]).name == "cc1plus":
                    links.append(command)
    return compiled, links, compile_rows


def retained_evidence(root: Path) -> list[dict[str, object]]:
    share = root / "share/darwin-bootstrap"
    rows: list[dict[str, object]] = []
    for path in sorted(share.iterdir()):
        if path.is_file() and not path.is_symlink():
            rows.append({
                "path": path.name,
                "bytes": path.stat().st_size,
                "sha256": sha256(path),
            })
    return rows


def compiler_components(compile_rows: list[dict[str, object]]) -> list[dict[str, str]]:
    components: dict[str, dict[str, str]] = {}

    def add(role: str, path: Path) -> None:
        if not path.is_file():
            return
        resolved = path.resolve()
        key = str(resolved)
        components.setdefault(key, {
            "role": role,
            "path": key,
            "magic": magic(resolved),
            "sha256": sha256(resolved),
        })

    for wrapper_text in sorted({str(row["compiler_path"]) for row in compile_rows}):
        wrapper = Path(wrapper_text)
        add("compiler-wrapper", wrapper)
        if not wrapper.is_file() or magic(wrapper) != "script":
            continue
        contents = wrapper.read_text(encoding="utf-8", errors="replace")
        references = re.findall(r"/nix/store/[A-Za-z0-9._+/-]+", contents)
        for reference in references:
            referenced = Path(reference.rstrip(".,:;)"))
            add("wrapper-referenced-file", referenced)
            if referenced.name == "xgcc" and referenced.parent.is_dir():
                for sibling in sorted(referenced.parent.iterdir()):
                    if sibling.is_file():
                        add("compiler-executable-sibling", sibling)
    return [components[path] for path in sorted(components)]


def write_manifest(output: Path, inventories: dict[str, dict[str, dict[str, object]]]) -> None:
    fields = ["side", "class", "path", "kind", "link_target", "bytes", "mode", "magic", "sha256"]
    with output.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        for side, inventory in inventories.items():
            for path in sorted(inventory):
                writer.writerow({"side": side, **inventory[path]})


def main() -> None:
    args = arguments()
    inventories = {
        "producer": inventory(args.producer),
        "consumer": inventory(args.consumer),
    }
    compiled, link_commands, compile_rows = compile_and_link_evidence(args.consumer)
    retained = {
        "producer": retained_evidence(args.producer),
        "consumer": retained_evidence(args.consumer),
    }
    components = compiler_components(compile_rows)
    args.output.mkdir(parents=True, exist_ok=False)
    collector_copy = args.output / "collect-gcc46-provenance.py"
    shutil.copy2(Path(__file__), collector_copy)
    (args.output / "METHODOLOGY.txt").write_text(
        "This bundle inventories finalized retained producer and consumer trees; "
        "it must not be collected from a mutating build.\n"
        "A retained tree may be stored directly or as the normalized regular-file "
        "archive emitted by gcc46-cxx; archived bytes are hashed without extraction.\n"
        "Consumer compile argv records are parsed from the retained Make log. "
        "output_inferred=1 means the normal source-basename .o rule supplied a "
        "path omitted from argv.\n"
        "Compiler-component hashes cover the observed wrapper and directly "
        "referenced executable files, including xgcc/cc1 siblings.\n"
        "Same hashes for retained generator inputs disclose reuse; different "
        "hashes plus compile argv support, but do not alone prove, execution of "
        "every rebuild command.\n"
        "This is not an authorization manifest for backend-object reuse: it does "
        "not retain each preprocessed translation unit or the complete dependency "
        "and header closure. Reuse must remain opt-in until those inputs and the "
        "producer/consumer configuration match exactly.\n",
        encoding="utf-8",
    )
    write_manifest(args.output / "artifacts.tsv", inventories)
    with (args.output / "compile-commands.tsv").open(
        "w", newline="", encoding="utf-8"
    ) as stream:
        fields = [
            "output_path", "output_inferred", "source_paths",
            "compiler_path", "compiler_sha256", "argv",
        ]
        writer = csv.DictWriter(
            stream, fieldnames=fields, delimiter="\t", lineterminator="\n"
        )
        writer.writeheader()
        writer.writerows(compile_rows)
    with (args.output / "retained-evidence.tsv").open(
        "w", newline="", encoding="utf-8"
    ) as stream:
        fields = ["side", "path", "bytes", "sha256"]
        writer = csv.DictWriter(
            stream, fieldnames=fields, delimiter="\t", lineterminator="\n"
        )
        writer.writeheader()
        for side, rows in retained.items():
            for row in rows:
                writer.writerow({"side": side, **row})
    with (args.output / "compiler-components.tsv").open(
        "w", newline="", encoding="utf-8"
    ) as stream:
        fields = ["role", "path", "magic", "sha256"]
        writer = csv.DictWriter(
            stream, fieldnames=fields, delimiter="\t", lineterminator="\n"
        )
        writer.writeheader()
        writer.writerows(components)

    producer = inventories["producer"]
    consumer = inventories["consumer"]
    comparison_rows: list[dict[str, object]] = []
    comparison_counts: Counter[str] = Counter()
    for path in sorted(set(producer) | set(consumer)):
        before = producer.get(path)
        after = consumer.get(path)
        if before is None:
            status = "consumer-only"
        elif after is None:
            status = "producer-only"
        elif before["sha256"] == after["sha256"]:
            status = "same-hash"
        else:
            status = "different-hash"
        artifact_class = str((after or before)["class"])
        comparison_counts[f"{artifact_class}:{status}"] += 1
        comparison_rows.append({
            "class": artifact_class,
            "path": path,
            "status": status,
            "producer_magic": "" if before is None else before["magic"],
            "consumer_magic": "" if after is None else after["magic"],
            "producer_sha256": "" if before is None else before["sha256"],
            "consumer_sha256": "" if after is None else after["sha256"],
        })
    with (args.output / "comparison.tsv").open("w", newline="", encoding="utf-8") as stream:
        fields = list(comparison_rows[0])
        writer = csv.DictWriter(stream, fieldnames=fields, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(comparison_rows)

    consumer_objects = {
        path for path, item in consumer.items()
        if str(item["class"]).endswith("object") and item["class"] != "generator-object"
    }
    compiled_consumer_objects = sorted(consumer_objects & compiled)
    unlogged_consumer_objects = sorted(consumer_objects - compiled)
    (args.output / "compiled-object-paths.txt").write_text(
        "".join(f"{path}\n" for path in sorted(compiled)), encoding="utf-8"
    )
    (args.output / "unlogged-consumer-objects.txt").write_text(
        "".join(f"{path}\n" for path in unlogged_consumer_objects), encoding="utf-8"
    )
    (args.output / "cc1plus-link-commands.txt").write_text(
        "\n".join(link_commands) + ("\n" if link_commands else ""), encoding="utf-8"
    )

    reused_marker = args.consumer / "share/darwin-bootstrap/reused-all-gcc-object-count"
    summary = {
        "collector_sha256": sha256(collector_copy),
        "producer": str(args.producer),
        "consumer": str(args.consumer),
        "producer_counts": Counter(str(item["class"]) for item in producer.values()),
        "consumer_counts": Counter(str(item["class"]) for item in consumer.values()),
        "comparison_counts": dict(sorted(comparison_counts.items())),
        "logged_compile_output_count": len(compiled),
        "logged_compile_command_count": len(compile_rows),
        "compiler_component_count": len(components),
        "consumer_non_generator_object_count": len(consumer_objects),
        "consumer_non_generator_objects_in_compile_log": len(compiled_consumer_objects),
        "consumer_non_generator_objects_not_in_compile_log": len(unlogged_consumer_objects),
        "cc1plus_link_command_count": len(link_commands),
        "cc1plus_link_mentions_generator_object": any(
            re.search(r"(?:^|\s)(?:gcc/)?build/[^\s]+\.o(?:\s|$)", command)
            for command in link_commands
        ),
        "reuse_marker_exists": reused_marker.exists(),
        "reuse_marker_value": reused_marker.read_text().strip() if reused_marker.exists() else "",
    }
    with (args.output / "summary.json").open("w", encoding="utf-8") as stream:
        json.dump(summary, stream, indent=2, sort_keys=True)
        stream.write("\n")


if __name__ == "__main__":
    main()
