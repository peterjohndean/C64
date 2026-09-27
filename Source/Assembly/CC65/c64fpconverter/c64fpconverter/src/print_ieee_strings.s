.ifndef PRINT_IEEE_STRINGS_S
PRINT_IEEE_STRINGS_S = 1

.include "labels_screen.s"

.scope PrintIeee
    .segment "RODATA"

    .export rpt_ieee_hdr, rpt_ieee_bits
    .export ieee_fwd_hdr, ieee_fwd_s1, ieee_fwd_s1b
    .export ieee_fwd_s2, ieee_fwd_s2b
    .export ieee_fwd_s3, ieee_fwd_s3b, ieee_fwd_s3c
    .export ieee_fwd_s3d, ieee_fwd_s3e
    .export ieee_fwd_s4, ieee_fwd_end
    .export ieee_rev_hdr, ieee_rev_s1
    .export ieee_rev_s2, ieee_rev_s2b
    .export ieee_rev_s3, ieee_rev_s3b
    .export ieee_rev_s4, ieee_rev_s4b
    .export ieee_rev_end, ieee_rev_end2
    .export ieee_fwd_s1_sub
    .export ieee_rev_s3_sub

    rpt_ieee_hdr:  .asciiz "ieee-754 single:"
    rpt_ieee_bits: .asciiz "  seeeeeee emmmmmmm mmmmmmmm mmmmmmmm"

    ; ============================================================
    ; NOTE: .literal is NOT passed through ca65's charmap. Letters
    ; MUST be uppercase A-Z. See project conversation.
    ; ============================================================

    ; ---- IEEE forward ----
    ieee_fwd_hdr:
        .literal "DECIMAL -> IEEE-754", PETSCII_RETURN
        .literal "  INPUT:  ", 0

    ieee_fwd_s1:
        .literal PETSCII_RETURN, PETSCII_RETURN
        .literal "  STEP 1. NORMALISE TO ONE 1 BEFORE THE POINT.", PETSCII_RETURN
        .literal "            SIGNIFICAND  ", 0

    ieee_fwd_s1_sub:
        .literal PETSCII_RETURN, PETSCII_RETURN
        .literal "  STEP 1. VALUE IS 0.FRACTION X 2^-126.", PETSCII_RETURN
        .literal "            SIGNIFICAND  ", 0

    ieee_fwd_s1b:
        .literal " X 2^", 0

    ieee_fwd_s2:
        .literal PETSCII_RETURN, PETSCII_RETURN
        .literal "  STEP 2. BIAS THE EXPONENT (EXCESS-127).", PETSCII_RETURN
        .literal "            ", 0

    ieee_fwd_s2b:
        .literal " + 127 = $", 0

    ieee_fwd_s3:
        .literal PETSCII_RETURN, PETSCII_RETURN
        .literal "  STEP 3. PACK SIGN, EXPONENT, AND FRACTION.", PETSCII_RETURN
        .literal "            NOTE: IEEE SPLITS THE EXPONENT ACROSS", PETSCII_RETURN
        .literal "            BYTE 0 AND BYTE 1.", PETSCII_RETURN
        .literal "            SIGN BIT: ", 0

    ieee_fwd_s3b:
        .literal PETSCII_RETURN
        .literal "            BYTE 0 = $", 0

    ieee_fwd_s3c:
        .literal PETSCII_RETURN
        .literal "            BYTE 1 = $", 0

    ieee_fwd_s3d:
        .literal PETSCII_RETURN
        .literal "            BYTE 2 = $", 0

    ieee_fwd_s3e:
        .literal PETSCII_RETURN
        .literal "            BYTE 3 = $", 0

    ieee_fwd_s4:
        .literal PETSCII_RETURN, PETSCII_RETURN
        .literal "  STEP 4. COMBINE.", PETSCII_RETURN
        .literal "            RESULT: ", 0

    ieee_fwd_end:
        .literal PETSCII_RETURN, PETSCII_RETURN, 0

    ; ---- IEEE reverse ----
    ieee_rev_hdr:
        .literal "IEEE-754 -> DECIMAL", PETSCII_RETURN
        .literal "  INPUT:  ", 0

    ieee_rev_s1:
        .literal PETSCII_RETURN, PETSCII_RETURN
        .literal "  STEP 1. READ SIGN BIT (BIT 7 OF BYTE 0).", PETSCII_RETURN
        .literal "            SIGN: ", 0

    ieee_rev_s2:
        .literal PETSCII_RETURN, PETSCII_RETURN
        .literal "  STEP 2. RECOVER EXPONENT FIELD", PETSCII_RETURN
        .literal "          (7 BITS OF BYTE 0 + BIT 7 OF BYTE 1).", PETSCII_RETURN
        .literal "            $", 0

    ieee_rev_s2b:
        .literal " - 127 = ", 0

    ieee_rev_s3:
        .literal PETSCII_RETURN, PETSCII_RETURN
        .literal "  STEP 3. RECONSTRUCT SIGNIFICAND.", PETSCII_RETURN
        .literal "            IMPLICIT LEADING 1 RESTORED: ", 0

    ieee_rev_s3_sub:
        .literal PETSCII_RETURN, PETSCII_RETURN
        .literal "  STEP 3. RECONSTRUCT SIGNIFICAND.", PETSCII_RETURN
        .literal "            EXPONENT FIELD IS 0 -> SUBNORMAL;", PETSCII_RETURN
        .literal "            NO IMPLICIT 1; SIGNIFICAND STARTS 0.", 0

    ieee_rev_s3b:
        .literal PETSCII_RETURN
        .literal "            SIGNIFICAND: ", 0

    ieee_rev_s4:
        .literal PETSCII_RETURN, PETSCII_RETURN
        .literal "  STEP 4. COMBINE.", PETSCII_RETURN
        .literal "            ", 0

    ieee_rev_s4b:
        .literal " X 2^", 0

    ieee_rev_end:
        .literal PETSCII_RETURN, PETSCII_RETURN
        .literal "  RESULT: ", 0

    ieee_rev_end2:
        .literal PETSCII_RETURN, PETSCII_RETURN, 0
.endscope

.endif
