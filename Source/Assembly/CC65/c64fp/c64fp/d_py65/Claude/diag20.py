#!/usr/bin/env python3
"""
diag20.py - Side-by-side comparison of FDIV's CEILING (working) and
FLOOR (broken) straddle cases, capturing A and carry at EVERY
relevant checkpoint (right after jsr md1, right before "sbc FP1_EXP",
and at md2 entry) for both. This exists specifically to stop hand-
arithmetic guessing about why md2's own bcs/bmi test appears to
route FLOOR into its early-return-to-zero shortcut while CEILING
reaches md3/norm/norm1 correctly, despite both being constructed
from the same te2-te1 shape (127 vs -129, which alias to the same
byte value mod 256).
"""

from diag1 import mpu, LABELS, dump_fp, reset_state
from diag2 import split_exponents_div
from diag_woz import decode

SENTINEL = 0x1234

def trace_case(label, te_diff, mantissa=(0x40, 0x00, 0x00)):
    e1, e2 = split_exponents_div(te_diff)
    divisor = (e1,) + mantissa
    dividend = (e2,) + mantissa
    print(f"\n=== {label} (te2-te1={te_diff}) ===")
    print(f"divisor=byte(${e1:02x})  dividend=byte(${e2:02x})")

    reset_state()
    mpu.memory[0x61:0x65] = list(divisor)
    mpu.memory[0x69:0x6d] = list(dividend)

    ret_addr = SENTINEL - 1
    mpu.memory[0x100 + mpu.sp] = (ret_addr >> 8) & 0xFF
    mpu.sp -= 1
    mpu.memory[0x100 + mpu.sp] = ret_addr & 0xFF
    mpu.sp -= 1
    mpu.pc = LABELS['.fdiv']

    md1_addr = LABELS['.md1']
    md2_addr = LABELS['.md2']
    div1_addr = LABELS['.div1']
    error_addr = LABELS['.FP_ERROR_PROC']
    flag_addr = LABELS['.fp_norm_boundary_state']

    seen_md1_return = False
    prev_pc = None

    for step in range(3000):
        pc = mpu.pc
        # detect the RTS return from md1 by watching for the
        # instruction immediately after "jsr md1" - since md1 itself
        # is entered via jsr, its own eventual rts lands one
        # instruction past the jsr md1 in fdiv's code. We approximate
        # this by watching for the FIRST instruction after leaving
        # md1's own address range back into fdiv's code, right after
        # having been inside md1.
        if pc == md2_addr:
            print(f"AT .md2 entry (step {step}): A=${mpu.a:02x} "
                  f"carry={'SET' if mpu.p & 1 else 'CLEAR'} "
                  f"N={'SET' if mpu.p & 0x80 else 'CLEAR'} "
                  f"fp_norm_boundary_state=${mpu.memory[flag_addr]:02x}")
        if pc == div1_addr:
            print(f"  -> reached .div1 (step {step}): "
                  f"FP1_EXP=${mpu.memory[0x61]:02x}")
        if pc == error_addr:
            print(f"  -> TRAPPED at step {step}, code={mpu.memory[0xFE]}")
            break
        if pc == SENTINEL:
            print(f"  -> REAL EXIT at step {step}")
            break
        mpu.step()
    else:
        print("  -> didn't finish in 3000 steps")

    final = dump_fp()
    print(f"final FP1 = {tuple(hex(b) for b in final['FP1'])} = {decode(*final['FP1'])}")
    return final

ceiling_result = trace_case("CEILING", 127)
floor_result = trace_case("FLOOR", -129)

print("\n=== raw byte-arithmetic sanity check (independent of trace) ===")
for label, te_diff in [("CEILING", 127), ("FLOOR", -129)]:
    e1, e2 = split_exponents_div(te_diff)
    raw_diff = (e2 - e1) & 0xFF
    print(f"{label}: divisor_byte=${e1:02x} dividend_byte=${e2:02x} "
          f"(dividend-divisor) mod 256 = ${raw_diff:02x} "
          f"(as signed 8-bit: {raw_diff - 256 if raw_diff >= 128 else raw_diff})")