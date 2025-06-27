.data
sign_mask:          .quad 0x8000000000000000   # sign bit for IEEE 754 double
nan_value:          .quad 0x7ff8000000000000
strtod_end:         .quad 0  # will be passed as an arg to strtod function
input_string:       .quad 0
input_string_size:  .quad 0
current_ch_index:   .quad 0  # index of a char that is being processed now

.text
.globl eval_string_expression


# Arg #1: pointer to input string
# Arg #2: input string size
# Returns double (in %xmm0)
eval_string_expression:
  push %rbp
  mov %rsp, %rbp

  mov %rdi, input_string(%rip)
  mov %rsi, input_string_size(%rip)

  # Clear some xmm registers that will be used
  pxor %xmm0, %xmm0
  pxor %xmm8, %xmm8
  pxor %xmm9, %xmm9

  call eval_sum

  mov current_ch_index(%rip), %rax
  cmp input_string_size(%rip), %rax
  jge eval_string_expression_exit
  movsd nan_value(%rip), %xmm0

eval_string_expression_exit:
  leave
  ret


# Returns double (in %xmm0).
# Note: %xmm8 will be used as a local variable (it is that 'res' from readme)
eval_sum:
  push %rbp
  mov %rsp, %rbp
  call eval_product
  movsd %xmm0, %xmm8
  mov current_ch_index(%rip), %rax
  cmp input_string_size(%rip), %rax
  jge eval_sum_exit
eval_sum_loop:
# checking if current character is '+' or '-' and if yes
# then calculating other operand(s) and applying corresponding operation (-/+)
  mov $'+', %rdi
  call match_char
  test %rax, %rax
  jnz eval_sum_apply_plus_operator
  mov $'-', %rdi
  call match_char
  test %rax, %rax
  jnz eval_sum_apply_minus_operator
eval_sum_loop_exit_check:
# if peek_char() == 0 || peek_char() == ')' then exit from loop
  call peek_char
  test %rax, %rax
  jz eval_sum_exit
  cmpb $')', %al
  jz eval_sum_exit
  jmp eval_sum_exit_with_error  # invalid operator
eval_sum_apply_plus_operator:
  mov current_ch_index(%rip), %rax
  cmp input_string_size(%rip), %rax
  jge eval_sum_exit_with_error  # there is an operator but no operand
  call eval_product
  addsd %xmm0, %xmm8
  jmp eval_sum_loop
eval_sum_apply_minus_operator:
  mov current_ch_index(%rip), %rax
  cmp input_string_size(%rip), %rax
  jge eval_sum_exit_with_error  # there is an operator but no operand
  call eval_product
  subsd %xmm0, %xmm8
  jmp eval_sum_loop
eval_sum_exit:
  movsd %xmm8, %xmm0  # make that local variable a return value
  leave
  ret
eval_sum_exit_with_error:
  movsd nan_value(%rip), %xmm0
  leave
  ret


process_product:
  push %rbp
  mov %rsp, %rbp

  call process_term
  movsd %xmm0, %xmm1  # see algorithm in readme, that v is %xmm1, u is %xmm0
  # if process_term returns NaN then result will also be NaN

  cmp input_string_size(%rip), %rcx
  jge process_product_loop_exit

  call peek_op
  cmpb $'*', %al
  je process_product_loop
  cmpb $'/', %al
  je process_product_loop
  cmpb $'%', %al
  je process_product_loop
  cmpb $'+', %al
  je process_product_loop_exit
  cmpb $'-', %al
  je process_product_loop_exit
  cmpb $')', %al
  je process_product_loop_exit
  cmpb $0, %al
  je process_product_loop_exit
  jmp return_nan

process_product_loop:
  inc %rcx  # consuming operator because we have already processed it

  cmp input_string_size(%rip), %rcx  # error: no right operand
  jge return_nan

  push %rax  # twice for stack alignment
  push %rax  # twice for stack alignment
  sub $16, %rsp
  movaps %xmm1, (%rsp)

  call process_term
  # if this returns NaN then result will also be NaN
  
  movaps (%rsp), %xmm1
  add $16, %rsp
  pop %rax
  pop %rax

  call apply_product_op

  call peek_op
  cmpb $'*', %al
  je process_product_loop
  cmpb $'/', %al
  je process_product_loop
  cmpb $'%', %al
  je process_product_loop
  cmpb $'+', %al
  je process_product_loop_exit
  cmpb $'-', %al
  je process_product_loop_exit
  cmpb $')', %al
  je process_product_loop_exit
  cmpb $0, %al
  je process_product_loop_exit
  jmp return_nan

process_product_loop_exit:
  movsd %xmm1, %xmm0  # make v return value

  leave
  ret

process_term:
  push %rbp
  mov %rsp, %rbp

  cmp input_string_size(%rip), %rcx
  jge return_nan

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

  # Testing if there is unary minus on input
  call peek_op
  cmpb $'-', %al
  je process_term_unary_minus

  # Testing if there is left parenthesis on input
  call peek_op
  cmpb $'(', %al
  je process_term_grouping
  jmp return_nan

process_term_exit:
  leave
  ret

# double strtod(const char* str, char** end);
process_term_number:
  mov input_string(%rip), %rdi
  add %rcx, %rdi
  lea strtod_end(%rip), %rsi
  push %rcx
  push %rdi
  
  sub $16, %rsp
  movaps %xmm1, (%rsp)
  call strtod
  
  movaps (%rsp), %xmm1
  add $16, %rsp
  
  pop %rdi
  pop %rcx
  mov strtod_end(%rip), %r8
  sub %rdi, %r8
  add %r8, %rcx
  # parsed number is already in %xmm0 due to strtod function call
  # most of the work done in this label is just for %rcx index shifting
  jmp process_term_exit

process_term_unary_minus:
  inc %rcx  # skipping that minus

  cmp input_string_size(%rip), %rcx
  jge return_nan
  
  sub $16, %rsp
  movaps %xmm1, (%rsp)
  
  call process_term
  
  movaps (%rsp), %xmm1
  add $16, %rsp

  movq sign_mask(%rip), %xmm1
  xorpd %xmm1, %xmm0  # flipping the sign bit
  jmp process_term_exit

process_term_grouping:
  inc %rcx  # skipping that '('
  
  cmp input_string_size(%rip), %rcx
  jge return_nan

  sub $16, %rsp
  movaps %xmm1, (%rsp)

  call process_sum
  
  movaps (%rsp), %xmm1
  add $16, %rsp
  
  cmp input_string_size(%rip), %rcx
  jge return_nan

  # assert that next char is ')'
  call peek_op
  cmp $')', %al
  jne return_nan

  inc %rcx  # skipping that ')'
  jmp process_term_exit

skip_whitespaces:
  push %rbp
  mov %rsp, %rbp
skip_whitespaces_loop:
  mov input_string(%rip), %rsi
  movzbl (%rsi, %rcx, 1), %eax
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
  call skip_whitespaces
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

