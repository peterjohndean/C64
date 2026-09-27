#!/usr/bin/env python3
"""
diag_recompute_decomp.py - verify recompute_decomp's derived fields.

Two groups of tests:

  WOZ   - decomp_mant_int_str  (raw 24-bit mantissa as signed int)
  IEEE  - decomp_ieee_sign_ch / decomp_ieee_exp_byte /
          decomp_ieee_mant_str

Both call recompute_representations (not recompute_decomp alone),
because recompute_ieee_decomp reads from ieee754_bytes, which is
populated by the earlier FP_TO_IEEE754 step inside
recompute_representations.
"""
import diag_convert
from diag_woz import encode

mpu = diag_convert.mpu
CUR      = diag_convert.resolve('current_value')
RECOMP   = diag_convert.resolve('recompute_representations')
INT_STR  = diag_convert.resolve('decomp_mant_int_str')
IEEE_SIGN = diag_convert.resolve('decomp_ieee_sign_ch')
IEEE_EXP  = diag_convert.resolve('decomp_ieee_exp_byte')
IEEE_MANT = diag_convert.resolve('decomp_ieee_mant_str')
BAS_EXP  = diag_convert.resolve('decomp_basic_exp_byte')
BAS_BIAS = diag_convert.resolve('decomp_basic_bias_str')


# ============================================================
# Woz: decomp_mant_int_str
# ============================================================
print("=== WOZ mantissa integer ===")
CASES_WOZ = [
    ([0x81, 0x64, 0x87, 0xEA], b"6588394"),   # pi-ish
    ([0x80, 0x40, 0x00, 0x00], b"4194304"),   # +1.0
    ([0x7F, 0x80, 0x00, 0x00], b"-8388608"),  # -1.0
    ([0x83, 0x64, 0x00, 0x00], b"6553600"),   # 12.5
    ([0x00, 0x00, 0x00, 0x00], b"0"),         # canonical zero
]
for fp, expect in CASES_WOZ:
    mpu.memory[CUR:CUR+4] = fp
    diag_convert.call(RECOMP, max_steps=200_000)
    got = bytes(mpu.memory[INT_STR:][:10]).split(b'\0')[0]
    print(f"{[f'{b:02X}' for b in fp]}: {got!r}  "
          f"[{'OK' if got == expect else '** MISMATCH **'}]")


# ============================================================
# IEEE: decomp_ieee_sign_ch / _exp_byte / _mant_str
#
# Expected exponent byte is the RAW 8-bit exponent field (biased
# by +127), not the unbiased value. The bias string is derived
# separately and is not checked here.
#
# ============================================================
print()
print("=== IEEE fields ===")
CASES_IEEE = [
    # (current_value bytes,       want_sign, want_exp, want_mant)
    ([0x81, 0x64, 0x87, 0xEA], ord('+'), 0x80, b"1.570795"),  # pi
    ([0x80, 0x40, 0x00, 0x00], ord('+'), 0x7F, b"1.000000"),  # +1.0
    ([0x7F, 0x80, 0x00, 0x00], ord('-'), 0x7F, b"1.000000"),  # -1.0
    ([0x83, 0x64, 0x00, 0x00], ord('+'), 0x82, b"1.562500"),  # 12.5
    ([0x00, 0x00, 0x00, 0x00], ord('+'), 0x00, b"0.000000"),  # zero
    # --- subnormal: exp field 0, fraction nonzero ---
    ([0x01, 0x40, 0x00, 0x00], ord('+'), 0x00, b"0.500000"),  # 2^-127
    ([0x01, 0x40, 0x3E, 0xCB], ord('+'), 0x00, b"0.501916"),  # 5.8999E-39
    ([0x01, 0x7F, 0xFF, 0xFF], ord('+'), 0x00, b"0.999999"),  # just below 2^-126
    ([0x01, 0xC0, 0x00, 0x00], ord('-'), 0x00, b"0.500000"),  # -2^-127
]
for fp, want_sign, want_exp, want_mant in CASES_IEEE:
    mpu.memory[CUR:CUR+4] = fp
    diag_convert.call(RECOMP, max_steps=200_000)
    got_sign = mpu.memory[IEEE_SIGN]
    got_exp  = mpu.memory[IEEE_EXP]
    got_mant = bytes(mpu.memory[IEEE_MANT:][:16]).split(b'\0')[0]
    ok = (got_sign == want_sign and
          got_exp == want_exp and
          got_mant == want_mant)
    print(f"{[f'{b:02X}' for b in fp]}: "
          f"sign={chr(got_sign)} exp=${got_exp:02X} mant={got_mant!r}  "
          f"[{'OK' if ok else '** MISMATCH **'}]")


# ============================================================
# C64 BASIC: decomp_basic_exp_byte
# ============================================================
print()
print("=== BASIC fields ===")
CASES_BAS = [
    # (current_value bytes,       want_exp, want_bias)
    ([0x81, 0x64, 0x87, 0xEA], 0x82, b"+1"),      # pi
    ([0x80, 0x40, 0x00, 0x00], 0x81, b"+0"),      # +1.0
    ([0x7F, 0x80, 0x00, 0x00], 0x81, b"+0"),      # -1.0  ($81, not $80 —
                                                   # see derivation above)
    ([0x83, 0x64, 0x00, 0x00], 0x84, b"+3"),      # 12.5
    ([0x00, 0x00, 0x00, 0x00], 0x00, b"+0"),      # zero
]
for fp, want_exp, want_bias in CASES_BAS:
    mpu.memory[CUR:CUR+4] = fp
    diag_convert.call(RECOMP, max_steps=200_000)
    got_exp  = mpu.memory[BAS_EXP]
    got_bias = bytes(mpu.memory[BAS_BIAS:][:5]).split(b'\0')[0]
    ok = (got_exp == want_exp and got_bias == want_bias)
    print(f"{[f'{b:02X}' for b in fp]}: "
          f"exp=${got_exp:02X} bias={got_bias!r}  "
          f"[{'OK' if ok else '** MISMATCH **'}]")
