.include "labels_rom_kernal.s"

; Export the routine so it can be seen
.export OUTPUT_BYTETODEC

.segment "CODE"

; ============================================================
; PROCEDURE : OUTPUT_BYTETODEC_PROC
; ============================================================
; PURPOSE
; -------
; Converts a single byte value ($00-$FF) into its decimal 
; ASCII representation (0-255) and outputs it to the screen 
; via KERNAL_CHROUT.
;
; PADDING OPTIONS
; ---------------
; You control the formatting using the X register:
;   X = $00 : No padding      (e.g., outputs "7", "42", "255")
;   X = $20 : Space padded    (e.g., outputs "  7", " 42", "255")
;   X = $30 : Zero padded     (e.g., outputs "007", "042", "255")
;
; ALGORITHM
; ---------
; Uses successive subtraction of 100s, then 10s. The remainder 
; becomes the units digit. A "significant digit" flag tracks 
; if we have started printing real numbers to ensure we don't 
; pad a zero in the tens column if the hundreds column was 
; already legitimately printed (e.g., forcing 105 instead of 1 5).
;
; REGISTER USE
; ------------
;   Entry : A = byte value to convert
;           X = padding character ($00, $20, or $30)
;   Exit  : A = ASCII character of the units digit
;
; DESTROYS  : A, X, Y
; PRESERVES : Stack balanced
; ============================================================
.proc OUTPUT_BYTETODEC_PROC
    sta @value          ; Save the original byte value
    stx @pad_char       ; Save the padding preference
    ldy #$00
    sty @sig_flag       ; Reset flag using Y so A remains untouched!

    ; ── HUNDREDS ─────────────────────────────────────────────
    ldy #$FF            ; Initialize quotient to -1
    sec
@h_loop:
    iny                 ; Increment quotient
    sbc #100            ; Subtract 100
    bcs @h_loop         ; Keep subtracting until A drops below 0
    adc #100            ; Add 100 back to restore the remainder
    sta @value          ; Save remainder (tens + units) for next step

    tya                 ; Move hundreds quotient to A
    bne @print_h        ; If > 0, we must print it

    ; Hundreds is zero. Check padding rules.
    ldx @pad_char
    beq @skip_h         ; X=$00 means no padding, skip entirely
    txa
    jsr KERNAL_CHROUT   ; Print the padding character (space or zero)
    jmp @skip_h         ; Skip setting the significant digit flag

@print_h:
    ora #$30            ; Convert quotient to ASCII ('0'-'9')
    jsr KERNAL_CHROUT
    dec @sig_flag       ; Change flag from $00 to $FF (marks that we've printed a digit)

@skip_h:
    ; ── TENS ─────────────────────────────────────────────────
    lda @value          ; Load the remainder
    ldy #$FF            ; Initialize quotient to -1
    sec
@t_loop:
    iny
    sbc #10
    bcs @t_loop
    adc #10
    sta @value          ; Save final remainder (units)

    tya
    bne @print_t        ; If > 0, we must print it

    ; Tens is zero. Do we print '0', print padding, or skip?
    bit @sig_flag       
    bmi @print_t        ; If flag is $FF (negative bit 7), hundreds were printed. We MUST print '0'.

    ; Hundreds were not printed. Check padding rules.
    ldx @pad_char
    beq @skip_t         ; X=$00 means no padding, skip entirely
    txa
    jsr KERNAL_CHROUT   ; Print the padding character
    jmp @skip_t

@print_t:
    ora #$30            ; Convert quotient to ASCII
    jsr KERNAL_CHROUT

@skip_t:
    ; ── UNITS ────────────────────────────────────────────────
    lda @value          ; Units are always printed, even if the value is 0
    ora #$30            
    jmp KERNAL_CHROUT   ; Tail call: output and return directly to caller!

; ── LOCAL VARIABLES ──────────────────────────────────────
.segment "BSS"
@value:    .res 1
@pad_char: .res 1
@sig_flag: .res 1
.segment "CODE"         

.endproc

OUTPUT_BYTETODEC = OUTPUT_BYTETODEC_PROC
