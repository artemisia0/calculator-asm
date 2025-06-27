#### Some examples

```
2 + 2*2                         ==> 6
```
```
1 + (-1.1+2)*2%1.5              ==> 1.3
```
```
   1   +(3+2.5)%2.5             ==> 1.5
```
```
-5*-5/5                         ==> 5
```
```
-3.14 % (2 -(-(-(-1))))         ==> -0.14
```
```
7-                              ==> Invalid expression :(
```
```
(3)                             ==> 3
```
```
()                              ==> Invalid expression :(
```

#### Calculator algorithm

```
eval_sum()
    res = eval_product()
    loop
        if match_ch('?')  # Where ? is in ['+', '-']
            res ?= eval_product()
            continue
        # peek_ch() == 0  => no more input
        if peek_ch() == 0 or peek_ch() == ')'
            return res
        return NaN  # Invalid operator
    return res

eval_product()
    res = eval_primary()
    loop
        if match_ch('?')  # Where ? is in ['*', '/', '%']
            res ?= eval_primary()
            continue
        if match_ch('+') or match_ch('-')
                         or peek_op() == 0 or peek_ch() == ')'
            return res
        return NaN  # Invalid operator
    return res

eval_primary()
    if peek_ch() in ['0', '1', ..., '9']
        return eval_number()
    if match_ch('(')
        res = eval_sum()  # Note that eval_sum never consumes ')'
        if not match_ch(')')
            return NaN
        return res
    if match_ch('-')  # Unary minus
        return -eval_primary()
    return NaN

match_ch(ch)
    if a character that is being processed at the moment
    equals ch then returns true AND consumes that character.
    returns false otherwise and does not consume the character.

peek_op()
    returns character that is being processed at the moment
    or if there is no more input (we're at the end of the input string)
    then returns 0
```

