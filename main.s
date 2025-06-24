.data
nan_value: .double 0.0
zero: .double 0.0
input_string: .quad 0

.text
.globl eval_string_expression

eval_string_expression:  # Return value is in %xmm0
  push %rbp
  mov %rsp, %rbp

  # Clear all xmm registers at program start
  # I know it looks very strange, I actually need xmm0 to xmm4 only
  pxor %xmm0, %xmm0
  pxor %xmm1, %xmm1
  pxor %xmm2, %xmm2
  pxor %xmm3, %xmm3
  pxor %xmm4, %xmm4
  pxor %xmm5, %xmm5
  pxor %xmm6, %xmm6
  pxor %xmm7, %xmm7
  pxor %xmm8, %xmm8
  pxor %xmm9, %xmm9
  pxor %xmm10, %xmm10
  pxor %xmm11, %xmm11
  pxor %xmm12, %xmm12
  pxor %xmm13, %xmm13
  pxor %xmm14, %xmm14
  pxor %xmm15, %xmm15

  # Calculating nan_value by dividing zero by zero
  movsd zero(%rip), %xmm0
  divsd zero(%rip), %xmm0
  movsd %xmm0, nan_value(%rip)

  # I want to store the pointer to the input string at input_string(%rip)
  sub $16, %rsp
  mov %rdi, input_string(%rip)
  xor %rcx, %rcx  # Input string index is in rcx

  call process_sum

  add $16, %rsp
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
  push %rax  # saving operator
  inc %rcx  # consuming operator because we have already processed it
  call process_product
  pop %rax
  call apply_sum_op

  call peek_op
  cmpb $'+', %al
  je process_sum_loop
  cmpb $'-', %al
  je process_sum_loop

process_sum_loop_exit:

  movsd %xmm1, %xmm0  # make v return value

  leave
  ret

process_product:
  push %rbp
  mov %rsp, %rbp

  call process_term
  movsd %xmm0, %xmm1  # see algorithm in readme, that v is %xmm1, u is %xmm0

  call peek_op
  cmpb $'*', %al
  je process_product_loop
  cmpb $'/', %al
  je process_product_loop
  cmpb $'%', %al
  je process_product_loop

  jmp process_product_loop_exit

process_product_loop:
  push %rax  # saving operator
  inc %rcx  # consuming operator because we have already processed it
  call process_term
  pop %rax
  call apply_product_op

  call peek_op
  cmpb $'*', %al
  je process_product_loop
  cmpb $'/', %al
  je process_product_loop
  cmpb $'%', %al
  je process_product_loop

process_product_loop_exit:

  movsd %xmm1, %xmm0  # make v return value

  leave
  ret

// TODO FIXME
process_term:
  push %rbp
  mov %rsp, %rbp

  movsd zero(%rip), %xmm0

  leave
  ret

peek_op:
  push %rbp
  mov %rsp, %rbp
  mov input_string(%rip), %rsi
  movzbl (%rsi, %rcx, 1), %eax
  leave
  ret

apply_sum_op:  # %xmm1 ?= %xmm0  that is return value is in %xmm1, NOT %xmm0
  push %rbp
  mov %rsp, %rbp

  cmpb $'+', %al
  je apply_plus_op
  cmpb $'-', %al
  je apply_minus_op
  jmp apply_sum_op_exit

apply_plus_op:
  addsd %xmm0, %xmm1
  jmp apply_sum_op_exit

apply_minus_op:
  subsd %xmm0, %xmm1
  jmp apply_sum_op_exit

apply_sum_op_exit:
  leave
  ret

apply_product_op:  # %xmm1 ?= %xmm0 (RETURN VALUE IS IN %xmm1)
  push %rbp
  mov %rsp, %rbp

  cmpb $'*', %al
  je apply_mul_op
  cmpb $'/', %al
  je apply_div_op
  cmpb $'%', %al
  je apply_mod_op
  jmp apply_product_op_exit

apply_mul_op:
  mulsd %xmm0, %xmm1
  jmp apply_product_op_exit

apply_div_op:
  divsd %xmm0, %xmm1
  jmp apply_product_op_exit

# Since there is floating-point module operator (native) we need to implement
# it on our own: x mod y = x - floor(x / y) * y
apply_mod_op:
  movsd %xmm1, %xmm2
  divsd %xmm0, %xmm2
  roundsd $3, %xmm2, %xmm2
  mulsd %xmm0, %xmm2
  subsd %xmm2, %xmm1
  jmp apply_product_op_exit

apply_product_op_exit:
  leave
  ret

