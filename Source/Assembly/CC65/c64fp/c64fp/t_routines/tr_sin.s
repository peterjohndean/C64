
.include "tr.inc"

.export tr_sin

.import FP_SIN
.import TEST_CHECK

.proc tr_sin
    ; --------------------------------------------------------
    ; [BUG FIX] The previous version did:
    ;     lda #<(30)
    ;     jsr FP_FROM_INT8
    ;     jsr FP_SIN
    ; which puts the INTEGER 30.0 into FP1 - not 30 degrees, and
    ; not 30 radians-worth-of-anything-reasonable either. FP_SIN
    ; (lib_fp_sin.s) has no range reduction yet - its documented
    ; scope is |x| <= pi/2 (~1.5708 radians). Feeding it 30.0
    ; radians is so far outside that range that the Horner
    ; polynomial's intermediate t=x*x=900 (and higher powers of
    ; t after that) overflow this format's exponent range for
    ; real - not a "silently a bit imprecise" case, a genuine
    ; FP_ERROR trap (code 0, "overflow"), exactly what you saw.
    ;
    ; Fix: load FP1 directly with 30 DEGREES EXPRESSED IN RADIANS
    ; (0.5235987755... = 30 * pi/180) via FP_LOAD1_MACRO, rather
    ; than loading the bare integer 30 and hoping FP_SIN does
    ; degree handling or range reduction it doesn't do yet. This
    ; constant was derived and cross-checked the same way as
    ; FP_SIN's own Taylor coefficients (see the conversation this
    ; was built in) - not hand-guessed.
    ;
    ; A companion FP_ERROR_INIT_MACRO guard is added below too:
    ; lib_fp_error.s's own header is explicit that a trap with no
    ; recovery point armed is UNDEFINED BEHAVIOUR ("almost
    ; certainly a crash, not a controlled one") - which is exactly
    ; what the garbage "unexpected error - got: 6200" was: the
    ; overflow trap's unwind restored the stack pointer from
    ; FP_ERROR_SP, which nothing had ever set, and RTS'd
    ; somewhere meaningless. Arming a guard here means that IF a
    ; future test accidentally goes out of FP_SIN's documented
    ; scope again, it fails safely (lands at t00_recover, prints
    ; "trapped error: overflow", and this test simply continues)
    ; instead of corrupting the stack and crashing unrelated code
    ; downstream. Same pattern as this library's T32-T36.
    ; --------------------------------------------------------
    FP_ERROR_INIT_MACRO t00_recover
    FP_LOAD1_MACRO rad30        ; FP1 = 0.5235987755... (30 degrees,
                                ; already in FP_SIN's documented
                                ; [-pi/2, pi/2] scope)
    jsr FP_SIN                  ; FP1 = sin(30 deg) ~= 0.5
    FP_ERROR_CLEAR_MACRO        ; success path: discard the now-
                                ; unneeded recovery point (see
                                ; macros_fp.s - skipping this leaks
                                ; 2 bytes of stack per call)
t00_recover:
    ; only reached if FP_SIN actually trapped - FP_ERROR_CODE
    ; would say what, but for a correctly-scoped input this
    ; recovery label is never entered
    TEST_CHECK_MACRO_V2 0, msg_t00, 7

    ; --------------------------------------------------------
    ; T01-T03: more points across FP_SIN's documented
    ; [-pi/2, pi/2] scope, not just the one already-proven 30
    ; degree case - each is a genuinely different test of the
    ; SAME 5-term Horner polynomial at a different distance from
    ; its x=0 expansion point, since a Taylor series's accuracy is
    ; NOT uniform across its valid range (see lib_fp_sin.s's own
    ; header table: error grows from ~2e-11 at 30 degrees to
    ; ~3.5e-6 at 90 degrees). T03 in particular exercises the
    ; documented scope's own BOUNDARY (90 degrees = pi/2 exactly,
    ; the edge lib_fp_sin.s's header explicitly calls "still
    ; acceptable" rather than comfortably inside the safe zone) -
    ; proving that boundary behaves as documented, rather than
    ; just trusting the header comment's own math.
    ;
    ; Expected values (Python math.sin, for visual comparison
    ; against whatever TEST_CHECK prints - remember FP_TO_ASCII
    ; TRUNCATES fractional digits rather than rounding, so e.g.
    ; 0.86602540 may legitimately print as 0.8660253 or similar,
    ; not necessarily 0.8660254 - see the T00 conversation for why
    ; that's expected, not a bug):
    ;   sin(45 deg) = 0.70710678
    ;   sin(60 deg) = 0.86602540
    ;   sin(90 deg) = 1.00000000  <- FP_SIN's own table predicts
    ;                                ~3.5e-6 error here specifically
    ; --------------------------------------------------------
    FP_ERROR_INIT_MACRO t01_recover
    FP_LOAD1_MACRO rad45
    jsr FP_SIN                  ; FP1 = sin(45 deg) ~= 0.70710678
    FP_ERROR_CLEAR_MACRO
t01_recover:
    TEST_CHECK_MACRO_V2 1, msg_t01, 7

    FP_ERROR_INIT_MACRO t02_recover
    FP_LOAD1_MACRO rad60
    jsr FP_SIN                  ; FP1 = sin(60 deg) ~= 0.86602540
    FP_ERROR_CLEAR_MACRO
t02_recover:
    TEST_CHECK_MACRO_V2 2, msg_t02, 7

    FP_ERROR_INIT_MACRO t03_recover
    FP_LOAD1_MACRO rad90
    jsr FP_SIN                  ; FP1 = sin(90 deg) ~= 1.0 - the
                                ; documented scope boundary itself
    FP_ERROR_CLEAR_MACRO
t03_recover:
    TEST_CHECK_MACRO_V2 3, msg_t03, 7

    rts

.segment "RODATA"
msg_t00:    .asciiz     "sin (30deg)"
msg_t01:    .asciiz     "sin (45deg)"
msg_t02:    .asciiz     "sin (60deg)"
msg_t03:    .asciiz     "sin (90deg) - scope boundary"
rad30:      .byte $7f,$43,$05,$49   ; 0.5235987755982988 rad = 30 deg
rad45:      .byte $7f,$64,$87,$ed   ; 0.7853981633974483 rad = 45 deg
rad60:      .byte $80,$43,$05,$49   ; 1.0471975511965976 rad = 60 deg
rad90:      .byte $80,$64,$87,$ed   ; 1.5707963267948966 rad = 90 deg
.endproc
