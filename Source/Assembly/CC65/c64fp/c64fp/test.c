//
//  test.c
//  c64fp
//
//  Created by Peter Dean on 9/9/2026.
//

#include "test.h"
#include <stdio.h>
#include <stdint.h>

/* Define a 4-byte structure layout for your operands[span_0](start_span)[span_0](end_span) */
struct fp_operand {
    uint8_t b0;
    uint8_t b1;
    uint8_t b2;
    uint8_t b3;
};

void set_math_operands(void) {
    /* 1. Declare ALL pointers at the very top of the function */
    volatile struct fp_operand *divisor = (volatile struct fp_operand *)0x61;
    volatile struct fp_operand *dividend = (volatile struct fp_operand *)0x69;

    /* 2. Perform executable assignments below */
    divisor->b0 = 0x41;
    divisor->b1 = 0x40;
    divisor->b2 = 0x00;
    divisor->b3 = 0x00;

    dividend->b0 = 0xc0;
    dividend->b1 = 0x40;
    dividend->b2 = 0x00;
    dividend->b3 = 0x00;
}

void print_fp1_math_operands(void) {
    /* 1. Declare ALL pointers at the very top of the function */
    volatile struct fp_operand *fp1 = (volatile struct fp_operand *)0x61;

    printf("FP1 Hex: %02X %02X %02X %02X\n",
           (unsigned char)fp1->b0,
           (unsigned char)fp1->b1,
           (unsigned char)fp1->b2,
           (unsigned char)fp1->b3);
}

