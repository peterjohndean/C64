#!/usr/bin/env python3
"""
ds_diag3.py - Conditional FMUL-specific patch test.

ds_diag2.py results:
  - Unconditional patch (Y=$16, dec FP1_EXP) fixed all LSB cases.
  - But broke two CEILING cases: t26 (trap -> value) and t27 (off by 1).
  - t15 (CEILING) and t16 (FLOOR) were unaffected either way.

Hypothesis: the patch's "dec FP1_EXP" interferes with the classify
state that md2's ovchk/norm/norm1 defer to. If we only apply the patch
when fp_norm_boundary_state == NORMAL (no CEILING/FLOOR rescue is
pending), the classify-affected paths keep the baseline behaviour.

This script tests both "always" (baseline of ds_diag2's patch), and
"conditional" (patch only if state == NORMAL), on the same set plus
a few extra full-mantissa NORMAL cases.

Run: python3 ds_diag3.py
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
FLAG_ADDR = LABELS['.fp_norm_boundary_state']
FP_NORM_STATE_NORMAL  = 0
FP_NORM_STATE_CEILING = 1
FP_NORM_STATE_FLOOR   = 2

def state_name(v):
    return {0: 'NORMAL', 1: 'CEILING', 2: 'FLOOR'}.get(v, f'?{v}')

def run_fmul(fp1, fp2, patch_mode='conditional'):
    """patch_mode:
         'none'        - baseline (24 iterations, no exponent change)
         'always'      - unconditional patch (ds_diag2 behaviour)
         'conditional' - patch only if state == NORMAL
    """
    reset_state()
    set_fp1(*fp1)
    set_fp2(*fp2)
    push_sentinel()
    mpu.pc = LABELS['.fmul']

    patched = False
    state_at_md3 = None
    error_addr = LABELS['.FP_ERROR_PROC']
    for _ in range(50000):
        pc = mpu.pc
        if pc == CLC_ADDR and not patched:
            state_at_md3 = mpu.memory[FLAG_ADDR]
            apply = False
            if patch_mode == 'always':
                apply = True
            elif patch_mode == 'conditional':
                apply = (state_at_md3 == FP_NORM_STATE_NORMAL)
            if apply:
                mpu.y = 0x16
                mpu.memory[0x61] = (mpu.memory[0x61] - 1) & 0xFF
                patched = True
        if pc == error_addr:
            return True, 'trapped', dump_fp(), state_at_md3
        if pc == SENTINEL:
            return False, 'returned', dump_fp(), state_at_md3
        mpu.step()
    return None, 'timeout', dump_fp(), state_at_md3

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

def report(label, expected, trapped, state, state_at_md3):
    if trapped:
        got = "TRAP"
    else:
        got = hex_str(state['FP1'])
    if expected == "TRAP":
        ok = trapped
    else:
        exp_bytes = tuple(int(x, 16) for x in expected.split())
        ok = (not trapped) and state['FP1'] == exp_bytes
    marker = "OK  " if ok else "FAIL"
    st = state_name(state_at_md3) if state_at_md3 is not None else '?'
    print(f"  [{marker}] {label:34s} state@md3={st:8s} "
          f"expect={expected:14s} got={got}")
    return ok

# ---------------------------------------------------------------------
print("=" * 78)
print("Conditional FMUL patch test")
print("=" * 78)
print(f"  clc intercept @ ${CLC_ADDR:04x}")
print(f"  state flag @ ${FLAG_ADDR:04x}")
print()

# ---------------------------------------------------------------------
# Test data
# ---------------------------------------------------------------------
PI        = (0x81, 0x64, 0x87, 0xED)
TWO_PI    = (0x82, 0x64, 0x87, 0xED)
ONE_THIRD = (0x7F, 0x55, 0x55, 0x55)
TWO_THIRD = (0x80, 0x55, 0x55, 0x55)
ONE       = (0x80, 0x40, 0x00, 0x00)
TEN       = (0x83, 0x50, 0x00, 0x00)
TWELVE    = (0x83, 0x60, 0x00, 0x00)
NEG_FIVE  = (0x82, 0xB0, 0x00, 0x00)

FMUL_TESTS = [
    # LSB cases (full mantissas) - the ones the patch is meant to fix
    ("FMUL(1.0, pi)   LSB",      ONE, PI,        "81 64 87 ED"),
    ("FMUL(1.0, 2pi)  LSB",      ONE, TWO_PI,    "82 64 87 ED"),
    ("FMUL(1.0, 1/3)  LSB",      ONE, ONE_THIRD, "7f 55 55 55"),
    ("FMUL(pi, pi)    LSB",      PI,  PI,        None),   # informational
    ("FMUL(2/3, 2/3)  LSB",      TWO_THIRD, TWO_THIRD, None),
    # Controls (sparse mantissas)
    ("FMUL(1.0, 10)   ctrl",     ONE, TEN,       "83 50 00 00"),
    ("FMUL(10, 10)    ctrl",     TEN, TEN,       "86 64 00 00"),
    ("FMUL(12, -5)    ctrl",     TWELVE, NEG_FIVE, "85 88 00 00"),
    # Boundary cases (from tr_exp_boundary_all.s)
    ("FMUL t15 ceiling",  (0xC0,0x40,0x00,0x00), (0xBF,0x40,0x00,0x00), "ff 40 00 00"),
    ("FMUL t16 floor",    (0x40,0x40,0x00,0x00), (0x40,0x40,0x00,0x00), "00 40 00 00"),
    ("FMUL t26 ceil trap",(0xBF,0x84,0xF8,0xCF), (0xC0,0x9B,0xF4,0xB7), "TRAP"),
    ("FMUL t27 ceil resc",(0xBF,0x6F,0x47,0x90), (0xC0,0x47,0x30,0x80), "ff 7b c7 b6"),
]

FDIV_TESTS = [
    ("FDIV(pi, pi)",   PI, PI,     "80 40 00 00"),
    ("FDIV(2pi, 2pi)", TWO_PI, TWO_PI, "80 40 00 00"),
]

# ---------------------------------------------------------------------
# BASELINE
# ---------------------------------------------------------------------
print("--- BASELINE (no patch) ---")
for label, fp1, fp2, expected in FMUL_TESTS:
    trapped, outcome, state, st_md3 = run_fmul(fp1, fp2, patch_mode='none')
    if expected is None:
        got = "TRAP" if trapped else hex_str(state['FP1'])
        print(f"  [info] {label:34s} state@md3={state_name(st_md3):8s} got={got}")
    else:
        report(label, expected, trapped, state, st_md3)

# ---------------------------------------------------------------------
# ALWAYS PATCH (ds_diag2 behaviour, for reference)
# ---------------------------------------------------------------------
print()
print("--- ALWAYS PATCH (reference, from ds_diag2) ---")
for label, fp1, fp2, expected in FMUL_TESTS:
    trapped, outcome, state, st_md3 = run_fmul(fp1, fp2, patch_mode='always')
    if expected is None:
        got = "TRAP" if trapped else hex_str(state['FP1'])
        print(f"  [info] {label:34s} state@md3={state_name(st_md3):8s} got={got}")
    else:
        report(label, expected, trapped, state, st_md3)

# ---------------------------------------------------------------------
# CONDITIONAL PATCH
# ---------------------------------------------------------------------
print()
print("--- CONDITIONAL PATCH (only if state == NORMAL) ---")
all_ok = True
for label, fp1, fp2, expected in FMUL_TESTS:
    trapped, outcome, state, st_md3 = run_fmul(fp1, fp2, patch_mode='conditional')
    if expected is None:
        got = "TRAP" if trapped else hex_str(state['FP1'])
        print(f"  [info] {label:34s} state@md3={state_name(st_md3):8s} got={got}")
    else:
        all_ok &= report(label, expected, trapped, state, st_md3)

print()
print("--- FDIV (must be unaffected) ---")
for label, fp1, fp2, expected in FDIV_TESTS:
    trapped, outcome, state = run_fdiv(fp1, fp2)
    exp_bytes = tuple(int(x, 16) for x in expected.split())
    ok = (not trapped) and state['FP1'] == exp_bytes
    all_ok &= ok
    marker = "OK  " if ok else "FAIL"
    got = "TRAP" if trapped else hex_str(state['FP1'])
    print(f"  [{marker}] {label:34s} expect={expected:14s} got={got}")

print()
print("=" * 78)
if all_ok:
    print("ALL CONDITIONAL PATCH TESTS PASSED")
else:
    print("SOME TESTS FAILED - see above")
print("=" * 78)
