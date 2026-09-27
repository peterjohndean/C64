
.ifndef PRINT_WOZ_STRINGS_S
PRINT_WOZ_STRINGS_S = 1

.include "labels_screen.s"

.scope PrintWoz
    .segment "RODATA"

    .export rpt_woz_hdr, rpt_woz_bits
    .export woz_fwd_hdr
    .export woz_fwd_s1, woz_fwd_s1b
    .export woz_fwd_s2, woz_fwd_s2b
    .export woz_fwd_s3, woz_fwd_s3b, woz_fwd_s3c, woz_fwd_s3d
    .export woz_fwd_s4, woz_fwd_end
    .export woz_rev_hdr
    .export woz_rev_s1, woz_rev_s1b
    .export woz_rev_s2, woz_rev_s2b
    .export woz_rev_s3, woz_rev_s3a, woz_rev_s3b, woz_rev_s3c, woz_rev_s3d
    .export woz_rev_end, woz_rev_end2

    rpt_woz_hdr:  .asciiz "woz/rankin (native format):"
    rpt_woz_bits: .asciiz "  eeeeeeee smmmmmmm mmmmmmmm mmmmmmmm"

    ; ============================================================
    ; NOTE: .literal is NOT passed through ca65's charmap (unlike
    ; .asciiz). Letters here MUST be uppercase A-Z to produce the
    ; PETSCII $41-$5A bytes that display as letters on the C64's
    ; default charset. Lowercase source would produce $61-$7A,
    ; which renders as graphics symbols. See project conversation.
    ; ============================================================

    ; ---- Woz forward ----
    woz_fwd_hdr:
        .literal "DECIMAL -> WOZ/RANKIN", PETSCII_RETURN
        .literal "  INPUT:  ", 0

    woz_fwd_s1:
        .literal PETSCII_RETURN, PETSCII_RETURN
        .literal "  STEP 1. NORMALISE TO ONE 1 BEFORE THE POINT.", PETSCII_RETURN
        .literal "            MANTISSA  ", 0

    woz_fwd_s1b:
        .literal " X 2^", 0

    woz_fwd_s2:
        .literal PETSCII_RETURN, PETSCII_RETURN
        .literal "  STEP 2. BIAS THE EXPONENT (EXCESS-128).", PETSCII_RETURN
        .literal "            ", 0

    woz_fwd_s2b:
        .literal " + 128 = $", 0

    woz_fwd_s3:
        .literal PETSCII_RETURN, PETSCII_RETURN
        .literal "  STEP 3. PACK THE 24-BIT MANTISSA (TWO'S COMPLEMENT).", PETSCII_RETURN
        .literal "            SIGN BIT: ", 0

    woz_fwd_s3b:
        .literal PETSCII_RETURN
        .literal "            BYTE 1 = $", 0

    woz_fwd_s3c:
        .literal PETSCII_RETURN
        .literal "            BYTE 2 = $", 0

    woz_fwd_s3d:
        .literal PETSCII_RETURN
        .literal "            BYTE 3 = $", 0

    woz_fwd_s4:
        .literal PETSCII_RETURN, PETSCII_RETURN
        .literal "  STEP 4. COMBINE EXPONENT AND MANTISSA BYTES.", PETSCII_RETURN
        .literal "            RESULT: ", 0

    woz_fwd_end:
        .literal PETSCII_RETURN, PETSCII_RETURN, 0

    ; ---- Woz reverse ----
    woz_rev_hdr:
        .literal "WOZ/RANKIN -> DECIMAL", PETSCII_RETURN
        .literal "  INPUT:  ", 0

    woz_rev_s1:
        .literal PETSCII_RETURN, PETSCII_RETURN
        .literal "  STEP 1. READ EXPONENT BYTE, UNBIAS (EXCESS-128).", PETSCII_RETURN
        .literal "            $", 0

    woz_rev_s1b:
        .literal " - 128 = ", 0

    woz_rev_s2:
        .literal PETSCII_RETURN, PETSCII_RETURN
        .literal "  STEP 2. READ MANTISSA BYTES, MSB FIRST.", PETSCII_RETURN
        .literal "            ", 0

    woz_rev_s2b:
        .literal PETSCII_RETURN
        .literal "            SIGN: ", 0

    woz_rev_s3:
        .literal PETSCII_RETURN, PETSCII_RETURN
        .literal "  STEP 3. RECONSTRUCT.", PETSCII_RETURN
        .literal "            MANTISSA_INT = $", 0

    woz_rev_s3a:
        .literal " = ", 0

    woz_rev_s3b:
        .literal PETSCII_RETURN
        .literal "            MANTISSA_INT / 2^22 = ", 0

    woz_rev_s3c:
        .literal PETSCII_RETURN
        .literal "            VALUE = ", 0

    woz_rev_s3d:
        .literal " X 2^", 0

    woz_rev_end:
        .literal PETSCII_RETURN, PETSCII_RETURN
        .literal "  RESULT: ", 0

    woz_rev_end2:
        .literal PETSCII_RETURN, 0
.endscope

.endif
