#!/usr/bin/env python3
"""
ds_diag5.py - Python-level validation of the "extra bit fold-in" fix
for FP_FMUL's LSB loss.

Bug recap (established by ds_diag1/ds_diag4):
  After 24 iterations of FP_FMUL's shift-and-add loop, the 48-bit
  register holds the correctly-computed product, shifted right by
  24. The top 24 bits (FP1_MANT) are the truncated product mantissa,
  and the "25th bit" (the LSB of the pre-shift accumulator) sits in
  EXT[0] bit 7, having been pushed out by the final right shift.
  norm1 then shifts FP1_MANT LEFT (when needed) to normalize, but
  does NOT bring the extra bit in - so it's lost. This is why
  FP_FMUL(1.0, pi) returns $816487EC instead of $816487ED.

Previous fix attempt (ds_diag2/3/4):
  Reduce the loop count from 24 to 23, plus a compensating dec of
  FP1_EXP. This preserves the LSB but doubles the raw accumulator,
  which overflows the sign bit for products whose true mantissa MSB
  is close to bit 23 (e.g. pi/4 * pi/4 flips sign). NOT viable.

Proposed fix (this diagnostic):
  Keep 24 iterations. After the loop, if EXT[0] bit 7 is set, fold
  it back into FP1_MANT+2 bit 0 AFTER norm1's left-shift.

Method (per test case):
  1. Run real binary to "mdend" label, capture (FP1_MANT, EXT,
     FP1_EXP) - pre-norm state.
  2. Continue binary to completion - baseline output.
  3. Python-simulate current norm on the captured pre-norm state,
     verify it matches the baseline output. (Simulation sanity.)
  4. Python-simulate the MODIFIED norm (with fold-in) - fixed output.
  5. Independently compute the correct mantissa using diag_woz.
  6. Report: (baseline == correct)? (fixed == correct)?
             (fixed != baseline)?

Success criterion:
  - All cases where baseline == correct: fixed must also == correct
    (fix doesn't break working cases).
  - All cases where baseline != correct: fixed must == correct
    (fix repairs the LSB loss).

Run: PYTHONPATH=src:.:../ python3 ds_diag5.py
"""

import random

from diag1 import mpu, LABELS, reset_state, set_fp1, set_fp2
from diag_woz import decode, encode

SENTINEL = 0x1234

def resolve_label(name):
    for candidate in ('.' + name, name, '__' + name):
        if candidate in LABELS:
            return LABELS[candidate]
    return None

FMUL_ADDR  = resolve_label('fmul')
MDEND_ADDR = resolve_label('mdend')
ERROR_ADDR = resolve_label('FP_ERROR_PROC') or resolve_label('FP_ERROR')

if not all([FMUL_ADDR, MDEND_ADDR, ERROR_ADDR]):
    raise SystemExit(f"Required labels not found: "
                     f"fmul={FMUL_ADDR} mdend={MDEND_ADDR} error={ERROR_ADDR}")

def push_sentinel():
    ret_addr = SENTINEL - 1
    mpu.memory[0x100 + mpu.sp] = (ret_addr >> 8) & 0xFF
    mpu.sp -= 1
    mpu.memory[0x100 + mpu.sp] = ret_addr & 0xFF
    mpu.sp -= 1

def run_fmul_to_mdend(fp1, fp2, max_steps=20000):
    """Run FMUL from entry to mdend. Return (FP1_MANT, FP_EXT, FP1_EXP)."""
    reset_state()
    set_fp1(*fp1)
    set_fp2(*fp2)
    push_sentinel()
    mpu.pc = FMUL_ADDR
    for _ in range(max_steps):
        if mpu.pc == MDEND_ADDR:
            return (tuple(mpu.memory[0x62:0x65]),
                    tuple(mpu.memory[0x65:0x68]),
                    mpu.memory[0x61])
        if mpu.pc == ERROR_ADDR:
            return None
        mpu.step()
    return None

def run_fmul_full(fp1, fp2, max_steps=20000):
    """Run FMUL to completion. Return FP1 bytes, or 'TRAP'."""
    reset_state()
    set_fp1(*fp1)
    set_fp2(*fp2)
    push_sentinel()
    mpu.pc = FMUL_ADDR
    for _ in range(max_steps):
        if mpu.pc == ERROR_ADDR:
            return 'TRAP'
        if mpu.pc == SENTINEL:
            return tuple(mpu.memory[0x61:0x65])
        mpu.step()
    return None

def is_normalized_mant(mant_int):
    b = (mant_int >> 16) & 0xFF
    return ((b << 1) ^ b) & 0x80 != 0

def mant_bytes_to_int(mant_bytes):
    v = (mant_bytes[0] << 16) | (mant_bytes[1] << 8) | mant_bytes[2]
    return v

def int_to_mant_bytes(v):
    v = v & 0xFFFFFF
    return ((v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF)

def simulate_norm(mant_bytes, exp_byte, extra_bit, apply_fix):
    """Simulate the current norm algorithm. If apply_fix, fold in
    the extra bit after the FIRST shift (matching the case that
    actually needs it). Returns (mant_bytes, exp_byte, shifts)."""
    m = mant_bytes_to_int(mant_bytes)
    e = exp_byte
    shifts = 0
    while not is_normalized_mant(m):
        if e == 0:
            break  # ambiguous case, stop (assume NORMAL state)
        m = (m << 1) & 0xFFFFFF
        e = (e - 1) & 0xFF
        shifts += 1
    if apply_fix and extra_bit and shifts == 1:
        m = m | 1
    return int_to_mant_bytes(m), e, shifts

def correct_mantissa(a_bytes, b_bytes):
    a_val = decode(*a_bytes)
    b_val = decode(*b_bytes)
    return encode(a_val * b_val)

def format_bytes(b):
    return ' '.join(f'{x:02x}' for x in b)

TEST_CASES = [
    ("1.0 * pi",       (0x80,0x40,0x00,0x00), (0x81,0x64,0x87,0xED)),
    ("1.0 * 2pi",      (0x80,0x40,0x00,0x00), (0x82,0x64,0x87,0xED)),
    ("1.0 * 1/3",      (0x80,0x40,0x00,0x00), (0x7F,0x55,0x55,0x55)),
    ("1.0 * 10",       (0x80,0x40,0x00,0x00), (0x83,0x50,0x00,0x00)),
    ("10 * 10",        (0x83,0x50,0x00,0x00), (0x83,0x50,0x00,0x00)),
    ("12 * -5",        (0x83,0x60,0x00,0x00), (0x82,0xB0,0x00,0x00)),
    ("pi/4 * pi/4",    (0x7F,0x64,0x87,0xED), (0x7F,0x64,0x87,0xED)),
    ("1.5 * 1.5",      (0x80,0x60,0x00,0x00), (0x80,0x60,0x00,0x00)),
    ("pi * pi",        (0x81,0x64,0x87,0xED), (0x81,0x64,0x87,0xED)),
    ("0.5 * 0.5",      (0x7F,0x40,0x00,0x00), (0x7F,0x40,0x00,0x00)),
    ("0.7 * 0.9",      (0x7F,0x59,0x99,0x9A), (0x7F,0x73,0x33,0x33)),
    ("1.234 * 5.678",  (0x80,0x4D,0xFA,0xE1), (0x82,0x5C,0xC2,0x8F)),
]

def main():
    print("=" * 78)
    print("ds_diag5.py - FMUL LSB-loss fix validation (Python-level)")
    print("=" * 78)
    print(f"  fmul  @ ${FMUL_ADDR:04x}")
    print(f"  mdend @ ${MDEND_ADDR:04x}")
    print(f"  error @ ${ERROR_ADDR:04x}")

    opc = mpu.memory[MDEND_ADDR]
    print(f"  sanity: byte @ mdend = ${opc:02x} "
          f"({'LSR - OK' if opc == 0x46 else 'unexpected'})")
    print()

    sim_match       = 0
    total           = 0
    baseline_fail   = 0
    fix_succeeds    = 0
    fix_regression  = 0
    fix_still_wrong = 0

    for name, a, b in TEST_CASES:
        pre = run_fmul_to_mdend(a, b)
        if pre is None:
            print(f"  [skip] {name}: trap/timeout at mdend")
            continue
        total += 1
        fp1_mant_bytes, ext_bytes, exp_byte = pre
        baseline_bytes = run_fmul_full(a, b)
        if baseline_bytes == 'TRAP' or baseline_bytes is None:
            print(f"  [skip] {name}: trap/timeout in full run")
            continue

        extra_bit = (ext_bytes[0] >> 7) & 1

        sim_base_mant, sim_base_exp, shifts = simulate_norm(
            fp1_mant_bytes, exp_byte, extra_bit, apply_fix=False)
        sim_base_bytes = (sim_base_exp,) + sim_base_mant

        sim_fix_mant, sim_fix_exp, _ = simulate_norm(
            fp1_mant_bytes, exp_byte, extra_bit, apply_fix=True)
        sim_fix_bytes = (sim_fix_exp,) + sim_fix_mant

        correct_bytes = correct_mantissa(a, b)

        sim_match += (sim_base_bytes == baseline_bytes)
        baseline_ok = (baseline_bytes == correct_bytes)
        fixed_ok = (sim_fix_bytes == correct_bytes)

        if not baseline_ok:
            baseline_fail += 1
            if fixed_ok:
                fix_succeeds += 1
            else:
                fix_still_wrong += 1
        elif not fixed_ok:
            fix_regression += 1

        tag = "OK " if fixed_ok else "!! "
        print(f"  {tag}{name:18s} extra={extra_bit} shifts={shifts} "
              f"pre={format_bytes(fp1_mant_bytes)}+{format_bytes(ext_bytes)}")
        print(f"      binary:  {format_bytes(baseline_bytes)}"
              + ("  (matches sim)" if sim_base_bytes == baseline_bytes
                 else "  (SIM MISMATCH)"))
        print(f"      fixed:   {format_bytes(sim_fix_bytes)}")
        print(f"      correct: {format_bytes(correct_bytes)}")
        if not baseline_ok and fixed_ok:
            print(f"      >>> FIXED (was wrong, now right)")
        elif not baseline_ok and not fixed_ok:
            print(f"      >>> STILL WRONG")
        elif baseline_ok and not fixed_ok:
            print(f"      >>> REGRESSION (was right, now wrong)")
        print()

    print("=" * 78)
    print("SUMMARY (deterministic cases)")
    print("=" * 78)
    print(f"  cases tested:                  {total}")
    print(f"  simulation matched binary:     {sim_match}/{total}")
    print(f"  baseline failures (LSB loss):  {baseline_fail}")
    print(f"  fixed by proposed patch:       {fix_succeeds}")
    print(f"  still wrong after patch:       {fix_still_wrong}")
    print(f"  regressions after patch:       {fix_regression}")
    print()

    # ---- random sweep ----
    print("=" * 78)
    print("RANDOM SWEEP (50 pairs, seed=42)")
    print("=" * 78)

    random.seed(42)
    sweep_ok_before_and_after = 0
    sweep_fixed                = 0
    sweep_regress              = 0
    sweep_still_wrong          = 0
    sweep_skipped              = 0

    for _ in range(50):
        a_mant = random.randint(0x400000, 0x7FFFFF)
        b_mant = random.randint(0x400000, 0x7FFFFF)
        a_exp  = random.randint(0x7F, 0x83)
        b_exp  = random.randint(0x7F, 0x83)
        a = (a_exp, (a_mant >> 16) & 0xFF, (a_mant >> 8) & 0xFF, a_mant & 0xFF)
        b = (b_exp, (b_mant >> 16) & 0xFF, (b_mant >> 8) & 0xFF, b_mant & 0xFF)

        pre = run_fmul_to_mdend(a, b)
        baseline_bytes = run_fmul_full(a, b)
        if pre is None or baseline_bytes in ('TRAP', None):
            sweep_skipped += 1
            continue

        fp1_mant_bytes, ext_bytes, exp_byte = pre
        extra_bit = (ext_bytes[0] >> 7) & 1

        sim_fix_mant, sim_fix_exp, _ = simulate_norm(
            fp1_mant_bytes, exp_byte, extra_bit, apply_fix=True)
        sim_fix_bytes = (sim_fix_exp,) + sim_fix_mant

        correct_bytes = correct_mantissa(a, b)

        base_ok = (baseline_bytes == correct_bytes)
        fix_ok  = (sim_fix_bytes   == correct_bytes)

        if base_ok and fix_ok:
            sweep_ok_before_and_after += 1
        elif not base_ok and fix_ok:
            sweep_fixed += 1
        elif base_ok and not fix_ok:
            sweep_regress += 1
        else:
            sweep_still_wrong += 1

    print(f"  skipped (trap or mdend timeout):        {sweep_skipped}")
    print(f"  correct before AND after fix:          {sweep_ok_before_and_after}")
    print(f"  broken before, fixed after:            {sweep_fixed}")
    print(f"  correct before, broken after:          {sweep_regress}")
    print(f"  broken before AND after fix:           {sweep_still_wrong}")
    print()
    print("=" * 78)
    if fix_regression == 0 and sweep_regress == 0:
        print("  VERDICT: no regressions detected.")
        if fix_succeeds > 0 or sweep_fixed > 0:
            print("  Fix repairs LSB loss on the expected cases.")
        else:
            print("  (No LSB-loss cases hit - try more failing inputs.)")
    else:
        print("  VERDICT: regressions detected - fix needs more work.")
    print("=" * 78)

if __name__ == '__main__':
    main()
