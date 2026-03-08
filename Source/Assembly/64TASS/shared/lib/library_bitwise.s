; ============================================================
; PROCEDURE : BITWISE_MULTIPLY_64_PROC
; Project   : Commodore 64 Bitwise Utility Library
; Target    : Commodore 64 / 6510 CPU
; Assembler : 64TASS v1.60+
; ============================================================
; PURPOSE
; -------
; Multiplies an unsigned 8-bit value by 64, producing a 16-bit
; result returned across two registers (MSB in A, LSB in X).
;
; Multiplication by 64 = 2^6 is performed entirely with bit
; shifts — no hardware multiply instruction exists on the 6510.
; Each left shift doubles the value (×2 per shift), so six
; left shifts achieve ×2^6 = ×64. The MSB is recovered by
; shifting the original value right by two positions.
;
; 16-BIT RESULT DECOMPOSITION
; ---------------------------
; For an 8-bit input %abcdefgh, the full 16-bit product is:
;
;   value × 64  =  value × 2^6
;
;   Bit layout of the 16-bit result:
;   ┌─────────────────┬─────────────────┐
;   │  MSB  (high)    │  LSB  (low)     │
;   │  bits 15-8      │  bits 7-0       │
;   ├─────────────────┼─────────────────┤
;   │  0 0 a b c d e f│  g h 0 0 0 0 0 0│
;   └─────────────────┴─────────────────┘
;
;   LSB = value << 6  (6 left  shifts of original value)
;   MSB = value >> 2  (2 right shifts of original value)
;
;   Total shift count = 6 + 2 = 8 — always equals the bit
;   width of the input. This is the general rule for any
;   power-of-2 multiplier 2^k applied to an n-bit value:
;     LSB shifts = k,    MSB shifts = n − k,  total = n.
;
; WORKED EXAMPLE
; --------------
;   Input:  A = $05  (%00000101)
;   × 64  = 320 = $0140
;
;   LSB: %00000101 << 6  →  %01000000  =  $40  → X
;   MSB: %00000101 >> 2  →  %00000001  =  $01  → A
;
;   Result: A=$01, X=$40  → 16-bit value $0140 = 320 ✓
;
; ALGORITHM
; ---------
;   1. PHA  — save the original input value onto the stack
;   2. ASL × 6 — shift A left six times to form the LSB
;      Bits shifted out through carry are discarded; they
;      belong to the MSB which is calculated separately
;   3. TAX  — move LSB into X for safe keeping
;   4. PLA  — restore the original value from the stack
;   5. LSR × 2 — shift A right twice to form the MSB
;      Zeros shift in from the left (logical, not arithmetic)
;   6. RTS  — return with MSB in A, LSB in X
;
; WHY PUSH/POP RATHER THAN A ZERO-PAGE SCRATCH BYTE?
; ---------------------------------------------------
; The ASL sequence overwrites A completely — after 6 shifts the
; original high bits are gone. The stack is the only way to
; recover the original value without a zero-page scratch
; location. PHA/PLA costs 7 cycles but requires no caller
; contract around zero-page usage, making this procedure
; self-contained and safe to call from any context.
;
; GENERALISING TO OTHER POWER-OF-2 MULTIPLIERS
; ---------------------------------------------
; The same push/shift/pop/shift pattern applies for any 2^k
; multiplier. Only the shift counts change:
;
;   Multiplier │ k │ LSB shifts (<<) │ MSB shifts (>>) │ Total
;   ───────────┼───┼─────────────────┼─────────────────┼──────
;       ×2     │ 1 │        1        │        7        │   8
;       ×4     │ 2 │        2        │        6        │   8
;       ×8     │ 3 │        3        │        5        │   8
;      ×16     │ 4 │        4        │        4        │   8
;      ×32     │ 5 │        5        │        3        │   8
;      ×64     │ 6 │        6        │        2        │   8
;     ×128     │ 7 │        7        │        1        │   8
;
; Note: For k < 4 (×2, ×4, ×8) ROL/ROR sequences into a
; second accumulator byte are an alternative. The push/shift/
; pop/shift approach is preferred for k ≥ 4 because it avoids
; an intermediate storage byte while keeping cycle counts low.
;
; REGISTER USE
; ------------
;   Entry : A = unsigned 8-bit value to multiply
;   Exit  : A = MSB of 16-bit result (bits 15-8)
;           X = LSB of 16-bit result (bits 7-0)
;
; DESTROYS  : A, X
; PRESERVES : Y, stack balanced (PHA matched by PLA)
;
; CYCLES    : 2 (PHA) + 12 (6× ASL) + 2 (TAX) + 4 (PLA)
;           + 4 (2× LSR) + 6 (RTS)  =  ~30 cycles
;
; EXAMPLE
; -------
;     lda #$05             ; input value = 5
;     jsr BITWISE_MULTIPLY_64_PROC
;     ; A = $01 (MSB), X = $40 (LSB) → 16-bit result $0140 = 320
;     stx result_lo        ; store low  byte of product
;     sta result_hi        ; store high byte of product
;
; NOTE ON NAMING CONVENTION
; -------------------------
; This procedure name uses mixed case (PascalCase + underscore).
; The project convention is lowercase throughout. Consider
; renaming to bitwise_multiply_64_proc for consistency.
; ============================================================
BITWISE_MULTIPLY_64_PROC .proc

    pha                     ; save original value — needed for MSB calculation
                            ; (6× ASL will destroy all useful bits in A)

    ; ── compute LSB: value << 6 ──────────────────────────────
    ; six left shifts = multiplication by 2^6 = 64 (low byte)
    ; bits shifted out through carry are the MSB contributions;
    ; they are deliberately discarded here and rebuilt via LSR
    .rept 6                 ; 64tass repeat directive: expand 6 asl instructions
        asl                 ; shift left once: A = A × 2, carry ← old bit 7
    .endrept                ; after 6 iterations: A = original << 6 (LSB)

    tax                     ; LSB is complete — move to X for safe keeping
                            ; A is now free for the MSB calculation

    ; ── compute MSB: value >> 2 ──────────────────────────────
    pla                     ; restore the original unshifted value from stack

    lsr                     ; shift right once:  A = A >> 1, zeros in from left
    lsr                     ; shift right again: A = A >> 2  (MSB complete)
                            ; bit layout after 2× LSR: %00abcdef
                            ; where abcdefgh was the original input

    rts                     ; return: A = MSB ($00-$3F), X = LSB ($00-$C0)
.endproc
