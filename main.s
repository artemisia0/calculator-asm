.data
nan_value: .double 0.0
zero: .double 0.0

.text
.globl eval_string_expression

eval_string_expression:  # Return value is in %xmm0
  push %rbp
  mov %rsp, %rbp

  # Calculating nan_value by dividing zero by zero
  movsd zero(%rip), %xmm0
  divsd zero(%rip), %xmm0
  movsd %xmm0, nan_value(%rip)

  # I want to store the pointer to the input string at -8(%rsp)
  sub $16, %rsp
  mov %rdi, -8(%rsp)
  xor %rcx, %rcx  # Input string index is in rcx

  call process_sum

  leave
  ret

process_sum:
  push %rbp
  mov %rsp, %rbp

  call process_product  # and so now processed product is in %xmm0
  movsd %xmm0, %xmm1  # see algorithm in readme, that v is %xmm1, u is %xmm0

  call peek_op
  cmpb $'+', %al
  je process_sum_loop
  cmpb $'-', %al
  je process_sum_loop

  jmp process_sum_loop_exit

process_sum_loop:
  mov %rax, -16(%rsp)  # saving operator and some more bytes on the stack
  inc %rcx  # consuming operator because we have already processed it
  call process_product
  mov 16(%rsp), %rax
  call apply_sum_op

  call peek_op
  cmpb $'+', %al
  je process_sum_loop
  cmpb $'-', %al
  je process_sum_loop

process_sum_loop_exit:

  movsd %xmm1, %xmm0  # make v a return value

  leave
  ret

process_product:
  push %rbp
  mov %rsp, %rbp

  leave
  ret

process_term:
  push %rbp
  mov %rsp, %rbp

  leave
  ret

peek_op:
  push %rbp
  mov %rsp, %rbp
  mov -8(%rsp), %rsi
  movzbl (%rsi, %rcx, 1), %eax
  leave
  ret

# TODO: Write same for *, /, % (write apply_product_op with similar logic)
apply_sum_op:  # %xmm1 ?= %xmm0  that is return value is in %xmm1, NOT %xmm0
  push %rbp
  mov %rsp, %rbp

  cmpb $'+', %al
  je apply_plus_op
  cmpb $'-', %al
  je apply_minus_op

apply_plus_op:
  addsd %xmm0, %xmm1
  jmp apply_sum_op_exit

apply_minus_op:
  subsd %xmm0, %xmm1
  jmp apply_sum_op_exit

apply_sum_op_exit:
  leave
  ret

# Some tips

# Compare to '+', '-' or other characters with logical OR operator
# cmpb $'+', %al
# je is_plus
# cmpb $'-', %al
# je is_minus
# and so on for any characters
# jmp not_process  # if is not plus, not minus and so on

