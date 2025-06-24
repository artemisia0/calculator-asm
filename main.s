.data
a: .double 3.1410932938298
b: .double 2.71

.text
.globl eval_string_expression

eval_string_expression:  ; Return value is in %xmm0
  push %rbp
  mov %rsp, %rbp

  ; I want to store the pointer to the input string at -8(%rsp)
  sub $16, %rsp
  mov %rdi, -8(%rsp)
  xor %rcx, %rcx  ; Input string index is in rcx

  ; process stands for parsing and evaluating at the same time
  jmp process_sum

  leave
  ret

process_sum:
  push %rbp
  mov %rsp, %rbp

  leave
  ret

process_product:
  push %rbp
  mov %rsp, %rbp

  leave
  ret

process_product:
  push %rbp
  mov %rsp, %rbp

  leave
  ret

