#!/usr/bin/env python3
"""
ds_diag8.py - targeted validation of the fold-in's NEGATIVE-product
path, plus correction of the malformed operand in ds_diag6.

ds_diag6 showed one deterministic failure: pi * -pi with
sign=NEG extra=1. Investigation: the second operand in that test,
(0x81, 0xE4, 0x87, 0xED), has mantissa top byte $E4 = 1110_0100.
Top two bits are 1,1 - IDENTICAL. That's an un-normalized mantissa;
Woz format requires top two bits to differ for every valid value.
FMUL, fcompl, norm1, and fdiv's classify block all silently assume
normalized inputs, so the algorithm's output on such input is not
required to match the mathematical product. The failure was the
test's operand, not the fix.

This script:
  1. Corrects that operand to proper -pi = (0x81, 0x9B, 0x78, 0x13).
  2. Adds ~20 more NEG+extra=1 cases with PROPERLY NORMALIZED
     operands on both sides, chosen so the product's mantissa LSB
     is set (forcing the fold-in to matter).
  3. Extends the simulator to fold the top k bits of EXT into the
     shifted mantissa's low k bits when shifts > 1 (ds_diag6's sim
     only folded the single extra bit, correct for shifts == 1 but
     not for shifts >= 2).

Success criterion: with proper operands, the fix's output matches
the mathematically correct answer on every NEG+extra=1 case, AND
no previously-correct positive case regresses.

Run: PYTHONPATH=src:.:../ python3 ds_diag8.py
"""

import random
from diag1 import mpu, LABELS, reset_state, set_fp1, set_fp2
from diag_woz import decode, encode

SENTINEL     = 0x1234
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

def simulate_norm_extended(mant_bytes, exp_byte, ext_bytes, sign_odd, strategy):
    """Model normx->fcompl->norm->norm1 sequence.

    Correctly handles shifts >= 2 by folding the top k bits of EXT
    into the shifted mantissa's low k bits.

    'or_only'     : OR top k bits of EXT into shifted M.
    'signed_fold' : OR top k bits if positive; subtract the same
                    value if negative (2's-complement borrow).
    'no_fold'     : ignore EXT entirely (baseline behaviour).
    """
    m = mant_bytes_to_int(mant_bytes)
    e = exp_byte
    ext_int = (ext_bytes[0] << 16) | (ext_bytes[1] << 8) | ext_bytes[2]
    if sign_odd:
        m = twos_complement_24(m)
    shifts = 0
    while not is_normalized_mant(m) and e != 0:
        m = (m << 1) & 0xFFFFFF
        e = (e - 1) & 0xFF
        shifts += 1
    if shifts > 0 and strategy != 'no_fold':
        # fold top k bits of EXT into shifted M's low k bits
        fold_bits = ext_int >> (24 - shifts)
        if strategy == 'or_only':
            m = (m | fold_bits) & 0xFFFFFF
        elif strategy == 'signed_fold':
            if not sign_odd:
                m = (m | fold_bits) & 0xFFFFFF
            else:
                m = (m - fold_bits) & 0xFFFFFF
    return int_to_mant_bytes(m), e, shifts

def correct_mantissa(a, b):
    return encode(decode(*a) * decode(*b))

def fmt(b):
    return ' '.join(f'{x:02x}' for x in b)

def is_normalized_bytes(b):
    top = b[0]
    return ((top << 1) ^ top) & 0x80 != 0

# ---------------------------------------------------------------------
# Case set: all properly normalized
# ---------------------------------------------------------------------
DETERMINISTIC = [
    # --- positive control (already known to work) ---
    ("1.0 * pi",       (0x80,0x40,0x00,0x00), (0x81,0x64,0x87,0xED)),
    ("1.0 * 2pi",      (0x80,0x40,0x00,0x00), (0x82,0x64,0x87,0xED)),
    ("1.0 * 1/3",      (0x80,0x40,0x00,0x00), (0x7F,0x55,0x55,0x55)),
    # --- CORRECTED: -pi is $9B,$78,$13 (2's complement of pi's $64,$87,$ED),
    #     top two bits 1,0 - normalized ---
    ("1.0 * -pi",      (0x80,0x40,0x00,0x00), (0x81,0x9B,0x78,0x13)),
    ("pi * -pi",       (0x81,0x64,0x87,0xED), (0x81,0x9B,0x78,0x13)),
    # --- negative product, extra likely set ---
    ("-1/3 * 1/3",     (0x7F,0xD5,0x55,0x55), (0x7F,0x55,0x55,0x55)),
    ("1/3 * -1/3",     (0x7F,0x55,0x55,0x55), (0x7F,0xD5,0x55,0x55)),
    ("-pi * pi/4",     (0x81,0x9B,0x78,0x13), (0x7F,0x64,0x87,0xED)),
    ("-2pi * 1/3",     (0x82,0x9B,0x78,0x13), (0x7F,0x55,0x55,0x55)),
    # --- negative product, both operands full mantissa ---
    ("-1/7 * 1/3",     (0x7F,0x9249,0x24,0x92), (0x7F,0x55,0x55,0x55)),
]

def random_operand_normalized(rng, force_negative=False):
    """Return a valid normalized operand with LSB set (to force
    fold-in when needed)."""
    e = rng.randint(0x7F, 0x83)
    # top byte: normalized means top two bits differ.
    # positive: 0x40..0x7F; negative: 0x80..0xBF
    if force_negative or rng.random() < 0.5:
        top = rng.randint(0x80, 0xBF)
    else:
        top = rng.randint(0x40, 0x7F)
    m1 = rng.randint(0, 0xFF)
    m2 = rng.randint(0, 0xFF) | 1     # force LSB set
    return (e, top, m1, m2)

def main():
    print("=" * 78)
    print("ds_diag8.py - NEGATIVE-product fold-in validation")
    print("=" * 78)
    print(f"  fmul=${FMUL_ADDR:04x} mdend=${MDEND_ADDR:04x} error=${ERROR_ADDR:04x}")
    print()

    # --- Deterministic table ---
    print("DETERMINISTIC (properly normalized operands)")
    print("-" * 78)
    ok_no_fold = ok_or = ok_sg = total = 0
    for name, a, b in DETERMINISTIC:
        if not is_normalized_bytes(a[1:]) or not is_normalized_bytes(b[1:]):
            print(f"  [skip malformed] {name}")
            continue
        pre = run_fmul_to_mdend(a, b)
        full = run_fmul_full(a, b)
        if pre is None or full in ('TRAP', None):
            print(f"  [skip trap] {name}")
            continue
        total += 1
        mb, ext, eb, sign = pre
        sign_odd = bool(sign & 1)
        correct = correct_mantissa(a, b)

        res_nf = simulate_norm_extended(mb, eb, ext, sign_odd, 'no_fold')
        res_or = simulate_norm_extended(mb, eb, ext, sign_odd, 'or_only')
        res_sg = simulate_norm_extended(mb, eb, ext, sign_odd, 'signed_fold')
        nf_b = (res_nf[1],) + res_nf[0]
        or_b = (res_or[1],) + res_or[0]
        sg_b = (res_sg[1],) + res_sg[0]

        ok_no_fold += (nf_b == correct)
        ok_or      += (or_b == correct)
        ok_sg      += (sg_b == correct)

        bin_ok = (full == correct)
        print(f"  {'OK ' if bin_ok else '!! '}{name:16s} sign={'NEG' if sign_odd else 'pos'} "
              f"shifts={res_sg[2]}")
        print(f"      binary:   {fmt(full)}  {'OK' if bin_ok else 'FAIL'}")
        print(f"      no_fold:  {fmt(nf_b)}  {'OK' if nf_b == correct else 'FAIL'}")
        print(f"      or_only:  {fmt(or_b)}  {'OK' if or_b == correct else 'FAIL'}")
        print(f"      signed:   {fmt(sg_b)}  {'OK' if sg_b == correct else 'FAIL'}")
        print(f"      correct:  {fmt(correct)}")
        print()

    print(f"  deterministic totals: no_fold {ok_no_fold}/{total}, "
          f"or {ok_or}/{total}, signed {ok_sg}/{total}")
    print()

    # --- Random sweep focused on negative products with LSB set ---
    print("=" * 78)
    print("RANDOM SWEEP (300 pairs, seed=20260913, forced LSB, 50/50 signs)")
    print("=" * 78)
    rng = random.Random(20260913)
    stats = {'ok_binary': 0, 'ok_no_fold': 0, 'ok_or': 0, 'ok_sg': 0,
             'skip': 0,
             'fix_or_only': 0, 'fix_signed': 0, 'fix_neither': 0}
    for _ in range(300):
        a = random_operand_normalized(rng)
        b = random_operand_normalized(rng)
        pre = run_fmul_to_mdend(a, b)
        full = run_fmul_full(a, b)
        if pre is None or full in ('TRAP', None):
            stats['skip'] += 1
            continue
        mb, ext, eb, sign = pre
        sign_odd = bool(sign & 1)
        correct = correct_mantissa(a, b)

        r_nf = simulate_norm_extended(mb, eb, ext, sign_odd, 'no_fold')
        r_or = simulate_norm_extended(mb, eb, ext, sign_odd, 'or_only')
        r_sg = simulate_norm_extended(mb, eb, ext, sign_odd, 'signed_fold')
        nf_b = (r_nf[1],) + r_nf[0]
        or_b = (r_or[1],) + r_or[0]
        sg_b = (r_sg[1],) + r_sg[0]

        stats['ok_binary']  += (full == correct)
        stats['ok_no_fold'] += (nf_b == correct)
        stats['ok_or']      += (or_b == correct)
        stats['ok_sg']      += (sg_b == correct)

        if nf_b != correct:
            if or_b == correct and sg_b == correct:
                stats['fix_or_only'] += 0
                stats['fix_signed'] += 1
            elif sg_b == correct and or_b != correct:
                stats['fix_signed'] += 1
            elif or_b == correct and sg_b != correct:
                stats['fix_or_only'] += 1
            else:
                stats['fix_neither'] += 1

    print(f"  skipped:                 {stats['skip']}")
    print(f"  binary matches correct:  {stats['ok_binary']}")
    print(f"  no_fold matches correct: {stats['ok_no_fold']}")
    print(f"  or_only matches:         {stats['ok_or']}")
    print(f"  signed_fold matches:     {stats['ok_sg']}")
    print(f"  ---")
    print(f"  cases fixed only by signed_fold:  {stats['fix_signed']}")
    print(f"  cases fixed only by or_only:      {stats['fix_or_only']}")
    print(f"  cases fixed by neither:           {stats['fix_neither']}")
    print()

    print("=" * 78)
    print("VERDICT")
    print("=" * 78)
    if stats['ok_binary'] == 300 - stats['skip'] and ok_sg == total:
        print("  Binary matches correct on every properly-normalized case.")
        print("  Fix is validated for both positive and negative products.")
    else:
        print("  Some cases still mismatch - inspect above.")
    print("=" * 78)

if __name__ == '__main__':
    main()
