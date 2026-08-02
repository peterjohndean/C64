.include "labels_fp.s"

.export FP_LOG

.import FP_ERROR
.import FP_SWAP, FP_FLOAT
.import FP_FSUB, FP_FADD, FP_FDIV, FP_FMUL

.segment "CODE"
; ============================================================
; PROCEDURE : FP_LOG_PROC
; Purpose : Natural logarithm. FP1 = ln(FP1).
; Algorithm : Range-reduces the argument by extracting its power-
;             of-2 exponent n, computes u = (m-sqrt2)/(m+sqrt2) for
;             the remaining mantissa m, evaluates a rational
;             (Pade-style) approximation in t = u*u, then combines
;             with n*ln(2) - patterned after an HP-2100 algorithm
;             per the original documentation. See the PROVENANCE
;             note in the file header regarding untested errata.
; Entry   : FP1 loaded with the argument; must be > 0
; Exit    : FP1 = ln(FP1)
; Destroys: A, X, Y; FP2 and this proc's private u/t/sexp scratch
; Traps   : error_trap calls FP_ERROR_PROC (code 2) if the argument is <= 0
; ============================================================
.proc FP_LOG_PROC
    lda FP1_MANT                ; test the argument's sign/magnitude
    beq @error_trap             ; zero mantissa: log(0) undefined
    bpl @cont                   ; positive: proceed
@error_trap:
    lda #2                      ; [ERROR HANDLING] error code 2: log
    jmp FP_ERROR                ; domain error (argument <= 0)
@cont:
    jsr FP_SWAP                 ; move the argument into FP2
    ldx #0                      ; [ERRATA FIX, wozfp2.txt] provisional
                                ; high byte of the 16-bit exponent value
    lda FP2_EXP
    ldy #$80
    sty FP2_EXP                 ; force FP2's exponent to 2^0
    eor #$80                    ; complement sign bit of the original
                                ; exponent (excess-128 <-> 2's complement)
    sta FP1_MANT+1              ; stash it into FP1 as a 16-bit integer
    bpl @exp_positive           ; [ERRATA FIX] sign-extend, don't always
    dex                         ; zero-extend: for argument < 1.0 this
                                ; exponent is negative and needs high
                                ; byte = $FF, not $00 - Rankin's original
                                ; bug (uncorrected, LOG(x<1) is wrong)
@exp_positive:
    stx FP1_MANT                ; [ERRATA FIX] high byte, correctly signed
    jsr FP_FLOAT                ; FP1 = float(n), the power-of-2 exponent
    ldx #3
@sexp1:
    lda FP2_EXP,x
    sta u,x                     ; u = FP2 (the range-reduced mantissa)
    lda FP1_EXP,x
    sta sexp,x                  ; sexp = n (saved for later)
    lda r22,x
    sta FP1_EXP,x               ; FP1 = sqrt(2)
    dex
    bpl @sexp1
    jsr FP_FSUB                 ; FP1 = u - sqrt(2)
    ldx #3
@savet:
    lda FP1_EXP,x
    sta t,x                     ; t = u - sqrt(2)
    lda u,x
    sta FP1_EXP,x               ; FP1 = u
    lda r22,x
    sta FP2_EXP,x               ; FP2 = sqrt(2)
    dex
    bpl @savet
    jsr FP_FADD                 ; FP1 = u + sqrt(2)
    ldx #3
@tm2:
    lda t,x
    sta FP2_EXP,x               ; FP2 = u - sqrt(2)
    dex
    bpl @tm2
    jsr FP_FDIV                 ; FP1 = (u-sqrt2)/(u+sqrt2)
    ldx #3
@mit:
    lda FP1_EXP,x
    sta t,x                     ; t = (u-sqrt2)/(u+sqrt2)
    sta FP2_EXP,x               ; FP2 = t, ready to square it
    dex
    bpl @mit
    jsr FP_FMUL                 ; FP1 = t*t
    jsr FP_SWAP                 ; move t*t into FP2
    ldx #3
@mic:
    lda c_const,x
    sta FP1_EXP,x               ; FP1 = C (approximation constant)
    dex
    bpl @mic
    jsr FP_FSUB                 ; FP1 = t*t - C
    ldx #3
@m2mb:
    lda mb,x
    sta FP2_EXP,x               ; FP2 = MB (approximation constant)
    dex
    bpl @m2mb
    jsr FP_FDIV                 ; FP1 = MB / (t*t - C)
    ldx #3
@m2a1:
    lda a1,x
    sta FP2_EXP,x               ; FP2 = A1 (approximation constant)
    dex
    bpl @m2a1
    jsr FP_FADD                 ; FP1 = MB/(t*t-C) + A1
    ldx #3
@m2t:
    lda t,x
    sta FP2_EXP,x               ; FP2 = t
    dex
    bpl @m2t
    jsr FP_FMUL                 ; FP1 = (MB/(t*t-C)+A1) * t
    ldx #3
@m2mhl:
    lda mhlf,x
    sta FP2_EXP,x               ; FP2 = 0.5
    dex
    bpl @m2mhl
    jsr FP_FADD                 ; FP1 += 0.5
    ldx #3
@ldexp:
    lda sexp,x
    sta FP2_EXP,x               ; FP2 = n (original exponent)
    dex
    bpl @ldexp
    jsr FP_FADD                 ; FP1 += n
    ldx #3
@mle2:
    lda le2,x
    sta FP2_EXP,x               ; FP2 = ln(2)
    dex
    bpl @mle2
    jsr FP_FMUL                 ; FP1 = (... + n) * ln(2)
    rts

; --- constant table (own copies, see FP_EXP_PROC for why each
;     proc keeps its own rather than sharing) ---
r22:        .byte $80,$5a,$82,$7a      ; sqrt(2)      = 1.4142136
le2:        .byte $7f,$58,$b9,$0c      ; ln(2)        = 0.69314718
a1:         .byte $80,$52,$b0,$40      ; A1           = 1.2920074
mb:         .byte $81,$ab,$86,$49      ; MB           = -2.6398577
c_const:    .byte $80,$6a,$08,$66      ; C            = 1.6567626
mhlf:       .byte $7f,$40,$00,$00      ; 0.5

; --- private scratch (see labels_fp.s for why this is plain
;     RAM rather than zero page) ---
u:      .res 4,0
t:      .res 4,0
sexp:   .res 4,0
.endproc

; ------------------------------------------------------------
; Short public aliases, matching the rest of the library's
; FP_FADD-style naming (no _PROC suffix).
; ------------------------------------------------------------
FP_LOG = FP_LOG_PROC
