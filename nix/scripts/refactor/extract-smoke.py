#!/usr/bin/env python3
"""Extract smoke-test stanzas from .nix buildPhase blocks into
proper checkPhase attributes.  Cuts everything between the last
`sign <binary>` line and `runHook postBuild`, moves it to a new
checkPhase."""
import re
import sys
from pathlib import Path

def transform(path: Path) -> bool:
    text = path.read_text()
    original = text

    lines = text.splitlines(keepends=True)

    # Find the buildPhase = '' line
    build_start = None
    for i, line in enumerate(lines):
        if re.search(r"buildPhase\s*=\s*''", line):
            build_start = i
            break
    if build_start is None:
        return False

    # Find the closing '' line of buildPhase
    build_end = None
    for j in range(build_start + 1, len(lines)):
        stripped = lines[j].lstrip()
        if stripped.startswith("''"):
            build_end = j
            break
    if build_end is None:
        return False

    # Within build_start+1..build_end-1, find the LAST `sign ` line and
    # the `runHook postBuild` after it.
    sign_idx = None
    post_idx = None
    for k in range(build_start + 1, build_end):
        if re.match(r"^\s*sign\s+\S+\s*$", lines[k]):
            sign_idx = k
    if sign_idx is None:
        return False
    for k in range(sign_idx + 1, build_end):
        if re.match(r"^\s*runHook postBuild\s*$", lines[k]):
            post_idx = k
            break
    if post_idx is None:
        return False

    # Smoke = lines between (sign_idx, post_idx), excluding blank-only
    # lines at start/end
    smoke_lines = lines[sign_idx + 1 : post_idx]
    # Trim leading blank lines
    while smoke_lines and not smoke_lines[0].strip():
        smoke_lines.pop(0)
    # Trim trailing blank lines
    while smoke_lines and not smoke_lines[-1].strip():
        smoke_lines.pop()
    if not smoke_lines:
        return False

    # Indent inside the buildPhase '' block — take from sign line
    indent = re.match(r"^(\s*)", lines[sign_idx]).group(1)

    # Construct new buildPhase: drop smoke, keep blank+postBuild
    new_build_section = (
        lines[: sign_idx + 1]
        + [f"\n{lines[post_idx]}"]   # blank line + postBuild
        + lines[build_end :]
    )

    # Find where the buildPhase ''; ends and insert checkPhase right after
    # Walk new_build_section to find the line with closing '' for buildPhase
    rebuilt = "".join(new_build_section)

    # Find the position right after the closing `''` of buildPhase
    # The `''` is `lines[build_end]` originally — preserved.
    # Insert checkPhase block immediately after.

    # Build the checkPhase block with the same outer indent as buildPhase
    outer_indent = re.match(r"^(\s*)", lines[build_start]).group(1)
    smoke_text = "".join(smoke_lines)

    check_block = (
        f"\n{outer_indent}doCheck = true;\n"
        f"{outer_indent}checkPhase = ''\n"
        f"{indent}runHook preCheck\n"
        f"{smoke_text}"
        f"{indent}runHook postCheck\n"
        f"{outer_indent}'';\n"
    )

    # Find buildPhase end in rebuilt and insert after
    # The `'';` line is roughly at new index (build_end - (post_idx - sign_idx - 1))
    # Easier: rebuild from rebuilt as a string
    pattern = re.compile(r"(buildPhase\s*=\s*''.*?\n\s*'';\n)", re.DOTALL)
    m = pattern.search(rebuilt)
    if not m:
        return False

    new_text = rebuilt[:m.end()] + check_block + rebuilt[m.end():]

    if new_text == original:
        return False
    path.write_text(new_text)
    return True

if __name__ == '__main__':
    changed = 0
    for arg in sys.argv[1:]:
        if transform(Path(arg)):
            print(f'  rewrote {arg}')
            changed += 1
    print(f'{changed} files rewritten')
