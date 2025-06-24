.data
nan_value: .double 0.0
zero: .double 0.0
input_string: .quad 0
input_string_size: .quad 0
sign_mask: .quad 0x8000000000000000   # sign bit for IEEE 754 double
strtod_end: .quad 0

.text
.globl eval_string_expression

eval_string_expression:  # Return value is in %xmm0
  push %rbp
  mov %rsp, %rbp

  # Clear some xmm registers that will be used
  # because right 8 bytes will be used only but registers are 16 bytes size.
  # It probably is not necessary but highly recommended anyway
  pxor %xmm0, %xmm0
  pxor %xmm1, %xmm1
  pxor %xmm2, %xmm2
  pxor %xmm3, %xmm3
  pxor %xmm4, %xmm4

  # Calculating nan_value by dividing zero by zero
  movsd zero(%rip), %xmm0
  divsd zero(%rip), %xmm0
  movsd %xmm0, nan_value(%rip)

  mov %rdi, input_string(%rip)
  mov %rsi, input_string_size(%rip)
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

process_term:
  push %rbp
  mov %rsp, %rbp

  # Testing if there is a number on input
  call peek_op
  mov %eax, %edi
  push %rcx  # two times for stack alignment
  push %rcx
  call isdigit
  pop %rcx
  pop %rcx
  cmp $0, %eax
  jne process_term_number
  jmp process_term_exit

  # Testing if there is unary minus on input
  call peek_op
  cmpb $'-', %al
  je process_term_unary_minus
  jmp process_term_exit

  # Testing if there is left parentesis on input
  call peek_op
  cmpb $'(', %al
  je process_term_grouping
  jmp process_term_exit

process_term_exit:

  leave
  ret

# double strtod(const char* str, char** end);
process_term_number:
  mov input_string(%rip), %rdi
  add %rcx, %rdi
  lea strtod_end(%rip), %rsi
  push %rcx  # pushing twice for stack alignment
  push %rcx  # but it would probably be simpler to subtract 16 from %rsp
  call strtod
  pop %rcx
  pop %rcx
  mov strtod_end(%rip), %r8
  mov input_string(%rip), %rax
  sub %rax, %r8
  add %r8, %rcx
  # parsed number is already in %xmm0 due to strtod function call
  # most of the work done in this label is just for %rcx index shifting
  jmp process_term_exit

process_term_unary_minus:
  inc %rcx  # skipping that minus
  call process_term
  movq sign_mask(%rip), %xmm1
  xorpd %xmm1, %xmm0  # flipping the sign bit
  jmp process_term_exit

process_term_grouping:
  inc %rcx  # skipping that '('
  call process_sum
  # assert that next char is ')'
  # for now I assume that the given expression is valid FIXME TODO
  inc %rcx  # skipping that ')'
  jmp process_term_exit

skip_whitespaces:
  push %rbp
  mov %rsp, %rbp
skip_whitespaces_loop:
  call peek_op
  cmpb $' ', %al
  jne skip_whitespaces_loop_exit
  inc %rcx
  cmp input_string_size(%rip), %rcx
  jge skip_whitespaces_loop_exit
  jmp skip_whitespaces_loop
skip_whitespaces_loop_exit:
  leave
  ret

peek_op:
  push %rbp
  mov %rsp, %rbp
  cmp input_string_size(%rip), %rcx
  jge peek_op_bad_index
  mov input_string(%rip), %rsi
  movzbl (%rsi, %rcx, 1), %eax
peek_op_exit:
  leave
  ret
peek_op_bad_index:
  mov $0, %eax
  jmp peek_op_exit

apply_sum_op:  # %xmm1 ?= %xmm0 (return value is in %xmm1, NOT %xmm0)
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

