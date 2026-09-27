#!/usr/bin/env python3
"""
diag27.py - Poisoning test for the NEW FP_NORM_ENTRY wrapper
(DeepSeek finding 1.3). Constructs a direct FP_NORM call (bypassing
FADD/FSUB/FMUL/FDIV entirely, the way lib_fp_from_uint16.s/
from_int24.s/from_uint24.s actually call it) that lands on the
SAME ambiguous FP1_EXP==0-still-needs-decrement branch used
throughout tonight's investigation, then checks whether the result
depends on fp_norm_boundary_state being poisoned beforehand -
exactly the diag17.py/diag18.py pattern that found and confirmed
the FADD/FSUB gap.

REQUIRES: lib_fp.s rebuilt with BOTH:
  - FP_NORM_ENTRY/FP_NEGATE_ENTRY added
  - ::FP_NORM = FP_NORM_ENTRY (not the bare `norm` label)
before this can show a PASS - run this FIRST against the
UNPATCHED build to confirm the vulnerability is real (should show
three DIFFERENT results), then again against the patched build to
confirm the fix (should show three IDENTICAL results).
"""

from diag1 import mpu, LABELS, dump_fp, reset_state
from diag_woz import decode

SENTINEL = 0x1234
FP_NORM_STATE_NORMAL  = 0
FP_NORM_STATE_CEILING = 1
FP_NORM_STATE_FLOOR   = 2

def run_fp_norm_direct(fp1_exp, fp1_mant, poison_state=None):
    """Calls FP_NORM directly - the way lib_fp_from_uint16.s etc.
    actually do - with NO FADD/FSUB/FMUL/FDIV entry-point reset
    protecting it. poison_state simulates whatever an earlier,
    completely unrelated FMUL/FDIV call left behind."""
    reset_state()
    mpu.memory[0x61] = fp1_exp
    mpu.memory[0x62:0x65] = list(fp1_mant)
    if poison_state is not None:
        mpu.memory[LABELS['.fp_norm_boundary_state']] = poison_state
    ret_addr = SENTINEL - 1
    mpu.memory[0x100 + mpu.sp] = (ret_addr >> 8) & 0xFF
    mpu.sp -= 1
    mpu.memory[0x100 + mpu.sp] = ret_addr & 0xFF
    mpu.sp -= 1
    mpu.pc = LABELS['.FP_NORM']   # the EXPORTED symbol - this is
                                   # the actual test: does it resolve
                                   # to the raw `norm` label, or the
                                   # new FP_NORM_ENTRY wrapper?
    error_addr = LABELS['.FP_ERROR_PROC']
    for _ in range(20000):
        pc = mpu.pc
        if pc == error_addr:
            return True, dump_fp()
        if pc == SENTINEL:
            return False, dump_fp()
        mpu.step()
    raise RuntimeError("didn't reach a final exit in 20000 steps")

# FP1_EXP=$01, mantissa=$10,00,00 - needs TWO left-shifts to
# normalize (top two bits stay 0,0 even after one shift), landing
# EXACTLY on FP1_EXP==0 still needing another decrement - the
# precise ambiguous branch this whole investigation is about.
fp1_exp = 0x01
fp1_mant = (0x10, 0x00, 0x00)

print("=== FP_NORM, direct external-style call, flag=NORMAL (honest default) ===")
trapped, state = run_fp_norm_direct(fp1_exp, fp1_mant, poison_state=None)
print(f"trapped={trapped} FP1={tuple(hex(b) for b in state['FP1'])}")
if not trapped:
    print(f"decoded={decode(*state['FP1'])}")
baseline = state['FP1']

print("\n=== FP_NORM, SAME input, flag POISONED to CEILING ===")
trapped_c, state_c = run_fp_norm_direct(fp1_exp, fp1_mant, poison_state=FP_NORM_STATE_CEILING)
print(f"trapped={trapped_c} FP1={tuple(hex(b) for b in state_c['FP1'])}")
if not trapped_c:
    print(f"decoded={decode(*state_c['FP1'])}")

print("\n=== FP_NORM, SAME input, flag POISONED to FLOOR ===")
trapped_f, state_f = run_fp_norm_direct(fp1_exp, fp1_mant, poison_state=FP_NORM_STATE_FLOOR)
print(f"trapped={trapped_f} FP1={tuple(hex(b) for b in state_f['FP1'])}")
if not trapped_f:
    print(f"decoded={decode(*state_f['FP1'])}")

print("\n=== Conclusion ===")
all_match = (trapped == trapped_c == trapped_f) and \
            (trapped or (state['FP1'] == state_c['FP1'] == state_f['FP1']))
if all_match:
    print("All three IDENTICAL -> FP_NORM_ENTRY wrapper is correctly "
          "protecting external callers from stale flag state. FIX CONFIRMED.")
else:
    print("Results DIFFER depending on prior flag state -> external "
          "callers of FP_NORM are STILL vulnerable. Either the wrapper "
          "wasn't applied, or ::FP_NORM still points at the bare "
          "`norm` label instead of FP_NORM_ENTRY.")
