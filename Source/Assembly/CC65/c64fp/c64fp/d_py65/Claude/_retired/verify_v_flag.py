"""
Emulates 6502 SBC's V-flag computation exactly, to verify which of
FDIV's $80/$00 collision cases (true_diff=-128 valid-floor vs
true_diff=+128 invalid-ceiling+1) gets V=0 vs V=1 - and therefore
which CEILING/FLOOR label each one actually needs, since assuming
this mirrors FMUL's own V=0->CEILING,V=1->FLOOR convention would be
WRONG here (verified below) without checking.
"""

def sbc(a, b, carry_in=1):
    """6502 SBC: A - B - (1-carry_in). Returns (result, carry_out, V).
    V is set when the SIGNED result doesn't fit in a signed byte -
    i.e. when the sign of the true mathematical result differs from
    what naive 2's-complement truncation to 8 bits would suggest."""
    borrow = 1 - carry_in
    raw = a - b - borrow
    result = raw & 0xFF
    carry_out = 1 if raw >= 0 else 0
    # V flag: overflow occurred if the operands' signs differ AND
    # the result's sign differs from the minuend's sign (standard
    # 6502 SBC overflow rule, equivalent to signed overflow check)
    a_signed = a - 256 if a >= 128 else a
    b_signed = b - 256 if b >= 128 else b
    true_result = a_signed - b_signed
    v = 1 if not (-128 <= true_result <= 127) else 0
    return result, carry_out, v

def to_biased_byte(true_exp):
    return (true_exp + 128) & 0xFF

def eor80(byte):
    return byte ^ 0x80

# --- reproduce the classify block's OWN computation exactly ---
def classify_fdiv_te_diff(divisor_biased, dividend_biased):
    te1 = eor80(divisor_biased)   # FP1_EXP eor $80
    te2 = eor80(dividend_biased)  # FP2_EXP eor $80
    result, carry, v = sbc(te2, te1, carry_in=1)  # sec; sbc boundary_tmp
    return result, v

print("=== Case A: true_diff = -128 (VALID floor) ===")
# pick te1, te2 such that te2-te1 = -128 exactly, fitting in range
te1, te2 = 64, -64   # te2 - te1 = -128
divisor = to_biased_byte(te1)
dividend = to_biased_byte(te2)
result, v = classify_fdiv_te_diff(divisor, dividend)
print(f"te1={te1} te2={te2}  divisor_byte=${divisor:02x} dividend_byte=${dividend:02x}")
print(f"classify result A=${result:02x}  V={v}")
print(f"-> per FMUL's OWN convention (V=0=>CEILING, V=1=>FLOOR), this would get: "
      f"{'CEILING' if v==0 else 'FLOOR'}")
print(f"-> but true_diff=-128 is the VALID FLOOR - if mantissa needs a decrement,")
print(f"   true final would be -129 (invalid) -> must FORCE ZERO -> that's FLOOR semantics")
print(f"   MATCH: {'YES' if (v==1) else 'NO - inverted, must use opposite label'}")

print("\n=== Case B: true_diff = +128 (INVALID one-past-ceiling) ===")
te1, te2 = -64, 64   # te2 - te1 = +128
divisor = to_biased_byte(te1)
dividend = to_biased_byte(te2)
result, v = classify_fdiv_te_diff(divisor, dividend)
print(f"te1={te1} te2={te2}  divisor_byte=${divisor:02x} dividend_byte=${dividend:02x}")
print(f"classify result A=${result:02x}  V={v}")
print(f"-> per FMUL's OWN convention (V=0=>CEILING, V=1=>FLOOR), this would get: "
      f"{'CEILING' if v==0 else 'FLOOR'}")
print(f"-> but true_diff=+128 is INVALID-ceiling+1 - if mantissa needs a decrement,")
print(f"   true final becomes 128-1=127 (VALID, the true ceiling) -> must ALLOW the")
print(f"   decrement/rescue -> that's CEILING semantics")
print(f"   MATCH: {'YES' if (v==0) else 'NO - inverted, must use opposite label'}")
