.include "labels_rom_kernal.s"

; Export the routines so they can be seen
.export OUTPUT_BYTETOHEX

.segment "CODE"

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
.proc OUTPUT_BYTETOHEX_PROC
	
    pha                     ; save original byte — low nibble needed after
                            ; high nibble is extracted and output

    ; ── extract high nibble: bits 7-4 → bits 3-0 ────────────
    ; four logical right shifts move the upper nibble into the
    ; lower four bit positions, ready for nibble-to-ASCII conversion
    lsr                     ; A = A >> 1  bit 7 → bit 6
    lsr                     ; A = A >> 2  bit 7 → bit 5
    lsr                     ; A = A >> 3  bit 7 → bit 4
    lsr                     ; A = A >> 4  bit 7 → bit 3 (high nibble in bits 3-0)

    jsr @nibble				; convert and output the high nibble character
                            ; KERNAL_CHROUT inside OutputNibble RTS back here

    ; ── extract low nibble: bits 3-0 ─────────────────────────
    pla                     ; restore the original byte value
    and #$0f                ; mask off upper nibble — keep only bits 3-0
                            ; execution falls straight into OutputNibble below

@nibble:					; ← also the JSR target for the high nibble above
    ; ── nibble-to-ASCII conversion ────────────────────────────
    ; at entry: A contains a nibble value in range $00-$0F
    ora #$30                ; add ASCII '0' ($30): maps 0-9 → '0'-'9'
                            ; and 10-15 → ':'-'?' (will be adjusted below)

    cmp #$3a                ; is result ≥ $3A (i.e. nibble was A-F)?
                            ; CMP sets C=1 if A ≥ $3A (A-F range)
                            ;         C=0 if A <  $3A (0-9 range)
    bcc @output				; C=0: digit 0-9, no adjustment needed → output

    adc #$06                ; C=1 from CMP: ADC adds $06 + C($01) = $07
                            ; bridges the ASCII gap '9'($39) → 'A'($41):
                            ; e.g. nibble $0A → $30+$0A=$3A → $3A+$07=$41='A' ✓
                            ;      nibble $0F → $30+$0F=$3F → $3F+$07=$46='F' ✓

@output:
    jmp KERNAL_CHROUT       ; tail call: output character in A
                            ; KERNAL_CHROUT's RTS returns directly to the
                            ; original caller of Output_ByteToHex — not here
.endproc

OUTPUT_BYTETOHEX = OUTPUT_BYTETOHEX_PROC
