#!/usr/bin/env python3
"""
diag26.py - Finds ONE concrete, confirmed example from the FMUL
OVERFLOW STRADDLE sweep's 'trapped' bucket (the ~28.4% "already
normalized, genuine overflow, CEILING correctly traps" cases the
harness fix revealed) and ONE from the 'returned' bucket (the
~71.6% "needs decrement, correctly rescued" cases) - both with
their exact byte-level results - so tr_exp_boundary_all.s's new
test cases use REAL, confirmed operand/result pairs rather than
hand-constructed ones.
"""

import random
from diag2 import (run_mul_loop_from, split_exponents, provisional_exponent, random_mantissa)
from diag_woz import decode, is_valid_result

te_sum = 127
e1, e2 = split_exponents(te_sum)
prov_exp = provisional_exponent(e1, e2)
print(f"e1=${e1:02x} e2=${e2:02x} prov_exp=${prov_exp:02x}\n")

random.seed(0)
found_trapped = None
found_returned = None
for i in range(200):
    m1 = random_mantissa()
    m2 = random_mantissa()
    trapped, outcome, state = run_mul_loop_from(prov_exp, m1, m2, te_sum)
    if trapped and found_trapped is None:
        found_trapped = (m1, m2)
    if (not trapped) and found_returned is None:
        found_returned = (m1, m2, state['FP1'])
    if found_trapped and found_returned:
        break

print("=== CONFIRMED trapped example (already normalized, genuine overflow) ===")
if found_trapped:
    m1, m2 = found_trapped
    print(f"multiplier_mant (FP1) = {tuple(hex(b) for b in m1)}")
    print(f"multiplicand_mant (FP2) = {tuple(hex(b) for b in m2)}")
    print(f"full FP1 operand bytes: ({e1:#04x},) + {m1}")
    print(f"full FP2 operand bytes: ({e2:#04x},) + {m2}")
else:
    print("none found in 200 draws (unexpected given ~28% rate)")

print("\n=== CONFIRMED returned example (needs decrement, rescued to CEILING) ===")
if found_returned:
    m1, m2, fp1 = found_returned
    print(f"multiplier_mant (FP1) = {tuple(hex(b) for b in m1)}")
    print(f"multiplicand_mant (FP2) = {tuple(hex(b) for b in m2)}")
    print(f"full FP1 operand bytes: ({e1:#04x},) + {m1}")
    print(f"full FP2 operand bytes: ({e2:#04x},) + {m2}")
    print(f"confirmed result FP1 = {tuple(hex(b) for b in fp1)} = {decode(*fp1)}")
