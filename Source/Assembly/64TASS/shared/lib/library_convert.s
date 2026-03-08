; ============================================================
; FILE      : library_convert.s
; Project   : Commodore 64 Conversion Utility Library
; Target    : Commodore 64 / 6510 CPU
; Assembler : 64TASS v1.60+
; ============================================================
; PURPOSE
; -------
; Provides procedures for converting binary byte values to
; their human-readable ASCII string representations and
; sending them to the screen via the KERNAL CHROUT routine.
;
; PROCEDURE INVENTORY
; -------------------
;   OUTPUT_BYTETOHEX_PROC       - byte → 2-char hex string  (e.g. $4F → "4F")
;   OUTPUT_BYTETOBINARY_PROC    - byte → 8-char binary string (e.g. $4F → "01001111")
;
; DEPENDENCIES
; ------------
; Both procedures call KERNAL_CHROUT, which must be defined
; before this file is assembled. The standard C64 KERNAL
; character output vector sits at:
;
;   KERNAL_CHROUT  =  $FFD2  ; output character in A to current channel
;
; NOTE ON SPELLING: the Commodore operating system is correctly
; spelled "KERNAL" (not "KERNAL"). This project uses KERNAL_CHROUT
; throughout — consider aligning with the canonical spelling
; KERNAL_CHROUT for clarity when cross-referencing CBM documentation.
;
; NOTE ON NAMING CONVENTION
; -------------------------
; Both procedure names use mixed case (PascalCase). The project
; convention is lowercase throughout. Consider renaming to
; output_byte_to_hex and output_byte_to_binary for consistency.
;
; ASSEMBLER : 64TASS (tested against v1.60)
; ============================================================


; ============================================================
; PROCEDURE : OUTPUT_BYTETOHEX_PROC
; ============================================================
; PURPOSE
; -------
; Converts a single byte value into its two-character ASCII
; hexadecimal representation and outputs both characters to
; the screen via KERNAL_CHROUT (high nibble first).
;
; Examples:
;   A = $00  →  outputs "00"
;   A = $4F  →  outputs "4F"
;   A = $FF  →  outputs "FF"
;
; NIBBLE-TO-ASCII CONVERSION
; --------------------------
; A nibble (4 bits) has values 0-15. The ASCII mapping is:
;
;   Nibble 0-9  →  ASCII '0'-'9'  ($30-$39)
;   Nibble A-F  →  ASCII 'A'-'F'  ($41-$46)
;
; The conversion uses a two-step approach:
;   1. Add $30 ('0') to map 0-9 → '0'-'9', and 10-15 → ':'-'?'
;   2. If the result is ≥ $3A (':'), add a further 7 ($41-$3A=7)
;      to jump over the six non-alphanumeric characters between
;      '9' ($39) and 'A' ($41) in the ASCII table.
;
;   ASCII table gap:  '9'=$39  ':'=$3A  ... '@'=$40  'A'=$41
;                                        ↑ 6 characters to skip
;   Adding 7 lands exactly on 'A' for input nibble 10.
;
; CARRY-BASED ADJUSTMENT (ADC #$06 TRICK)
; ----------------------------------------
; The CMP #$3A instruction both tests the value AND sets the
; carry flag:
;   CMP sets C=0 if A < $3A  (nibble 0-9:  no adjustment needed)
;   CMP sets C=1 if A ≥ $3A  (nibble A-F:  adjustment needed)
;
; The subsequent ADC #$06 exploits this directly:
;   C=0 path (0-9): branch taken at BCC, ADC never executes
;   C=1 path (A-F): ADC #$06 + C=1 = effectively adds 7
;                   which is exactly the ASCII gap to bridge
;
; This avoids a separate SEC instruction before the add and
; removes the need for a branch over the adjustment.
;
; SHARED OutputNibble ENTRY POINT
; --------------------------------
; The procedure contains only ONE copy of the nibble-to-ASCII
; conversion code, reused for both the high and low nibble via
; a carefully structured fall-through:
;
;   high nibble path:
;     1. Save A on stack (PHA)
;     2. Shift high nibble into bits 3-0 (4× LSR)
;     3. JSR OutputNibble  → converts and outputs high nibble
;        KERNAL_CHROUT RTS returns here
;     4. Restore A (PLA)
;     5. Mask low nibble (AND #$0F)
;     6. Fall through into OutputNibble for the second nibble
;
;   low nibble path:
;     Falls directly into OutputNibble after step 6 above —
;     no JSR needed because execution naturally reaches it.
;     The final JMP KERNAL_CHROUT tail-calls the output
;     routine; KERNAL_CHROUT's RTS returns directly to whoever
;     called Output_ByteToHex (not to here), cleanly exiting.
;
; TAIL-CALL OPTIMISATION (JMP KERNAL_CHROUT)
; -------------------------------------------
; Instead of JSR KERNAL_CHROUT / RTS, the code uses JMP.
; When KERNAL_CHROUT executes its own RTS, the CPU pops the
; return address that Output_ByteToHex's original caller pushed
; — returning directly to the caller with no intermediate RTS.
; This saves 6 bytes and 12 cycles across the two nibble calls.
;
; ALGORITHM
; ---------
;   1. PHA              — save original byte value
;   2. LSR × 4          — shift bits 7-4 into bits 3-0 (high nibble)
;   3. JSR OutputNibble — convert and output high nibble character
;   4. PLA              — restore original byte value
;   5. AND #$0F         — isolate low nibble (bits 3-0)
;   [fall through into OutputNibble]
;   OutputNibble entry:
;   6. ORA #$30         — add ASCII '0' offset
;   7. CMP #$3A         — test: is result in A-F range?
;   8. BCC Output       — if 0-9: skip adjustment, go to output
;   9. ADC #$06         — if A-F: add 7 (C=1 from CMP, $06+1=$07)
;   Output entry:
;  10. JMP KERNAL_CHROUT — output character (tail call, RTS exits proc)
;
; REGISTER USE
; ------------
;   Entry : A = byte value to convert and display
;   Exit  : A = ASCII character of low nibble (after tail-call)
;
; DESTROYS  : A
; PRESERVES : X, Y, stack balanced (PHA matched by PLA)
;
; CYCLES    : ~44 cycles + 2× KERNAL_CHROUT call time
;             (4 LSR + JSR + 4× shared nibble path + PLA +
;              AND + fall-through nibble path + JMP)
;
; EXAMPLE
; -------
;     lda #$4f                  ; value to display
;     jsr OUTPUT_BYTETOHEX_PROC ; outputs "4F" to current channel
; ============================================================
OUTPUT_BYTETOHEX_PROC .proc

    pha                     ; save original byte — low nibble needed after
                            ; high nibble is extracted and output

    ; ── extract high nibble: bits 7-4 → bits 3-0 ────────────
    ; four logical right shifts move the upper nibble into the
    ; lower four bit positions, ready for nibble-to-ASCII conversion
    lsr                     ; A = A >> 1  bit 7 → bit 6
    lsr                     ; A = A >> 2  bit 7 → bit 5
    lsr                     ; A = A >> 3  bit 7 → bit 4
    lsr                     ; A = A >> 4  bit 7 → bit 3 (high nibble in bits 3-0)

    jsr OutputNibble        ; convert and output the high nibble character
                            ; KERNAL_CHROUT inside OutputNibble RTS back here

    ; ── extract low nibble: bits 3-0 ─────────────────────────
    pla                     ; restore the original byte value
    and #$0f                ; mask off upper nibble — keep only bits 3-0
                            ; execution falls straight into OutputNibble below

OutputNibble                ; ← also the JSR target for the high nibble above
    ; ── nibble-to-ASCII conversion ────────────────────────────
    ; at entry: A contains a nibble value in range $00-$0F
    ora #$30                ; add ASCII '0' ($30): maps 0-9 → '0'-'9'
                            ; and 10-15 → ':'-'?' (will be adjusted below)

    cmp #$3a                ; is result ≥ $3A (i.e. nibble was A-F)?
                            ; CMP sets C=1 if A ≥ $3A (A-F range)
                            ;         C=0 if A <  $3A (0-9 range)
    bcc Output              ; C=0: digit 0-9, no adjustment needed → output

    adc #$06                ; C=1 from CMP: ADC adds $06 + C($01) = $07
                            ; bridges the ASCII gap '9'($39) → 'A'($41):
                            ; e.g. nibble $0A → $30+$0A=$3A → $3A+$07=$41='A' ✓
                            ;      nibble $0F → $30+$0F=$3F → $3F+$07=$46='F' ✓

Output
    jmp KERNAL_CHROUT       ; tail call: output character in A
                            ; KERNAL_CHROUT's RTS returns directly to the
                            ; original caller of Output_ByteToHex — not here
.endproc

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
OUTPUT_BYTETOBINARY_PROC .proc
    ldx #7                  ; bit counter: 8 bits, indexed 7 downto 0
                            ; (MSB first: bit 7 output on first iteration)

loop
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
    bpl loop                ; branch while X ≥ 0 (sign flag clear)
                            ; after X=0: DEX → X=$FF, bit 7 set → BPL falls through

    rts                     ; all 8 bits output, return to caller
.endproc
