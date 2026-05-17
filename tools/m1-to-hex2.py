#!/usr/bin/env python3
import argparse


def translate_token(token):
    if token.startswith("!0x") and len(token) == 5:
        return token[3:].upper()
    return token


def parse_int(value):
    return int(value, 0)


def parse_align_label(values):
    labels = {}
    for value in values or []:
        if "=" not in value:
            raise SystemExit(f"invalid --align-label value: {value}")
        label, address = value.split("=", 1)
        labels[label] = parse_int(address)
    return labels


def write_padding(output, state, target):
    if state["address"] > target:
        raise SystemExit(
            f"label alignment target 0x{target:x} is before current address 0x{state['address']:x}"
        )
    line = []
    while state["address"] < target:
        line.append("00")
        state["address"] += 1
        if len(line) == 16:
            output.write(" ".join(line))
            output.write("\n")
            line = []
    if line:
        output.write(" ".join(line))
        output.write("\n")


def translated_width(token):
    if token.startswith("%") or token.startswith("&"):
        return 4
    if token.startswith(":"):
        return 0
    return 1


def translate_file(path, output, state, align_labels):
    with path.open("r", encoding="utf-8", errors="replace") as source:
        for line in source:
            stripped = line.strip()
            if not stripped:
                output.write("\n")
                continue
            tokens = []
            for token in stripped.split():
                if token.startswith(":"):
                    label = token[1:]
                    if label in align_labels:
                        write_padding(output, state, align_labels[label])
                translated = translate_token(token)
                tokens.append(translated)
                state["address"] += translated_width(translated)
            output.write(" ".join(tokens))
            output.write("\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--architecture", default="amd64")
    parser.add_argument("--little-endian", action="store_true")
    parser.add_argument("--big-endian", action="store_true")
    parser.add_argument("--base-address", type=parse_int, default=0)
    parser.add_argument("--align-label", action="append")
    parser.add_argument("-f", "--file", dest="files", action="append", required=True)
    parser.add_argument("-o", "--output", required=True)
    args = parser.parse_args()
    align_labels = parse_align_label(args.align_label)
    state = {"address": args.base_address}

    with open(args.output, "w", encoding="utf-8") as output:
        for filename in args.files:
            translate_file(pathlib.Path(filename), output, state, align_labels)


if __name__ == "__main__":
    import pathlib

    main()
