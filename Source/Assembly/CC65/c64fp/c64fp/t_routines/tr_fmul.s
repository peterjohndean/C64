
.include "tr.inc"

.export tr_fmul

.import FP_FMUL
.import FP_FROM_UINT16, FP_FROM_INT8
.import TEST_FP1CMP, TEST_PASSED, TEST_FAILED, TEST_CHECK

.segment "CODE"
.proc tr_fmul
    TEST_ROUTINE_HEADER_MACRO msg_header

    ; --- T02: FMUL  12 * -5 = -60 ---
    FP_LOAD1_MACRO TestValue::val_12
    FP_LOAD2_MACRO TestValue::val_neg5
    jsr FP_FMUL
    TEST_FP1CMP_MACRO 0, msg_t00, TestValue::val_neg60

    ; --- T34: error handling - generic overflow (code 0) -------------
    ; Repeated squaring of 10,000.0 guarantees overflow within a
    ; handful of iterations regardless of exact starting value or
    ; exponent boundary arithmetic (10000^2=10^8, ^2=10^16, ^2=10^32,
    ; ^2=10^64 - already far past ~1.7*10^38 by the 4th squaring) -
    ; deliberately not relying on hitting an exact boundary byte
    ; pattern, which would be far more fragile to get right by hand.
    lda #>10000
    ldx #<10000
    jsr FP_FROM_UINT16                  ; FP1 = 10000.0
    FP_ERROR_INIT_MACRO t34_recover
    ldy #10                             ; well more iterations than needed
t34_loop:
    FP_COPY1TO2_MACRO
    jsr FP_FMUL                         ; FP1 = FP1 * FP1
    dey
    bne t34_loop
    ; should never reach here - see comment above
    FP_ERROR_CLEAR_MACRO
    TEST_FAILED_MACRO_V2 1, msg_t01
    jmp t34_done
t34_recover:
    lda FP_ERROR_CODE
    cmp #0
    bne t34_fail
    TEST_PASSED_MACRO_V2 1, msg_t01
    jmp t34_done
t34_fail:
    TEST_FAILED_MACRO_V2 1, msg_t01
t34_done:

    ; ========================================================
    ; T55-T57: FP_FMUL(1.0, x) == x - precision check at
    ; ordinary exponents.
    ;
    ; Motivated by tr_fmod.s T50-T57: x mod x gave exact 0 for
    ; "simple" mantissas (10, 3, 1, 100, 0.5, 1.5) but a half-ulp
    ; residue for pi and 2pi (full 24-bit mantissas). tr_fdiv.s
    ; T02-T05 ruled out FP_FDIV as the source (A/A == 1.0 exactly
    ; for both mantissa classes). With A/B == 1.0 exactly and
    ; FIX(1.0) == 1.0, FP_FMOD(A, A) reduces to A - 1.0*A, so the
    ; next suspect is whether FP_FMUL is lossless for a 1.0
    ; multiplicand against a full-mantissa operand.
    ;
    ; Interpretation:
    ;   T02/T03 fail, T04 passes -> FP_FMUL's shift-and-add loop
    ;       loses a bit against the 1.0 mantissa ($400000) for
    ;       full-mantissa multiplicands. Blast radius: every
    ;       multiplication by 1.0, and by extension every place
    ;       that normalises through a unit-mantissa multiply.
    ;   All three pass -> FP_FMUL is not the source; next suspect
    ;       is FP_FSUB's cancellation handling (see tr_fsub.s).
    ; ========================================================

    ; --- T55: FMUL 1.0 * pi ---
    FP_LOAD1_MACRO TestValue::val_1
    FP_LOAD2_MACRO TestValue::val_pi
    jsr FP_FMUL
    FP_STORE1_MACRO fp1_snapshot
    TEST_CHECK_MACRO_V2 2, msg_t02, 7           ; print actual bytes
    FP_LOAD1_MACRO fp1_snapshot
    TEST_FP1CMP_MACRO 2, msg_t02, TestValue::val_pi ; val_pi_1uplow

    ; --- T56: FMUL 1.0 * 2pi ---
    FP_LOAD1_MACRO TestValue::val_1
    FP_LOAD2_MACRO TestValue::val_2pi
    jsr FP_FMUL
    FP_STORE1_MACRO fp1_snapshot
    TEST_CHECK_MACRO_V2 3, msg_t03, 7               ; print actual bytes
    FP_LOAD1_MACRO fp1_snapshot
    TEST_FP1CMP_MACRO 3, msg_t03, TestValue::val_2pi    ; val_2pi_1uplow

    ; --- T57: FMUL 1.0 * 10 == 10 (control - trailing-zero mantissa) ---
    FP_LOAD1_MACRO TestValue::val_1
    FP_LOAD2_MACRO TestValue::val_10
    jsr FP_FMUL
    TEST_FP1CMP_MACRO 4, msg_t04, TestValue::val_10

    ; --- T58: FMUL 1.0 * 1/3 (another full mantissa) ---
    FP_LOAD1_MACRO TestValue::val_1
    FP_LOAD2_MACRO TestValue::val_one_third
    jsr FP_FMUL
    FP_STORE1_MACRO fp1_snapshot
    TEST_CHECK_MACRO_V2 5, msg_t05, 7
    FP_LOAD1_MACRO fp1_snapshot
    TEST_FP1CMP_MACRO 5, msg_t05, TestValue::val_one_third  ; val_1_3rd_1ulplow

;    ; --- T59: FMUL 1.0 * pi (true pi, one ulp low val_pi) ---
;    FP_LOAD1_MACRO TestValue::val_1
;    FP_LOAD2_MACRO val_pi_1uplow
;    jsr FP_FMUL
;    FP_STORE1_MACRO fp1_snapshot
;    TEST_CHECK_MACRO_V2 6, msg_t06, 7
;    FP_LOAD1_MACRO fp1_snapshot
;    TEST_FP1CMP_MACRO 6, msg_t06, val_pi_1uplow

    rts

.segment "BSS"
fp1_snapshot:       .res 4,0

.segment "RODATA"
msg_header:     .asciiz "mathematics: multiplication"
msg_t00:        .asciiz "12 * -5 = -60"
msg_t01:        .asciiz "trap overflow"
msg_t02:        .asciiz "1.0 * pi  = pi"
msg_t03:        .asciiz "1.0 * 2pi = 2pi"
msg_t04:        .asciiz "1.0 * 10  = 10"
msg_t05:        .asciiz "1.0 * 1/3 = 1/3"
msg_t06:        .asciiz "1.0 * pi (1ulp-low)"

;val_pi_1uplow:      .byte $81,$64,$87,$ec
;val_2pi_1uplow:     .byte $82,$64,$87,$ec
;val_1_3rd_1ulplow:  .byte $7f,$55,$55,$54
.endproc
