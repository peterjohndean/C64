#!/usr/bin/env python3
"""
diag5.py - Independent Woz/Rankin format encode/decode, self-tested
against every constant this project has already confirmed elsewhere
(1.0, -1.0, 10.0, 12.0, boundary_1.0's 2^127 case), THEN used to
decode "12*-5"'s own FP2 operand and check whether it's actually
-5.0 at all - before trusting any further comparison against the
simulator's FMUL output.

This removes hand-arithmetic entirely from the loop: every number
below is computed, not eyeballed.
"""

def decode(exp, m0, m1, m2):
    """value = (m / 2^22) * 2^(exp-128), where m is the 24-bit
    two's-complement signed integer from the 3 mantissa bytes,
    MSB first. Derived from labels_fp.s's own bit-layout diagram."""
    m = (m0 << 16) | (m1 << 8) | m2
    if m0 & 0x80:
        m -= 0x1000000
    return (m / 4194304.0) * (2.0 ** (exp - 128))

def encode(value):
    """Inverse of decode(), truncating toward zero (this library's
    documented convention). Returns (exp, m0, m1, m2)."""
    if value == 0:
        return (0, 0, 0, 0)
    sign = -1 if value < 0 else 1
    mag = abs(value)
    import math
    e = math.floor(math.log2(mag)) + 1   # smallest e such that mag < 2^e
    # normalize mantissa into [1.0, 2.0)
    mant = mag / (2.0 ** (e - 1))
    while mant >= 2.0:
        mant /= 2.0
        e += 1
    while mant < 1.0:
        mant *= 2.0
        e -= 1
    m_int = int(mant * 4194304)   # truncate toward zero, matching
                                   # this library's own convention
    if sign < 0:
        m_int = -m_int
        m_int &= 0xFFFFFF          # 24-bit two's complement
    exp_byte = e - 1 + 128
    m0 = (m_int >> 16) & 0xFF
    m1 = (m_int >> 8) & 0xFF
    m2 = m_int & 0xFF
    return (exp_byte, m0, m1, m2)

# --- self-test against EVERY constant this project has already
#     independently confirmed, before trusting decode() for anything
#     new. If any of these fail, stop - don't trust the rest. ---
SELF_TEST = [
    ("1.0",   (0x80,0x40,0x00,0x00), 1.0),
    ("-1.0",  (0x7f,0x80,0x00,0x00), -1.0),
    ("10.0",  (0x83,0x50,0x00,0x00), 10.0),
    ("12.0",  (0x83,0x60,0x00,0x00), 12.0),
    ("boundary_1.0 result", (0xff,0x40,0x00,0x00), 2.0**127),
    ("7.5 (VICE-confirmed FP_TO_ASCII_SCI_V2 output)", (0x82,0x78,0x00,0x00), 7.5),
]

if __name__ == '__main__':
    print("=== self-test: decode() against known-good constants ===")
    all_ok = True
    for name, bytes4, expected in SELF_TEST:
        got = decode(*bytes4)
        ok = abs(got - expected) < 1e-6 * max(1, abs(expected))
        all_ok &= ok
        print(f"  {name:35s}: decoded={got!r:20}  expected={expected!r}  "
              f"{'OK' if ok else 'MISMATCH - STOP, do not trust decode()'}")
    if not all_ok:
        raise SystemExit("decode() failed self-test - fix before proceeding")
    print("\ndecode() is self-consistent with every known-good constant.\n")

    print("=== what does FP2=$82,88,00,00 actually decode to? ===")
    fp2_actual = decode(0x82, 0x88, 0x00, 0x00)
    print(f"  FP2 = $82,88,00,00 -> {fp2_actual}")
    print(f"  (the test case is NAMED '12*-5', implying this should be -5.0)")

    print("\n=== what SHOULD 12.0 * FP2 equal? ===")
    expected_product = 12.0 * fp2_actual
    print(f"  12.0 * {fp2_actual} = {expected_product}")
    exp_bytes = encode(expected_product)
    print(f"  encode({expected_product}) -> "
          f"${exp_bytes[0]:02x},{exp_bytes[1]:02x},{exp_bytes[2]:02x},{exp_bytes[3]:02x}")

    print("\n=== compare against the simulator's ACTUAL FMUL(12.0, FP2) output ===")
    print(f"  actual (from your VICE FP_TO_ASCII_SCI_V2 check): $82,78,00,00 = 7.5")
    actual_decoded = decode(0x82, 0x78, 0x00, 0x00)
    print(f"  actual decoded value: {actual_decoded}")
    print(f"  MATCH: {'YES' if abs(actual_decoded - expected_product) < 1e-6 else 'NO - real discrepancy'}")
    