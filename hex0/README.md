# Darwin hex0 seed

`hex0-amd64-darwin.hex0` is the committed x86_64 Darwin seed binary as
hexadecimal bytes plus comments.  It follows the stage0/live-bootstrap model:
the trusted seed is small, auditable bytes; the next stage (`hex1`) is built by
running those bytes as a real program.

The seed accepts `hex0 INPUT OUTPUT`, ignores whitespace and `#`/`;` comments,
and writes bytes from pairs of hexadecimal nybbles.  It is self-host checked by
assembling `hex0-amd64-darwin.hex0` with the resulting `hex0` and comparing the
bytes.

`hex0-amd64-darwin.S` is only an audit aid for the instruction bytes in the
hex source.  The bootstrap package does not assemble it.
