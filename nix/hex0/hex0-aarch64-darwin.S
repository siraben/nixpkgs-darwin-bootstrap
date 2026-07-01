/* Human-readable assembly for hex0-aarch64-darwin.hex0.
   The committed .hex0 file is the bootstrap seed; this file is documentation
   for auditing the machine-code bytes.

   Mirrors hex0-amd64-darwin.S on the Darwin arm64 ABI:
   - dyld LC_MAIN entry: x0 = argc, x1 = argv
   - BSD syscall: number in x16, svc #0x80, error => carry set
   - the stack is the only writable memory (1-byte read buffer at [sp],
     1-byte write buffer at [sp, #1])

   Register use:
   x19 = argv
   x20 = input fd
   x21 = output fd
   w22 = nybble accumulator (-1 = empty, >= 0 = high nybble pending)
   w23 = current byte / scratch                                        */

.globl _start
.p2align 2
_start:
  sub sp, sp, #16
  cmp x0, #3
  b.lt fail

  mov x19, x1
  ldr x0, [x19, #8]        /* argv[1]: input path */
  mov x1, #0               /* O_RDONLY */
  mov x2, #0
  mov x16, #5              /* SYS_open */
  svc #0x80
  b.cs fail
  mov x20, x0

  ldr x0, [x19, #16]       /* argv[2]: output path */
  mov x1, #0x601           /* O_WRONLY | O_CREAT | O_TRUNC */
  mov x2, #0x1c0           /* 0700 */
  mov x16, #5              /* SYS_open */
  svc #0x80
  b.cs fail
  mov x21, x0

  movn w22, #0             /* accumulator = -1 (empty) */

read_loop:
  mov x0, x20
  mov x1, sp
  mov x2, #1
  mov x16, #3              /* SYS_read */
  svc #0x80
  b.cs fail
  cbz x0, eof

  ldrb w23, [sp]
  cmp w23, #35             /* '#' */
  b.eq comment_loop
  cmp w23, #59             /* ';' */
  b.eq comment_loop
  cmp w23, #32             /* ' ' */
  b.eq read_loop
  cmp w23, #10             /* '\n' */
  b.eq read_loop
  cmp w23, #13             /* '\r' */
  b.eq read_loop
  cmp w23, #9              /* '\t' */
  b.eq read_loop

  cmp w23, #48             /* '0' */
  b.lo fail
  cmp w23, #57             /* '9' */
  b.ls digit
  cmp w23, #65             /* 'A' */
  b.lo fail
  cmp w23, #70             /* 'F' */
  b.ls upper
  cmp w23, #97             /* 'a' */
  b.lo fail
  cmp w23, #102            /* 'f' */
  b.ls lower
  b fail

digit:
  sub w23, w23, #48
  b have_nybble
upper:
  sub w23, w23, #55
  b have_nybble
lower:
  sub w23, w23, #87

have_nybble:
  tbnz w22, #31, save_high /* accumulator empty: this is the high nybble */
  lsl w22, w22, #4
  orr w22, w22, w23
  strb w22, [sp, #1]
  mov x0, x21
  add x1, sp, #1
  mov x2, #1
  mov x16, #4              /* SYS_write */
  svc #0x80
  b.cs fail
  cmp x0, #1
  b.ne fail
  movn w22, #0
  b read_loop

save_high:
  mov w22, w23
  b read_loop

comment_loop:
  mov x0, x20
  mov x1, sp
  mov x2, #1
  mov x16, #3              /* SYS_read */
  svc #0x80
  b.cs fail
  cbz x0, eof
  ldrb w23, [sp]
  cmp w23, #10             /* '\n' */
  b.eq read_loop
  cmp w23, #13             /* '\r' */
  b.eq read_loop
  b comment_loop

eof:
  tbz w22, #31, fail       /* dangling high nybble: reject */
  mov x0, #0
  mov x16, #1              /* SYS_exit */
  svc #0x80

fail:
  mov x0, #1
  mov x16, #1              /* SYS_exit */
  svc #0x80
