#include <stdio.h>
#include <inttypes.h>
#include <string.h>
#include <math.h>
#include <stdlib.h>
#include <assert.h>
#include <errno.h>

#define ADD_TESTS

// Implemented in asm module and then linked together
// If input expression is invalid then output is NaN
extern double eval_string_expression(const char*, unsigned int);

enum {
  READ_TO_STRING_BLOCK_SIZE = 1024,
};

#ifdef ADD_TESTS
#define EPS 1e-9
#define ASSERT_DBL_EQ(a, b) assert(fabs((a) - (b)) < EPS)
#endif

// Reads contents from file to string until ch found in input file.
// Allocates memory with malloc/realloc.
char* read_to_string(FILE* file, char ch);

// Reading input from stdin and printing evaluated expression
// All parsing/evaluating logic is implemented in asm
int main() {

  // Unit test set is not complete but it is enough for now
#ifdef ADD_TESTS
  // Basic test for read_to_string
  FILE* test0_file = fopen("abc", "r");
  assert(test0_file != NULL);
  char* test0 = read_to_string(test0_file, '\n');
  char abc[] = "abc";
  assert(!strcmp(test0, abc));
  free(test0);

  // Just some general tests with valid expression
  char test1[] = "      2 + 2*2            ";
  ASSERT_DBL_EQ(eval_string_expression(test1, strlen(test1)), 6);

  char test2[] = "1 + (-1.1 + 2) * 2 % 1.5                ";
  ASSERT_DBL_EQ(eval_string_expression(test2, strlen(test2)), 1.3);

  char test3[] = "   1   +(3+2.5)%2.5         ";
  ASSERT_DBL_EQ(eval_string_expression(test3, strlen(test3)), 1.5);

  char test4[] = "-3.14 % (2 -(-(-(-(-(-1)))))) ";
  ASSERT_DBL_EQ(eval_string_expression(test4, strlen(test4)), -0.14);

  char test5[] = "-5*-5/5";
  ASSERT_DBL_EQ(eval_string_expression(test5, strlen(test5)), 5);

  // Testing with invalid input, answers must be NaN for all tests
  char test6[] = "-7-";  // Extra minus at end
  assert(isnan(eval_string_expression(test6, strlen(test6))));

  char test7[] = "()";  // No numbers, should not evaluated to anything
  assert(isnan(eval_string_expression(test7, strlen(test7))));

  char test8[] = " ";  // Just a space, also invalid expression
  assert(isnan(eval_string_expression(test8, strlen(test8))));

  char test9[] = "+1";  // Unary plus is not supported
  assert(isnan(eval_string_expression(test9, strlen(test9))));

  char test10[] = "2*(2+2";  // No closing parenthesis
  assert(isnan(eval_string_expression(test10, strlen(test10))));

  char test11[] = "2*2+2)";  // No opening parenthesis
  assert(isnan(eval_string_expression(test11, strlen(test11))));

  char test12[] = "1.2.3";  // 1.2.3 is not a valid floating-point number
  assert(isnan(eval_string_expression(test12, strlen(test12))));

  char test13[] = "1*/2";  // Extra / operator
  assert(isnan(eval_string_expression(test13, strlen(test13))));

  char test14[] = "7/(1-1.0)";  // 7/0 approaches infinity
  assert(isinf(eval_string_expression(test14, strlen(test14))));

  char test15[] = "*5+3";  // Extra * operator
  assert(isnan(eval_string_expression(test15, strlen(test15))));

  char test16[] = "-";  // Just minus is not an expression
  assert(isnan(eval_string_expression(test16, strlen(test16))));

  char test17[] = "(+)";  // Plus in parenthesis is not an expression :)
  assert(isnan(eval_string_expression(test17, strlen(test17))));

  char test18[] = "(1.-1)/(1-1.0)";  // Zero divided by zero is undefined
  assert(isnan(eval_string_expression(test18, strlen(test18))));

  // Testing with a very long numbers as an input (must be NaN)
  // Must be NaN because very long numbers (15 chars+) are not supported.
  // (must be NaN even if an expression is valid)
  FILE* file_with_very_long_number = fopen("very_long_number", "r");
  assert(file_with_very_long_number != NULL);
  char* test19 = read_to_string(file_with_very_long_number, '\n');
  assert(isnan(eval_string_expression(test19, strlen(test19))));
  fclose(file_with_very_long_number);
  free(test19);

  // Testing with long valid expression as an input (must be OK)
  FILE* file_with_very_long_expr = fopen("very_long_expr", "r");
  assert(file_with_very_long_expr != NULL);
  char* test20 = read_to_string(file_with_very_long_expr, '\n');
  ASSERT_DBL_EQ(eval_string_expression(test20, strlen(test20)), 3.14);
  fclose(file_with_very_long_expr);
  free(test20);

  printf("\033[34mALL TEST CASES PASSED (OK)\033[0;m\n");
#endif  // ADD_TESTS

  while (1) {
    char* input_line = read_to_string(stdin, '\n');
    if (input_line == NULL) {
      break;
    }

    int input_line_size = strlen(input_line);
    // Ignoring empty line
    if (input_line_size == 0) {
      continue;
    }

    double res = eval_string_expression(input_line, input_line_size);
    if (isnan(res)) {
      printf("\033[1;31mInvalid expression :(\033[0;m\n");
      continue;
    }
    printf("\033[1;32m%.16g\033[0;m\n", res);
    free(input_line);
  }
  return 0;
}

// Cheap implementation of std::vector<char> or std::string logic.
char* read_to_string(FILE* file, char bad_ch) {
  assert(file != NULL);
  // sizeof(char) = 1
  char* str = malloc(READ_TO_STRING_BLOCK_SIZE*sizeof(char)); 
  int str_size = READ_TO_STRING_BLOCK_SIZE;
  int i = 0;
  while (1) {
    while (i < str_size) {
      char ch = fgetc(file);
      if (ch == bad_ch || ch == 0) {
        str[i] = 0;  // '\0'
        return str;
      }
      str[i++] = ch;
    }
    if (i < str_size) {
      break;
    }
    if (i == str_size) {
      str_size += READ_TO_STRING_BLOCK_SIZE;
      str = realloc(str, str_size);
      if (str == NULL) {
        return NULL;
      }
      continue;
    }
    assert(i < str_size);
    break;
  }
  assert(i < str_size);
  str[i] = 0;  // '\0'
  return str;
}

