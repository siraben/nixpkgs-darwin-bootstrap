.global _main
_main:
  mov $0x2000004, %rax
  mov $1, %rdi
  lea message(%rip), %rsi
  mov $13, %rdx
  syscall
  xor %rdi, %rdi
  mov $0x2000001, %rax
  syscall
message:
  .ascii "hello darwin\n"
