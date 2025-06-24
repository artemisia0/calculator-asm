#include <stdio.h>
#include <inttypes.h>
#include <string.h>
#include <math.h>


// Implemented in asm module and then linked together
// If input expression is invalid then output is NaN
extern double eval_string_expression(const char*, unsigned int);

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
    double res = eval_string_expression(input_line, strlen(input_line));
    if (isnan(res)) {
      printf("\033[1;31mInvalid expression error :(\033[0;m\n");
      break;
    }
    // I also added awesome style, colors + bold font
    // It should work fine on most linux
    printf("\033[1;32m%.15lf\033[0;m\n", res);
  }
  return 0;
}

