/*
 * Sim65 trace functionality example.
 *
 * Description
 * -----------
 *
 * The easiest way to use tracing in sim65 is to pass the '--trace' option
 * to sim65 while starting a program.
 *
 * However, it is also possiblke to enable and disable the trace functionality
 * at runtime, from within the C code itself. This can be useful to produce
 * runtime traces of small code fragments for debugging purposes.
 *
 * In this example, We use the TRACE_ON and TRACE_OFF macros provided in sim65.h
 * to trace what the CPU is doing during a single statement: the assignment of
 * a constant to a global variable.
 *
 * Running the example
 * -------------------
 *
 * cl65 -t sim6502 -O trace_example.c -o trace_example.prg
 * sim65 trace_example.prg
 *
 * Compiling and running the program like this will produce a trace of six 6502 instructions.
 * The first four instructions correspond to the 'x = 0x1234' assignment statement.
 * The last two instructions (ending in a store to address $FFCB) disable the trace facility.
 *
 */

#include <sim65.h>
#include <lib_fp.h>
#include <stdio.h>
#include <stdint.h>

void c64_to_ascii(char* str) {
    unsigned char* ptr = (unsigned char*)str;

    while (*ptr != '\0') {
        // Handle C64 lowercase / uppercase mapping to standard ASCII
        if (*ptr >= 0x01 && *ptr <= 0x1A) {
            // C64 screen codes $01-$1A (A-Z) -> ASCII lowercase 'a'-'z'
            *ptr += 0x60;
        } else if (*ptr >= 0x41 && *ptr <= 0x5A) {
            // PETSCII uppercase 'A'-'Z' -> ASCII uppercase
            // (Already aligns with standard ASCII, leave as is)
        } else if (*ptr >= 0xC1 && *ptr <= 0xDA) {
            // Shifted PETSCII 'A'-'Z' -> ASCII lowercase
            *ptr -= 0x80;
        }
        ptr++;
    }
}

/* Define a 4-byte structure layout for your operands[span_0](start_span)[span_0](end_span) */
struct fp_operand {
    uint8_t b0;
    uint8_t b1;
    uint8_t b2;
    uint8_t b3;
};

void set_math_operands(void) {
    /* 1. Declare ALL pointers at the very top of the function */
    volatile struct fp_operand *divisor = (volatile struct fp_operand *)&FP_FP1;
    volatile struct fp_operand *dividend = (volatile struct fp_operand *)&FP_FP2;

    /* 2. Perform executable assignments below */
    divisor->b0 = 0x81;
    divisor->b1 = 0x40;
    divisor->b2 = 0x00;
    divisor->b3 = 0x00;

    dividend->b0 = 0x81;
    dividend->b1 = 0x60;
    dividend->b2 = 0x00;
    dividend->b3 = 0x00;
}

void print_fp1_math_operands(void) {
    /* 1. Declare ALL pointers at the very top of the function */
    volatile struct fp_operand *fp1 = (volatile struct fp_operand *)&FP_FP1;

    printf("FP1 Hex: %02X %02X %02X %02X\n",
           (unsigned char)fp1->b0,
           (unsigned char)fp1->b1,
           (unsigned char)fp1->b2,
           (unsigned char)fp1->b3);
}


int main(void)
{
//    printf("%s\n", (char*)0x04A0);

    // Point directly to the screen RAM address
//    char* my_string = (char*)0x0545;            // .msg0
//    uint8_t value = *(volatile uint8_t*)0xFE;   // error code from the floating-point library

    // Convert the string in-place
//    c64_to_ascii(my_string);

    // Output the standard PETSCII string using the C runtime
//    printf("%s %d\n", my_string, value);

    set_math_operands();
    print_fp1_math_operands();

    TRACE_ON();
    FP_FDIV(); // 3 ? 2
    TRACE_OFF();

    print_fp1_math_operands();

    return 0;
}
