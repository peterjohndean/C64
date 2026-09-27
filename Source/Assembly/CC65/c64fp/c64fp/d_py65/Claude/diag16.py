#!/usr/bin/env python3
"""
diag16.py - Empirical construction + trace of FADD/FSUB analogues of
last night's FMUL CEILING/FLOOR boundary cases, to check whether
fp_norm_boundary_state (set ONLY by fmul/fdiv's classify block) causes
a false-negative (FADD/FSUB gets no rescue at the ambiguous
FP1_EXP==0 point) or false-positive (a stale flag value from an
earlier, unrelated fmul/fdiv call incorrectly fires for an ordinary
FADD/FSUB result).
"""

from diag1 import mpu, LABELS, dump_fp, reset_state
from diag_woz import decode, encode

SENTINEL = 0x1234

def run_fadd_traced(fp1_bytes, fp2_bytes, poison_state=None):
    """poison_state: if not None, deliberately writes this value into
    fp_norm_boundary_state BEFORE calling fadd, simulating a leftover
    value from an earlier, unrelated fmul/fdiv call - exactly what a
    real program's call sequence could produce, since nothing resets
    this flag except norm1/rts1's own one-shot consume."""
    reset_state()
    mpu.memory[0x61:0x65] = list(fp1_bytes)
    mpu.memory[0x69:0x6d] = list(fp2_bytes)
    flag_addr = LABELS['.fp_norm_boundary_state']
    if poison_state is not None:
        mpu.memory[flag_addr] = poison_state
    ret_addr = SENTINEL - 1
    mpu.memory[0x100 + mpu.sp] = (ret_addr >> 8) & 0xFF
    mpu.sp -= 1
    mpu.memory[0x100 + mpu.sp] = ret_addr & 0xFF
    mpu.sp -= 1
    entry_sp = mpu.sp
    mpu.pc = LABELS['.fadd']
    error_addr = LABELS['.FP_ERROR_PROC']
    for _ in range(20000):
        pc = mpu.pc
        if pc == error_addr:
            return True, None, dump_fp()
        if pc == SENTINEL:
            return False, 'rts', dump_fp()
        mpu.step()
    raise RuntimeError("fadd trace didn't finish")

def run_fsub_traced(fp1_bytes, fp2_bytes, poison_state=None):
    reset_state()
    mpu.memory[0x61:0x65] = list(fp1_bytes)
    mpu.memory[0x69:0x6d] = list(fp2_bytes)
    flag_addr = LABELS['.fp_norm_boundary_state']
    if poison_state is not None:
        mpu.memory[flag_addr] = poison_state
    ret_addr = SENTINEL - 1
    mpu.memory[0x100 + mpu.sp] = (ret_addr >> 8) & 0xFF
    mpu.sp -= 1
    mpu.memory[0x100 + mpu.sp] = ret_addr & 0xFF
    mpu.sp -= 1
    mpu.pc = LABELS['.fsub']
    error_addr = LABELS['.FP_ERROR_PROC']
    for _ in range(20000):
        pc = mpu.pc
        if pc == error_addr:
            return True, None, dump_fp()
        if pc == SENTINEL:
            return False, 'rts', dump_fp()
        mpu.step()
    raise RuntimeError("fsub trace didn't finish")

FP_NORM_STATE_NORMAL  = 0
FP_NORM_STATE_CEILING = 1
FP_NORM_STATE_FLOOR   = 2

# --- Construct a genuine FADD CEILING case empirically: two values
#     whose true sum lands exactly at the format's ceiling (2^127),
#     via an addition that requires a norm1-style renormalization. ---
# Pick two values near the top of the range whose sum straddles the
# boundary such that the aligned mantissa addition produces a carry
# needing exactly the ambiguous FP1_EXP==0 decrement.
a = 2.0**126 * 1.9999998
b = 2.0**126 * 1.9999998
true_sum = a + b
print(f"FADD case: {a:.10e} + {b:.10e} = {true_sum:.10e} (2^127={2.0**127:.10e})")
fp1 = encode(a)
fp2 = encode(b)
print(f"encoded: FP1={tuple(hex(x) for x in fp1)}  FP2={tuple(hex(x) for x in fp2)}")

print("\n=== FADD, flag=NORMAL (fresh reset_state, the REAL default) ===")
trapped, outcome, state = run_fadd_traced(fp1, fp2, poison_state=None)
print(f"trapped={trapped} outcome={outcome} FP1={tuple(hex(b) for b in state['FP1'])}")
if not trapped:
    print(f"decoded = {decode(*state['FP1']):.10e}  expected = {true_sum:.10e}")

print("\n=== FADD, flag POISONED to CEILING (simulating leftover fmul state) ===")
trapped, outcome, state = run_fadd_traced(fp1, fp2, poison_state=FP_NORM_STATE_CEILING)
print(f"trapped={trapped} outcome={outcome} FP1={tuple(hex(b) for b in state['FP1'])}")
if not trapped:
    print(f"decoded = {decode(*state['FP1']):.10e}  expected = {true_sum:.10e}")