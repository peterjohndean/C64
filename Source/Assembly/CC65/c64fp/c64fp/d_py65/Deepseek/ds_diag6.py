#!/usr/bin/env python3
"""
ds_diag6.py - fcompl-aware validation of the FMUL LSB-loss fix.

ds_diag5 established:
  - FMUL's LSB loss is real and lives at EXT[0] bit 7 after mdend.
  - Folding that bit into M2 after the first norm1 shift repairs the
    positive-product cases (1.0*pi, 1.0*2pi, 1.0*1/3).
  - One apparent "regression" (12 * -5) was a simulation artifact -
    the sim didn't model fcompl's 2's-complement negation that runs
    BEFORE norm for negative products.

ds_diag6 adds:
  1. fcompl modeling in the simulator.
  2. Sign-aware fold-in strategies, tested against ground truth.
  3. Extended random sweep with mixed-sign operand pairs and full
     mantissa patterns.

Two strategies tested per case:
  'or_only'    - OR #1 into M2 after the first shift, regardless of
                 sign. (ds_diag5's hypothesis.)
  'signed_fold'- OR #1 if positive, DEC (subtract 1 with borrow
                 propagation) if negative. (New hypothesis: the
                 trailing bit represents a positive magnitude
                 addition; when the register has been negated by
                 fcompl, adding to its LSB moves the value in the
                 wrong direction, so we must subtract instead.)

The one whose simulated output matches the mathematically-correct
mantissa on every case (positive, negative, and mixed signs) is the
one to implement in the source patch.

Run: PYTHONPATH=src:.:../ python3 ds_diag6.py
"""

import random
from diag1 import mpu, LABELS, reset_state, set_fp1, set_fp2
from diag_woz import decode, encode

SENTINEL = 0x1234
FP_SIGN_ADDR = 0x02

def resolve_label(name):
    for cand in ('.' + name, name, '__' + name):
        if cand in LABELS:
            return LABELS[cand]
    return None

FMUL_ADDR  = resolve_label('fmul')
MDEND_ADDR = resolve_label('mdend')
ERROR_ADDR = resolve_label('FP_ERROR_PROC') or resolve_label('FP_ERROR')

def push_sentinel():
    r = SENTINEL - 1
    mpu.memory[0x100 + mpu.sp] = (r >> 8) & 0xFF
    mpu.sp -= 1
    mpu.memory[0x100 + mpu.sp] = r & 0xFF
    mpu.sp -= 1

def run_fmul_to_mdend(fp1, fp2, max_steps=20000):
    """Return (FP1_MANT_bytes, EXT_bytes, FP1_EXP, fp_sign) at mdend,
    or None on trap/timeout."""
    reset_state()
    set_fp1(*fp1); set_fp2(*fp2); push_sentinel()
    mpu.pc = FMUL_ADDR
    for _ in range(max_steps):
        if mpu.pc == MDEND_ADDR:
            return (tuple(mpu.memory[0x62:0x65]),
                    tuple(mpu.memory[0x65:0x68]),
                    mpu.memory[0x61],
                    mpu.memory[FP_SIGN_ADDR])
        if mpu.pc == ERROR_ADDR:
            return None
        mpu.step()
    return None

def run_fmul_full(fp1, fp2, max_steps=20000):
    reset_state()
    set_fp1(*fp1); set_fp2(*fp2); push_sentinel()
    mpu.pc = FMUL_ADDR
    for _ in range(max_steps):
        if mpu.pc == ERROR_ADDR: return 'TRAP'
        if mpu.pc == SENTINEL:   return tuple(mpu.memory[0x61:0x65])
        mpu.step()
    return None

def mant_bytes_to_int(mb):
    return (mb[0] << 16) | (mb[1] << 8) | mb[2]

def int_to_mant_bytes(v):
    v &= 0xFFFFFF
    return ((v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF)

def is_normalized_mant(v):
    b = (v >> 16) & 0xFF
    return ((b << 1) ^ b) & 0x80 != 0

def twos_complement_24(m):
    return (0x1000000 - (m & 0xFFFFFF)) & 0xFFFFFF

def simulate_norm(mant_bytes, exp_byte, extra_bit, sign_odd, strategy):
    """Simulate the post-mdend norm path.

    Sign handling: if sign_odd, the register value becomes
    fcompl(mant_bytes) before norm1's shift chain runs (matching the
    real binary's normx->fcompl->addend->norm route).

    Fold-in: on the FIRST shift only, if extra_bit is set:
      'or_only'    : m |= 1
      'signed_fold': if not sign_odd: m |= 1
                     else:            m -= 1
    """
    m = mant_bytes_to_int(mant_bytes)
    e = exp_byte
    if sign_odd:
        m = twos_complement_24(m)
    shifts = 0
    folded = False
    while not is_normalized_mant(m) and e != 0:
        m = (m << 1) & 0xFFFFFF
        e = (e - 1) & 0xFF
        shifts += 1
        if extra_bit and not folded:
            if strategy == 'or_only':
                m = m | 1
            elif strategy == 'signed_fold':
                if not sign_odd:
                    m = m | 1
                else:
                    m = (m - 1) & 0xFFFFFF
            folded = True
    return int_to_mant_bytes(m), e, shifts

def correct_mantissa(a, b):
    return encode(decode(*a) * decode(*b))

def fmt(b):
    return ' '.join(f'{x:02x}' for x in b)

DETERMINISTIC = [
    ("1.0 * pi",       (0x80,0x40,0x00,0x00), (0x81,0x64,0x87,0xED)),
    ("1.0 * 2pi",      (0x80,0x40,0x00,0x00), (0x82,0x64,0x87,0xED)),
    ("1.0 * 1/3",      (0x80,0x40,0x00,0x00), (0x7F,0x55,0x55,0x55)),
    ("1.0 * 10",       (0x80,0x40,0x00,0x00), (0x83,0x50,0x00,0x00)),
    ("10 * 10",        (0x83,0x50,0x00,0x00), (0x83,0x50,0x00,0x00)),
    ("12 * -5",        (0x83,0x60,0x00,0x00), (0x82,0xB0,0x00,0x00)),
    ("-12 * 5",        (0x83,0xA0,0x00,0x00), (0x83,0x50,0x00,0x00)),
    ("-12 * -5",       (0x83,0xA0,0x00,0x00), (0x82,0xB0,0x00,0x00)),
    ("pi/4 * pi/4",    (0x7F,0x64,0x87,0xED), (0x7F,0x64,0x87,0xED)),
    ("pi * pi",        (0x81,0x64,0x87,0xED), (0x81,0x64,0x87,0xED)),
    ("pi * -pi",       (0x81,0x64,0x87,0xED), (0x81,0xE4,0x87,0xED)),
    ("1.5 * 1.5",      (0x80,0x60,0x00,0x00), (0x80,0x60,0x00,0x00)),
    ("1/3 * 1/3",      (0x7F,0x55,0x55,0x55), (0x7F,0x55,0x55,0x55)),
    ("1/3 * -1/3",     (0x7F,0x55,0x55,0x55), (0x7F,0xD5,0x55,0x55)),
    ("0.5 * 0.5",      (0x7F,0x40,0x00,0x00), (0x7F,0x40,0x00,0x00)),
    ("-1.5 * -1.5",    (0x80,0xA0,0x00,0x00), (0x80,0xA0,0x00,0x00)),
    ("7 * -11",        (0x82,0x70,0x00,0x00), (0x83,0xB0,0x00,0x00)),
]

def random_operand(allow_negative):
    e = random.randint(0x7F, 0x83)
    top = random.randint(0x40, 0x7F)
    if allow_negative and random.random() < 0.5:
        top = random.randint(0x80, 0xBF)
    m2 = random.randint(0, 0xFF)
    m3 = random.randint(0, 0xFF)
    # bias towards full mantissas (LSB set) so LSB-loss cases appear
    if random.random() < 0.6:
        m3 |= 1
    return (e, top, m2, m3)

def main():
    print("=" * 78)
    print("ds_diag6.py - fcompl-aware validation of FMUL LSB-loss fix")
    print("=" * 78)
    print(f"  fmul=${FMUL_ADDR:04x} mdend=${MDEND_ADDR:04x} error=${ERROR_ADDR:04x}")
    print()

    print("DETERMINISTIC CASES")
    print("-" * 78)
    or_only_ok  = 0
    signed_ok   = 0
    total       = 0

    for name, a, b in DETERMINISTIC:
        pre = run_fmul_to_mdend(a, b)
        full = run_fmul_full(a, b)
        if pre is None or full in ('TRAP', None):
            print(f"  [skip] {name}")
            continue
        total += 1
        mb, ext, eb, sign = pre
        extra_bit = (ext[0] >> 7) & 1
        sign_odd  = bool(sign & 1)
        correct   = correct_mantissa(a, b)

        or_m, or_e, _ = simulate_norm(mb, eb, extra_bit, sign_odd, 'or_only')
        sg_m, sg_e, _ = simulate_norm(mb, eb, extra_bit, sign_odd, 'signed_fold')
        or_b = (or_e,) + or_m
        sg_b = (sg_e,) + sg_m

        or_ok = (or_b == correct)
        sg_ok = (sg_b == correct)
        or_only_ok += or_ok
        signed_ok  += sg_ok
        bin_ok = (full == correct)

        tag = "OK " if (or_ok and sg_ok) else ("OR!" if or_ok else ("SG!" if sg_ok else "!! "))
        print(f"  {tag}{name:14s} sign={'NEG' if sign_odd else 'pos'} "
              f"extra={extra_bit}")
        print(f"      binary:       {fmt(full)}  {'(correct)' if bin_ok else '(LSB LOSS)'}")
        print(f"      or_only:      {fmt(or_b)}  {'OK' if or_ok else 'FAIL'}")
        print(f"      signed_fold:  {fmt(sg_b)}  {'OK' if sg_ok else 'FAIL'}")
        print(f"      correct:      {fmt(correct)}")
        print()

    print("=" * 78)
    print(f"  deterministic: or_only OK {or_only_ok}/{total}, "
          f"signed_fold OK {signed_ok}/{total}")
    print()

    # ---- extended random sweep ----
    print("=" * 78)
    print("RANDOM SWEEP (300 pairs, seed=20260912, mixed signs)")
    print("=" * 78)
    random.seed(20260912)
    stats = {'or_ok': 0, 'sg_ok': 0, 'bin_ok': 0, 'skip': 0,
             'or_fix': 0, 'sg_fix': 0, 'or_regress': 0, 'sg_regress': 0,
             'both_fix': 0, 'only_sg_fix': 0, 'only_or_fix': 0,
             'neither_fix': 0}

    for _ in range(300):
        a = random_operand(allow_negative=True)
        b = random_operand(allow_negative=True)
        pre = run_fmul_to_mdend(a, b)
        full = run_fmul_full(a, b)
        if pre is None or full in ('TRAP', None):
            stats['skip'] += 1
            continue
        mb, ext, eb, sign = pre
        extra_bit = (ext[0] >> 7) & 1
        sign_odd  = bool(sign & 1)
        correct   = correct_mantissa(a, b)

        or_m, or_e, _ = simulate_norm(mb, eb, extra_bit, sign_odd, 'or_only')
        sg_m, sg_e, _ = simulate_norm(mb, eb, extra_bit, sign_odd, 'signed_fold')
        or_b = (or_e,) + or_m
        sg_b = (sg_e,) + sg_m

        bin_ok = (full == correct)
        or_ok  = (or_b == correct)
        sg_ok  = (sg_b == correct)
        stats['bin_ok'] += bin_ok
        stats['or_ok']  += or_ok
        stats['sg_ok']  += sg_ok

        if not bin_ok:
            if or_ok and sg_ok:    stats['both_fix'] += 1
            elif not or_ok and sg_ok: stats['only_sg_fix'] += 1
            elif or_ok and not sg_ok: stats['only_or_fix'] += 1
            else:                   stats['neither_fix'] += 1
        else:
            if not or_ok: stats['or_regress'] += 1
            if not sg_ok: stats['sg_regress'] += 1

    print(f"  skipped (trap/timeout):          {stats['skip']}")
    print(f"  binary already correct:          {stats['bin_ok']}")
    print(f"  or_only  correct:                {stats['or_ok']}")
    print(f"  signed   correct:                {stats['sg_ok']}")
    print()
    print(f"  LSB-loss cases both strategies fixed:   {stats['both_fix']}")
    print(f"  LSB-loss cases ONLY signed_fold fixed:  {stats['only_sg_fix']}")
    print(f"  LSB-loss cases ONLY or_only fixed:      {stats['only_or_fix']}")
    print(f"  LSB-loss cases NEITHER fixed:           {stats['neither_fix']}")
    print(f"  or_only regressions (was ok, now fail): {stats['or_regress']}")
    print(f"  signed  regressions (was ok, now fail): {stats['sg_regress']}")
    print()

    print("=" * 78)
    print("VERDICT")
    print("=" * 78)
    if stats['sg_regress'] == 0 and stats['sg_ok'] >= stats['or_ok']:
        print("  signed_fold: no regressions, matches or beats or_only.")
        if stats['only_sg_fix'] > 0:
            print("  -> signed_fold is REQUIRED for negative products.")
            print("  -> Source patch must be SIGN-AWARE (OR for positive,")
            print("     DEC for negative mantissas).")
        else:
            print("  -> signed_fold and or_only equivalent on this sweep;")
            print("     signed_fold is still the safer choice.")
    elif stats['or_regress'] == 0 and stats['or_ok'] > stats['sg_ok']:
        print("  or_only: fewer regressions than signed_fold.")
        print("  -> Source patch stays simple (unconditional OR).")
    else:
        print("  Both strategies have regressions - investigate.")
    print("=" * 78)

if __name__ == '__main__':
    main()
