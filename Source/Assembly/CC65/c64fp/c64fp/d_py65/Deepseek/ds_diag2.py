#!/usr/bin/env python3
"""
ds_diag2.py - Simulator-side test of the FMUL-specific iteration-count
fix.

Background (from ds_diag1.py's milestone and iteration traces):
  - FP_FMUL(1.0, pi) returns $81,$64,$87,$EC - one ulp low - because the
    24th iteration's right-shift moves the accumulator's LSB into
    FP_EXT[0] bit 7, where norm never reads it.
  - Reducing the loop to 23 iterations preserves the LSB, but halves the
    result unless FP1_EXP is decremented to compensate.
  - Directly patching md3's `ldy #$17` breaks FDIV, because md3 is
    shared between FMUL and FDIV.

This script tests the FMUL-specific version: intercept PC at the `clc`
instruction immediately following `jsr md2` in FMUL (which is only
reachable via the FMUL path), and apply `Y = $16; dec FP1_EXP` exactly
once per call. FDIV is untouched.

Test set:
  - FMUL(1.0, pi) / FMUL(1.0, 2pi) / FMUL(1.0, 1/3)  -- the failing cases
  - FMUL(1.0, 10) / FMUL(10, 10) / FMUL(12, -5)      -- must not regress
  - FMUL boundary: t15 (ceiling), t16 (floor), t26 (trap), t27 (rescue)
  - FDIV(pi, pi) / FDIV(2pi, 2pi)                    -- must be unaffected

Run: python3 ds_diag2.py
"""

from diag1 import mpu, LABELS, reset_state, set_fp1, set_fp2, dump_fp
from diag_woz import decode

SENTINEL = 0x1234

def push_sentinel():
    ret_addr = SENTINEL - 1
    mpu.memory[0x100 + mpu.sp] = (ret_addr >> 8) & 0xFF
    mpu.sp -= 1
    mpu.memory[0x100 + mpu.sp] = ret_addr & 0xFF
    mpu.sp -= 1

CLC_ADDR = LABELS['.mul1'] - 1

def run_fmul(fp1, fp2, patch=False):
    reset_state()
    set_fp1(*fp1)
    set_fp2(*fp2)
    push_sentinel()
    mpu.pc = LABELS['.fmul']

    patched_this_call = False
    error_addr = LABELS['.FP_ERROR_PROC']
    for _ in range(50000):
        pc = mpu.pc
        if patch and pc == CLC_ADDR and not patched_this_call:
            mpu.y = 0x16
            mpu.memory[0x61] = (mpu.memory[0x61] - 1) & 0xFF
            patched_this_call = True
        if pc == error_addr:
            return True, 'trapped', dump_fp()
        if pc == SENTINEL:
            return False, 'returned', dump_fp()
        mpu.step()
    return None, 'timeout', dump_fp()

def run_fdiv(fp1, fp2):
    reset_state()
    set_fp1(*fp1)
    set_fp2(*fp2)
    push_sentinel()
    mpu.pc = LABELS['.fdiv']
    error_addr = LABELS['.FP_ERROR_PROC']
    for _ in range(50000):
        pc = mpu.pc
        if pc == error_addr:
            return True, 'trapped', dump_fp()
        if pc == SENTINEL:
            return False, 'returned', dump_fp()
        mpu.step()
    return None, 'timeout', dump_fp()

def hex_str(fp1):
    return ' '.join(f'{b:02x}' for b in fp1)

def report(label, expected, trapped, outcome, state):
    if trapped:
        got = "TRAPPED"
    else:
        got = hex_str(state['FP1'])
    if expected == "TRAP":
        ok = trapped
        exp_str = "TRAP"
    else:
        exp_bytes = tuple(int(x, 16) for x in expected.split())
        ok = (not trapped) and state['FP1'] == exp_bytes
        exp_str = expected
    marker = "OK  " if ok else "FAIL"
    extra = ''
    if not trapped and state['FP1'] != (0, 0, 0, 0):
        try:
            extra = f"  decoded={decode(*state['FP1'])}"
        except Exception:
            pass
    print(f"  [{marker}] {label:38s} expect={exp_str:14s} got={got}{extra}")
    return ok

# ---------------------------------------------------------------------
# Sanity check the intercept address
# ---------------------------------------------------------------------
print("=" * 72)
print("FMUL-specific iteration-count patch - test suite")
print("=" * 72)
print()
print(f"  clc intercept @ ${CLC_ADDR:04x} = ${mpu.memory[CLC_ADDR]:02x} "
      f"({'CLC - OK' if mpu.memory[CLC_ADDR] == 0x18 else 'UNEXPECTED'})")
print()

# ---------------------------------------------------------------------
# Test data
# ---------------------------------------------------------------------
PI   = (0x81, 0x64, 0x87, 0xED)
TWO_PI = (0x82, 0x64, 0x87, 0xED)
ONE_THIRD = (0x7F, 0x55, 0x55, 0x55)
ONE  = (0x80, 0x40, 0x00, 0x00)
TEN  = (0x83, 0x50, 0x00, 0x00)
TWELVE = (0x83, 0x60, 0x00, 0x00)
NEG_FIVE = (0x82, 0xB0, 0x00, 0x00)

FMUL_TESTS = [
    ("FMUL(1.0, pi)   [LSB case]", ONE, PI, "81 64 87 ED"),
    ("FMUL(1.0, 2pi)  [LSB case]", ONE, TWO_PI, "82 64 87 ED"),
    ("FMUL(1.0, 1/3)  [LSB case]", ONE, ONE_THIRD, "7f 55 55 55"),
    ("FMUL(1.0, 10)   [sparse]",   ONE, TEN, "83 50 00 00"),
    ("FMUL(10, 10)    [sparse]",   TEN, TEN, "86 64 00 00"),
    ("FMUL(12, -5)    [signed]",   TWELVE, NEG_FIVE, "85 88 00 00"),
    # Boundary cases - expected values taken from tr_exp_boundary_all.s
    ("FMUL ceiling t15",  (0xC0,0x40,0x00,0x00), (0xBF,0x40,0x00,0x00), "ff 40 00 00"),
    ("FMUL floor t16",    (0x40,0x40,0x00,0x00), (0x40,0x40,0x00,0x00), "00 40 00 00"),
    ("FMUL ceil t26",     (0xBF,0x84,0xF8,0xCF), (0xC0,0x9B,0xF4,0xB7), "TRAP"),
    ("FMUL resc t27",     (0xBF,0x6F,0x47,0x90), (0xC0,0x47,0x30,0x80), "ff 7b c7 b6"),
]

FDIV_TESTS = [
    ("FDIV(pi, pi)   [must not change]", PI, PI, "80 40 00 00"),
    ("FDIV(2pi, 2pi) [must not change]", TWO_PI, TWO_PI, "80 40 00 00"),
]

# ---------------------------------------------------------------------
# Baseline
# ---------------------------------------------------------------------
print("--- BASELINE (no patch) ---")
for label, fp1, fp2, expected in FMUL_TESTS:
    trapped, outcome, state = run_fmul(fp1, fp2, patch=False)
    report(label, expected, trapped, outcome, state)

print()
print("--- PATCHED (FMUL-specific: Y=$16, dec FP1_EXP after md2) ---")
for label, fp1, fp2, expected in FMUL_TESTS:
    trapped, outcome, state = run_fmul(fp1, fp2, patch=True)
    report(label, expected, trapped, outcome, state)

print()
print("--- FDIV (unpatched, sanity check) ---")
for label, fp1, fp2, expected in FDIV_TESTS:
    trapped, outcome, state = run_fdiv(fp1, fp2)
    report(label, expected, trapped, outcome, state)

print()
print("=" * 72)
print("DONE")
print("=" * 72)
print()
print("INTERPRETATION")
print("--------------")
print("If the patched column shows OK across all FMUL tests AND the")
print("baseline column shows FAIL on the LSB cases, the FMUL-specific")
print("patch is the fix. The FDIV tests are the crucial control: if")
print("they pass, md3 is genuinely untouched for division.")
print()
print("If any boundary test (t15/t16/t26/t27) fails under the patch, the")
print("dec FP1_EXP interacts with md2's classify state (which runs before")
print("md2), and a per-path fix at the FMUL entry point alone is not")
print("sufficient - the classify block would need to be adjusted to see")
print("the adjusted exponent.")
