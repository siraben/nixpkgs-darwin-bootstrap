/* Human-readable assembly for hex0-amd64-darwin.hex0.
   The committed .hex0 file is the bootstrap seed; this file is documentation
   for auditing the machine-code bytes, not an input to the bootstrap chain. */

.globl _start
.p2align 4
_start:
  subq $16, %rsp
  cmpq $3, %rdi
  jl fail

  movq %rsi, %r15
  movq 8(%r15), %rdi
  xorl %esi, %esi
  movl $0x02000005, %eax
  syscall
  testq %rax, %rax
  js fail
  movq %rax, %r13

  movq 16(%r15), %rdi
  movl $0x601, %esi
  movl $0700, %edx
  movl $0x02000005, %eax
  syscall
  testq %rax, %rax
  js fail
  movq %rax, %r14

  movl $-1, %r12d

read_loop:
  movq %r13, %rdi
  leaq (%rsp), %rsi
  movl $1, %edx
  movl $0x02000003, %eax
  syscall
  testq %rax, %rax
  js fail
  jz eof

  movzbl (%rsp), %eax
  cmpb $35, %al
  je comment_loop
  cmpb $59, %al
  je comment_loop
  cmpb $32, %al
  je read_loop
  cmpb $10, %al
  je read_loop
  cmpb $13, %al
  je read_loop
  cmpb $9, %al
  je read_loop

  cmpb $48, %al
  jb fail
  cmpb $57, %al
  jbe digit
  cmpb $65, %al
  jb fail
  cmpb $70, %al
  jbe upper
  cmpb $97, %al
  jb fail
  cmpb $102, %al
  jbe lower
  jmp fail

digit:
  subl $48, %eax
  jmp have_nybble
upper:
  subl $55, %eax
  jmp have_nybble
lower:
  subl $87, %eax

have_nybble:
  cmpl $0, %r12d
  jl save_high
  shll $4, %r12d
  orl %eax, %r12d
  movb %r12b, 1(%rsp)
  movq %r14, %rdi
  leaq 1(%rsp), %rsi
  movl $1, %edx
  movl $0x02000004, %eax
  syscall
  cmpq $1, %rax
  jne fail
  movl $-1, %r12d
  jmp read_loop

save_high:
  movl %eax, %r12d
  jmp read_loop

comment_loop:
  movq %r13, %rdi
  leaq (%rsp), %rsi
  movl $1, %edx
  movl $0x02000003, %eax
  syscall
  testq %rax, %rax
  js fail
  jz eof
  movzbl (%rsp), %eax
  cmpb $10, %al
  je read_loop
  cmpb $13, %al
  je read_loop
  jmp comment_loop

eof:
  cmpl $0, %r12d
  jge fail
  xorl %edi, %edi
  movl $0x02000001, %eax
  syscall

fail:
  movl $1, %edi
  movl $0x02000001, %eax
  syscall
