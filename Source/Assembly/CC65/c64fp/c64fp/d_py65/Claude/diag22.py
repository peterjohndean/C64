#!/usr/bin/env python3
"""
diag22.py - Checks whether diag2.py's FDIV FLOOR sweep's 204/204
BLOCKED_WRONG results are ACTUALLY correct canonical-zero outcomes,
mislabeled by is_normalized() not special-casing zero (the same
false-positive class already found and fixed for FMUL's own floor
sweep earlier tonight, but never applied to sweep_fdiv_straddle_point).
"""

from diag1 import mpu, LABELS, dump_fp, run_fdiv
from diag2 import split_exponents_div, provisional_exponent, random_mantissa_bytes
from diag_woz import decode, is_normalized

te_diff = -129
e1, e2 = split_exponents_div(te_diff)

print("=== Sampling 10 of the sweep's own random cases directly ===")
import random
random.seed(0)
all_zero = True
for i in range(10):
    m1 = random_mantissa_bytes()
    m2 = random_mantissa_bytes()
    divisor = (e1,) + m1
    dividend = (e2,) + m2
    trapped, outcome, state = run_fdiv(divisor, dividend)
    fp1 = state['FP1']
    is_canonical_zero = (fp1 == (0, 0, 0, 0))
    is_norm = is_normalized(fp1[1:])
    all_zero &= is_canonical_zero
    print(f"case {i}: divisor_mant={m1} dividend_mant={m2} "
          f"-> FP1={tuple(hex(b) for b in fp1)} "
          f"canonical_zero={is_canonical_zero} is_normalized={is_norm} "
          f"decoded={decode(*fp1)}")

print(f"\nAll 10 sampled cases are canonical zero: {all_zero}")
print("(if True, this confirms the sweep's BLOCKED_WRONG label is a "
      "false positive from is_normalized() not special-casing zero - "
      "the actual code is behaving correctly)")
