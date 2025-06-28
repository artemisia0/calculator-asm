.data
# sign_mask:          .quad 0x8000000000000000   # sign bit for IEEE 754 double
nan_value:          .quad 0x7ff8000000000000
strtod_end:         .quad 0  # will be passed as an arg to strtod function
input_string:       .quad 0
input_string_size:  .quad 0
current_char_index: .quad 0  # index of a char that is being processed now

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
  xor %rax, %rax
  mov %rax, strtod_end(%rip)
  mov %rax, current_char_index(%rip)

  # Clear some xmm registers that will be used
  pxor %xmm0, %xmm0
  pxor %xmm1, %xmm1
  pxor %xmm8, %xmm8  # eval_sum function local variable ('res' from readme)
  pxor %xmm9, %xmm9  # eval_product func. local variable ('res' from readme)

  call eval_sum

  mov current_char_index(%rip), %rax
  cmp input_string_size(%rip), %rax
  jge eval_string_expression_exit
  movq nan_value(%rip), %xmm0
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
  mov current_char_index(%rip), %rax
  cmp input_string_size(%rip), %rax
  jge eval_sum_exit
eval_sum_loop:
# checking if current character is '+' or '-' and if yes
# then calculating other operand(s) and applying corresponding operation (-+)
  mov $'+', %rdi
  call match_char
  test %rax, %rax
  jnz eval_sum_apply_plus_operator
  mov $'-', %rdi
  call match_char
  test %rax, %rax
  jnz eval_sum_apply_minus_operator
# if peek_char() == 0 || peek_char() == ')' then exit from loop
  call peek_char
  test %rax, %rax
  jz eval_sum_exit
  cmpb $')', %al
  jz eval_sum_exit
  jmp eval_sum_exit_with_error  # invalid operator
eval_sum_apply_plus_operator:
  sub $16, %rsp
  movaps %xmm8, (%rsp)
  call eval_product
  movaps (%rsp), %xmm8
  add $16, %rsp
  addsd %xmm0, %xmm8
  jmp eval_sum_loop
eval_sum_apply_minus_operator:
  sub $16, %rsp
  movaps %xmm8, (%rsp)
  call eval_product
  movaps (%rsp), %xmm8
  add $16, %rsp
  subsd %xmm0, %xmm8
  jmp eval_sum_loop
eval_sum_exit:
  movsd %xmm8, %xmm0  # make that local variable a return value
  leave
  ret
eval_sum_exit_with_error:
  movq nan_value(%rip), %xmm0
  leave
  ret


# Returns double (in %xmm0).
# Note: %xmm9 will be used as a local variable (it is that 'res' from readme)
eval_product:
  push %rbp
  mov %rsp, %rbp
  call eval_primary
  movsd %xmm0, %xmm9
  mov current_char_index(%rip), %rax
  cmp input_string_size(%rip), %rax
  jge eval_product_exit
eval_product_loop:
# checking if current character is one of '*', '/' or '%' and if yes
# then calculating other operand(s) and applying corresponding operation (*%/)
  mov $'*', %rdi
  call match_char
  test %rax, %rax
  jnz eval_product_apply_mul_operator
  mov $'/', %rdi
  call match_char
  test %rax, %rax
  jnz eval_product_apply_div_operator
  mov $'%', %rdi
  call match_char
  test %rax, %rax
  jnz eval_product_apply_mod_operator
# if peek_char() == 0 || peek_char() == ')'
# || peek_char() == '+' || peek_char() == '-' then exit from loop
  call peek_char
  test %rax, %rax
  jz eval_product_exit
  cmpb $')', %al
  jz eval_product_exit
  cmpb $'+', %al
  jz eval_product_exit
  cmpb $'-', %al
  jz eval_product_exit
  jmp eval_product_exit_with_error  # invalid operator
eval_product_apply_mul_operator:
  sub $16, %rsp
  movaps %xmm9, (%rsp)
  call eval_primary
  movaps (%rsp), %xmm9
  add $16, %rsp
  mulsd %xmm0, %xmm9
  jmp eval_product_loop
eval_product_apply_div_operator:
  sub $16, %rsp
  movaps %xmm9, (%rsp)
  call eval_primary
  movaps (%rsp), %xmm9
  add $16, %rsp
  divsd %xmm0, %xmm9
  jmp eval_product_loop
eval_product_apply_mod_operator:
  sub $16, %rsp
  movaps %xmm9, (%rsp)
  call eval_primary
  movaps (%rsp), %xmm9
  add $16, %rsp
  movsd %xmm0, %xmm1
  movsd %xmm9, %xmm0
  call fmod
  movsd %xmm0, %xmm9
  jmp eval_product_loop
eval_product_exit:
  movsd %xmm9, %xmm0  # make that local variable a return value
  leave
  ret
eval_product_exit_with_error:
  movq nan_value(%rip), %xmm0
  leave
  ret


# Returns double (in %xmm0)
eval_primary:
  push %rbp
  mov %rsp, %rbp
  mov current_char_index(%rip), %rax
  cmp input_string_size(%rip), %rax
  jge eval_primary_exit_with_error
  # if peek_char() is a digit (then primary expression must be a number)
  call peek_char
  mov %rax, %rdi
  call isdigit
  test %rax, %rax
  jnz eval_primary_number
  # if match_char('-') (then it is primary expression with unary minus)
  mov $'-', %rdi
  call match_char
  test %rax, %rax
  jnz eval_primary_with_unary_minus
  # if match_char('(')
  mov $'(', %rdi
  call match_char
  test %rax, %rax
  jnz eval_primary_grouping
  jmp eval_primary_exit_with_error  # invalid operand
eval_primary_number:
  mov input_string(%rip), %rdi
  mov current_char_index(%rip), %rax
  add %rax, %rdi
  lea strtod_end(%rip), %rsi
  # double strtod(const char* str, char** end);
  call strtod
  mov strtod_end(%rip), %rax
  sub input_string(%rip), %rax
  mov %rax, current_char_index(%rip)
  jmp eval_primary_exit
eval_primary_with_unary_minus:
  call eval_primary
  movsd %xmm0, %xmm1
  xorpd %xmm0, %xmm0
  subsd %xmm1, %xmm0
  jmp eval_primary_exit
eval_primary_grouping:
  call eval_sum
  mov $')', %rdi
  call match_char
  test %rax, %rax
  jz eval_primary_exit_with_error
  jmp eval_primary_exit
eval_primary_exit:
  leave
  ret
eval_primary_exit_with_error:
  movq nan_value(%rip), %xmm0
  leave
  ret


# Arg #1: character in %rdi.
# Returns 1 or 0 (in %rax).
# Note that this function increments current_char_index if char in %rdi
# matches current non-whitespace char in input_string.
# It means that match_char consumes char on match while
# peek_char just returns current non-whitespace char.
match_char:
  push %rbp
  mov %rsp, %rbp
  call skip_whitespaces
  # Note that it is not necessary to check
  # if input_string_size > current_char_index (works fine anyway)
  call peek_char
  cmp %rdi, %rax
  jz match_char_exit_with_one
  jmp match_char_exit_with_zero
match_char_exit_with_one:
  mov current_char_index(%rip), %rax
  inc %rax
  mov %rax, current_char_index(%rip)
  mov $1, %rax
  leave
  ret
match_char_exit_with_zero:
  xor %rax, %rax
  leave
  ret


# Returns non-whitespace char that is being processed at the moment (in %rax)
peek_char:
  push %rbp
  mov %rsp, %rbp
  call skip_whitespaces
  mov current_char_index(%rip), %rax
  cmp input_string_size(%rip), %rax
  jge peek_char_exit_with_zero
  mov input_string(%rip), %rsi
  mov current_char_index(%rip), %rcx
  movzbl (%rsi, %rcx, 1), %eax
  jmp peek_char_exit
peek_char_exit_with_zero:
  xor %rax, %rax
  leave
  ret
peek_char_exit:
  leave
  ret


skip_whitespaces:
  push %rbp
  mov %rsp, %rbp
skip_whitespaces_loop:
  mov input_string(%rip), %rsi
  mov current_char_index(%rip), %rcx
  cmp input_string_size(%rip), %rcx
  jge skip_whitespaces_exit
  movzbl (%rsi, %rcx, 1), %eax
  cmp $' ', %al
  jnz skip_whitespaces_exit
  mov current_char_index(%rip), %rax
  inc %rax
  mov %rax, current_char_index(%rip)
  jmp skip_whitespaces_loop
skip_whitespaces_exit:
  leave
  ret

