#!/usr/bin/env python3
"""Strip the `if hostPlatform.isx86_64 then ... else null` wrapper from
Darwin-bootstrap .nix files that only support x86_64.  Preserves the
rest of the file verbatim, dedenting the body by the minimum indent of
the wrapped block."""
import re
import sys
from pathlib import Path

def transform(path: Path) -> bool:
    text = path.read_text()
    lines = text.splitlines(keepends=True)

    # Find the wrapper
    if_idx = None
    for i, line in enumerate(lines):
        if re.match(r'^\s*if hostPlatform\.isx86_64 then\s*$', line):
            if_idx = i
            break
    if if_idx is None:
        return False

    # Find the matching `else` at top level (same indent as `if`)
    if_indent = len(lines[if_idx]) - len(lines[if_idx].lstrip())
    else_idx = None
    null_idx = None
    for j in range(if_idx + 1, len(lines)):
        line = lines[j]
        if not line.strip():
            continue
        indent = len(line) - len(line.lstrip())
        if indent == if_indent and line.strip() == 'else':
            else_idx = j
            # Find the `null` line after `else`
            for k in range(j + 1, len(lines)):
                if lines[k].strip() == 'null':
                    null_idx = k
                    break
            break

    if else_idx is None or null_idx is None:
        return False

    # Body is between if_idx+1 and else_idx-1 (inclusive, skipping trailing blank lines).
    body = lines[if_idx + 1 : else_idx]
    # Compute common indent of body (ignore blank lines).
    body_indents = [
        len(l) - len(l.lstrip())
        for l in body
        if l.strip()
    ]
    min_indent = min(body_indents) if body_indents else 0

    # Strip min_indent spaces from each body line.
    new_body = []
    for line in body:
        if line.strip():
            new_body.append(line[min_indent:])
        else:
            new_body.append(line)

    new_lines = lines[:if_idx] + new_body
    # Drop any trailing blank lines coming from where `else null` was.
    while new_lines and not new_lines[-1].strip():
        new_lines.pop()
    if new_lines and not new_lines[-1].endswith('\n'):
        new_lines[-1] += '\n'

    new_text = ''.join(new_lines)
    path.write_text(new_text)
    return True

if __name__ == '__main__':
    changed = 0
    for arg in sys.argv[1:]:
        p = Path(arg)
        if transform(p):
            print(f'  rewrote {p}')
            changed += 1
        else:
            print(f'  skipped {p} (no wrapper found)')
    print(f'{changed} files rewritten')
