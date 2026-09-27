#!/usr/bin/env python3
"""
diag24.py - Sweeps FDIV's $80/$00 collision (true_diff=-128 valid
floor vs true_diff=+128 invalid one-past-ceiling) across many
mantissa combinations, specifically checking the two bugs predicted
from diag23's single-mantissa trace:

  1. true_diff=-128 + mantissa needs decrement -> predicted: silent
     corruption (the ORIGINAL norm floor-guard bug), should be
     forced zero instead.
  2. true_diff=+128 + mantissa needs decrement -> predicted: spurious
     trap on what should be a valid, rescued result at the true
     ceiling (127).

Uses is_valid_result() (canonical-zero-aware) for classification,
learned from tonight's earlier false-positive with is_normalized()
alone.
"""

import random
from diag1 import mpu, LABELS, dump_fp, run_fdiv
from diag_woz import decode, is_normalized

def is_valid_result(fp1_bytes):
    if fp1_bytes == (0, 0, 0, 0):
        return True
    return is_normalized(fp1_bytes[1:])

def split_for_true_diff(true_diff):
    base_te1 = max(-128, min(127, -true_diff // 2))
    te2 = base_te1 + true_diff
    return (base_te1 + 128) & 0xff, (te2 + 128) & 0xff

def random_mantissa():
    while True:
        b0 = random.randint(0, 255)
        if is_normalized((b0, 0, 0)):
            return (b0, random.randint(0, 255), random.randint(0, 255))

def sweep(true_diff, label, n=200, seed=0):
    random.seed(seed)
    e1, e2 = split_for_true_diff(true_diff)
    results = {}
    examples = {'trapped': [], 'zero': [], 'other': []}

    def record(bucket, m1, m2, fp1):
        results[bucket] = results.get(bucket, 0) + 1
        if len(examples.get(bucket, [])) < 3:
            examples.setdefault(bucket, []).append((m1, m2, fp1))

    for _ in range(n):
        m1 = random_mantissa()   # divisor mantissa
        m2 = random_mantissa()   # dividend mantissa
        divisor = (e1,) + m1
        dividend = (e2,) + m2
        trapped, outcome, state = run_fdiv(divisor, dividend)
        fp1 = state['FP1']
        if trapped:
            record('trapped', m1, m2, None)
        elif fp1 == (0, 0, 0, 0):
            record('zero', m1, m2, fp1)
        elif is_valid_result(fp1):
            record(f'valid:{outcome}', m1, m2, fp1)
        else:
            record('INVALID_MANTISSA', m1, m2, fp1)

    print(f"\n=== {label} (true_diff={true_diff}), {n} random cases ===")
    total = sum(results.values())
    for bucket, count in sorted(results.items()):
        pct = 100 * count / total
        print(f"  {bucket:20s}: {count:4d}/{total} ({pct:5.1f}%)")
    for bucket, exs in examples.items():
        if exs and results.get(bucket, 0) > 0:
            m1, m2, fp1 = exs[0]
            decoded = decode(*fp1) if fp1 else None
            print(f"    example[{bucket}]: divisor_m={m1} dividend_m={m2} "
                  f"-> FP1={fp1} decoded={decoded}")
    return results

print("Testing the two predicted bugs with mantissas spanning both "
      "'needs decrement' and 'already normalized' cases...\n")
sweep(-128, "VALID FLOOR")
sweep(128, "INVALID one-past-ceiling")
