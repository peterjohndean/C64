#!/usr/bin/env python3
"""
ds_diag9.py - locate the source of the LOG regression introduced by
the FMUL LSB-loss fix.

Symptom (post-fix): ln(0.5) returns $68,$a7,$46,$f4. Pre-fix it was
$7f,$a7,$46,$f4. Mantissa is identical; exponent is 23 ($17) lower.
That's 23 extra decrements of FP1_EXP - a systematic loop difference,
not a rounding artifact.

Hypothesis: the fix sets fp_mul_extra at FMUL's mdend, but does NOT
clear it at FMUL's OWN entry. If FMUL's operand has a negative
mantissa, the md1 -> abswap -> jsr fcompl path reaches norm1 with
whatever flag value was left over from a PRIOR FMUL, causing a
spurious fold-in that corrupts the multiplicand before the multiply
loop even starts.

This script tests the hypothesis by running FP_LOG for ln(0.5) in
several modes, each of which forcibly clears fp_mul_extra at a
specific instruction address, and comparing the returned FP1 against
the pre-fix baseline (which we can simulate by clearing at norm1
entry, thereby disabling the fold-in entirely).

Modes:
  1. baseline       - fix as-is in the binary
  2. clear@fmul     - clear flag at every fmul entry
  3. clear@fcompl   - clear flag at every fcompl entry
  4. clear@md1      - clear flag at every md1 entry
  5. clear@norm1    - clear flag at every norm1 entry (= disable fix)

If mode 2/3/4 produces the correct result ($7f,$a7,$46,$f4), the
missing clear point is the fix.

Run: PYTHONPATH=src:.:../ python3 ds_diag9.py
"""

from diag1 import mpu, LABELS, reset_state, set_fp1, set_fp2
from diag_woz import decode

SENTINEL = 0x1234


def resolve(*candidates):
    for c in candidates:
        for pfx in ('.', ''):
            key = pfx + c
            if key in LABELS:
                return LABELS[key]
    return None


FP_LOG_ADDR    = resolve('FP_LOG', 'FP_LOG_PROC')
FP_FMUL_ADDR   = resolve('fmul')
FP_FCOMPL_ADDR = resolve('fcompl')
FP_MD1_ADDR    = resolve('md1')
FP_NORM1_ADDR  = resolve('norm1')
FP_ERROR_ADDR  = resolve('FP_ERROR_PROC', 'FP_ERROR')
FP_EXTRA_ADDR  = resolve('fp_mul_extra', 'FP_MUL_EXTRA', '_fp_mul_extra')


def push_sentinel():
    r = SENTINEL - 1
    mpu.memory[0x100 + mpu.sp] = (r >> 8) & 0xFF
    mpu.sp -= 1
    mpu.memory[0x100 + mpu.sp] = r & 0xFF
    mpu.sp -= 1


def fmt_fp1():
    return tuple(mpu.memory[0x61:0x65])


def run_log(mode):
    """Run FP_LOG on ln(0.5) with the given clear-mode.
    Returns (final_fp1_bytes_or_'TRAP', norm1_count, fmul_count)."""
    reset_state()
    set_fp1(0x7F, 0x40, 0x00, 0x00)   # ln(0.5)
    set_fp2(0x80, 0x40, 0x00, 0x00)   # 1.0 as scratch
    push_sentinel()
    mpu.pc = FP_LOG_ADDR

    clear_at = None
    if mode == 'clear@fmul':    clear_at = FP_FMUL_ADDR
    elif mode == 'clear@fcompl': clear_at = FP_FCOMPL_ADDR
    elif mode == 'clear@md1':   clear_at = FP_MD1_ADDR
    elif mode == 'clear@norm1': clear_at = FP_NORM1_ADDR

    norm1_count = 0
    fmul_count = 0
    for _ in range(200000):
        pc = mpu.pc
        if clear_at is not None and pc == clear_at:
            mpu.memory[FP_EXTRA_ADDR] = 0
        if pc == FP_NORM1_ADDR:
            norm1_count += 1
        if pc == FP_FMUL_ADDR:
            fmul_count += 1
        if pc == FP_ERROR_ADDR:
            return ('TRAP', norm1_count, fmul_count)
        if pc == SENTINEL:
            return (fmt_fp1(), norm1_count, fmul_count)
        mpu.step()
    return (None, norm1_count, fmul_count)


def main():
    print("=" * 72)
    print("ds_diag9.py - LOG regression investigation")
    print("=" * 72)

    for name, addr in [('FP_LOG', FP_LOG_ADDR), ('fmul', FP_FMUL_ADDR),
                       ('fcompl', FP_FCOMPL_ADDR), ('md1', FP_MD1_ADDR),
                       ('norm1', FP_NORM1_ADDR), ('fp_mul_extra', FP_EXTRA_ADDR)]:
        s = f"${addr:04x}" if addr else "MISSING"
        print(f"  {name:16s} = {s}")
    print()

    if FP_EXTRA_ADDR is None:
        print("ERROR: fp_mul_extra not found in the label file.")
        print()
        print("Add '.export fp_mul_extra' to lib_fp.s, rebuild, and")
        print("re-run.  Or check the label file for how the symbol is")
        print("actually spelled (some builds emit it namespaced as")
        print("FP_CORE_PROC::fp_mul_extra).")
        return

    expected_correct = (0x7F, 0xA7, 0x46, 0xF4)
    expected_broken  = (0x68, 0xA7, 0x46, 0xF4)

    print(f"  expected correct : {' '.join(f'{x:02x}' for x in expected_correct)}")
    print(f"  expected broken  : {' '.join(f'{x:02x}' for x in expected_broken)}")
    print()

    for mode in ('baseline', 'clear@fmul', 'clear@fcompl',
                 'clear@md1', 'clear@norm1'):
        result, n1, nm = run_log(mode)
        if result == 'TRAP':
            tag = "TRAP"
            dec = 'n/a'
        elif result is None:
            tag = "TIMEOUT"
            dec = 'n/a'
        else:
            tag = ' '.join(f'{x:02x}' for x in result)
            try:
                dec = f"{decode(*result):.6f}"
            except Exception:
                dec = '???'
        note = ''
        if result == expected_correct:
            note = '  <= CORRECT'
        elif result == expected_broken:
            note = '  <= BROKEN (baseline symptom)'
        print(f"  {mode:14s}  FP1=[{tag}]  {dec:>12s}  "
              f"norm1={n1:4d} fmul={nm:2d}{note}")

    print()
    print("=" * 72)
    print("Interpretation:")
    print("  If 'clear@fmul' or 'clear@fcompl' or 'clear@md1' produces")
    print("  the CORRECT result while 'baseline' produces BROKEN, the")
    print("  fix is missing a clear at that specific address.")
    print("  'clear@norm1' disables the fix entirely; it provides the")
    print("  pre-fix reference value for comparison.")
    print("=" * 72)


if __name__ == '__main__':
    main()
