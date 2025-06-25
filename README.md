Some examples:
```
2 + 2*2  => 6
```
```
1 + (-1.1 + 2) * 2 % 1.5  => 1.3
```
```
   1   +(3+2.5)%2.5  => 1.5
```
```
-5*-5/5  => 5
```
```
-3.14 % (2 -(-(-(-(-(-1))))))  => -0.14
```

Main idea of an algorithm (written in some unknown language):

```
; For now we can assume that input expression is valid for the sake of simplicity

evaluate_expression:
    ; Prepare stack, set up stuff
    v = process_sum
    return v

process_sum:
    v = process_product
    op = process_operator
    while op in [+, -]
        u = process_product
        v ?= u  ; where ? is one of [+, -]
    return v

process_product:
    v = process_term
    op = process_operator
    while op in [*, /, %]
        u = process_term
        v ?= u  ; where ? is one of [*, /, %]
    return v

process_term:
    if (there is character that is digit on input)
        return process_number
    if (there is '-' character on input)
        return -process_term  ; - here means arithmetic negation
    if (there is '(' character on input)
        v = process_sum
        assert(next_character_on_input = ')')
        return v
```

