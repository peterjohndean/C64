#!/usr/bin/env python3
"""
diag18.py - FSUB analogue of diag17.py's poisoning test, plus a
re-check of diag16.py's near-2^127 FADD case, to confirm the
fp_norm_boundary_state reset at fadd's entry (which fsub also passes
through, via its own jmp fadd) closes the gap for BOTH operations,
not just the one already tested, and doesn't disturb anything that
was already working.
"""

from diag1 import mpu, LABELS, dump_fp, reset_state
from diag_woz import decode, encode

SENTINEL = 0x1234
FP_NORM_STATE_NORMAL  = 0
FP_NORM_STATE_CEILING = 1
FP_NORM_STATE_FLOOR   = 2

def run_traced(entry_label, fp1_bytes, fp2_bytes, poison_state=None):
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
    mpu.pc = LABELS[entry_label]
    error_addr = LABELS['.FP_ERROR_PROC']
    for _ in range(20000):
        pc = mpu.pc
        if pc == error_addr:
            return True, None, dump_fp()
        if pc == SENTINEL:
            return False, 'rts', dump_fp()
        mpu.step()
    raise RuntimeError(f"{entry_label} trace didn't finish")

# --- FSUB: FP1 = FP2 - FP1. Construct so the subtraction leaves a
#     small-magnitude result at exponent $00 needing renormalization -
#     same shape as diag17's FADD case, reached via fsub's fcompl
#     detour into fadd instead of a direct add. Use FP1=$00,20,00,00
#     (small positive) subtracted FROM a slightly larger FP2 at the
#     same exponent, so the difference is still small and near the
#     floor, exercising the same ambiguous renormalize path. ---
fp1 = (0x00, 0x20, 0x00, 0x00)
fp2 = (0x00, 0x60, 0x00, 0x00)   # FP2 - FP1 = 0.5 - (-0.5)... check via decode
print(f"FSUB: FP2({tuple(hex(b) for b in fp2)})={decode(*fp2)} "
      f"- FP1({tuple(hex(b) for b in fp1)})={decode(*fp1)}")

print("\n=== FSUB, flag=NORMAL ===")
trapped, outcome, state = run_traced('.fsub', fp1, fp2, poison_state=None)
print(f"trapped={trapped} outcome={outcome} FP1={tuple(hex(b) for b in state['FP1'])}"
      + (f"  decoded={decode(*state['FP1'])}" if not trapped else ""))

print("\n=== FSUB, flag POISONED to FLOOR ===")
trapped, outcome, state = run_traced('.fsub', fp1, fp2, poison_state=FP_NORM_STATE_FLOOR)
print(f"trapped={trapped} outcome={outcome} FP1={tuple(hex(b) for b in state['FP1'])}"
      + (f"  decoded={decode(*state['FP1'])}" if not trapped else ""))

print("\n=== FSUB, flag POISONED to CEILING ===")
trapped, outcome, state = run_traced('.fsub', fp1, fp2, poison_state=FP_NORM_STATE_CEILING)
print(f"trapped={trapped} outcome={outcome} FP1={tuple(hex(b) for b in state['FP1'])}"
      + (f"  decoded={decode(*state['FP1'])}" if not trapped else ""))

# --- re-check diag16.py's near-2^127 FADD case still works ---
a = 2.0**126 * 1.9999998
b = 2.0**126 * 1.9999998
true_sum = a + b
fp1_near = encode(a)
fp2_near = encode(b)
print(f"\n=== re-check: FADD near 2^127, flag=NORMAL ===")
trapped, outcome, state = run_traced('.fadd', fp1_near, fp2_near, poison_state=None)
print(f"trapped={trapped} outcome={outcome} FP1={tuple(hex(b) for b in state['FP1'])}")
if not trapped:
    print(f"decoded={decode(*state['FP1']):.10e}  expected={true_sum:.10e}")