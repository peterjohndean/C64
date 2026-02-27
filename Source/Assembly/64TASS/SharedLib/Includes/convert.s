; ============================================================
; PROC: Output_ByteToHex
; Purpose : Convert a byte value to its two-character ASCII
;           hex representation and output via KERNAL
; Input   : A  - byte value to convert and display
; Destroys: Accumulator (A register)
; Cycles  : ~40 cycles + 2x KERNAL_CHROUT call time
; ============================================================
Output_ByteToHex .proc
    pha					; Preserve original A
    lsr					; Shift upper nibble into lower 4 bits
    lsr
    lsr
    lsr
    jsr OutputNibble	; Output high nibble
    pla
    and #$0F			; Mask to get low nibble
    
OutputNibble
    ora #$30            ; Add ASCII '0'
    cmp #$3A            ; If >= '9'+1
    bcc Output          ; ...then it's 0–9
    adc #$06            ; else convert to A–F
                        ; C=1 from CMP, so effectively adds 7
Output
    jmp KERNEL_CHROUT	; Output nibble, the kernel routine will rts
.endproc

; ============================================================
; PROC: OutputByteToBinary
; Purpose : Convert a byte value to its eight-character ASCII
;           binary representation and output via KERNAL
; Input   : A  - byte value to convert and display
;           X  - destroyed (used as bit counter)
; Destroys: Accumulator (A), X register
; Cycles  : ~8 * (~15 cycles + KERNAL_CHROUT call time)
; ============================================================
OutputByteToBinary .proc
    ldx #7				; 8 bits to output
loop
    asl					; Shift left, MSB → Carry
    pha					; Save A
    lda #0
    adc #'0'			; Convert carry to '0' or '1'
    jsr KERNEL_CHROUT	; Output binary value
    pla					; Restore A
    dex
    bpl loop
    rts
.endproc
