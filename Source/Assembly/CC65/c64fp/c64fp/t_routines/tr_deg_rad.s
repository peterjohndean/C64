
.include "tr.inc"

.export tr_deg_rad

.import FP_DEG_TO_RAD, FP_RAD_TO_DEG
.import FP_FROM_INT8
.import TEST_CHECK

.segment "CODE"
.proc tr_deg_rad
    TEST_ROUTINE_HEADER_MACRO msg_header

    ; --------------------------------------------------------
    ; T00-T01: degrees -> radians, two ordinary angles
    ; T02: radians -> degrees, using pi itself (a value already
    ;      independently verified in lib_fp_sin_full.s) so the
    ;      expected result is a clean, memorable 180.0
    ; T03  45 deg round-tripped -> ~44.9999923 deg (measured), error
    ;      ~-7.7e-6 from the 24-bit precision of the pi/180 and 180/pi
    ;      constants. Improved from the pre-fix value (-1.5e-5) now that
    ;      the FMUL LSB fix preserves one more mantissa bit through the
    ;      round trip.
    ;
    ; Expected values (Python math, for visual comparison - same
    ; truncating-display caveat as every earlier test in this
    ; suite):
    ;   T00  30 deg  -> 0.5235988 rad
    ;   T01  90 deg  -> 1.5707963 rad
    ;   T02  pi rad  -> 180.0000000 deg
    ;   T03  45 deg round-tripped -> ~44.9999847 deg (measured), error
    ;        ~-1.5e-5 from the 24-bit precision of the pi/180 and 180/pi
    ;        constants. NOT a bug - see lib_fp_deg_rad.s's own precision
    ;        note; this is the format-limited round-trip error, not a
    ;        regression against a cleaner ideal.
    ; --------------------------------------------------------
    FP_ERROR_INIT_MACRO t00_recover
    lda #30
    jsr FP_FROM_INT8
    jsr FP_DEG_TO_RAD            ; FP1 = 30 deg in radians ~= 0.5235988
    FP_ERROR_CLEAR_MACRO
t00_recover:
    TEST_CHECK_MACRO_V2 0, msg_t00, 7

    FP_ERROR_INIT_MACRO t01_recover
    lda #90
    jsr FP_FROM_INT8
    jsr FP_DEG_TO_RAD            ; FP1 = 90 deg in radians ~= 1.5707963
    FP_ERROR_CLEAR_MACRO
t01_recover:
    TEST_CHECK_MACRO_V2 1, msg_t01, 7

    FP_ERROR_INIT_MACRO t02_recover
    FP_LOAD1_MACRO TestValue::val_pi
    jsr FP_RAD_TO_DEG            ; FP1 = pi radians in degrees ~= 180.0
    FP_ERROR_CLEAR_MACRO
t02_recover:
    TEST_CHECK_MACRO_V2 2, msg_t02, 7

    FP_ERROR_INIT_MACRO t03_recover
    lda #45
    jsr FP_FROM_INT8
    jsr FP_DEG_TO_RAD            ; FP1 = 45 deg in radians
    jsr FP_RAD_TO_DEG            ; FP1 = back to degrees - should be
                                 ; VERY close to 45.0 but not exact,
                                 ; per the header's round-trip table
    FP_ERROR_CLEAR_MACRO
t03_recover:
    TEST_CHECK_MACRO_V2 3, msg_t03, 7

    rts

.segment "RODATA"
msg_header: .asciiz     "conversion: degrees/radians"
msg_t00:    .asciiz     "deg->rad (30deg)"
msg_t01:    .asciiz     "deg->rad (90deg)"
msg_t02:    .asciiz     "rad_to_deg (pi)"
msg_t03:    .asciiz     "deg->rad->deg (45deg)"
.endproc
