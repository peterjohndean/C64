#!/usr/bin/env python3
"""
diag17.py - Construct the FADD/FSUB FLOOR analogue directly: two
operands ALREADY at exponent $00 (true exp -128, the documented
floor - see labels_fp.s), whose mantissa sum needs a LEFT-shift
(decrement) to renormalize - the exact ambiguous case norm1 can't
safely handle without fp_norm_boundary_state, which fadd/fsub never
set.
"""

from diag1 import mpu, LABELS, dump_fp, reset_state
from diag_woz import decode

SENTINEL = 0x1234
FP_NORM_STATE_NORMAL  = 0
FP_NORM_STATE_CEILING = 1
FP_NORM_STATE_FLOOR   = 2

def run_fadd_traced(fp1_bytes, fp2_bytes, poison_state=None):
    reset_state()
    mpu.memory[0x61:0x65] = list(fp1_bytes)
    mpu.memory[0x69:0x6d] = list(fp2_bytes)
    if poison_state is not None:
        mpu.memory[LABELS['.fp_norm_boundary_state']] = poison_state
    ret_addr = SENTINEL - 1
    mpu.memory[0x100 + mpu.sp] = (ret_addr >> 8) & 0xFF
    mpu.sp -= 1
    mpu.memory[0x100 + mpu.sp] = ret_addr & 0xFF
    mpu.sp -= 1
    mpu.pc = LABELS['.fadd']
    error_addr = LABELS['.FP_ERROR_PROC']
    for _ in range(20000):
        pc = mpu.pc
        if pc == error_addr:
            return True, None, dump_fp()
        if pc == SENTINEL:
            return False, 'rts', dump_fp()
        mpu.step()
    raise RuntimeError("didn't finish")

# Two operands at exponent $00 (true floor, per labels_fp.s), each
# with a SMALL mantissa - $20,00,00 (top two bits 0,0 - NOT
# normalized on its own, matching FMUL's own unnorm_at_floor case
# from diag1.py's CASES, which is a real, reachable state per that
# test) - their sum, still at exponent $00, needs one left-shift to
# become properly normalized.
fp1 = (0x00, 0x20, 0x00, 0x00)
fp2 = (0x00, 0x20, 0x00, 0x00)
print(f"FP1={fp1} FP2={fp2}")

print("\n=== FADD, flag=NORMAL (real default) ===")
trapped, outcome, state = run_fadd_traced(fp1, fp2, poison_state=None)
print(f"trapped={trapped} outcome={outcome} FP1={tuple(hex(b) for b in state['FP1'])}")

print("\n=== FADD, flag POISONED to FLOOR ===")
trapped, outcome, state = run_fadd_traced(fp1, fp2, poison_state=FP_NORM_STATE_FLOOR)
print(f"trapped={trapped} outcome={outcome} FP1={tuple(hex(b) for b in state['FP1'])}")

print("\n=== FADD, flag POISONED to CEILING ===")
trapped, outcome, state = run_fadd_traced(fp1, fp2, poison_state=FP_NORM_STATE_CEILING)
print(f"trapped={trapped} outcome={outcome} FP1={tuple(hex(b) for b in state['FP1'])}")