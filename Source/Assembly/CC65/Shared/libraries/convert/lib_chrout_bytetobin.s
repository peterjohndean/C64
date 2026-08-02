.include "labels_rom_kernal.s"

; Export the routines so they can be seen
.export OUTPUT_BYTETOBINARY

.segment "CODE"

; ============================================================
; PROCEDURE : OUTPUT_BYTETOBINARY_PROC
; ============================================================
; PURPOSE
; -------
; Converts a single byte value into its eight-character ASCII
; binary representation and outputs each character in order
; from most-significant bit (bit 7) to least-significant (bit 0)
; via KERNAL_CHROUT.
;
; Examples:
;   A = $00  →  outputs "00000000"
;   A = $4F  →  outputs "01001111"
;   A = $FF  →  outputs "11111111"
;
; ASL-CARRY BIT EXTRACTION
; ------------------------
; Each bit is extracted by shifting the value LEFT one position.
; ASL moves bit 7 into the carry flag and discards it from A,
; so successive calls to ASL peel off bits from MSB to LSB:
;
;   Iteration 0 (X=7): ASL → carry = original bit 7
;   Iteration 1 (X=6): ASL → carry = original bit 6
;   ...
;   Iteration 7 (X=0): ASL → carry = original bit 0
;
; CARRY-TO-ASCII TRICK (LDA #0 / ADC #'0')
; ------------------------------------------
; The carry flag holds the extracted bit (0 or 1) after each
; ASL. The trick converts carry directly to ASCII '0' or '1':
;
;   lda #0         ; A = 0
;   adc #'0'       ; A = 0 + $30 + C  →  $30 ('0') or $31 ('1')
;
; ADC adds the carry flag as part of its operation, so this
; two-instruction sequence produces the correct ASCII digit
; without any branching or masking. Clean and cycle-efficient.
;
; LOOP CONTROL (X REGISTER AS BIT COUNTER)
; -----------------------------------------
; X is initialised to 7 and decremented each iteration:
;
;   X=7  →  bit 7 output  (MSB first)
;   X=6  →  bit 6 output
;   ...
;   X=0  →  bit 0 output  (LSB last)
;   DEX makes X = $FF ($FF is negative in signed terms)
;   BPL tests the sign flag: branches while X ≥ 0 (bits 0-7)
;   When X wraps to $FF (bit 7 set), BPL falls through → RTS
;
; ALGORITHM
; ---------
;   1. LDX #7           — 8 bits to output (counter 7 downto 0)
;   loop:
;   2. ASL              — shift MSB into carry, A shifts left
;   3. PHA              — save shifted A (bit extracted, rest needed)
;   4. LDA #0           — clear A, preserving carry from ASL
;   5. ADC #'0'         — A = '0' + carry → ASCII '0' or '1'
;   6. JSR KERNAL_CHROUT — output the digit character
;   7. PLA              — restore shifted A for next iteration
;   8. DEX              — decrement bit counter
;   9. BPL loop         — repeat while X ≥ 0 (8 iterations total)
;  10. RTS              — all 8 bits output, return to caller
;
; REGISTER USE
; ------------
;   Entry : A = byte value to convert and display
;   Exit  : A = undefined (overwritten during loop)
;           X = $FF (wrapped below zero after final DEX)
;
; DESTROYS  : A, X
; PRESERVES : Y, stack balanced (each PHA matched by PLA)
;
; CYCLES    : 8 × (~18 cycles + KERNAL_CHROUT call time) + 6 (RTS)
;             ≈ 150 cycles + 8× KERNAL_CHROUT call time
;
; EXAMPLE
; -------
;     lda #$4f                      ; value to display
;     jsr OUTPUT_BYTETOBINARY_PROC  ; outputs "01001111" to current channel
; ============================================================
.proc OUTPUT_BYTETOBINARY_PROC
    ldx #7                  ; bit counter: 8 bits, indexed 7 downto 0
                            ; (MSB first: bit 7 output on first iteration)

@loop:
    asl                     ; shift left: bit 7 → carry, A = A << 1
                            ; carry now holds the bit we want to print

    pha                     ; save shifted A — subsequent iterations need
                            ; the remaining bits still in their shifted positions

    lda #0                  ; clear A while carry is preserved from ASL
                            ; (LDA does not affect the carry flag)
    adc #'0'                ; A = 0 + $30 + carry
                            ;   carry=0 → A = $30 = '0'  (bit was 0)
                            ;   carry=1 → A = $31 = '1'  (bit was 1)

    jsr KERNAL_CHROUT       ; output the ASCII digit for this bit

    pla                     ; restore shifted A: next ASL peels off the
                            ; next bit (current bit 7 was the original bit
                            ; 7-iteration, now gone; next MSB is ready)

    dex                     ; decrement bit counter
    bpl @loop				; branch while X ≥ 0 (sign flag clear)
                            ; after X=0: DEX → X=$FF, bit 7 set → BPL falls through

    rts                     ; all 8 bits output, return to caller
.endproc

OUTPUT_BYTETOBINARY = OUTPUT_BYTETOBINARY_PROC

