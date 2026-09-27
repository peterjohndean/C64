#!/usr/bin/env python3
"""
diag15.py - Exact integer arithmetic check of the FP_FMUL mantissa
multiply for call 9 (34028120.0 * 10.0), to determine whether
340281088.0 vs 340281200.0 is a genuine mantissa-multiply bug or
within this format's own truncation-toward-zero rounding contract.
"""

# multiplier (from FP_EXT, originally FP1's mantissa) and
# multiplicand (FP2_MANT), as raw 24-bit integers
multiplier = 0x40E74B
multiplicand = 0x500000

# true, EXACT integer product (48-bit)
exact_product = multiplier * multiplicand
print(f"multiplier      = {multiplier} (0x{multiplier:06X})")
print(f"multiplicand    = {multiplicand} (0x{multiplicand:06X})")
print(f"exact 48-bit product = {exact_product} (0x{exact_product:012X})")

# the algorithm keeps only the TOP 24 bits of this 48-bit product
# (since both operands are already scaled by 2^22, the product is
# scaled by 2^44, and needs to come back down to a 2^22-scaled
# 24-bit mantissa) - shift right by 24, matching one renormalization
# bit if the top bit doesn't come out set
top_24 = exact_product >> 24
print(f"top 24 bits (>>24) = {top_24} (0x{top_24:06X})")

# what the actual hardware/simulator produced (from FP1_MANT after
# .mdend, before final normalize - $28,$90,$8e per diag14.py)
actual_mdend_mantissa = 0x28908e
print(f"\nactual .mdend mantissa (from trace) = {actual_mdend_mantissa} (0x{actual_mdend_mantissa:06X})")

print(f"\ndifference (top_24 vs actual): {top_24 - actual_mdend_mantissa}")

# check norm1's actual shift against the pre-normalize mantissa
pre_normalize = 0x28908E
shifted = (pre_normalize << 1) & 0xFFFFFF
print(f"pre_normalize={pre_normalize:06X} shifted_left_1={shifted:06X}")
print(f"actual final mantissa reported: 0x51211C")
print(f"match: {shifted == 0x51211C}")

# and what SHOULD the final answer be, computed independently
# top_24 was itself derived from >>24 of the exact 48-bit product -
# but maybe >>24 threw away a bit that should have been rounded in.
# Redo without any shift assumption: what 24-bit mantissa, at what
# exponent, makes this exactly 340281200.0?
true_value = 340281200.0
import struct
# decode via the SAME method as diag_woz, to get ground truth bytes
def encode(value):
    import math
    if value == 0: return (0,0,0,0)
    e = math.floor(math.log2(value)) + 1
    mant = value / (2.0**(e-1))
    while mant >= 2.0: mant/=2.0; e+=1
    while mant < 1.0: mant*=2.0; e-=1
    m_int = int(mant * 4194304)
    return (e-1+128, (m_int>>16)&0xFF, (m_int>>8)&0xFF, m_int&0xFF)
print("true encode(340281200.0) =", tuple(hex(b) for b in encode(true_value)))