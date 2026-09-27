#!/usr/bin/env python3
"""
diag10.py - Find one concrete FLOOR-straddle mantissa pair that
produces .rts1_BLOCKED_WRONG, then trace norm's decision logic
(the FP1_EXP==0 branch) instruction-by-instruction to see exactly
why it doesn't route to @force_underflow for that case.
"""

import random
from diag1 import mpu, LABELS, dump_fp, reset_state, provisional_exponent
from diag2 import classify_state_for, split_exponents, random_mantissa, is_normalized, FP_NORM_BOUNDARY_STATE_ADDR

te_sum = -129
e1, e2 = split_exponents(te_sum)
prov_exp = provisional_exponent(e1, e2)

SENTINEL = 0x1234

def run_and_check(m1, m2, seed_note=""):
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
    if mpu.pc == LABELS['.rts1'] and not is_normalized(mpu.memory[0x62:0x65]):
        return 'BLOCKED_WRONG'
    # if mpu.pc == LABELS['.rts1'] and not is_normalized(mpu.memory[0x61:0x65]):
#         return 'BLOCKED_WRONG'
    if mpu.pc == SENTINEL:
        return 'via_sentinel'
    return 'other'

# find one reproducible BLOCKED_WRONG case
random.seed(0)
found = None
for i in range(200):
    m1 = random_mantissa()
    m2 = random_mantissa()
    result = run_and_check(m1, m2)
    if result == 'BLOCKED_WRONG':
        found = (m1, m2)
        print(f"found BLOCKED_WRONG at random draw {i}: m1={m1} m2={m2}")
        break

if not found:
    print("no BLOCKED_WRONG case found in 200 draws - unexpected given the 70% rate")
else:
    m1, m2 = found
    print(f"\n=== tracing mdend onward for m1={m1} m2={m2} ===\n")
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

    addr_to_label = {}
    for name, a in LABELS.items():
        addr_to_label.setdefault(a, name)

    mdend_addr = LABELS['.mdend']
    seen = False
    for step in range(1500):
        pc = mpu.pc
        if pc == mdend_addr:
            seen = True
        if seen:
            label = addr_to_label.get(pc, '')
            print(f"step {step:5d}  PC=${pc:04x} {label:20s} opcode=${mpu.memory[pc]:02x} "
                  f"A={mpu.a:02x} FP1_EXP=${mpu.memory[0x61]:02x} "
                  f"fp_norm_boundary_state=${mpu.memory[FP_NORM_BOUNDARY_STATE_ADDR]:02x}")
        mpu.step()
        if seen and pc in (LABELS['.rts1'], SENTINEL):
            break
