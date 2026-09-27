.ifndef PRINT_BASIC_STRINGS_S
PRINT_BASIC_STRINGS_S = 1

.include "labels_screen.s"

.scope PrintBasic
    .segment "RODATA"

    .export rpt_bas_hdr, rpt_bas_bits
    .export bas_fwd_hdr, bas_fwd_s1, bas_fwd_s1b
    .export bas_fwd_s2
    .export bas_fwd_s3, bas_fwd_s3b, bas_fwd_s3c, bas_fwd_s3d, bas_fwd_s3e
    .export bas_fwd_s4, bas_fwd_end
    .export bas_rev_hdr, bas_rev_s1, bas_rev_s1b
    .export bas_rev_s2, bas_rev_s2b
    .export bas_rev_s3, bas_rev_s3b
    .export bas_rev_end, bas_rev_end2

    rpt_bas_hdr:  .asciiz "c64 basic (packed):"
    rpt_bas_bits: .asciiz "  eeeeeeee smmmmmmm mmmmmmmm mmmmmmmm mmmmmmmm"

    ; NOTE: .literal is NOT passed through ca65's charmap (unlike
    ; .asciiz). Letters here MUST be uppercase A-Z. See project
    ; conversation.

    ; ---- BASIC forward ----
    bas_fwd_hdr:
        .literal "DECIMAL -> C64 BASIC", PETSCII_RETURN
        .literal "  INPUT:  ", 0

    bas_fwd_s1:
        .literal PETSCII_RETURN, PETSCII_RETURN
        .literal "  STEP 1. NORMALISE TO ONE 1 BEFORE THE POINT.", PETSCII_RETURN
        .literal "            MANTISSA  ", 0

    bas_fwd_s1b:
        .literal " X 2^", 0

    bas_fwd_s2:
        .literal PETSCII_RETURN, PETSCII_RETURN
        .literal "  STEP 2. BIAS THE EXPONENT.", PETSCII_RETURN
        .literal "          BASIC USES THE SAME EXCESS-128", PETSCII_RETURN
        .literal "          SCHEME AS WOZ, BUT ITS MANTISSA", PETSCII_RETURN
        .literal "          IS [0.5, 1.0) INSTEAD OF [1.0, 2.0),", PETSCII_RETURN
        .literal "          SO THE BYTE IS 1 MORE.", PETSCII_RETURN
        .literal "            BIAS + 129 = $", 0

    bas_fwd_s3:
        .literal PETSCII_RETURN, PETSCII_RETURN
        .literal "  STEP 3. PACK SIGN, EXPONENT, AND MANTISSA.", PETSCII_RETURN
        .literal "          BASIC USES SIGN-MAGNITUDE (NOT 2'S", PETSCII_RETURN
        .literal "          COMPLEMENT) AND HAS 4 MANTISSA", PETSCII_RETURN
        .literal "          BYTES (NOT 3).", PETSCII_RETURN
        .literal "            SIGN BIT: ", 0

    bas_fwd_s3b:
        .literal PETSCII_RETURN
        .literal "            BYTE 1 = $", 0

    bas_fwd_s3c:
        .literal PETSCII_RETURN
        .literal "            BYTE 2 = $", 0

    bas_fwd_s3d:
        .literal PETSCII_RETURN
        .literal "            BYTE 3 = $", 0

    bas_fwd_s3e:
        .literal PETSCII_RETURN
        .literal "            BYTE 4 = $", 0

    bas_fwd_s4:
        .literal PETSCII_RETURN, PETSCII_RETURN
        .literal "  STEP 4. COMBINE.", PETSCII_RETURN
        .literal "            RESULT: ", 0

    bas_fwd_end:
        .literal PETSCII_RETURN, PETSCII_RETURN, 0

    ; ---- BASIC reverse ----
    bas_rev_hdr:
        .literal "C64 BASIC -> DECIMAL", PETSCII_RETURN
        .literal "  INPUT:  ", 0

    bas_rev_s1:
        .literal PETSCII_RETURN, PETSCII_RETURN
        .literal "  STEP 1. READ EXPONENT BYTE.", PETSCII_RETURN
        .literal "            $", 0

    bas_rev_s1b:
        .literal " - 129 = ", 0

    bas_rev_s2:
        .literal PETSCII_RETURN, PETSCII_RETURN
        .literal "  STEP 2. READ SIGN BIT (TOP BIT OF BYTE 1)", PETSCII_RETURN
        .literal "          AND MANTISSA MAGNITUDE (31 BITS).", PETSCII_RETURN
        .literal "            SIGN: ", 0

    bas_rev_s2b:
        .literal PETSCII_RETURN
        .literal "            MANTISSA: ", 0

    bas_rev_s3:
        .literal PETSCII_RETURN, PETSCII_RETURN
        .literal "  STEP 3. RECONSTRUCT.", PETSCII_RETURN
        .literal "            ", 0

    bas_rev_s3b:
        .literal " X 2^", 0

    bas_rev_end:
        .literal PETSCII_RETURN, PETSCII_RETURN
        .literal "  RESULT: ", 0

    bas_rev_end2:
        .literal PETSCII_RETURN, 0
.endscope

.endif
