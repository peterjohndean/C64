#!/usr/bin/env python3
"""
diag_fp_compare_boundary.py - verify FP_COMPARE_PROC across the
entire exponent range, with emphasis on the alignment-trampoline
short-circuit that was recently fixed.

Before the fix: cases with exponent differences >= 25 hung in
FP_CORE_PROC's alignment loop. After the fix: they should
short-circuit correctly.

Entry   : FP1 = $61-$64, FP2 = $69-$6C (set directly)
Exit    : A = 0 (equal), 1 (FP1>FP2), $FF (FP1<FP2)
"""
import diag_convert
mpu = diag_convert.mpu
FP_COMPARE = diag_convert.resolve('FP_COMPARE')

# Woz-format byte tuples. See labels_fp.s for the format:
#   $80,$40,00,00  = +1.0
#   $7F,$80,00,00  = -1.0
#   $01,$40,00,00  = +2^-127   (smallest positive)
#   $01,$80,00,00  = -2^-126   (smallest negative, NOT -2^-127;
#                               see labels_fp.s zero convention)
#   $FF,$7F,FF,FE  = +3.4e38   (near ceiling)
#   $FF,$80,00,02  = -3.4e38   (near ceiling, negative)
ONE       = [0x80, 0x40, 0x00, 0x00]
NEG_ONE   = [0x7F, 0x80, 0x00, 0x00]
TWO       = [0x81, 0x40, 0x00, 0x00]
NEG_TWO   = [0x80, 0x80, 0x00, 0x00]
ZERO      = [0x00, 0x00, 0x00, 0x00]
MIN_POS   = [0x01, 0x40, 0x00, 0x00]   # +2^-127
MIN_NEG   = [0x01, 0x80, 0x00, 0x00]   # -2^-126
MAX_POS   = [0xFF, 0x7F, 0xFF, 0xFE]   # +3.4e38
MAX_NEG   = [0xFF, 0x80, 0x00, 0x02]   # -3.4e38
NEAR_ONE  = [0x80, 0x40, 0x00, 0x01]   # 1.0 + LSB (mantissa diff)

CASES = [
    # ---- sanity (should always work, no hang risk) ----
    (ONE,     ONE,     0x00, "1 == 1"),
    (TWO,     ONE,     0x01, "2 > 1"),
    (ONE,     TWO,     0xFF, "1 < 2"),
    (NEG_ONE, ONE,     0xFF, "-1 < 1"),
    (ONE,     NEG_ONE, 0x01, "1 > -1"),
    (ZERO,    ZERO,    0x00, "0 == 0"),
    (ZERO,    ONE,     0xFF, "0 < 1"),
    (ONE,     ZERO,    0x01, "1 > 0"),
    (NEG_TWO, NEG_ONE, 0xFF, "-2 < -1"),
    (NEG_ONE, NEG_TWO, 0x01, "-1 > -2"),

    # ---- same exponent, mantissa-only difference ----
    (ONE,     NEAR_ONE, 0xFF, "1.0 < 1.0+LSB"),
    (NEAR_ONE, ONE,     0x01, "1.0+LSB > 1.0"),

    # ---- huge exponent difference, POSITIVE magnitude ----
    # These are the cases that HUNG before the alignment fix.
    (MIN_POS, ONE,      0xFF, "2^-127 < 1"),
    (ONE,     MIN_POS,  0x01, "1 > 2^-127"),
    (MAX_POS, ONE,      0x01, "3.4e38 > 1"),
    (ONE,     MAX_POS,  0xFF, "1 < 3.4e38"),
    (MIN_POS, MAX_POS,  0xFF, "2^-127 < 3.4e38"),
    (MAX_POS, MIN_POS,  0x01, "3.4e38 > 2^-127"),

    # ---- huge exponent difference, MIXED sign ----
    # Also previously hang-prone. The sign handling happens BEFORE
    # the alignment shift, so these exercise a different code path.
    (MIN_POS, NEG_ONE,  0x01, "2^-127 > -1"),
    (NEG_ONE, MIN_POS,  0xFF, "-1 < 2^-127"),
    (MIN_NEG, ONE,      0xFF, "-2^-126 < 1"),
    (ONE,     MIN_NEG,  0x01, "1 > -2^-126"),
    (MAX_NEG, ONE,      0xFF, "-3.4e38 < 1"),
    (ONE,     MAX_NEG,  0x01, "1 > -3.4e38"),
    (MAX_POS, MAX_NEG,  0x01, "+3.4e38 > -3.4e38"),
    (MAX_NEG, MAX_POS,  0xFF, "-3.4e38 < +3.4e38"),

    # ---- direct ten_const-style compare (what FP_TO_ASCII_SCI
    #      does internally: FP1 is the normalised mantissa, FP2 is
    #      a constant like 10.0 = $83,$50,00,00) ----
    ([0x83, 0x50, 0x00, 0x00], [0x80, 0x40, 0x00, 0x00],
     0x01, "10 > 1 (ten_const vs one_const)"),
    ([0x80, 0x40, 0x00, 0x00], [0x83, 0x50, 0x00, 0x00],
     0xFF, "1 < 10 (one_const vs ten_const)"),
    ([0x01, 0x40, 0x00, 0x00], [0x83, 0x50, 0x00, 0x00],
     0xFF, "2^-127 < 10 (the case that used to hang)"),
]

passed = 0
failed = 0
hung = 0

for fp1, fp2, want_a, desc in CASES:
    mpu.memory[0x61:0x65] = fp1
    mpu.memory[0x69:0x6D] = fp2
    # Save FP1 to check that FP_COMPARE preserves it
    fp1_before = list(mpu.memory[0x61:0x65])
    try:
        _, s = diag_convert.call(
            FP_COMPARE,
            max_steps=50_000,
            trap_label='.FP_ERROR_PROC',
        )
    except RuntimeError as e:
        print(f"{desc:42s}  ** HANG ** ({e})")
        hung += 1
        continue

    got_a = s['a']
    fp1_after = list(mpu.memory[0x61:0x65])

    ok = (got_a == want_a)
    preserved = (fp1_before == fp1_after)

    if ok and preserved:
        print(f"{desc:42s}  A=${got_a:02X}  [OK]")
        passed += 1
    else:
        detail = ""
        if not ok:
            detail += f" A=${got_a:02X} (want ${want_a:02X})"
        if not preserved:
            detail += f" FP1 clobbered: {[f'{b:02X}' for b in fp1_after]}"
        print(f"{desc:42s}  [** FAIL **]{detail}")
        failed += 1

print()
print(f"Passed: {passed}  Failed: {failed}  Hung: {hung}  "
      f"Total: {len(CASES)}")
if hung:
    print("Hangs indicate the alignment-trampoline fix is incomplete.")
if failed:
    print("Failures indicate FP_COMPARE returns the wrong relation.")
