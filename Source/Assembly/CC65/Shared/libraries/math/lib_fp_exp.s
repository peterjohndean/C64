.include "labels_fp.s"

.export FP_EXP

.import FP_FMUL, FP_FSUB, FP_FADD, FP_FDIV
.import FP_FIX, FP_FLOAT, FP_SWAP
.import FP_ERROR

.segment "CODE"
; ============================================================
; PROCEDURE : FP_EXP_PROC
; Purpose : Exponential function. FP1 = e^FP1.
; Algorithm : Splits x into an integer part n and fractional
;             remainder u via log2(e)*x and FP_FIX, evaluates a
;             rational approximation for e^u in u*u, then
;             multiplies by 2^(n+1) by directly adding (n+1) to
;             the result's exponent - the "poor man's ldexp"
;             also used implicitly throughout this package.
; Entry   : FP1 loaded with the argument x
; Exit    : FP1 = e^x
; Destroys: A, X, Y; FP2 and this proc's private u/t/sexp/int_val
;           scratch
; Traps   : ovflw_trap calls FP_ERROR_PROC (code 3) if x is large enough
;           would overflow; underflow (x very negative) instead
;           silently returns 0.0, per the original's convention
; ============================================================
.proc FP_EXP_PROC
    ldx #3
@l2e_loop:
    lda l2e,x
    sta FP2_EXP,x               ; FP2 = log2(e)
    dex
    bpl @l2e_loop
    jsr FP_FMUL                 ; FP1 = log2(e) * x
    ldx #3
@fsa:
    lda FP1_EXP,x
    sta u,x                     ; u = log2(e) * x  (saved before FIX
    dex                         ; truncates FP1 to an integer)
    bpl @fsa
    jsr FP_FIX                  ; FP1_MANT/+1 = integer part of u
    lda FP1_MANT+1
    sta int_val                 ; int_val = truncated integer
    sec
    sbc #124                    ; int_val - 124 ...
    lda FP1_MANT
    sbc #0                      ; ... as a 16-bit subtraction
    bpl @ovflw_trap             ; result >= 0: int_val >= 124, overflow
    clc
    lda FP1_MANT+1
    adc #120                    ; int_val + 120 ...
    lda FP1_MANT
    adc #0                      ; ... as a 16-bit addition
    bpl @contin                 ; result positive: in range, continue
    lda #0
    ldx #3
@zero_result:
    sta FP1_EXP,x               ; int_val < -120: underflow, result = 0
    dex
    bpl @zero_result
    rts
@ovflw_trap:
    lda #3                      ; [ERROR HANDLING] error code 3:
    jmp FP_ERROR                ; exp overflow
@contin:
    jsr FP_FLOAT                ; FP1 = float(int_val)
    ldx #3
@entd:
    lda u,x
    sta FP2_EXP,x               ; FP2 = u
    dex
    bpl @entd
    jsr FP_FSUB                 ; FP1 = u - float(int_val)  (fractional
                                ; remainder, range roughly -0.5..0.5)
    ldx #3
@zsav:
    lda FP1_EXP,x
    sta u,x                     ; u = fractional remainder
    sta FP2_EXP,x               ; FP2 = u, ready to square it
    dex
    bpl @zsav
    jsr FP_FMUL                 ; FP1 = u*u
    ldx #3
@la2:
    lda a2,x
    sta FP2_EXP,x               ; FP2 = A2 (approximation constant)
    lda FP1_EXP,x
    sta sexp,x                  ; sexp = u*u (saved for later)
    dex
    bpl @la2
    jsr FP_FADD                 ; FP1 = u*u + A2
    ldx #3
@lb2:
    lda b2,x
    sta FP2_EXP,x               ; FP2 = B2 (approximation constant)
    dex
    bpl @lb2
    jsr FP_FDIV                 ; FP1 = B2 / (u*u + A2)
    ldx #3
@dload:
    lda FP1_EXP,x
    sta t,x                     ; t = B2 / (u*u + A2)
    lda c2,x
    sta FP1_EXP,x               ; FP1 = C2 (approximation constant)
    lda sexp,x
    sta FP2_EXP,x               ; FP2 = u*u
    dex
    bpl @dload
    jsr FP_FMUL                 ; FP1 = C2 * u*u
    jsr FP_SWAP                 ; move C2*u*u into FP2
    ldx #3
@ltmp:
    lda t,x
    sta FP1_EXP,x               ; FP1 = B2/(u*u+A2)
    dex
    bpl @ltmp
    jsr FP_FSUB                 ; FP1 = C2*u*u - B2/(u*u+A2)
    ldx #3
@ldd:
    lda d_const,x
    sta FP2_EXP,x               ; FP2 = D (approximation constant)
    dex
    bpl @ldd
    jsr FP_FADD                 ; FP1 = D + C2*u*u - B2/(u*u+A2)
    jsr FP_SWAP                 ; move that sum into FP2
    ldx #3
@lfa:
    lda u,x
    sta FP1_EXP,x               ; FP1 = u
    dex
    bpl @lfa
    jsr FP_FSUB                 ; FP1 = -u + D+C2*u*u-B2/(u*u+A2)
    ldx #3
@lf3:
    lda u,x
    sta FP2_EXP,x               ; FP2 = u
    dex
    bpl @lf3
    jsr FP_FDIV                 ; FP1 = u / (above)
    ldx #3
@ld12:
    lda mhlf,x
    sta FP2_EXP,x               ; FP2 = 0.5
    dex
    bpl @ld12
    jsr FP_FADD                 ; FP1 = 0.5 + u/(above)
    sec
    lda int_val
    adc FP1_EXP                 ; multiply the result by
    sta FP1_EXP                 ; 2^(int_val+1) - fold the
                                ; power-of-2 scale factor
                                ; straight into the exponent
    rts

; --- constant table (own copies - the original 1976 listing
;     shared its MHLF/0.5 constant with the LOG page since both
;     lived in the same physical page; keeping FP_LOG_PROC and
;     FP_EXP_PROC independently droppable costs 4 duplicated
;     bytes here in exchange for that independence) ---
l2e:        .byte $80,$5c,$55,$1e     ; log2(e)         = 1.4426950409
a2:         .byte $86,$57,$6a,$e1     ; A2              = 87.417497202
b2:         .byte $89,$4d,$3f,$1d     ; B2              = 617.9722695
c2:         .byte $7b,$46,$fa,$70     ; C2              = 0.03465735903
d_const:    .byte $83,$4f,$a3,$03     ; D               = 9.9545957821
mhlf:       .byte $7f,$40,$00,$00     ; 0.5

; --- private scratch ---
u:          .res 4,0
t:          .res 4,0
sexp:       .res 4,0
int_val:    .byte 0
.endproc

; ------------------------------------------------------------
; Short public aliases, matching the rest of the library's
; FP_FADD-style naming (no _PROC suffix).
; ------------------------------------------------------------
FP_EXP = FP_EXP_PROC
