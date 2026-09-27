#!/usr/bin/env python3
"""
diag11.py - Direct instrumentation of sweep_straddle_point's own
random-case loop for the OVERFLOW straddle, printing exactly what
is_normalized() sees and returns for each .rts1 hit - since the
[1:] slice fix made no observable difference, meaning the earlier
diagnosis was wrong somewhere.
"""

import random
from diag1 import mpu, LABELS, dump_fp, reset_state, provisional_exponent
from diag2 import classify_state_for, split_exponents, random_mantissa, is_normalized, FP_NORM_BOUNDARY_STATE_ADDR

te_sum = 127
e1, e2 = split_exponents(te_sum)
prov_exp = provisional_exponent(e1, e2)
SENTINEL = 0x1234

def run_once(m1, m2):
    reset_state()
    mpu.memory[0x61] = prov_exp
    mpu.memory[0x62:0x65] = [0, 0, 0]
    mpu.memory[0x65:0x68] = list(m1)
    mpu.memory[0x6a:0x6d] = list(m2)
    mpu.memory[FP_NORM_BOUNDARY_STATE_ADDR] = classify_state_for(te_sum)
    mpu.y = 0x17
    ret_addr = SENTINEL - 1
    mpu.memory[0x100 + mpu.sp] = (ret_addr >> 8) & 0xFF
    mpu.sp -= 1
    mpu.memory[0x100 + mpu.sp] = ret_addr & 0xFF
    mpu.sp -= 1
    mpu.pc = LABELS['.mul1']
    targets = {LABELS['.zero_exponent'], LABELS['.rts1'], LABELS['.norm1'], SENTINEL}
    for _ in range(2000):
        if mpu.pc in targets:
            break
        mpu.step()
    return dump_fp()

random.seed(0)
for i in range(5):
    m1 = random_mantissa()
    m2 = random_mantissa()
    state = run_once(m1, m2)
    fp1_full = state['FP1']
    fp1_mant_only = fp1_full[1:]
    norm_full = is_normalized(fp1_full)
    norm_mant = is_normalized(fp1_mant_only)
    print(f"draw {i}: m1={m1} m2={m2}")
    print(f"  final FP1 = {tuple(hex(b) for b in fp1_full)}")
    print(f"  is_normalized(full 4-byte)   = {norm_full}")
    print(f"  is_normalized(mantissa only) = {norm_mant}")
    print()