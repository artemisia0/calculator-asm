#include <stdio.h>
#include <inttypes.h>


// Implemented in asm module and then linked together
// If input expression is invalid then output is NaN
extern double eval_string_expression(const char*);

enum {
  INPUT_LINE_SIZE = 1024,
};

// Reading input from stdin and printing evaluated expression
// All parsing/evaluating logic is implemented in asm
int main() {
  while (1) {
    char input_line[INPUT_LINE_SIZE];
    if (fgets(input_line, INPUT_LINE_SIZE, stdin) == NULL) {
      break;
    }
    // I also added awesome style, colors + bold font
    // It should work fine on most linux
    printf("\033[1;32m%.15lf\033[0;m\n", eval_string_expression(input_line));
    // If colors are not supported then try this
    // printf("%f\n", eval_string_expression(input_line));
  }
  return 0;
}

