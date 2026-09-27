#!/usr/bin/env python3
"""
ds_diag7.py - instruction-level validation of the proposed norm1
fold-in patch, before any change to lib_fp.s.

The patch under test (three parts of lib_fp.s):

  1. BSS byte fp_mul_extra (byte at $C0F0 in this diagnostic).

  2. In fmul, between mul2's "bpl mul1" and mdend:
         lda FP_EXT
         and #$80
         sta fp_mul_extra
     (Captures FP_EXT[0] bit 7 into the flag - the LSB that the
      final loop iteration pushed out of the mantissa.)

  3. In norm1, after the existing three shift instructions:
         lda fp_mul_extra
         beq @no_extra_fold
         bit FP1_MANT
         bmi @extra_fold_neg
         lda FP1_MANT+2
         ora #$01
         sta FP1_MANT+2
         jmp @extra_fold_done
     @extra_fold_neg:
         lda FP1_MANT+2
         bne @extra_fold_dec_low
         lda #$FF
         sta FP1_MANT+2
         lda FP1_MANT+1
         bne @extra_fold_dec_mid
         lda #$FF
         sta FP1_MANT+1
         dec FP1_MANT
         jmp @extra_fold_done
     @extra_fold_dec_mid:
         dec FP1_MANT+1
         jmp @extra_fold_done
     @extra_fold_dec_low:
         dec FP1_MANT+2
     @extra_fold_done:
         lda #0
         sta fp_mul_extra
     @no_extra_fold:
         ; falls through into norm

This diagnostic replicates part 3 (the fold-in body) plus the
preceding dec-FP1_EXP-and-shift sequence that norm1 already
performs, and validates it against a grid of states covering:

  - positive products, extra bit set (OR path)
  - positive products, extra bit clear (no fold-in)
  - negative products, extra bit set, no borrow
  - negative products, extra bit set, borrow into M1
  - negative products, extra bit set, borrow through M1 into M0
  - negative products, extra bit clear (no fold-in)

For each case, expected output is computed by an independent
Python implementation of the same algorithm. A match on every
case means the assembled instruction sequence (including branch
offsets, borrow propagation, and flag handling) is correct.

Run: PYTHONPATH=src:.:../ python3 ds_diag7.py
"""

from diag1 import mpu

SENTINEL = 0x1234

# Memory map for the diagnostic (all scratch, no library conflict):
#   $C000-$C03F  scratch code
#   $C0F0        fp_mul_extra flag byte
SCRATCH_ADDR      = 0xC000
FP_MUL_EXTRA_ADDR = 0xC0F0

# Zero-page addresses of FP1 state (from labels_fp.s)
FP1_EXP    = 0x61
FP1_MANT   = 0x62
FP1_MANT_1 = 0x63
FP1_MANT_2 = 0x64


# ---------------------------------------------------------------------
# Assemble the scratch code, computing branch offsets programmatically
# so a byte-list edit can't silently break a branch target.
# ---------------------------------------------------------------------
def assemble_scratch_code():
    # (label, byte-list) pairs. Offset placeholders are None and
    # filled in after positions are computed.
    parts = [
        ('start',       [0xC6, FP1_EXP]),       # dec FP1_EXP
        ('asl_m2',      [0x06, FP1_MANT_2]),    # asl FP1_MANT+2
        ('rol_m1',      [0x26, FP1_MANT_1]),    # rol FP1_MANT+1
        ('rol_m0',      [0x26, FP1_MANT]),      # rol FP1_MANT
        ('lda_extra',   [0xAD, FP_MUL_EXTRA_ADDR & 0xFF,
                             FP_MUL_EXTRA_ADDR >> 8]),
        ('beq_no_fold', [0xF0, None]),          # beq @no_extra_fold
        ('bit_m0',      [0x24, FP1_MANT]),      # bit FP1_MANT
        ('bmi_neg',     [0x30, None]),          # bmi @extra_fold_neg
        ('lda_m2_pos',  [0xA5, FP1_MANT_2]),    # lda FP1_MANT+2
        ('ora_1',       [0x09, 0x01]),          # ora #$01
        ('sta_m2_pos',  [0x85, FP1_MANT_2]),    # sta FP1_MANT+2
        ('jmp_done1',   [0x4C, None, None]),    # jmp @extra_fold_done
        ('neg_lda_m2',  [0xA5, FP1_MANT_2]),    # @extra_fold_neg: lda FP1_MANT+2
        ('bne_dec_low', [0xD0, None]),          # bne @extra_fold_dec_low
        ('lda_ff1',     [0xA9, 0xFF]),          # lda #$FF
        ('sta_m2_neg',  [0x85, FP1_MANT_2]),    # sta FP1_MANT+2
        ('lda_m1',      [0xA5, FP1_MANT_1]),    # lda FP1_MANT+1
        ('bne_dec_mid', [0xD0, None]),          # bne @extra_fold_dec_mid
        ('lda_ff2',     [0xA9, 0xFF]),          # lda #$FF
        ('sta_m1_neg',  [0x85, FP1_MANT_1]),    # sta FP1_MANT+1
        ('dec_m0',      [0xC6, FP1_MANT]),      # dec FP1_MANT
        ('jmp_done2',   [0x4C, None, None]),    # jmp @extra_fold_done
        ('dec_mid_lbl', [0xC6, FP1_MANT_1]),    # @extra_fold_dec_mid: dec FP1_MANT+1
        ('jmp_done3',   [0x4C, None, None]),    # jmp @extra_fold_done
        ('dec_low_lbl', [0xC6, FP1_MANT_2]),    # @extra_fold_dec_low: dec FP1_MANT+2
        ('done_lbl',    [0xA9, 0x00]),          # @extra_fold_done: lda #0
        ('sta_extra',   [0x8D, FP_MUL_EXTRA_ADDR & 0xFF,
                             FP_MUL_EXTRA_ADDR >> 8]),
        ('no_fold_lbl', [0x60]),                # @no_extra_fold: rts
    ]

    # Pass 1: compute label positions
    positions = {}
    addr = SCRATCH_ADDR
    for name, data in parts:
        positions[name] = addr
        addr += len(data)

    # Pass 2: fill branch offsets and jmp targets
    def rel8(from_name, to_name):
        src = positions[from_name] + 2  # offset relative to byte AFTER operand
        dst = positions[to_name]
        off = dst - src
        assert -128 <= off <= 127, f"{from_name} -> {to_name}: {off}"
        return off & 0xFF

    def abs16(to_name):
        a = positions[to_name]
        return [a & 0xFF, a >> 8]

    for name, data in parts:
        if name == 'beq_no_fold':
            data[1] = rel8(name, 'no_fold_lbl')
        elif name == 'bmi_neg':
            data[1] = rel8(name, 'neg_lda_m2')
        elif name == 'bne_dec_low':
            data[1] = rel8(name, 'dec_low_lbl')
        elif name == 'bne_dec_mid':
            data[1] = rel8(name, 'dec_mid_lbl')
        elif name in ('jmp_done1', 'jmp_done2', 'jmp_done3'):
            data[1:3] = abs16('done_lbl')

    # Flatten
    blob = bytearray()
    for name, data in parts:
        for b in data:
            assert b is not None, f"unfilled byte in {name}"
            blob.append(b)

    return bytes(blob), positions, addr


# ---------------------------------------------------------------------
# Independent Python model of the intended algorithm
# ---------------------------------------------------------------------
def simulate_norm1_with_fold(pre_mant, pre_exp, extra_flag):
    """Emulate the scratch code (and, transitively, the proposed
    norm1 patch). All inputs are integers; return (mant, exp)."""
    m0, m1, m2 = (pre_mant >> 16) & 0xFF, (pre_mant >> 8) & 0xFF, pre_mant & 0xFF
    exp = (pre_exp - 1) & 0xFF
    # Shift left as one 24-bit unit, discarding overflow bit (C_out
    # from m0's top): asl m2; rol m1; rol m0
    m2 = (m2 << 1) & 0xFF
    m1 = ((m1 << 1) | ((pre_mant & 0xFF) >> 7)) & 0xFF
    m0 = ((m0 << 1) | (((pre_mant >> 8) & 0xFF) >> 7)) & 0xFF
    # Sign test AFTER the shift
    if extra_flag:
        if m0 & 0x80:
            # negative: subtract 1 with borrow propagation
            if m2 != 0:
                m2 = (m2 - 1) & 0xFF
            else:
                m2 = 0xFF
                if m1 != 0:
                    m1 = (m1 - 1) & 0xFF
                else:
                    m1 = 0xFF
                    m0 = (m0 - 1) & 0xFF
        else:
            # positive: set bit 0 of m2
            m2 = m2 | 0x01
    return (m0 << 16) | (m1 << 8) | m2, exp


# ---------------------------------------------------------------------
# Test grid
# ---------------------------------------------------------------------
# (name, pre_mant, pre_exp, extra_flag)
TESTS = [
    # Positive products (no fcompl ran)
    ("pos, extra=1, no borrow (the 1.0*pi case)",
        0x3243F6, 0x82, 0x80),
    ("pos, extra=1, M2 not touching borrow edge",
        0x3243F6, 0x82, 0x80),   # duplicate of above, but ok
    ("pos, extra=0 (flag clear)",
        0x3243F6, 0x82, 0x00),
    ("pos, extra=1, M2 LSB already 0",
        0x3243F4, 0x82, 0x80),   # after shift M2 = $E8 | 1 = $E9

    # Negative products (fcompl ran, so pre_mant is post-negation)
    ("neg, extra=1, no borrow",
        0xC00028, 0x82, 0x80),   # post-shift $800050 -> $80004F
    ("neg, extra=1, borrow into M1",
        0xC00080, 0x82, 0x80),   # post-shift $800100 -> $8000FF
    ("neg, extra=1, borrow through M1 to M0",
        0xC08000, 0x82, 0x80),   # post-shift $810000 -> $80FFFF
    ("neg, extra=0 (flag clear)",
        0xC00028, 0x82, 0x00),   # post-shift $800050, no change

    # Boundary-shape cases
    ("neg, extra=1, M1=$01 (borrow reaches M1 only)",
        0xC00080, 0x82, 0x80),   # duplicate of borrow-into-M1
]


def push_sentinel():
    ret = SENTINEL - 1
    mpu.memory[0x100 + mpu.sp] = (ret >> 8) & 0xFF
    mpu.sp -= 1
    mpu.memory[0x100 + mpu.sp] = ret & 0xFF
    mpu.sp -= 1


def setup_state(pre_mant, pre_exp, extra_flag):
    mpu.memory[FP1_EXP]    = pre_exp
    mpu.memory[FP1_MANT]   = (pre_mant >> 16) & 0xFF
    mpu.memory[FP1_MANT_1] = (pre_mant >> 8) & 0xFF
    mpu.memory[FP1_MANT_2] = pre_mant & 0xFF
    mpu.memory[FP_MUL_EXTRA_ADDR] = extra_flag
    mpu.sp = 0xFF
    mpu.p = 0x20
    push_sentinel()


def call_scratch():
    mpu.pc = SCRATCH_ADDR
    for _ in range(2000):
        if mpu.pc == SENTINEL:
            return
        mpu.step()
    raise RuntimeError("scratch code didn't return to sentinel")


def read_state():
    m0 = mpu.memory[FP1_MANT]
    m1 = mpu.memory[FP1_MANT_1]
    m2 = mpu.memory[FP1_MANT_2]
    return ((m0 << 16) | (m1 << 8) | m2,
            mpu.memory[FP1_EXP],
            mpu.memory[FP_MUL_EXTRA_ADDR])


def fmt_mant(m):
    return f"${(m>>16)&0xFF:02x} ${(m>>8)&0xFF:02x} ${m&0xFF:02x}"


def main():
    print("=" * 72)
    print("ds_diag7.py - instruction-level validation of norm1 fold-in")
    print("=" * 72)

    code, positions, end_addr = assemble_scratch_code()
    print(f"  scratch code:  ${SCRATCH_ADDR:04x}-${end_addr-1:04x} "
          f"({len(code)} bytes)")
    print(f"  fp_mul_extra:  ${FP_MUL_EXTRA_ADDR:04x}")
    print(f"  labels:")
    for name in sorted(positions, key=lambda k: positions[k]):
        print(f"    {name:16s} ${positions[name]:04x}")
    print()

    # Copy the code into simulator memory
    for i, b in enumerate(code):
        mpu.memory[SCRATCH_ADDR + i] = b

    all_ok = True
    for name, pre_mant, pre_exp, extra_flag in TESTS:
        setup_state(pre_mant, pre_exp, extra_flag)
        call_scratch()
        got_mant, got_exp, got_flag = read_state()

        exp_mant, exp_exp = simulate_norm1_with_fold(pre_mant, pre_exp, extra_flag)

        ok = (got_mant == exp_mant and
              got_exp == exp_exp and
              got_flag == 0x00)  # flag must be cleared

        marker = "OK  " if ok else "FAIL"
        print(f"  [{marker}] {name}")
        print(f"      pre:  mant={fmt_mant(pre_mant)}  exp=${pre_exp:02x}  flag=${extra_flag:02x}")
        print(f"      got:  mant={fmt_mant(got_mant)}  exp=${got_exp:02x}  flag=${got_flag:02x}")
        print(f"      want: mant={fmt_mant(exp_mant)}  exp=${exp_exp:02x}  flag=$00")
        print()
        all_ok &= ok

    print("=" * 72)
    if all_ok:
        print("ALL CASES PASSED - instruction sequence is correct.")
        print()
        print("Next steps for the source patch:")
        print("  1. Add 'fp_mul_extra: .byte 0' to lib_fp.s's BSS block.")
        print("  2. Insert the lda FP_EXT / and #$80 / sta fp_mul_extra")
        print("     sequence between mul2's loop-exit and mdend in fmul.")
        print("  3. Insert the fold-in block after the three shift")
        print("     instructions in norm1, exactly as tested here.")
        print("  4. Add 'lda #0 / sta fp_mul_extra' at fadd's, fdiv's,")
        print("     and float_conv's entry points (so a stale flag from")
        print("     a prior FMUL cannot leak into a subsequent")
        print("     operation's norm1 path).")
    else:
        print("SOME CASES FAILED - do NOT patch the source yet.")
        print("Investigate the failing cases above.")
    print("=" * 72)


if __name__ == '__main__':
    main()
