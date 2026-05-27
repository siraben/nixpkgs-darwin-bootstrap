#!/usr/bin/env python3
"""Extract `cat > NAME <<'EOF' ... EOF` heredoc fixtures from Darwin
bootstrap .nix files into actual checked-in files under
   <package-dir>/fixtures/<.nix-stem>-<target-name>
and rewrite the buildPhase / checkPhase to
   cp ${root + "/<package-dir>/fixtures/<stem>-<target>"} <target>
or
   install -Dm644 ${root + "/.../<dst>"} <dst>
as appropriate.
"""
import re
import sys
from pathlib import Path

# Heredoc cat pattern: handles single-quoted, double-quoted, and unquoted markers.
HEREDOC = re.compile(
    r"(?P<indent>[ \t]*)cat > (?P<target>\$?[\w\$/.-]+) <<'?(?P<marker>\w+)'?\s*\n"
    r"(?P<body>.*?)\n"
    r"(?P=indent)(?P=marker)\s*$",
    re.MULTILINE | re.DOTALL,
)


def transform(path: Path, repo_root: Path) -> int:
    text = path.read_text()
    orig = text
    stem = path.stem
    fixtures_dir = path.parent / "fixtures"
    rel_fixtures_dir = fixtures_dir.relative_to(repo_root)

    matches = list(HEREDOC.finditer(text))
    if not matches:
        return 0

    # Apply in reverse so offsets remain valid.
    n = 0
    for m in reversed(matches):
        target = m.group("target")
        body = m.group("body")
        indent = m.group("indent")

        # Skip targets that interpolate shell vars or $out paths — they
        # produce files at runtime locations and aren't simple fixtures.
        if target.startswith("$") or "/" in target:
            continue

        # Strip uniform leading whitespace (matches the heredoc indent)
        body_lines = body.split("\n")
        if body_lines:
            common_indent = len(body_lines[0]) - len(body_lines[0].lstrip())
            stripped = "\n".join(
                line[common_indent:] if line.strip() else line
                for line in body_lines
            )
        else:
            stripped = body
        if not stripped.endswith("\n"):
            stripped += "\n"

        fixtures_dir.mkdir(exist_ok=True)
        fixture_name = f"{stem}-{target}"
        fixture_path = fixtures_dir / fixture_name
        fixture_path.write_text(stripped)

        # Build replacement line
        rel_for_nix = f"/{rel_fixtures_dir}/{fixture_name}"
        replacement = (
            f'{indent}cp ${{root + "{rel_for_nix}"}} {target}'
        )

        text = text[:m.start()] + replacement + text[m.end():]
        n += 1

    if text != orig:
        path.write_text(text)
    return n


if __name__ == "__main__":
    repo_root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    total = 0
    for nix in sorted(repo_root.rglob("*.nix")):
        # Skip the orchestrator, utils, tests
        if nix.name in ("packages.nix", "utils.nix", "flake.nix", "default.nix") and nix.parent == repo_root:
            continue
        # Skip 3rd-party / vendored
        rel = nix.relative_to(repo_root)
        if rel.parts[0] in (".git", "result", "vendor", "stage0-posix") and rel.parts[0] != "stage0-posix":
            continue
        if rel.parts[0] == "stage0-posix" and nix.name in ("phase-graph.nix", "platforms.nix", "mescc-tools-boot.nix"):
            continue
        n = transform(nix, repo_root)
        if n:
            print(f"  {rel}: extracted {n} fixture(s)")
            total += n
    print(f"\n{total} heredocs extracted to per-package fixtures/ dirs")
