
bank .proc
    ; Switching out BASIC ROM for RAM,
    ; provides us access to $A000-$BFFF = 8k RAM
romBasicOff
    sei
    lda R6510
    and #%11111110      ; BASIC ROM off, RAM on
    sta R6510
    cli
    rts

romBasicOn
    sei
    lda R6510
    ora #%00000001      ; BASIC ROM on, RAM off
    sta R6510
    cli
    rts
.endproc
