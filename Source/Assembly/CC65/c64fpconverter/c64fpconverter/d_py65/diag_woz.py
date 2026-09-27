#!/usr/bin/env python3
"""
diag_woz.py - Independent Woz/Rankin format encode/decode, used
throughout this project's diagnostic scripts as GROUND TRUTH,
computed independently of the py65 simulator or any hand arithmetic.

Self-tests on import against every constant this project has
independently confirmed elsewhere (via VICE hardware traces or
FP_TO_ASCII_SCI output) - if these fail, something is wrong with
THIS module, and nothing that imports it should be trusted until
it's fixed.
"""

import math

def decode(exp, m0, m1, m2):
    """value = (m / 2^22) * 2^(exp-128), where m is the 24-bit
    two's-complement signed integer from the 3 mantissa bytes,
    MSB first."""
    m = (m0 << 16) | (m1 << 8) | m2
    if m0 & 0x80:
        m -= 0x1000000
    return (m / 4194304.0) * (2.0 ** (exp - 128))

def encode(value):
    """Inverse of decode(), truncating toward zero. Handles the
    exact-power-of-two NEGATIVE boundary case, per lib_fp_ceil.s's
    own documented -1.0 example ($7F,80,00,00, NOT the naive two's-
    complement $80,C0,00,00 - which isn't normalized, since $C0's
    top two bits (1,1) match instead of differing)."""
    if value == 0:
        return (0, 0, 0, 0)
    sign = -1 if value < 0 else 1
    mag = abs(value)
    e = math.floor(math.log2(mag)) + 1
    mant = mag / (2.0 ** (e - 1))
    while mant >= 2.0:
        mant /= 2.0
        e += 1
    while mant < 1.0:
        mant *= 2.0
        e -= 1
    m_int = int(mant * 4194304)
    if sign < 0:
        m_int = -m_int
        m_int &= 0xFFFFFF
        top_byte = (m_int >> 16) & 0xFF
        while ((top_byte << 1) ^ top_byte) & 0x80 == 0:
            m_int = (m_int << 1) & 0xFFFFFF
            e -= 1
            top_byte = (m_int >> 16) & 0xFF
    exp_byte = e - 1 + 128
    if exp_byte <= 0 and value != 0:
        raise ValueError(
            f"encode({value}): underflows to non-canonical zero "
            f"(exp would be {exp_byte}); "
            f"positive floor is 2^-127 ≈ 5.877e-39, "
            f"negative floor is -2^-126 ≈ -1.175e-38 "
            f"(the format is asymmetric at the bottom - see "
            f"labels_fp.s's zero convention)"
        )
    return (exp_byte, (m_int >> 16) & 0xFF, (m_int >> 8) & 0xFF, m_int & 0xFF)

def is_normalized(mantissa_bytes):
    """True iff the mantissa's top two bits differ - this format's
    own normalization test. Takes the 3-byte MANTISSA ONLY, NOT a
    4-byte FP1 tuple including the exponent - passing the wrong
    slice was a real, session-long bug (every '.rts1_BLOCKED_WRONG'
    percentage reported before this fix was meaningless).

    NOTE: parenthesization matters - bool(x) & 0x80 is NOT the same
    as bool(x & 0x80). Python's bool is 0 or 1, and 1 & 0x80 == 0, so
    the WRONG order silently returns False for every nonzero input
    regardless of actual normalization. This was also a real,
    session-long bug until caught."""
    b0 = mantissa_bytes[0]
    return bool(((b0 << 1) ^ b0) & 0x80)

def is_valid_result(fp1_bytes):
    """True iff fp1_bytes (a 4-byte FP1 tuple: exp, m0, m1, m2) is
    either a properly normalized nonzero value, or canonical zero
    (exponent AND all mantissa bytes == 0) - the two shapes ANY
    correct FP_CORE_PROC result can legitimately take.

    Use this instead of bare is_normalized() when classifying
    sweep/test outcomes as correct/wrong. is_normalized() alone was
    never designed to be asked about zero, and mislabels it as "not
    normalized" even when zero is exactly the right answer (e.g. a
    genuine, unconditional underflow case) - this false positive was
    found TWICE tonight (once for FMUL's floor sweep, again for
    FDIV's) before being fixed here, centrally, for good."""
    if fp1_bytes == (0, 0, 0, 0):
        return True
    return is_normalized(fp1_bytes[1:])

_SELF_TEST = [
    ("1.0",   (0x80,0x40,0x00,0x00), 1.0),
    ("-1.0",  (0x7f,0x80,0x00,0x00), -1.0),
    ("10.0",  (0x83,0x50,0x00,0x00), 10.0),
    ("12.0",  (0x83,0x60,0x00,0x00), 12.0),
    ("2^127 boundary result (VICE-confirmed)", (0xff,0x40,0x00,0x00), 2.0**127),
    ("7.5 (VICE-confirmed FP_TO_ASCII_SCI_V2 output)", (0x82,0x78,0x00,0x00), 7.5),
    ("-90.0 = 12.0 * -7.5 (VICE-confirmed)", (0x86,0xa6,0x00,0x00), -90.0),
]

def _run_self_test():
    for name, bytes4, expected in _SELF_TEST:
        got = decode(*bytes4)
        assert abs(got - expected) < 1e-6 * max(1, abs(expected)), \
            f"diag_woz.decode() self-test FAILED for {name!r}: " \
            f"{bytes4} -> {got}, expected {expected}"
    assert is_normalized((0xa2, 0x00, 0x00)) is True, \
        "is_normalized() regression: $A2's top two bits (1,0) differ - should be True"
    assert is_normalized((0x00, 0x00, 0x00)) is False, \
        "is_normalized() regression: $00's top two bits (0,0) match - should be False"
    assert is_valid_result((0, 0, 0, 0)) is True, \
        "is_valid_result() regression: canonical zero must be valid"
    assert is_valid_result((0x80, 0x40, 0x00, 0x00)) is True, \
        "is_valid_result() regression: 1.0 must be valid"
    assert is_valid_result((0x00, 0x20, 0x00, 0x00)) is False, \
        "is_valid_result() regression: nonzero-but-unnormalized must be invalid"

_run_self_test()

if __name__ == '__main__':
    print(f"diag_woz.py: {len(_SELF_TEST)} decode() checks + "
          f"is_normalized()/is_valid_result() regression checks passed.")
