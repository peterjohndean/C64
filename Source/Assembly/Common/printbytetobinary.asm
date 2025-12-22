; ------------------------------------------------------------
; Print binary representation of A
; Output the byte in A as seven binary 1'/0's ASCII characters to channel.
; Input:
;	A = byte to convert and output
; Destroys:
;	A
; ------------------------------------------------------------
!zone OUTPUTBYTEASASCIIBINARY {
OutputByteToBinary:
    LDX #7				; 8 bits to output
.LOOP:
    ASL					; Shift left, MSB → Carry
    PHA					; Save A
    LDA #0
    ADC #'0'			; Convert carry to '0' or '1'
    jsr KERNEL_CHROUT	; Output binary value
    PLA					; Restore A
    DEX
    BPL .LOOP
    RTS
}
